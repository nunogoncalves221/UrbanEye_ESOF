import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
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
        double.parse(results[0]['lat']),
        double.parse(results[0]['lon']),
      );
    }
  }
  return null;
}

// ───────────────────────────────────────────────────────────────
// WIDGET
// ───────────────────────────────────────────────────────────────
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
  State<LocationPickerScreen> createState() => _LocationPickerScreenState();
}

// ───────────────────────────────────────────────────────────────
// STATE
// ───────────────────────────────────────────────────────────────
class _LocationPickerScreenState extends State<LocationPickerScreen> {
  final MapController _mapController = MapController();
  final TextEditingController _addressController = TextEditingController();

  LatLng? _selectedPoint;
  LatLng? _currentLocation;

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

  // ─────────────────────────────────────────────────────────────
  // INIT
  // ─────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();

    _initLocation(); // 🔥 GPS AQUI

    if (widget.initialLatitude != null &&
        widget.initialLongitude != null) {
      _selectedPoint = LatLng(
        widget.initialLatitude!,
        widget.initialLongitude!,
      );
    }

    _loadExistingReports();
  }

  Future<void> _initLocation() async {
    final loc = await getCurrentLatLng();

    if (loc != null && mounted) {
      setState(() {
        _currentLocation = loc;
      });

      // opcional: move mapa logo para lá
      _mapController.move(loc, 15);
    }
  }

  // ─────────────────────────────────────────────────────────────
  Future<void> _loadExistingReports() async {
    try {
      final snapshot =
          await FirebaseFirestore.instance.collection('reports').get();

      final reports = snapshot.docs
          .map((doc) => ReportModel.fromMap(doc.id, doc.data()))
          .toList();

      if (mounted) {
        setState(() => _existingReports = reports);
      }
    } catch (_) {}
  }

  // ─────────────────────────────────────────────────────────────
  LatLng get _mapCenter =>
      _selectedPoint ??
      _currentLocation ??
      const LatLng(41.1496, -8.6109); // fallback aliados

  // ─────────────────────────────────────────────────────────────
  void _onMapTap(TapPosition _, LatLng point) {
    setState(() {
      _selectedPoint = point;
      _addressLabel = null;
      _searchError = null;
    });

    _reverseGeocode(point);
  }

  Future<void> _reverseGeocode(LatLng point) async {
    final label = await widget.reverseGeocode(
      point.latitude,
      point.longitude,
    );

    if (mounted) {
      setState(() => _addressLabel = label);
    }
  }

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
          _selectedPoint = point;
          _isSearching = false;
        });

        _mapController.move(point, 16);
        _reverseGeocode(point);
      } else {
        setState(() {
          _searchError = 'Address not found';
          _isSearching = false;
        });
      }
    } catch (_) {
      setState(() {
        _searchError = 'Search failed';
        _isSearching = false;
      });
    }
  }

  void _confirm() {
    if (_selectedPoint != null) {
      Navigator.pop(context, _selectedPoint);
    }
  }

  @override
  void dispose() {
    _addressController.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Choose Location'),
        actions: [
          if (_selectedPoint != null)
            TextButton(
              onPressed: _confirm,
              child: const Text('Confirm'),
            ),
        ],
      ),

      body: Column(
        children: [
          // SEARCH BAR
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _addressController,
                    decoration: InputDecoration(
                      hintText: 'Search address...',
                      border: const OutlineInputBorder(),
                      errorText: _searchError,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: _isSearching ? null : _searchAddress,
                  icon: const Icon(Icons.search),
                ),
              ],
            ),
          ),

          // MAP
          Expanded(
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: _mapCenter,
                initialZoom: 15,
                onTap: _onMapTap,
              ),
              children: [
                TileLayer(
                  urlTemplate:
                      'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                       userAgentPackageName: 'com.example.project',
                ),

                MarkerLayer(
                  markers: [
                    if (_selectedPoint != null)
                      Marker(
                        point: _selectedPoint!,
                        width: 50,
                        height: 50,
                        child: const Icon(
                          Icons.location_pin,
                          color: Colors.red,
                          size: 50,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),

          // CONFIRM
          if (_selectedPoint != null)
            Padding(
              padding: const EdgeInsets.all(12),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _confirm,
                  child: const Text('Confirm Location'),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
 