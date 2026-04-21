import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class MapPrototypePage extends StatefulWidget {
  const MapPrototypePage({super.key});

  @override
  State<MapPrototypePage> createState() => _MapPrototypePageState();
}

class _MapPrototypePageState extends State<MapPrototypePage> {
  final MapController _mapController = MapController();
  final LatLng lisbon = LatLng(38.7223, -9.1393);
  double currentZoom = 13;

  void _zoomIn() {
    currentZoom += 1;
    _mapController.move(lisbon, currentZoom);
  }

  void _zoomOut() {
    currentZoom -= 1;
    _mapController.move(lisbon, currentZoom);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      //appBar: AppBar(
      //title: const Text('Mapa Prototype'),
      //),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: lisbon,
              initialZoom: currentZoom,
              minZoom: 3,
              maxZoom: 19,
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.all,
              ),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.prototype_app',
              ),
              MarkerLayer(
                markers: [
                  Marker(
                    point: lisbon,
                    width: 80,
                    height: 80,
                    child: const Icon(Icons.location_pin, size: 40),
                  ),
                ],
              ),
            ],
          ),
          Positioned(
            right: 16,
            bottom: 100,
            child: Column(
              children: [
                FloatingActionButton(
                  heroTag: 'zoomIn',
                  onPressed: _zoomIn,
                  child: const Icon(Icons.add),
                ),
                const SizedBox(height: 12),
                FloatingActionButton(
                  heroTag: 'zoomOut',
                  onPressed: _zoomOut,
                  child: const Icon(Icons.remove),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
