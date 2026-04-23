import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

typedef ReverseGeocodeFn = Future<String?> Function(double lat, double lon);
typedef SearchAddressFn = Future<LatLng?> Function(String query);

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
  State<LocationPickerScreen> createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends State<LocationPickerScreen> {
  final MapController _mapController = MapController();
  final TextEditingController _addressController = TextEditingController();

  static const LatLng _defaultCenter = LatLng(38.7223, -9.1393); // Lisboa

  LatLng? _selectedPoint;
  String? _addressLabel;
  bool _isSearching = false;
  String? _searchError;

  @override
  void initState() {
    super.initState();
    if (widget.initialLatitude != null && widget.initialLongitude != null) {
      _selectedPoint = LatLng(
        widget.initialLatitude!,
        widget.initialLongitude!,
      );
    }
  }

  LatLng get _mapCenter => _selectedPoint ?? _defaultCenter;

  // ── Tap on map ────────────────────────────────────────────────
  void _onMapTap(TapPosition _, LatLng point) {
    setState(() {
      _selectedPoint = point;
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
          _selectedPoint = point;
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Choose Location'),
        actions: [
          if (_selectedPoint != null)
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
                    initialCenter: _mapCenter,
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
                    if (_selectedPoint != null)
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: _selectedPoint!,
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
                if (_selectedPoint == null)
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
          if (_selectedPoint != null)
            Container(
              color: Colors.grey.shade100,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Lat: ${_selectedPoint!.latitude.toStringAsFixed(5)}, '
                    'Lng: ${_selectedPoint!.longitude.toStringAsFixed(5)}',
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
