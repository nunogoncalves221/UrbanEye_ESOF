import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:project/features/report/report_model.dart';
import 'package:project/services/report_service.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final MapController _mapController = MapController();
  static const LatLng _porto = LatLng(41.1496, -8.6109);
  double _currentZoom = 13;

  List<ReportModel> _reports = [];

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

  static const Map<String, String> _statusLabels = {
    'pending': 'Pending',
    'in_progress': 'In Progress',
    'resolved': 'Resolved',
  };

  @override
  void initState() {
    super.initState();
    _loadReports();
  }

  Future<void> _loadReports() async {
    try {
      final snapshot =
          await FirebaseFirestore.instance.collection('reports').get();
      final reports = snapshot.docs
          .map((doc) => ReportModel.fromMap(doc.id, doc.data()))
          .toList();
      if (mounted) setState(() => _reports = reports);
    } catch (_) {}
  }

  void _zoomIn() {
    _currentZoom += 1;
    _mapController.move(_mapController.camera.center, _currentZoom);
  }

  void _zoomOut() {
    _currentZoom -= 1;
    _mapController.move(_mapController.camera.center, _currentZoom);
  }

  void _showReportInfo(BuildContext context, ReportModel report) {
    final color = _statusColors[report.status] ?? Colors.grey;
    final icon = _categoryIcons[report.category] ?? Icons.flag;
    final statusLabel = _statusLabels[report.status] ?? report.status;
    final user = FirebaseAuth.instance.currentUser;
    final reportService = const ReportService();

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => StatefulBuilder(
        builder: (context, setModalState) {
          return Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(icon, color: color),
                    const SizedBox(width: 8),
                    Text(
                      report.category,
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold),
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
                        statusLabel,
                        style: TextStyle(
                            color: color,
                            fontSize: 12,
                            fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(report.description, style: const TextStyle(fontSize: 14)),
                const SizedBox(height: 8),
                Text(
                  'Lat: ${report.latitude.toStringAsFixed(5)}, Lng: ${report.longitude.toStringAsFixed(5)}',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 16),
                _buildConfirmationSection(
                  context,
                  report,
                  user,
                  reportService,
                  setModalState,
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // build the confirmation buttons or thank you message
  Widget _buildConfirmationSection(
    BuildContext context,
    ReportModel report,
    user,
    ReportService reportService,
    StateSetter setModalState,
  ) {
    if (user == null || user.uid == report.userId) {
      return const SizedBox.shrink();
    }

    return FutureBuilder<bool>(
      future: reportService.hasUserConfirmed(report.id!, user.uid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox.shrink();
        }

        if (snapshot.data == true) {
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.green.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text(
              'Thank you for your feedback!',
              style: TextStyle(
                color: Colors.green,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
          );
        }

        return Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => _handleConfirmation(
                  context,
                  report,
                  user.uid,
                  true,
                  reportService,
                  setModalState,
                ),
                icon: const Icon(Icons.check, color: Colors.white),
                label: const Text('Exists'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => _handleConfirmation(
                  context,
                  report,
                  user.uid,
                  false,
                  reportService,
                  setModalState,
                ),
                icon: const Icon(Icons.close, color: Colors.white),
                label: const Text("Doesn't exist"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  // handle user confirmation button click
  Future<void> _handleConfirmation(
    BuildContext context,
    ReportModel report,
    String userId,
    bool confirmed,
    ReportService reportService,
    StateSetter setModalState,
  ) async {
    await reportService.confirmProblem(report.id!, userId, confirmed);

    final exists = await reportService.checkReportExists(report.id!);
    if (!exists) {
      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('This issue no longer exists'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    setModalState(() {});

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Thank you for your feedback!'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: _porto,
            initialZoom: _currentZoom,
            minZoom: 3,
            maxZoom: 19,
            interactionOptions: const InteractionOptions(
              flags: InteractiveFlag.all,
            ),
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.example.project',
            ),
            MarkerLayer(
              markers: _reports.map((report) {
                final color = _statusColors[report.status] ?? Colors.grey;
                final icon = _categoryIcons[report.category] ?? Icons.flag;
                return Marker(
                  point: LatLng(report.latitude, report.longitude),
                  width: 36,
                  height: 36,
                  child: GestureDetector(
                    onTap: () => _showReportInfo(context, report),
                    child: Container(
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.9),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black26,
                            blurRadius: 4,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Icon(icon, size: 18, color: Colors.white),
                    ),
                  ),
                );
              }).toList(),
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
                  _LegendDot(color: Colors.orange, label: 'Pending'),
                  const SizedBox(height: 4),
                  _LegendDot(color: Colors.blue, label: 'In Progress'),
                  const SizedBox(height: 4),
                  _LegendDot(color: Colors.green, label: 'Resolved'),
                ],
              ),
            ),
          ),
        ),

        // Zoom buttons
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