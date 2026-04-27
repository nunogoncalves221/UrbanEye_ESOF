import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:project/features/report/report_screen.dart';
import 'package:project/features/auth/auth_screen.dart';
import 'package:project/features/auth/profile_screen.dart';
import 'package:project/services/report_service.dart';

class MainScreen extends StatefulWidget {
  final FirebaseAuth auth;
  final ReportServiceBase reportService;

  const MainScreen({
    super.key,
    required this.auth,
    this.reportService = const ReportService(),
  });

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  final MapController _mapController = MapController();
  final TextEditingController _addressController = TextEditingController();

  static const LatLng _defaultCenter = LatLng(38.7223, -9.1393); // Lisboa

  LatLng? _selectedPoint;
  bool _isSearching = false;

  LatLng get _mapCenter => _selectedPoint ?? _defaultCenter;

  // search by address
  Future<void> _searchAddress() async {
    final query = _addressController.text.trim();
    if (query.isEmpty) return;

    setState(() => _isSearching = true);

    try {
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
          final point = LatLng(
            double.parse(results[0]['lat'] as String),
            double.parse(results[0]['lon'] as String),
          );
          setState(() {
            _selectedPoint = point;
            _isSearching = false;
          });
          _mapController.move(point, 16);
        } else {
          setState(() => _isSearching = false);
        }
      } else {
        setState(() => _isSearching = false);
      }
    } catch (_) {
      setState(() => _isSearching = false);
    }
  }

  @override
  void dispose() {
    _addressController.dispose();
    super.dispose();
  }

  // navigate to ReportScreen
  void _openReport(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ReportScreen(auth: widget.auth)),
    );
  }

  // navigate to AuthScreen
  void _goToAuth(BuildContext context) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => AuthScreen(service: widget.reportService),
      ),
    );
  }

  // navigate to ProfileScreen
  void _goToProfile(BuildContext context) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => ProfileScreen(
          auth: widget.auth,
          service: widget.reportService,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // show map and report button
      appBar: AppBar(
        title: const Text('Home Screen'),
        automaticallyImplyLeading: false,
        actions: [
          StreamBuilder<User?>(
            stream: widget.auth.authStateChanges(),
            builder: (context, snapshot) {
              final user = snapshot.data;

              if (user == null) {
                //not logged in
                return TextButton(
                  onPressed: () => _goToAuth(context),
                  child: const Text('Login / Register'),
                );
              } else {
                //logged in
                return TextButton(
                  onPressed: () => _goToProfile(context),
                  child: const Text('Profile'),
                );
              }
            },
          ),
        ],
      ),

      body: Column(
        children: [
          // search bar
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _addressController,
                    decoration: InputDecoration(
                      hintText: 'Search for an address...',
                      border: const OutlineInputBorder(),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
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

          // map
          Expanded(
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: _mapCenter,
                initialZoom: 13,
                minZoom: 3,
                maxZoom: 19,
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
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
          ),

          // report button
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => _openReport(context),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 18),
                ),
                child: const Text(
                  'Report a Problem',
                  style: TextStyle(fontSize: 18),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
