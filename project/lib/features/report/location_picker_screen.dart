import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'report_model.dart';
 
typedef ReverseGeocodeFn = Future<String?> Function(double lat, double lon);
typedef SearchAddressFn = Future<LatLng?> Function(String query);

// ───────────────────────────────────────────────────────────────
// GPS CURRENT LOCATION
// ───────────────────────────────────────────────────────────────
Future<LatLng?> getCurrentLatLng() async {
  LocationPermission permission = await Geolocator.checkPermission();

  if (permission == LocationPermission.denied) {
    permission = await Geolocator.requestPermission();
  }

  if (permission == LocationPermission.deniedForever) {
    return null;
  }

  final position = await Geolocator.getCurrentPosition(
    desiredAccuracy: LocationAccuracy.high,
  );

  return LatLng(position.latitude, position.longitude);
}

// ───────────────────────────────────────────────────────────────
// DEFAULT FUNCTIONS (mantidas iguais)
// ───────────────────────────────────────────────────────────────
Future<String?> defaultReverseGeocode(double lat, double lon) async {
  try {
    final uri = Uri.parse(
      'https://nominatim.openstreetmap.org/reverse'
      '?lat=$lat&lon=$lon&format=json',
    );
    final response = await http.get(
      uri,
      headers: {'User-Agent': 'project-app/1.0'},
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['display_name'] as String?;
    }
  } catch (_) {}
  return null;
}
 
Future<LatLng?> defaultSearchAddress(String query) async {
  final uri = Uri.parse(
    'https://nominatim.openstreetmap.org/search'
    '?q=${Uri.encodeComponent(query)}&format=json&limit=1',
  );
  final response = await http.get(
    uri,
    headers: {'User-Agent': 'project-app/1.0'},
  );
  if (response.statusCode == 200) {
    final List results = jsonDecode(response.body);
    if (results.isNotEmpty) {
      return LatLng(
        double.parse(results[0]['lat'] as String),
        double.parse(results[0]['lon'] as String),
      );
    }
  }
  return null;
}
 
class LocationPickerScreen extends StatefulWidget {
  final double? initialLatitude;
  final double? initialLongitude;
  final ReverseGeocodeFn reverseGeocode;
  final SearchAddressFn searchAddress;
 
  const LocationPickerScreen({
    super.key,
    this.initialLatitude,
    this.initialLongitude,
    this.reverseGeocode = defaultReverseGeocode,
    this.searchAddress = defaultSearchAddress,
  });
 
  @override
  State<LocationPickerScreen> createState() => LocationPickerScreenState();
}
 
class LocationPickerScreenState extends State<LocationPickerScreen> {
  final MapController _mapController = MapController();
  final TextEditingController _addressController = TextEditingController();
 
  static const LatLng _defaultCenter = LatLng(41.1496, -8.6109 ); // Porto
   
 
  LatLng? selectedPoint;
   LatLng? currentLocation;
  String? _addressLabel;
  bool _isSearching = false;
  String? _searchError;
  List<ReportModel> _existingReports = [];
 
  static const Map<String, IconData> _categoryIcons = {
    'Pothole': Icons.report_problem,
    'Streetlight': Icons.lightbulb_outline,
    'Street sign': Icons.signpost,
    'Traffic light': Icons.traffic,
    'Vandalism': Icons.format_paint,
    'Blocked Sidewalk': Icons.block,
    'Water leak/Flooding': Icons.water_damage,
    'Overgrown Vegetation': Icons.park,
    'Abandoned Vehicle': Icons.directions_car,
    'Trash': Icons.delete_outline,
  };
 
  static const Map<String, Color> _statusColors = {
    'pending': Colors.orange,
    'in_progress': Colors.blue,
    'resolved': Colors.green,
  };
 

 Future<void> _initLocation() async {
    final loc = await getCurrentLatLng();
    if (loc != null && mounted) {
      setState(() {
        currentLocation = loc;
      });

      _mapController.move(loc, 15);
    }
  }
  @override
void initState() {
  super.initState();

  _initLocation(); // chama sempre GPS

  if (widget.initialLatitude != null &&
      widget.initialLongitude != null) {
    selectedPoint = LatLng(
      widget.initialLatitude!,
      widget.initialLongitude!,
    );
  }

  _loadExistingReports();
}
 
  Future<void> _loadExistingReports() async {
    try {
      final snapshot =
          await FirebaseFirestore.instance.collection('reports').get();
      final reports = snapshot.docs
          .map((doc) => ReportModel.fromMap(doc.id, doc.data()))
          .toList();
      if (mounted) setState(() => _existingReports = reports);

      
    } catch (_) {}
  }
 
  LatLng get mapCenter =>
    selectedPoint ??
    currentLocation ??
    _defaultCenter;
  

 
  // ── Tap on map ────────────────────────────────────────────────
  void _onMapTap(TapPosition _, LatLng point) {
    setState(() {
      selectedPoint = point;
      _addressLabel = null;
      _searchError = null;
    });
    _reverseGeocode(point);
  }
 
  // ── Reverse geocode (coordinates → address label) ─────────────
  Future<void> _reverseGeocode(LatLng point) async {
    final label = await widget.reverseGeocode(point.latitude, point.longitude);
    if (mounted) setState(() => _addressLabel = label);
    
  }
 
  // ── Search by address ─────────────────────────────────────────
  Future<void> _searchAddress() async {
    final query = _addressController.text.trim();
    if (query.isEmpty) return;
 
    setState(() {
      _isSearching = true;
      _searchError = null;
    });
 
    try {
      final point = await widget.searchAddress(query);
      if (point != null) {
        setState(() {
          selectedPoint = point;
          _isSearching = false;
        });
        _mapController.move(point, 16);
        _reverseGeocode(point);
      } else {
        setState(() {
          _searchError = 'Address not found. Try a different query.';
          _isSearching = false;
        });
      }
    } catch (_) {
      setState(() {
        _searchError = 'Search failed. Check your connection.';
        _isSearching = false;
      });
    }
  }
 
  void _showReportInfo(ReportModel report) {
    final color = _statusColors[report.status] ?? Colors.grey;
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  _categoryIcons[report.category] ?? Icons.flag,
                  color: color,
                ),
                const SizedBox(width: 8),
                Text(
                  report.category,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    report.status,
                    style: TextStyle(
                        color: color,
                        fontSize: 12,
                        fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(report.description,
                style: const TextStyle(fontSize: 14)),
            const SizedBox(height: 8),
            Text(
              'Lat: ${report.latitude.toStringAsFixed(5)}, Lng: ${report.longitude.toStringAsFixed(5)}',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
 
  void _confirm() {
    if (selectedPoint != null) {
      Navigator.pop(context, selectedPoint);
    }
  }
 
  @override
  void dispose() {
    _addressController.dispose();
    super.dispose();
  }
 
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Choose Location'),
        actions: [
          if (selectedPoint != null)
            TextButton(
              onPressed: _confirm,
              child: const Text(
                'Confirm',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          // ── Address search bar ─────────────────────────────────
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _addressController,
                    decoration: InputDecoration(
                      hintText: 'Type a street address...',
                      border: const OutlineInputBorder(),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      errorText: _searchError,
                    ),
                    onSubmitted: (_) => _searchAddress(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  onPressed: _isSearching ? null : _searchAddress,
                  icon: _isSearching
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.search),
                ),
              ],
            ),
          ),
 
          // ── Map ───────────────────────────────────────────────
          Expanded(
            child: Stack(
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: mapCenter,
                    initialZoom: 13,
                    minZoom: 3,
                    maxZoom: 19,
                    onTap: _onMapTap,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.example.project',
                    ),
                    // ── Existing reports ────────────────────────
                    MarkerLayer(
                      markers: [
                        ..._existingReports.map((report) {
                          final color =
                              _statusColors[report.status] ?? Colors.grey;
                          final icon =
                              _categoryIcons[report.category] ?? Icons.flag;
                          return Marker(
                            point:
                                LatLng(report.latitude, report.longitude),
                            width: 36,
                            height: 36,
                            child: GestureDetector(
                              onTap: () => _showReportInfo(report),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: color.withValues(alpha: 0.9),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white,
                                    width: 2,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black26,
                                      blurRadius: 4,
                                      offset: Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Icon(icon,
                                    size: 18, color: Colors.white),
                              ),
                            ),
                          );
                        }),
                        // ── Selected pin ────────────────────────
                        if (selectedPoint != null)
                          Marker(
                            point: selectedPoint!,
                            width: 48,
                            height: 48,
                            child: const Icon(
                              Icons.location_pin,
                              size: 48,
                              color: Colors.red,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
 
                // Legend
                Positioned(
                  left: 12,
                  top: 12,
                  child: Card(
                    elevation: 3,
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _LegendDot(
                              color: Colors.orange, label: 'Pending'),
                          const SizedBox(height: 4),
                          _LegendDot(
                              color: Colors.blue, label: 'In Progress'),
                          const SizedBox(height: 4),
                          _LegendDot(
                              color: Colors.green, label: 'Resolved'),
                        ],
                      ),
                    ),
                  ),
                ),
 
                Positioned(
                  right: 16,
                  bottom: 80,
                  child: Column(
                    children: [
                      FloatingActionButton(
                        heroTag: 'zoomIn',
                        onPressed: () {
                          final current = _mapController.camera.zoom;
                          _mapController.move(
                            _mapController.camera.center,
                            current + 1,
                          );
                        },
                        child: const Icon(Icons.add),
                      ),
                      const SizedBox(height: 12),
                      FloatingActionButton(
                        heroTag: 'zoomOut',
                        onPressed: () {
                          final current = _mapController.camera.zoom;
                          _mapController.move(
                            _mapController.camera.center,
                            current - 1,
                          );
                        },
                        child: const Icon(Icons.remove),
                      ),
                    ],
                  ),
                ),
 
                // Hint overlay when nothing is selected yet
                if (selectedPoint == null)
                  const Positioned(
                    bottom: 24,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Card(
                        child: Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                          child: Text('Tap the map to place a pin'),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
 
          // ── Selected location info ─────────────────────────────
          if (selectedPoint != null)
            Container(
              color: Colors.grey.shade100,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Lat: ${selectedPoint!.latitude.toStringAsFixed(5)}, '
                    'Lng: ${selectedPoint!.longitude.toStringAsFixed(5)}',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  if (_addressLabel != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      _addressLabel!,
                      style: const TextStyle(fontSize: 13),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _confirm,
                      child: const Text('Confirm Location'),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
 
class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendDot({required this.color, required this.label});
 
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 11)),
      ],
    );
  }
}
 