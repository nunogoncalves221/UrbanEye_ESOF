import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:project/services/points_service.dart';
import 'package:project/features/notifications/notification_bell.dart';
import 'package:project/services/notification_service.dart';
import 'package:project/services/report_service.dart';
import 'package:project/services/user_role.dart';
import 'package:project/services/user_role_service.dart';
import 'report_model.dart';

enum _SortField { date, status, priority, category, location }

enum _SortDirection { asc, desc }

class AllReportsScreen extends StatefulWidget {
  const AllReportsScreen({super.key});

  @override
  State<AllReportsScreen> createState() => _AllReportsScreenState();
}

class _AllReportsScreenState extends State<AllReportsScreen> {
  List<ReportModel> _allReports = [];
  bool _loading = true;
  String? _error;
  bool _isAuthority = false;

  Set<String> _favouriteIds = {};
  bool _filterFavourites = false;
  String? _filterStatus;
  String? _filterPriority;
  String? _filterCategory;
  String? _filterZone;

  _SortField _sortField = _SortField.date;
  _SortDirection _sortDir = _SortDirection.desc;

  static const Map<String, Color> _statusColors = {
    'pending': Colors.orange,
    'in_progress': Colors.blue,
    'resolved': Colors.green,
  };

  static const Map<String, Color> _priorityColors = {
    'low': Colors.grey,
    'medium': Colors.amber,
    'high': Colors.red,
  };

  static const Map<String, String> _priorityLabels = {
    'low': 'Low Priority',
    'medium': 'Medium Priority',
    'high': 'High Priority',
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

  static const Set<String> _knownCategories = {
    'Pothole',
    'Streetlight',
    'Street sign',
    'Traffic light',
    'Vandalism',
    'Blocked Sidewalk',
    'Water leak/Flooding',
    'Overgrown Vegetation',
    'Abandoned Vehicle',
    'Trash',
  };

  @override
  void initState() {
    super.initState();
    _loadReports();
    _loadRole();
    _loadFavourites();
  }

  Future<void> _loadRole() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final role = await const UserRoleService().getRole(user);
    if (mounted) {
      setState(() => _isAuthority = role == UserRole.authority);
    }
  }

  Future<void> _loadFavourites() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final ids = await ReportService().getUserFavouriteIds(user.uid);
    if (mounted) setState(() => _favouriteIds = ids);
  }

  Future<void> _toggleFavourite(ReportModel report) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || report.id == null) return;
    try {
      await ReportService().toggleFavourite(report.id!, user.uid);
      setState(() {
        if (_favouriteIds.contains(report.id)) {
          _favouriteIds.remove(report.id);
        } else {
          _favouriteIds.add(report.id!);
        }
      });
    } catch (_) {}
  }

  Future<void> _updatePriority(ReportModel report, String newPriority) async {
    try {
      await FirebaseFirestore.instance
          .collection('reports')
          .doc(report.id)
          .update({'priority': newPriority});
      unawaited(NotificationService().notifyReportChange(
        reportId: report.id!,
        reportCategory: report.category,
        type: 'priority_change',
        message: 'Report "${report.category}" priority set to $newPriority.',
        reportOwnerId: report.userId,
      ));
      setState(() {
        final idx = _allReports.indexWhere((r) => r.id == report.id);
        if (idx != -1) {
          _allReports[idx] = ReportModel(
            id: report.id,
            category: report.category,
            description: report.description,
            latitude: report.latitude,
            longitude: report.longitude,
            photoUrl: report.photoUrl,
            userId: report.userId,
            status: report.status,
            priority: newPriority,
            createdAt: report.createdAt,
            address: report.address,
            authorityConfirmed: report.authorityConfirmed,
          );
        }
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update priority: $e')),
        );
      }
    }
  }

  Future<void> _loadReports() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('reports')
          .get();
      final reports = snapshot.docs
          .map((doc) => ReportModel.fromMap(doc.id, doc.data()))
          .toList();
      if (mounted) {
        setState(() {
          _allReports = reports;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  List<String> get _zones {
    final zones = <String>{};
    for (final r in _allReports) {
      final zone = _extractZone(r);
      if (zone != null) zones.add(zone);
    }
    return zones.toList()..sort();
  }

  String? _extractZone(ReportModel r) {
    if (r.address == null || r.address!.isEmpty) return null;
    final parts = r.address!.split(',');
    if (parts.length >= 2) return parts[parts.length - 2].trim();
    return parts.first.trim();
  }

  List<String> get _categories {
    final cats = _allReports.map((r) => r.category).toSet().toList();
    return cats..sort();
  }

  List<ReportModel> get _filtered {
    var list = _allReports.where((r) {
      if (_filterFavourites && !_favouriteIds.contains(r.id)) return false;
      if (_filterStatus != null && r.status != _filterStatus) return false;
      if (_isAuthority &&
          _filterPriority != null &&
          r.priority != _filterPriority)
        return false;
      if (_filterCategory != null) {
        if (_filterCategory == '__other__') {
          if (_knownCategories.contains(r.category)) return false;
        } else {
          if (r.category != _filterCategory) return false;
        }
      }
      if (_filterZone != null && _extractZone(r) != _filterZone) return false;
      return true;
    }).toList();

    list.sort((a, b) {
      int cmp;
      switch (_sortField) {
        case _SortField.date:
          cmp = a.createdAt.compareTo(b.createdAt);
          break;
        case _SortField.status:
          cmp = a.status.compareTo(b.status);
          break;
        case _SortField.category:
          cmp = a.category.compareTo(b.category);
          break;
        case _SortField.priority:
          int w(String? p) {
            switch (p?.toLowerCase()) {
              case 'high':
                return 3;
              case 'medium':
                return 2;
              default:
                return 1;
            }
          }
          cmp = w(a.priority).compareTo(w(b.priority));
          break;
        case _SortField.location:
          cmp = (_extractZone(a) ?? '').compareTo(_extractZone(b) ?? '');
          break;
      }
      return _sortDir == _SortDirection.asc ? cmp : -cmp;
    });

    return list;
  }

  String _formatDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/'
      '${d.month.toString().padLeft(2, '0')}/'
      '${d.year}';

  bool get _hasActiveFilters =>
      _filterFavourites ||
      _filterStatus != null ||
      _filterPriority != null ||
      _filterCategory != null ||
      _filterZone != null;

  void _clearFilters() => setState(() {
    _filterFavourites = false;
    _filterStatus = null;
    _filterPriority = null;
    _filterCategory = null;
    _filterZone = null;
  });

  Future<void> _updateStatus(ReportModel report, String newStatus) async {
    if (report.status == newStatus) return;

    try {
      await FirebaseFirestore.instance
          .collection('reports')
          .doc(report.id)
          .update({'status': newStatus});
      unawaited(NotificationService().notifyReportChange(
        reportId: report.id!,
        reportCategory: report.category,
        type: 'status_change',
        message: 'Report "${report.category}" status changed to $newStatus.',
        reportOwnerId: report.userId,
      ));
      setState(() {
        final idx = _allReports.indexWhere((r) => r.id == report.id);
        if (idx != -1) {
          _allReports[idx] = ReportModel(
            id: report.id,
            category: report.category,
            description: report.description,
            latitude: report.latitude,
            longitude: report.longitude,
            photoUrl: report.photoUrl,
            userId: report.userId,
            status: newStatus,
            priority: report.priority,
            createdAt: report.createdAt,
            address: report.address,
            authorityConfirmed: report.authorityConfirmed,
          );
        }
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to update status: $e')));
      }
      return;
    }

    if (newStatus == 'resolved') {
      try {
        await PointsService().onReportResolved(report.id!, report.userId);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Points error: $e')),
          );
        }
      }
    }
  }

  void _showFilterSort() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _FilterSortSheet(
        isAuthority: _isAuthority,
        isLoggedIn: FirebaseAuth.instance.currentUser != null,
        zones: _zones,
        categories: _categories,
        filterFavourites: _filterFavourites,
        filterStatus: _filterStatus,
        filterPriority: _filterPriority,
        filterCategory: _filterCategory,
        filterZone: _filterZone,
        sortField: _sortField,
        sortDir: _sortDir,
        onApply:
            (status, priority, category, zone, field, dir, favouritesOnly) {
              setState(() {
                _filterFavourites = favouritesOnly;
                _filterStatus = status;
                _filterPriority = priority;
                _filterCategory = category;
                _filterZone = zone;
                _sortField = field;
                _sortDir = dir;
              });
            },
      ),
    );
  }

  Future<String?> _reverseGeocode(double lat, double lon) async {
    try {
      final uri = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?lat=$lat&lon=$lon&format=json',
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

  void _showReportDetail(BuildContext context, ReportModel report) {
    final color = _statusColors[report.status] ?? Colors.grey;
    final icon = _categoryIcons[report.category] ?? Icons.flag;
    final statusLabel = _statusLabels[report.status] ?? report.status;
    final user = FirebaseAuth.instance.currentUser;
    final reportService = ReportService();

    final uploadDate =
        '${report.createdAt.day.toString().padLeft(2, '0')}/'
        '${report.createdAt.month.toString().padLeft(2, '0')}/'
        '${report.createdAt.year}  '
        '${report.createdAt.hour.toString().padLeft(2, '0')}:'
        '${report.createdAt.minute.toString().padLeft(2, '0')}';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => StatefulBuilder(
        builder: (context, setModalState) {
          return Padding(
            padding: EdgeInsets.fromLTRB(
              20,
              16,
              20,
              MediaQuery.of(context).viewInsets.bottom + 24,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        statusLabel,
                        style: TextStyle(
                          color: color,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  report.description,
                  style: const TextStyle(fontSize: 14, color: Colors.black87),
                ),
                const SizedBox(height: 14),
                Divider(color: Colors.grey.shade200, height: 1),
                const SizedBox(height: 12),
                FutureBuilder<String?>(
                  future: report.address != null
                      ? Future.value(report.address)
                      : _reverseGeocode(report.latitude, report.longitude),
                  builder: (context, snapshot) => _InfoRow(
                    icon: Icons.location_on_outlined,
                    iconColor: Colors.redAccent,
                    text: snapshot.data ?? 'Loading address...',
                  ),
                ),
                const SizedBox(height: 8),
                _InfoRow(
                  icon: Icons.calendar_today_outlined,
                  iconColor: Colors.blueAccent,
                  text: 'Reported on $uploadDate',
                ),
                const SizedBox(height: 12),
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

                const SizedBox(height: 16),
                // ── secção de acções (authority vs user normal) ──
                _buildActionSection(
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
          Center(child: InteractiveViewer(child: Image.network(photoUrl))),
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

  Widget _buildActionSection(
    BuildContext context,
    ReportModel report,
    user,
    ReportService reportService,
    StateSetter setModalState,
  ) {
    if (user == null) return const SizedBox.shrink();

    // ── AUTHORITY ──
    if (_isAuthority) {
      // Se já foi confirmado pela authority, mostrar badge
      if (report.authorityConfirmed) {
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.green.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.verified, color: Colors.green, size: 18),
              SizedBox(width: 8),
              Text(
                'Report confirmed by authority',
                style: TextStyle(
                  color: Colors.green,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        );
      }

      // Botões Confirm / Reject
      return Row(
        children: [
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () => _handleAuthorityConfirm(
                context,
                report,
                reportService,
                setModalState,
              ),
              icon: const Icon(Icons.verified_outlined, color: Colors.white),
              label: const Text('Confirm Report'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () =>
                  _handleAuthorityReject(context, report, reportService),
              icon: const Icon(Icons.delete_outline, color: Colors.white),
              label: const Text('Reject Report'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
            ),
          ),
        ],
      );
    }

    // ── USER NORMAL ──
    // Se a authority já confirmou, não pedir confirmação ao user
    if (report.authorityConfirmed) return const SizedBox.shrink();

    // O próprio criador não confirma o próprio report
    if (user.uid == report.userId) return const SizedBox.shrink();

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
                onPressed: () => _handleUserConfirmation(
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
                onPressed: () => _handleUserConfirmation(
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

  // Authority confirma o report
  Future<void> _handleAuthorityConfirm(
    BuildContext context,
    ReportModel report,
    ReportService reportService,
    StateSetter setModalState,
  ) async {
    await reportService.confirmReportByAuthority(report.id!);
    unawaited(NotificationService().notifyReportChange(
      reportId: report.id!,
      reportCategory: report.category,
      type: 'authority_confirmed',
      message: 'Report "${report.category}" was confirmed by the authority.',
      reportOwnerId: report.userId,
    ));

    // Actualizar lista local
    setState(() {
      final idx = _allReports.indexWhere((r) => r.id == report.id);
      if (idx != -1) {
        _allReports[idx] = ReportModel(
          id: report.id,
          category: report.category,
          description: report.description,
          latitude: report.latitude,
          longitude: report.longitude,
          photoUrl: report.photoUrl,
          userId: report.userId,
          status: report.status,
          priority: report.priority,
          createdAt: report.createdAt,
          address: report.address,
          authorityConfirmed: true,
        );
      }
    });

    // Actualizar o modal sem fechar
    setModalState(() {});

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Report confirmed successfully.'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  // Authority rejeita (apaga) o report
  Future<void> _handleAuthorityReject(
    BuildContext context,
    ReportModel report,
    ReportService reportService,
  ) async {
    // Diálogo de confirmação antes de apagar
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reject Report'),
        content: const Text(
          'Are you sure you want to reject and permanently delete this report?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    await PointsService().onReportRejected(report.userId);
    // Notificar antes de apagar (favoritos ainda existem no Firestore)
    await NotificationService().notifyReportChange(
      reportId: report.id!,
      reportCategory: report.category,
      type: 'authority_rejected',
      message: 'Report "${report.category}" was rejected by the authority.',
      reportOwnerId: report.userId,
    );

    await reportService.deleteReport(report);

    // Remover da lista local
    setState(() => _allReports.removeWhere((r) => r.id == report.id));

    if (context.mounted) {
      Navigator.pop(context); // fechar o bottom sheet
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Report rejected and deleted.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // User normal confirma/nega
  Future<void> _handleUserConfirmation(
    BuildContext context,
    ReportModel report,
    String userId,
    bool confirmed,
    ReportService reportService,
    StateSetter setModalState,
  ) async {
    try {
      await reportService.confirmProblem(report.id!, userId, confirmed);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Confirmation error: $e')),
        );
      }
      return;
    }

    final exists = await reportService.checkReportExists(report.id!);
    if (!exists) {
      setState(() => _allReports.removeWhere((r) => r.id == report.id));
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('All Reports'),
        actions: [
          const NotificationBell(),
          if (_hasActiveFilters)
            TextButton(
              onPressed: _clearFilters,
              child: const Text('Clear filters'),
            ),
          IconButton(
            icon: Badge(
              isLabelVisible: _hasActiveFilters,
              child: const Icon(Icons.tune),
            ),
            tooltip: 'Filter & Sort',
            onPressed: _showFilterSort,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: Colors.red),
                  const SizedBox(height: 12),
                  Text(
                    'Failed to load reports.\n$_error',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _loading = true;
                        _error = null;
                      });
                      _loadReports();
                    },
                    child: const Text('Retry'),
                  ),
                ],
              ),
            )
          : _buildList(),
    );
  }

  Widget _buildList() {
    final reports = _filtered;

    if (reports.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.inbox_outlined, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              _hasActiveFilters
                  ? 'No reports match the current filters.'
                  : 'No reports found.',
              style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
              textAlign: TextAlign.center,
            ),
            if (_hasActiveFilters) ...[
              const SizedBox(height: 8),
              TextButton(
                onPressed: _clearFilters,
                child: const Text('Clear filters'),
              ),
            ],
          ],
        ),
      );
    }

    return Column(
      children: [
        if (_hasActiveFilters)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  if (_filterFavourites)
                    _FilterChip(
                      label: 'Favourites',
                      color: Colors.amber,
                      onRemove: () => setState(() => _filterFavourites = false),
                    ),
                  if (_filterStatus != null)
                    _FilterChip(
                      label: _statusLabels[_filterStatus!] ?? _filterStatus!,
                      color: _statusColors[_filterStatus!] ?? Colors.grey,
                      onRemove: () => setState(() => _filterStatus = null),
                    ),
                  if (_isAuthority && _filterPriority != null)
                    _FilterChip(
                      label:
                          _priorityLabels[_filterPriority!] ?? _filterPriority!,
                      color: _priorityColors[_filterPriority!] ?? Colors.grey,
                      onRemove: () => setState(() => _filterPriority = null),
                    ),
                  if (_filterCategory != null)
                    _FilterChip(
                      label: _filterCategory == '__other__'
                          ? 'Other'
                          : _filterCategory!,
                      onRemove: () => setState(() => _filterCategory = null),
                    ),
                  if (_filterZone != null)
                    _FilterChip(
                      label: _filterZone!,
                      onRemove: () => setState(() => _filterZone = null),
                    ),
                ],
              ),
            ),
          ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Row(
            children: [
              Text(
                '${reports.length} report${reports.length == 1 ? '' : 's'}',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
              ),
              const Spacer(),
              GestureDetector(
                onTap: _showFilterSort,
                child: Row(
                  children: [
                    Icon(
                      _sortDir == _SortDirection.asc
                          ? Icons.arrow_upward
                          : Icons.arrow_downward,
                      size: 14,
                      color: Colors.grey.shade600,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _sortFieldLabel(_sortField),
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            itemCount: reports.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, i) => ReportCard(
              report: reports[i],
              statusColors: _statusColors,
              statusLabels: _statusLabels,
              priorityColors: _priorityColors,
              priorityLabels: _priorityLabels,
              categoryIcons: _categoryIcons,
              formatDate: _formatDate,
              extractZone: _extractZone,
              isAuthority: _isAuthority,
              isFavourite: _favouriteIds.contains(reports[i].id),
              onStatusChanged: _isAuthority
                  ? (newStatus) => _updateStatus(reports[i], newStatus)
                  : null,
              onPriorityChanged: _isAuthority
                  ? (newPriority) => _updatePriority(reports[i], newPriority)
                  : null,
              onFavouriteToggle: FirebaseAuth.instance.currentUser != null
                  ? () => _toggleFavourite(reports[i])
                  : null,
              onTap: () => _showReportDetail(context, reports[i]),
            ),
          ),
        ),
      ],
    );
  }

  String _sortFieldLabel(_SortField f) {
    switch (f) {
      case _SortField.date:
        return 'Date';
      case _SortField.status:
        return 'Status';
      case _SortField.priority:
        return 'Priority';
      case _SortField.category:
        return 'Category';
      case _SortField.location:
        return 'Location';
    }
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
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class ReportCard extends StatelessWidget {
  final ReportModel report;
  final Map<String, Color> statusColors;
  final Map<String, String> statusLabels;
  final Map<String, Color> priorityColors;
  final Map<String, String> priorityLabels;
  final Map<String, IconData> categoryIcons;
  final String Function(DateTime) formatDate;
  final String? Function(ReportModel) extractZone;
  final bool isAuthority;
  final bool isFavourite;
  final void Function(String newStatus)? onStatusChanged;
  final void Function(String newPriority)? onPriorityChanged;
  final VoidCallback? onFavouriteToggle;
  final VoidCallback? onTap;

  const ReportCard({
    required this.report,
    required this.statusColors,
    required this.statusLabels,
    required this.priorityColors,
    required this.priorityLabels,
    required this.categoryIcons,
    required this.formatDate,
    required this.extractZone,
    this.isAuthority = false,
    this.isFavourite = false,
    this.onStatusChanged,
    this.onPriorityChanged,
    this.onFavouriteToggle,
    this.onTap,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final statusColor = statusColors[report.status] ?? Colors.grey;
    final statusLabel = statusLabels[report.status] ?? report.status;
    final categoryIcon = categoryIcons[report.category] ?? Icons.flag;
    final zone = extractZone(report);

    final currentPriority = report.priority?.toLowerCase() ?? 'low';
    final priorityColor = priorityColors[currentPriority] ?? Colors.grey;
    final priorityLabel = priorityLabels[currentPriority] ?? currentPriority;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  categoryIcon,
                  color: Theme.of(context).colorScheme.primary,
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
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Status badge / dropdown
                        isAuthority && onStatusChanged != null
                            ? PopupMenuButton<String>(
                                padding: EdgeInsets.zero,
                                tooltip: 'Change status',
                                onSelected: onStatusChanged,
                                itemBuilder: (_) => statusLabels.entries
                                    .map(
                                      (e) => PopupMenuItem(
                                        value: e.key,
                                        child: Row(
                                          children: [
                                            Container(
                                              width: 10,
                                              height: 10,
                                              margin: const EdgeInsets.only(
                                                right: 8,
                                              ),
                                              decoration: BoxDecoration(
                                                color:
                                                    statusColors[e.key] ??
                                                    Colors.grey,
                                                shape: BoxShape.circle,
                                              ),
                                            ),
                                            Text(e.value),
                                          ],
                                        ),
                                      ),
                                    )
                                    .toList(),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: statusColor.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(12),
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
                                      const SizedBox(width: 3),
                                      Icon(
                                        Icons.arrow_drop_down,
                                        size: 14,
                                        color: statusColor,
                                      ),
                                    ],
                                  ),
                                ),
                              )
                            : Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: statusColor.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  statusLabel,
                                  style: TextStyle(
                                    color: statusColor,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                        // Priority badge (authority only)
                        if (isAuthority) ...[
                          const SizedBox(width: 6),
                          PopupMenuButton<String>(
                            padding: EdgeInsets.zero,
                            tooltip: 'Change priority',
                            onSelected: (v) => onPriorityChanged?.call(v),
                            itemBuilder: (_) => priorityLabels.entries
                                .map(
                                  (e) => PopupMenuItem(
                                    value: e.key,
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 10,
                                          height: 10,
                                          margin: const EdgeInsets.only(
                                            right: 8,
                                          ),
                                          decoration: BoxDecoration(
                                            color:
                                                priorityColors[e.key] ??
                                                Colors.grey,
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                        Text(e.value),
                                      ],
                                    ),
                                  ),
                                )
                                .toList(),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: priorityColor.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    priorityLabel,
                                    style: TextStyle(
                                      color: priorityColor,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(width: 3),
                                  Icon(
                                    Icons.arrow_drop_down,
                                    size: 14,
                                    color: priorityColor,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                        // Verified badge no card se confirmado pela authority
                        if (report.authorityConfirmed) ...[
                          const SizedBox(width: 6),
                          const Tooltip(
                            message: 'Confirmed by authority',
                            child: Icon(
                              Icons.verified,
                              size: 16,
                              color: Colors.green,
                            ),
                          ),
                        ],
                        _FavouriteButton(
                          isFavourite: isFavourite,
                          onToggle: onFavouriteToggle,
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
                        if (report.address != null) ...[
                          Icon(
                            Icons.location_on_outlined,
                            size: 13,
                            color: Colors.grey.shade500,
                          ),
                          const SizedBox(width: 3),
                          Expanded(
                            child: Text(
                              report.address!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey.shade500,
                              ),
                            ),
                          ),
                        ] else
                          const Spacer(),
                        Icon(
                          Icons.access_time,
                          size: 12,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          formatDate(report.createdAt),
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade400,
                          ),
                        ),
                      ],
                    ),
                    if (zone != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        zone,
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade400,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FavouriteButton extends StatefulWidget {
  final bool isFavourite;
  final VoidCallback? onToggle;
  const _FavouriteButton({required this.isFavourite, this.onToggle});

  @override
  State<_FavouriteButton> createState() => _FavouriteButtonState();
}

class _FavouriteButtonState extends State<_FavouriteButton> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    if (widget.onToggle == null) return const SizedBox.shrink();
    final showFilled = widget.isFavourite || _hovering;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: IconButton(
        onPressed: widget.onToggle,
        icon: Icon(
          showFilled ? Icons.star : Icons.star_border,
          color: showFilled
              ? (_hovering && !widget.isFavourite
                    ? Colors.amber.withValues(alpha: 0.6)
                    : Colors.amber)
              : Colors.grey.shade400,
        ),
        iconSize: 20,
        padding: const EdgeInsets.all(6),
        constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onRemove;
  const _FilterChip({
    required this.label,
    this.color = Colors.blueGrey,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: Chip(
        label: Text(label, style: const TextStyle(fontSize: 12)),
        backgroundColor: color.withValues(alpha: 0.12),
        labelStyle: TextStyle(color: color),
        deleteIcon: Icon(Icons.close, size: 14, color: color),
        onDeleted: onRemove,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        padding: const EdgeInsets.symmetric(horizontal: 4),
      ),
    );
  }
}

class _FilterSortSheet extends StatefulWidget {
  final List<String> zones;
  final List<String> categories;
  final bool filterFavourites;
  final bool isLoggedIn;
  final String? filterStatus;
  final bool isAuthority;
  final String? filterCategory;
  final String? filterZone;
  final String? filterPriority;
  final _SortField sortField;
  final _SortDirection sortDir;
  final void Function(
    String? status,
    String? priority,
    String? category,
    String? zone,
    _SortField field,
    _SortDirection dir,
    bool favouritesOnly,
  )
  onApply;

  const _FilterSortSheet({
    required this.zones,
    required this.categories,
    required this.filterFavourites,
    required this.isLoggedIn,
    required this.filterStatus,
    required this.isAuthority,
    required this.filterCategory,
    required this.filterZone,
    required this.filterPriority,
    required this.sortField,
    required this.sortDir,
    required this.onApply,
  });

  @override
  State<_FilterSortSheet> createState() => _FilterSortSheetState();
}

class _FilterSortSheetState extends State<_FilterSortSheet> {
  late bool _favouritesOnly;
  late String? _status;
  late String? _priority;
  late String? _category;
  late String? _zone;
  late _SortField _field;
  late _SortDirection _dir;

  static const _statusOptions = <String, String>{
    'pending': 'Pending',
    'in_progress': 'In Progress',
    'resolved': 'Resolved',
  };
  static const _priorityOptions = <String, String>{
    'low': 'Low',
    'medium': 'Medium',
    'high': 'High',
  };

  @override
  void initState() {
    super.initState();
    _favouritesOnly = widget.filterFavourites;
    _status = widget.filterStatus;
    _priority = widget.filterPriority;
    _category = widget.filterCategory;
    _zone = widget.filterZone;
    _field = widget.sortField;
    _dir = widget.sortDir;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
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
            const SizedBox(height: 16),
            Text(
              'Filter',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            if (widget.isLoggedIn) ...[
              Row(
                children: [
                  const Icon(Icons.star, size: 18, color: Colors.amber),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Favourites only',
                      style: TextStyle(fontSize: 14),
                    ),
                  ),
                  Switch(
                    value: _favouritesOnly,
                    onChanged: (v) => setState(() => _favouritesOnly = v),
                  ),
                ],
              ),
              const SizedBox(height: 4),
            ],
            _SectionLabel(label: 'Status'),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                _ChoiceChip(
                  label: 'All',
                  selected: _status == null,
                  onSelected: (_) => setState(() => _status = null),
                ),
                ..._statusOptions.entries.map(
                  (e) => _ChoiceChip(
                    label: e.value,
                    selected: _status == e.key,
                    onSelected: (_) => setState(() => _status = e.key),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (widget.isAuthority) ...[
              _SectionLabel(label: 'Priority'),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  _ChoiceChip(
                    label: 'All',
                    selected: _priority == null,
                    onSelected: (_) => setState(() => _priority = null),
                  ),
                  ..._priorityOptions.entries.map(
                    (e) => _ChoiceChip(
                      label: e.value,
                      selected: _priority == e.key,
                      onSelected: (_) => setState(() => _priority = e.key),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],
            _SectionLabel(label: 'Category'),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                _ChoiceChip(
                  label: 'All',
                  selected: _category == null,
                  onSelected: (_) => setState(() => _category = null),
                ),
                ...widget.categories.map(
                  (c) => _ChoiceChip(
                    label: c,
                    selected: _category == c,
                    onSelected: (_) => setState(() => _category = c),
                  ),
                ),
                _ChoiceChip(
                  label: 'Other',
                  selected: _category == '__other__',
                  onSelected: (_) => setState(() => _category = '__other__'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (widget.zones.isNotEmpty) ...[
              _SectionLabel(label: 'Location zone'),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  _ChoiceChip(
                    label: 'All',
                    selected: _zone == null,
                    onSelected: (_) => setState(() => _zone = null),
                  ),
                  ...widget.zones.map(
                    (z) => _ChoiceChip(
                      label: z,
                      selected: _zone == z,
                      onSelected: (_) => setState(() => _zone = z),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],
            const Divider(),
            Text(
              'Sort by',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: _SortField.values
                  .where((f) => f != _SortField.priority || widget.isAuthority)
                  .map(
                    (f) => _ChoiceChip(
                      label: _fieldLabel(f),
                      selected: _field == f,
                      onSelected: (_) => setState(() => _field = f),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _ChoiceChip(
                    label: '↑ Ascending',
                    selected: _dir == _SortDirection.asc,
                    onSelected: (_) =>
                        setState(() => _dir = _SortDirection.asc),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _ChoiceChip(
                    label: '↓ Descending',
                    selected: _dir == _SortDirection.desc,
                    onSelected: (_) =>
                        setState(() => _dir = _SortDirection.desc),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () {
                  widget.onApply(
                    _status,
                    _priority,
                    _category,
                    _zone,
                    _field,
                    _dir,
                    _favouritesOnly,
                  );
                  Navigator.pop(context);
                },
                child: const Text('Apply'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _fieldLabel(_SortField f) {
    switch (f) {
      case _SortField.date:
        return 'Date';
      case _SortField.status:
        return 'Status';
      case _SortField.priority:
        return 'Priority';
      case _SortField.category:
        return 'Category';
      case _SortField.location:
        return 'Location';
    }
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 13,
          color: Colors.grey.shade600,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

class _ChoiceChip extends StatelessWidget {
  final String label;
  final bool selected;
  final ValueChanged<bool> onSelected;
  const _ChoiceChip({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label, style: const TextStyle(fontSize: 12)),
      selected: selected,
      onSelected: onSelected,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      padding: const EdgeInsets.symmetric(horizontal: 4),
    );
  }
}
