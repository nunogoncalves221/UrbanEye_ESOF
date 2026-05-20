import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
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

  Future<String?> _reverseGeocode(double lat, double lon) async {
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

  void _showReportInfo(BuildContext context, ReportModel report) {
    final color = _statusColors[report.status] ?? Colors.grey;
    final icon = _categoryIcons[report.category] ?? Icons.flag;
    final statusLabel = _statusLabels[report.status] ?? report.status;
    final user = FirebaseAuth.instance.currentUser;
    final reportService = const ReportService();

    final uploadDate =
        '${report.createdAt.day.toString().padLeft(2, '0')}/'
        '${report.createdAt.month.toString().padLeft(2, '0')}/'
        '${report.createdAt.year}  '
        '${report.createdAt.hour.toString().padLeft(2, '0')}:'
        '${report.createdAt.minute.toString().padLeft(2, '0')}';

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => StatefulBuilder(
        builder: (context, setModalState) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // drag handle
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),

                // category + status badge
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(icon, color: color, size: 22),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        report.category,
                        style: const TextStyle(
                            fontSize: 17, fontWeight: FontWeight.bold),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
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

                // description
                Text(
                  report.description,
                  style: const TextStyle(fontSize: 14, color: Colors.black87),
                ),
                const SizedBox(height: 14),

                Divider(color: Colors.grey.shade200, height: 1),
                const SizedBox(height: 12),

                // street name — fetch via reverse geocoding if not stored
                FutureBuilder<String?>(
                  future: report.address != null
                      ? Future.value(report.address)
                      : _reverseGeocode(report.latitude, report.longitude),
                  builder: (context, snapshot) {
                    final address = snapshot.data;
                    return _InfoRow(
                      icon: Icons.location_on_outlined,
                      iconColor: Colors.redAccent,
                      text: address ?? 'Loading address...',
                    );
                  },
                ),
                const SizedBox(height: 8),

                // upload date
                _InfoRow(
                  icon: Icons.calendar_today_outlined,
                  iconColor: Colors.blueAccent,
                  text: 'Reported on $uploadDate',
                ),
                const SizedBox(height: 8),

                // confirmations count
                Row(
                  children: [
                    _CountChip(
                      icon: Icons.thumb_up_alt_outlined,
                      count: report.existsConfirmations,
                      color: Colors.green,
                      label: 'Confirmed',
                    ),
                    const SizedBox(width: 10),
                    _CountChip(
                      icon: Icons.thumb_down_alt_outlined,
                      count: report.notExistsConfirmations,
                      color: Colors.red,
                      label: 'Denied',
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                const SizedBox(height: 8),

                // check for photo
                if (report.photoUrl != null)
                  TextButton.icon(
                    onPressed: () => _showPhoto(context, report.photoUrl!),
                    icon: const Icon(Icons.photo_camera),
                    label: const Text('photo'),
                  )
                else
                  const Text(
                    '-no photo taken-',
                    style: TextStyle(color: Colors.grey, fontSize: 14),
                  ),

                const SizedBox(height: 12),

                // confirm/deny buttons
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

  // create popup
  void _showPhoto(BuildContext context, String photoUrl) {
    showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (context) => Stack(
        children: [
          Center(
            child: InteractiveViewer(
              child: Image.network(photoUrl),
            ),
          ),
          // X button to close
          Positioned(
            top: 40,
            right: 20,
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white, size: 30),
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ],
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

// ── helper widgets ──────────────────────────────────────────────────────────

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String text;

  const _InfoRow({
    required this.icon,
    required this.iconColor,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 15, color: iconColor),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(fontSize: 13, color: Colors.black87),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _CountChip extends StatelessWidget {
  final IconData icon;
  final int count;
  final Color color;
  final String label;

  const _CountChip({
    required this.icon,
    required this.count,
    required this.color,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 5),
          Text(
            '$count $label',
            style: TextStyle(
                fontSize: 12, color: color, fontWeight: FontWeight.w600),
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