import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'report_model.dart';

// sort options
enum _SortField { date, status, category, location }

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

  // filter state
  String? _filterStatus;
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

  /// returns available location zones derived from addresses
  List<String> get _zones {
    final zones = <String>{};
    for (final r in _allReports) {
      final zone = _extractZone(r);
      if (zone != null) zones.add(zone);
    }
    return zones.toList()..sort();
  }

  /// use the second-to-last comma segment of the address as zone
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
        case _SortField.status:
          cmp = a.status.compareTo(b.status);
        case _SortField.category:
          cmp = a.category.compareTo(b.category);
        case _SortField.location:
          final za = _extractZone(a) ?? '';
          final zb = _extractZone(b) ?? '';
          cmp = za.compareTo(zb);
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
      _filterStatus != null || _filterCategory != null || _filterZone != null;

  void _clearFilters() => setState(() {
        _filterStatus = null;
        _filterCategory = null;
        _filterZone = null;
      });

  // filter / sort bottom sheet

  void _showFilterSort() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _FilterSortSheet(
        zones: _zones,
        categories: _categories,
        filterStatus: _filterStatus,
        filterCategory: _filterCategory,
        filterZone: _filterZone,
        sortField: _sortField,
        sortDir: _sortDir,
        onApply: (status, category, zone, field, dir) {
          setState(() {
            _filterStatus = status;
            _filterCategory = category;
            _filterZone = zone;
            _sortField = field;
            _sortDir = dir;
          });
        },
      ),
    );
  }

  // build

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
                      const Icon(Icons.error_outline,
                          size: 48, color: Colors.red),
                      const SizedBox(height: 12),
                      Text('Failed to load reports.\n$_error',
                          textAlign: TextAlign.center),
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
              style:
                  TextStyle(fontSize: 16, color: Colors.grey.shade600),
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
        // active filter chips
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
                      color:
                          _statusColors[_filterStatus!] ?? Colors.grey,
                      onRemove: () =>
                          setState(() => _filterStatus = null),
                    ),
                  if (_filterCategory != null)
                    _FilterChip(
                      label: _filterCategory == '__other__'
                          ? 'Other'
                          : _filterCategory!,
                      onRemove: () =>
                          setState(() => _filterCategory = null),
                    ),
                  if (_filterZone != null)
                    _FilterChip(
                      label: _filterZone!,
                      onRemove: () =>
                          setState(() => _filterZone = null),
                    ),
                ],
              ),
            ),
          ),
        // count + sort label
        Padding(
          padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Row(
            children: [
              Text(
                '${reports.length} report${reports.length == 1 ? '' : 's'}',
                style: TextStyle(
                    color: Colors.grey.shade600, fontSize: 13),
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
                          color: Colors.grey.shade600, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        // list
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            itemCount: reports.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, i) =>
                _ReportCard(
              report: reports[i],
              statusColors: _statusColors,
              statusLabels: _statusLabels,
              categoryIcons: _categoryIcons,
              formatDate: _formatDate,
              extractZone: _extractZone,
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
      case _SortField.category:
        return 'Category';
      case _SortField.location:
        return 'Location';
    }
  }
}

// report card
class _ReportCard extends StatelessWidget {
  final ReportModel report;
  final Map<String, Color> statusColors;
  final Map<String, String> statusLabels;
  final Map<String, IconData> categoryIcons;
  final String Function(DateTime) formatDate;
  final String? Function(ReportModel) extractZone;

  const _ReportCard({
    required this.report,
    required this.statusColors,
    required this.statusLabels,
    required this.categoryIcons,
    required this.formatDate,
    required this.extractZone,
  });

  @override
  Widget build(BuildContext context) {
    final statusColor = statusColors[report.status] ?? Colors.grey;
    final statusLabel = statusLabels[report.status] ?? report.status;
    final categoryIcon = categoryIcons[report.category] ?? Icons.flag;
    final zone = extractZone(report);

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // category icon
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(categoryIcon,
                  color: Theme.of(context).colorScheme.primary),
            ),
            const SizedBox(width: 12),
            // content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // title row
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          report.category,
                          style: const TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 15),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          statusLabel,
                          style: TextStyle(
                              color: statusColor,
                              fontSize: 11,
                              fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  // description
                  Text(
                    report.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: Colors.grey.shade600, fontSize: 13),
                  ),
                  const SizedBox(height: 6),
                  // location + date
                  Row(
                    children: [
                      Icon(Icons.location_on_outlined,
                          size: 13, color: Colors.grey.shade500),
                      const SizedBox(width: 3),
                      Expanded(
                        child: Text(
                          report.address ??
                              '${report.latitude.toStringAsFixed(4)}, '
                                  '${report.longitude.toStringAsFixed(4)}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 11, color: Colors.grey.shade500),
                        ),
                      ),
                      Icon(Icons.access_time,
                          size: 12, color: Colors.grey.shade400),
                      const SizedBox(width: 3),
                      Text(
                        formatDate(report.createdAt),
                        style: TextStyle(
                            fontSize: 11, color: Colors.grey.shade400),
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
                          fontStyle: FontStyle.italic),
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
  final String? filterCategory;
  final String? filterZone;
  final _SortField sortField;
  final _SortDirection sortDir;
  final void Function(
    String? status,
    String? category,
    String? zone,
    _SortField field,
    _SortDirection dir,
  ) onApply;

  const _FilterSortSheet({
    required this.zones,
    required this.categories,
    required this.filterStatus,
    required this.filterCategory,
    required this.filterZone,
    required this.sortField,
    required this.sortDir,
    required this.onApply,
  });

  @override
  State<_FilterSortSheet> createState() => _FilterSortSheetState();
}

class _FilterSortSheetState extends State<_FilterSortSheet> {
  late String? _status;
  late String? _category;
  late String? _zone;
  late _SortField _field;
  late _SortDirection _dir;

  static const _statusOptions = <String, String>{
    'pending': 'Pending',
    'in_progress': 'In Progress',
    'resolved': 'Resolved',
  };

  @override
  void initState() {
    super.initState();
    _status = widget.filterStatus;
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
            // handle
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

            // filters
            Text('Filter',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold)),
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
                      onSelected: (_) =>
                          setState(() => _status = e.key),
                    )),
              ],
            ),
            const SizedBox(height: 12),

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
                      onSelected: (_) =>
                          setState(() => _category = c),
                    )),
                _ChoiceChip(
                  label: 'Other',
                  selected: _category == '__other__',
                  onSelected: (_) =>
                      setState(() => _category = '__other__'),
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
                        onSelected: (_) =>
                            setState(() => _zone = z),
                      )),
                ],
              ),
              const SizedBox(height: 12),
            ],

            const Divider(),

            // sort
            Text('Sort by',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),

            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: _SortField.values.map((f) => _ChoiceChip(
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

            // apply button
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () {
                  widget.onApply(
                      _status, _category, _zone, _field, _dir);
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
      child: Text(label,
          style: TextStyle(
              fontSize: 13,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500)),
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