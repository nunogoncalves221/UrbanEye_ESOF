import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:project/services/user_role.dart';
import 'package:project/services/user_role_service.dart';
import 'report_model.dart';

// sort options
enum _SortField { date, status, priority, category, location }
enum _SortDirection { asc, desc }

// allReportsScreen
class AllReportsScreen extends StatefulWidget {
  const AllReportsScreen({super.key});

  @override
  State<AllReportsScreen> createState() => _AllReportsScreenState();
}

class _AllReportsScreenState extends State<AllReportsScreen> {
  // data
  List<ReportModel> _allReports = [];
  bool _loading = true;
  String? _error;

  // authority role check
  bool _isAuthority = false;

  // filter state
  String? _filterStatus;
  String? _filterPriority;
  String? _filterCategory;
  String? _filterZone; // derived from address

  // sort state
  _SortField _sortField = _SortField.date;
  _SortDirection _sortDir = _SortDirection.desc; // newest first by default

  // constants
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

  // known categories
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

  // lifecycle
  @override
  void initState() {
    super.initState();
    _loadReports();
    _loadRole();
  }

  Future<void> _loadRole() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final role = await const UserRoleService().getRole(user);
    if (mounted) {
      setState(() => _isAuthority = role == UserRole.authority);
    }
  }
  Future<void> _updatePriority(ReportModel report, String newPriority) async {
  try {
    await FirebaseFirestore.instance
        .collection('reports')
        .doc(report.id)
        .update({'priority': newPriority});
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
      final snapshot =
          await FirebaseFirestore.instance.collection('reports').get();
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

  // derived helpers

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
    if (parts.length >= 2) {
      return parts[parts.length - 2].trim();
    }
    return parts.first.trim();
  }

  List<String> get _categories {
    final cats = _allReports.map((r) => r.category).toSet().toList();
    return cats..sort();
  }

  /// apply filters + sort
  List<ReportModel> get _filtered {
    var list = _allReports.where((r) {
      if (_filterStatus != null && r.status != _filterStatus) return false;
      if (_isAuthority && _filterPriority != null && r.priority != _filterPriority) return false;
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
          int getPriorityWeight(String? priority) {
            switch (priority?.toLowerCase()) {
              case 'high': return 3;
              case 'medium': return 2;
              case 'low':
              default: return 1;
            }
          }
          cmp = getPriorityWeight(a.priority).compareTo(getPriorityWeight(b.priority));
          break;
        case _SortField.location:
          final za = _extractZone(a) ?? '';
          final zb = _extractZone(b) ?? '';
          cmp = za.compareTo(zb);
          break;
      }
      return _sortDir == _SortDirection.asc ? cmp : -cmp;
    });

    return list;
  }

  // UI helpers

  String _formatDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/'
      '${d.month.toString().padLeft(2, '0')}/'
      '${d.year}';

  bool get _hasActiveFilters =>
      _filterStatus != null || _filterPriority != null || _filterCategory != null || _filterZone != null;

  void _clearFilters() => setState(() {
        _filterStatus = null;
        _filterPriority = null;
        _filterCategory = null;
        _filterZone = null;
      });

  Future<void> _updateStatus(ReportModel report, String newStatus) async {
    try {
      await FirebaseFirestore.instance
          .collection('reports')
          .doc(report.id)
          .update({'status': newStatus});
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
            priority: report.priority, // mantem prioridade original
            createdAt: report.createdAt,
            address: report.address,
          );
        }
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update status: $e')),
        );
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
        zones: _zones,
        categories: _categories,
        filterStatus: _filterStatus,
        filterPriority: _filterPriority,
        filterCategory: _filterCategory,
        filterZone: _filterZone,
        sortField: _sortField,
        sortDir: _sortDir,
        onApply: (status, priority, category, zone, field, dir) {
          setState(() {
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('All Reports'),
        actions: [
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
                      Text('Failed to load reports.\n$_error', textAlign: TextAlign.center),
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
              _hasActiveFilters ? 'No reports match the current filters.' : 'No reports found.',
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
                  if (_filterStatus != null)
                    _FilterChip(
                      label: _statusLabels[_filterStatus!] ?? _filterStatus!,
                      color: _statusColors[_filterStatus!] ?? Colors.grey,
                      onRemove: () => setState(() => _filterStatus = null),
                    ),
                  if (_isAuthority && _filterPriority != null)
                    _FilterChip(
                      label: _priorityLabels[_filterPriority!] ?? _filterPriority!,
                      color: _priorityColors[_filterPriority!] ?? Colors.grey,
                      onRemove: () => setState(() => _filterPriority = null),
                    ),
                  if (_filterCategory != null)
                    _FilterChip(
                      label: _filterCategory == '__other__' ? 'Other' : _filterCategory!,
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
                      _sortDir == _SortDirection.asc ? Icons.arrow_upward : Icons.arrow_downward,
                      size: 14,
                      color: Colors.grey.shade600,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _sortFieldLabel(_sortField),
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
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
              onStatusChanged: _isAuthority
                  ? (newStatus) => _updateStatus(reports[i], newStatus)
                  : null,
                  onPriorityChanged: _isAuthority        // ← adiciona isto
      ? (newPriority) => _updatePriority(reports[i], newPriority)
      : null,
            ),
          ),
        ),
      ],
    );
  }

  String _sortFieldLabel(_SortField f) {
    switch (f) {
      case _SortField.date: return 'Date';
      case _SortField.status: return 'Status';
      case _SortField.priority: return 'Priority';
      case _SortField.category: return 'Category';
      case _SortField.location: return 'Location';
    }
  }
}

// report card
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
  final void Function(String newStatus)? onStatusChanged;
  final void Function(String newPriority)? onPriorityChanged;

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
    this.onStatusChanged,
     this.onPriorityChanged,
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
              child: Icon(categoryIcon, color: Theme.of(context).colorScheme.primary),
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
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      isAuthority && onStatusChanged != null
                          ? PopupMenuButton<String>(
                              padding: EdgeInsets.zero,
                              tooltip: 'Change status',
                              onSelected: onStatusChanged,
                              itemBuilder: (_) => statusLabels.entries
                                  .map((e) => PopupMenuItem(
                                        value: e.key,
                                        child: Row(
                                          children: [
                                            Container(
                                              width: 10,
                                              height: 10,
                                              margin: const EdgeInsets.only(right: 8),
                                              decoration: BoxDecoration(
                                                color: statusColors[e.key] ?? Colors.grey,
                                                shape: BoxShape.circle,
                                              ),
                                            ),
                                            Text(e.value),
                                          ],
                                        ),
                                      ))
                                  .toList(),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: statusColor.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      statusLabel,
                                      style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.w600),
                                    ),
                                    const SizedBox(width: 3),
                                    Icon(Icons.arrow_drop_down, size: 14, color: statusColor),
                                  ],
                                ),
                              ),
                            )
                          : Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: statusColor.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                statusLabel,
                                style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.w600),
                              ),
                            ),
                   
                      if (isAuthority) ...[
                        const SizedBox(width: 6),
  PopupMenuButton<String>(
    padding: EdgeInsets.zero,
    tooltip: 'Change priority',
    onSelected: (v) => onPriorityChanged?.call(v),
    itemBuilder: (_) => priorityLabels.entries
        .map((e) => PopupMenuItem(
              value: e.key,
              child: Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      color: priorityColors[e.key] ?? Colors.grey,
                      shape: BoxShape.circle,
                    ),
                  ),
                  Text(e.value),
                ],
              ),
            ))
        .toList(),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: priorityColor.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            priorityLabel,
            style: TextStyle(color: priorityColor, fontSize: 11, fontWeight: FontWeight.w600),
          ),
          const SizedBox(width: 3),
          Icon(Icons.arrow_drop_down, size: 14, color: priorityColor),
        ],
      ),
    ),
  ),
],
],                      // ← fecha o children da Row de cima
                  ),
                  
                  const SizedBox(height: 4),
                  Text(
                    report.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(Icons.location_on_outlined, size: 13, color: Colors.grey.shade500),
                      const SizedBox(width: 3),
                      Expanded(
                        child: Text(
                          report.address ?? '${report.latitude.toStringAsFixed(4)}, ${report.longitude.toStringAsFixed(4)}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                        ),
                      ),
                      Icon(Icons.access_time, size: 12, color: Colors.grey.shade400),
                      const SizedBox(width: 3),
                      Text(
                        formatDate(report.createdAt),
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade400),
                      ),
                    ],
                  ),
                  if (zone != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      zone,
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade400, fontStyle: FontStyle.italic),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// active filter chip
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

// filter + sort bottom sheet
class _FilterSortSheet extends StatefulWidget {
  final List<String> zones;
  final List<String> categories;
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
  ) onApply;

  const _FilterSortSheet({
    required this.zones,
    required this.categories,
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

            Text('Filter', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),

            // status filter
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
                ..._statusOptions.entries.map((e) => _ChoiceChip(
                      label: e.value,
                      selected: _status == e.key,
                      onSelected: (_) => setState(() => _status = e.key),
                    )),
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
                  ..._priorityOptions.entries.map((e) => _ChoiceChip(
                        label: e.value,
                        selected: _priority == e.key,
                        onSelected: (_) => setState(() => _priority = e.key),
                      )),
                ],
              ),
              const SizedBox(height: 12),
            ],

            // category filter
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
                ...widget.categories.map((c) => _ChoiceChip(
                      label: c,
                      selected: _category == c,
                      onSelected: (_) => setState(() => _category = c),
                    )),
                _ChoiceChip(
                  label: 'Other',
                  selected: _category == '__other__',
                  onSelected: (_) => setState(() => _category = '__other__'),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // zone filter
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
                  ...widget.zones.map((z) => _ChoiceChip(
                        label: z,
                        selected: _zone == z,
                        onSelected: (_) => setState(() => _zone = z),
                      )),
                ],
              ),
              const SizedBox(height: 12),
            ],

            const Divider(),

            Text('Sort by', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),

            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: _SortField.values
                  .where((f) => f != _SortField.priority || widget.isAuthority)
                  .map((f) => _ChoiceChip(
                    label: _fieldLabel(f),
                    selected: _field == f,
                    onSelected: (_) => setState(() => _field = f),
                  )).toList(),
            ),
            const SizedBox(height: 12),

            // direction
            Row(
              children: [
                Expanded(
                  child: _ChoiceChip(
                    label: '↑ Ascending',
                    selected: _dir == _SortDirection.asc,
                    onSelected: (_) => setState(() => _dir = _SortDirection.asc),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _ChoiceChip(
                    label: '↓ Descending',
                    selected: _dir == _SortDirection.desc,
                    onSelected: (_) => setState(() => _dir = _SortDirection.desc),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // apply button
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () {
                  widget.onApply(_status, _priority, _category, _zone, _field, _dir);
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
      case _SortField.date: return 'Date';
      case _SortField.status: return 'Status';
      case _SortField.priority: return 'Priority';
      case _SortField.category: return 'Category';
      case _SortField.location: return 'Location';
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
      child: Text(label, style: TextStyle(fontSize: 13, color: Colors.grey.shade600, fontWeight: FontWeight.w500)),
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