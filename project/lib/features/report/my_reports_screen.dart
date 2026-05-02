import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'report_model.dart';
import '../../services/report_service.dart';
import '../../services/user_role.dart';
import '../../services/user_role_service.dart';
import 'report_screen.dart';

class MyReportsScreen extends StatefulWidget {
  final FirebaseAuth? auth;
  final ReportServiceBase service;

  const MyReportsScreen({
    super.key,
    this.auth,
    this.service = const ReportService(),
  });

  @override
  State<MyReportsScreen> createState() => _MyReportsScreenState();
}

class _MyReportsScreenState extends State<MyReportsScreen> {
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

  UserRole _role = UserRole.citizen;
  FirebaseAuth get _auth => widget.auth ?? FirebaseAuth.instance;

  @override
  void initState() {
    super.initState();
    final user = _auth.currentUser;
    if (user != null) {
      const UserRoleService().getRole(user).then((role) {
        if (mounted) setState(() => _role = role);
      });
    }
  }

  Future<void> _confirmDelete(
    BuildContext context,
    ReportModel report,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Report'),
        content: const Text(
          'Are you sure you want to delete this report? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await widget.service.deleteReport(report);
        if (context.mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(const SnackBar(content: Text('Report deleted.')));
        }
      } catch (_) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to delete report.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _changeStatus(BuildContext context, ReportModel report) async {
    const statuses = ['pending', 'in_progress', 'resolved'];
    const labels = {
      'pending': 'Pending',
      'in_progress': 'In Progress',
      'resolved': 'Resolved',
    };
    const colors = {
      'pending': Colors.orange,
      'in_progress': Colors.blue,
      'resolved': Colors.green,
    };

    final newStatus = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Update Status'),
        children: statuses.map((s) {
          final isCurrent = report.status == s;
          final color = colors[s]!;
          return SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, s),
            child: Row(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration:
                      BoxDecoration(color: color, shape: BoxShape.circle),
                ),
                const SizedBox(width: 10),
                Text(
                  labels[s]!,
                  style: TextStyle(
                    fontWeight:
                        isCurrent ? FontWeight.bold : FontWeight.normal,
                    color: isCurrent ? color : null,
                  ),
                ),
                if (isCurrent) ...[
                  const SizedBox(width: 6),
                  Icon(Icons.check, size: 16, color: color),
                ],
              ],
            ),
          );
        }).toList(),
      ),
    );

    if (newStatus == null || newStatus == report.status) return;

    try {
      await widget.service.updateReportStatus(report.id!, newStatus);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Status updated to "${labels[newStatus] ?? newStatus}"'),
            backgroundColor: colors[newStatus],
          ),
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to update status.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser;
    final isAuthority = _role == UserRole.authority;

    return Scaffold(
      appBar: AppBar(
        title: Text(isAuthority ? 'All Reports' : 'My Reports'),
        actions: [
          if (!isAuthority)
            IconButton(
              icon: const Icon(Icons.add),
              tooltip: 'New Report',
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => ReportScreen(auth: widget.auth)),
              ),
            ),
        ],
      ),
      body: user == null
          ? const Center(
              child: Text(
                'You must be signed in to view your reports.',
                textAlign: TextAlign.center,
              ),
            )
          : StreamBuilder<List<ReportModel>>(
              stream: isAuthority
                  ? widget.service.watchAllReports()
                  : widget.service.watchReportsByUser(user.uid),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.error_outline,
                            size: 48, color: Colors.red),
                        const SizedBox(height: 12),
                        Text(
                          'Failed to load reports.\n${snapshot.error}',
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
                }

                final reports = snapshot.data ?? [];

                if (reports.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.inbox_outlined,
                            size: 64, color: Colors.grey.shade400),
                        const SizedBox(height: 16),
                        Text(
                          'No reports yet.',
                          style: TextStyle(
                              fontSize: 18, color: Colors.grey.shade600),
                        ),
                        if (!isAuthority) ...[
                          const SizedBox(height: 8),
                          Text(
                            'Tap + to report a problem.',
                            style: TextStyle(color: Colors.grey.shade500),
                          ),
                        ],
                      ],
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: reports.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final report = reports[index];
                    final statusColor =
                        _statusColors[report.status] ?? Colors.grey;
                    final statusLabel =
                        _statusLabels[report.status] ?? report.status;
                    final categoryIcon =
                        _categoryIcons[report.category] ?? Icons.flag;

                    return Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => _showReportDetail(context, report),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .primaryContainer,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(
                                  categoryIcon,
                                  color:
                                      Theme.of(context).colorScheme.primary,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            report.category,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 15,
                                            ),
                                          ),
                                        ),
                                        // Status chip — clicável para authority
                                        GestureDetector(
                                          onTap: isAuthority
                                              ? () => _changeStatus(
                                                  context, report)
                                              : null,
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 8, vertical: 3),
                                            decoration: BoxDecoration(
                                              color: statusColor.withValues(
                                                  alpha: 0.2),
                                              borderRadius:
                                                  BorderRadius.circular(20),
                                              border: Border.all(
                                                  color: statusColor.withValues(
                                                      alpha: 0.2)),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Text(
                                                  statusLabel,
                                                  style: TextStyle(
                                                    color: statusColor,
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                                if (isAuthority) ...[
                                                  const SizedBox(width: 4),
                                                  Icon(Icons.edit,
                                                      size: 11,
                                                      color: statusColor),
                                                ],
                                              ],
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      report.description,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: Colors.grey.shade600,
                                        fontSize: 13,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Row(
                                      children: [
                                        Icon(Icons.location_on_outlined,
                                            size: 13,
                                            color: Colors.grey.shade500),
                                        const SizedBox(width: 3),
                                        Text(
                                          '${report.latitude.toStringAsFixed(4)}, '
                                          '${report.longitude.toStringAsFixed(4)}',
                                          style: TextStyle(
                                              fontSize: 11,
                                              color: Colors.grey.shade500),
                                        ),
                                        const Spacer(),
                                        Icon(Icons.access_time,
                                            size: 12,
                                            color: Colors.grey.shade400),
                                        const SizedBox(width: 3),
                                        Text(
                                          _formatDate(report.createdAt),
                                          style: TextStyle(
                                              fontSize: 11,
                                              color: Colors.grey.shade400),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              if (!isAuthority)
                                IconButton(
                                  icon: const Icon(Icons.delete_outline,
                                      color: Colors.redAccent),
                                  tooltip: 'Delete',
                                  onPressed: () =>
                                      _confirmDelete(context, report),
                                ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
    );
  }

  void _showReportDetail(BuildContext context, ReportModel report) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _ReportDetailSheet(
        report: report,
        isAuthority: _role == UserRole.authority,
        onChangeStatus: () => _changeStatus(context, report),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}';
  }
}

class _ReportDetailSheet extends StatelessWidget {
  final ReportModel report;
  final bool isAuthority;
  final VoidCallback onChangeStatus;

  const _ReportDetailSheet({
    required this.report,
    required this.isAuthority,
    required this.onChangeStatus,
  });

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
  Widget build(BuildContext context) {
    final statusColor = _statusColors[report.status] ?? Colors.grey;
    final statusLabel = _statusLabels[report.status] ?? report.status;

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      maxChildSize: 0.95,
      minChildSize: 0.4,
      expand: false,
      builder: (_, scrollController) {
        return SingleChildScrollView(
          controller: scrollController,
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                report.category,
                style: const TextStyle(
                    fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              if (report.photoUrl != null) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    report.photoUrl!,
                    height: 200,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      height: 100,
                      color: Colors.grey.shade200,
                      child: const Center(
                          child: Icon(Icons.broken_image, size: 40)),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              _DetailRow(
                icon: Icons.description_outlined,
                label: 'Description',
                value: report.description,
              ),
              const SizedBox(height: 12),
              _DetailRow(
                icon: Icons.location_on_outlined,
                label: 'Location',
                value:
                    'Lat ${report.latitude.toStringAsFixed(5)}, Lng ${report.longitude.toStringAsFixed(5)}',
              ),
              const SizedBox(height: 12),
              // Status row — authority pode clicar para mudar
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline,
                      size: 20,
                      color: Theme.of(context).colorScheme.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Status',
                            style: TextStyle(
                                fontSize: 12, color: Colors.grey.shade500)),
                        const SizedBox(height: 4),
                        GestureDetector(
                          onTap: isAuthority ? onChangeStatus : null,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: statusColor.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                  color: statusColor.withValues(alpha: 0.4)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  statusLabel,
                                  style: TextStyle(
                                    color: statusColor,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                if (isAuthority) ...[
                                  const SizedBox(width: 6),
                                  Icon(Icons.edit,
                                      size: 14, color: statusColor),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _DetailRow(
                icon: Icons.calendar_today_outlined,
                label: 'Submitted',
                value:
                    '${report.createdAt.day.toString().padLeft(2, '0')}/${report.createdAt.month.toString().padLeft(2, '0')}/${report.createdAt.year} '
                    '${report.createdAt.hour.toString().padLeft(2, '0')}:${report.createdAt.minute.toString().padLeft(2, '0')}',
              ),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style:
                      TextStyle(fontSize: 12, color: Colors.grey.shade500)),
              Text(value, style: const TextStyle(fontSize: 15)),
            ],
          ),
        ),
      ],
    );
  }
}
