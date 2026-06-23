import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nrmflutter/services/login_service.dart';

// ---------------------------------------------------------------------------
// Data models
// ---------------------------------------------------------------------------

class _Plan {
  final int id;
  final String name;
  final String villageName;
  final String facilitatorName;
  final int? project;
  final String? projectName;
  final String? organizationName;
  final int? tehsilSoi;
  final bool isCompleted;
  final bool isDprGenerated;
  final bool isDprReviewed;
  final bool isDprApproved;
  final String? createdAt;
  final int? stateSoi;
  final int? districtSoi;
  final String? gramPanchayat;
  final Map<String, dynamic> raw;

  bool get isTest {
    final n = name.toLowerCase();
    return n.contains('test') || n.contains('demo');
  }

  _Plan.fromJson(Map<String, dynamic> j)
      : id = j['id'] as int,
        name = (j['plan'] ?? '').toString(),
        villageName = (j['village_name'] ?? '').toString(),
        facilitatorName = (j['facilitator_name'] ?? '').toString(),
        project = j['project'] as int?,
        projectName = j['project_name']?.toString(),
        organizationName = j['organization_name']?.toString(),
        tehsilSoi = j['tehsil_soi'] is int
            ? j['tehsil_soi'] as int
            : int.tryParse(j['tehsil_soi']?.toString() ?? ''),
        isCompleted = j['is_completed'] == true,
        isDprGenerated = j['is_dpr_generated'] == true,
        isDprReviewed = j['is_dpr_reviewed'] == true,
        isDprApproved = j['is_dpr_approved'] == true,
        createdAt = j['created_at']?.toString(),
        stateSoi = j['state_soi'] as int?,
        districtSoi = j['district_soi'] as int?,
        gramPanchayat = j['gram_panchayat']?.toString(),
        raw = j;
}

class _Project {
  final int id;
  final String name;
  final String? organizationName;
  int count = 0;

  _Project({
    required this.id,
    required this.name,
    this.organizationName,
  });
}

// ---------------------------------------------------------------------------
// Plan Sheet entry point
// ---------------------------------------------------------------------------

class PlanSheet extends StatefulWidget {
  final String blockId;
  final int? selectedPlanId;
  final ValueChanged<_Plan> onPlanSelected;

  const PlanSheet({
    super.key,
    required this.blockId,
    this.selectedPlanId,
    required this.onPlanSelected,
  });

  @override
  State<PlanSheet> createState() => _PlanSheetState();
}

class _PlanSheetState extends State<PlanSheet> {
  final _loginService = LoginService();

  Map<String, dynamic>? _userData;
  bool _loading = true;

  // Role flags
  bool get _isSuperAdmin => _userData?['is_superadmin'] == true;
  bool get _isOrgAdmin =>
      (_userData?['groups'] as List?)
          ?.any((g) => (g['name'] ?? '') == 'Administrator') ==
      true;
  bool get _isPlanReviewer =>
      (_userData?['groups'] as List?)
          ?.any((g) => (g['name'] ?? '') == 'Test Plan Reviewer') ==
      true;

  // Plans data
  List<_Plan> _globalPlans = [];
  List<({int projectId, String projectName, List<_Plan> plans})>
      _projectPlans = [];
  List<_Project> _availableProjects = [];
  _Project? _selectedProject;
  Map<int, bool> _projectTehsilWarnings = {};

  // UI state
  bool _showProjectSelector = false;
  bool _filteringByTehsil = false;
  _Plan? _planDetails;
  String? _detailsProjectName;

  // Filters
  String _searchQuery = '';
  String? _villageFilter;
  String? _facilitatorFilter;
  bool _showFilterMenu = false;
  bool _showVillageFilter = false;
  bool _showFacilitatorFilter = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    _userData = await _loginService.getUserData();
    if (!mounted) return;

    if (_isSuperAdmin) {
      await _fetchGlobalPlans();
    } else if ((_isOrgAdmin || _isPlanReviewer) &&
        _projectDetails.isNotEmpty) {
      await _handleAdminProjects();
    } else if (_projectDetails.isNotEmpty) {
      await _fetchAllProjectPlans();
    }

    if (mounted) setState(() => _loading = false);
  }

  List<Map<String, dynamic>> get _projectDetails {
    final raw = _userData?['project_details'];
    if (raw is List) return raw.cast<Map<String, dynamic>>();
    return [];
  }

  // ---------------------------------------------------------------------------
  // Fetchers
  // ---------------------------------------------------------------------------

  Future<void> _fetchGlobalPlans() async {
    final resp = await _loginService.makeAuthenticatedRequest(
        'watershed/plans/?tehsil=${widget.blockId}');
    if (resp == null || resp.statusCode != 200) return;

    final plans = (jsonDecode(resp.body) as List)
        .map((j) => _Plan.fromJson(j as Map<String, dynamic>))
        .toList();

    final projectMap = <int, _Project>{};
    for (final p in plans) {
      if (p.project != null && p.projectName != null) {
        projectMap.putIfAbsent(
          p.project!,
          () => _Project(
            id: p.project!,
            name: p.projectName!,
            organizationName: p.organizationName,
          ),
        );
        projectMap[p.project!]!.count++;
      }
    }

    final projects = projectMap.values.toList();
    final warnings = <int, bool>{};
    for (final proj in projects) {
      final match = plans
          .where((p) => p.project == proj.id)
          .any((p) => p.tehsilSoi == int.tryParse(widget.blockId));
      if (!match) warnings[proj.id] = true;
    }

    if (!mounted) return;
    setState(() {
      _globalPlans = plans;
      _availableProjects = projects;
      _projectTehsilWarnings = warnings;
      if (projects.length == 1) {
        _selectedProject = projects.first;
      } else if (projects.length > 1) {
        _showProjectSelector = true;
      }
    });
  }

  Future<void> _handleAdminProjects() async {
    if (_projectDetails.length == 1) {
      final p = _projectDetails.first;
      _selectedProject = _Project(
        id: p['project_id'] as int,
        name: p['project_name'].toString(),
        organizationName: _userData?['organization']?.toString(),
      );
      await _fetchOrgAdminPlans(_selectedProject!.id);
    } else {
      final projects = _projectDetails
          .map((p) => _Project(
                id: p['project_id'] as int,
                name: p['project_name'].toString(),
                organizationName: _userData?['organization']?.toString(),
              ))
          .toList();

      if (!mounted) return;
      setState(() {
        _availableProjects = projects;
        _showProjectSelector = true;
        _filteringByTehsil = true;
      });

      final warnings = <int, bool>{};
      for (final proj in projects) {
        final hasMatch = await _checkProjectTehsilMatch(proj.id);
        if (!hasMatch) warnings[proj.id] = true;
      }

      if (!mounted) return;
      setState(() {
        _projectTehsilWarnings = warnings;
        _filteringByTehsil = false;
      });
    }
  }

  Future<void> _fetchOrgAdminPlans(int projectId) async {
    if (!mounted) return;
    setState(() => _loading = true);

    final resp = await _loginService.makeAuthenticatedRequest(
        'projects/$projectId/watershed/plans/?tehsil=${widget.blockId}');

    if (resp == null || resp.statusCode != 200) {
      if (mounted) setState(() => _loading = false);
      return;
    }

    var plans = (jsonDecode(resp.body) as List)
        .map((j) => _Plan.fromJson(j as Map<String, dynamic>))
        .toList();

    final blockIdInt = int.tryParse(widget.blockId);
    if (blockIdInt != null) {
      final all = plans.every((p) => p.tehsilSoi == blockIdInt);
      if (!all) plans = plans.where((p) => p.tehsilSoi == blockIdInt).toList();
    }

    final projectName = _projectDetails
        .firstWhere(
          (p) => p['project_id'] == projectId,
          orElse: () => {'project_name': 'Unknown Project'},
        )['project_name']
        .toString();

    if (!mounted) return;
    setState(() {
      _projectPlans = [
        (projectId: projectId, projectName: projectName, plans: plans)
      ];
      _loading = false;
    });
  }

  Future<void> _fetchAllProjectPlans() async {
    final allGroups =
        <({int projectId, String projectName, List<_Plan> plans})>[];
    final blockIdInt = int.tryParse(widget.blockId);

    for (final proj in _projectDetails) {
      final id = proj['project_id'] as int;
      final name = proj['project_name'].toString();
      final resp = await _loginService.makeAuthenticatedRequest(
          'projects/$id/watershed/plans/?tehsil=${widget.blockId}');
      if (resp == null || resp.statusCode != 200) continue;

      var plans = (jsonDecode(resp.body) as List)
          .map((j) => _Plan.fromJson(j as Map<String, dynamic>))
          .toList();

      if (blockIdInt != null) {
        final all = plans.every((p) => p.tehsilSoi == blockIdInt);
        if (!all) {
          plans = plans.where((p) => p.tehsilSoi == blockIdInt).toList();
        }
      }

      allGroups.add((projectId: id, projectName: name, plans: plans));
    }

    if (mounted) setState(() => _projectPlans = allGroups);
  }

  Future<bool> _checkProjectTehsilMatch(int projectId) async {
    final resp = await _loginService.makeAuthenticatedRequest(
        'projects/$projectId/watershed/plans/?tehsil=${widget.blockId}');
    if (resp == null || resp.statusCode != 200) return false;
    final plans = jsonDecode(resp.body) as List;
    return plans.isNotEmpty;
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  List<_Plan> get _filteredGlobalPlans {
    if (_selectedProject != null) {
      return _globalPlans.where((p) => p.project == _selectedProject!.id).toList();
    }
    if (_availableProjects.length == 1) {
      return _globalPlans.where((p) => p.project == _availableProjects.first.id).toList();
    }
    return _globalPlans.where((p) => p.project == null).toList();
  }

  ({List<_Plan> regular, List<_Plan> test}) _applyFilters(List<_Plan> plans) {
    var regular = plans.where((p) => !p.isTest).toList();
    var test = plans.where((p) => p.isTest).toList();

    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      regular = regular.where((p) => p.name.toLowerCase().contains(q)).toList();
      test = test.where((p) => p.name.toLowerCase().contains(q)).toList();
    }
    if (_villageFilter != null) {
      regular = regular.where((p) => p.villageName == _villageFilter).toList();
      test = test.where((p) => p.villageName == _villageFilter).toList();
    }
    if (_facilitatorFilter != null) {
      regular = regular
          .where((p) => p.facilitatorName == _facilitatorFilter)
          .toList();
      if (_isSuperAdmin || _isOrgAdmin || _isPlanReviewer) {
        test = test
            .where((p) => p.facilitatorName == _facilitatorFilter)
            .toList();
      }
    }
    return (regular: regular, test: test);
  }

  List<String> _uniqueVillages(List<_Plan> plans) =>
      plans.map((p) => p.villageName).toSet().where((v) => v.isNotEmpty).toList()
        ..sort();

  List<String> _uniqueFacilitators(List<_Plan> plans) =>
      plans.map((p) => p.facilitatorName).toSet().where((v) => v.isNotEmpty).toList()
        ..sort();

  List<_Plan> get _allPlans => _isSuperAdmin
      ? _filteredGlobalPlans
      : _projectPlans.expand((g) => g.plans).toList();

  void _selectPlan(_Plan plan) {
    HapticFeedback.lightImpact();
    widget.onPlanSelected(plan);
    Navigator.pop(context);
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    // Project selector overlay
    if (_showProjectSelector && _availableProjects.length > 1) {
      return _ProjectSelectorSheet(
        projects: _availableProjects,
        warnings: _projectTehsilWarnings,
        isFiltering: _filteringByTehsil,
        isSuperAdmin: _isSuperAdmin,
        globalPlansWithoutProject:
            _isSuperAdmin ? _globalPlans.where((p) => p.project == null).length : 0,
        onBack: () => Navigator.pop(context),
        onProjectSelected: (proj) {
          setState(() {
            _selectedProject = proj;
            _showProjectSelector = false;
          });
          if (_isOrgAdmin || _isPlanReviewer) {
            _fetchOrgAdminPlans(proj.id);
          }
        },
        onSelectNoProject: _isSuperAdmin
            ? () => setState(() {
                  _selectedProject = null;
                  _showProjectSelector = false;
                })
            : null,
        bottomPadding: bottomPadding,
      );
    }

    // Plan details overlay
    if (_planDetails != null) {
      return _PlanDetailsSheet(
        plan: _planDetails!,
        projectName: _detailsProjectName,
        isSuperAdmin: _isSuperAdmin,
        onBack: () => setState(() => _planDetails = null),
        bottomPadding: bottomPadding,
      );
    }

    // Main plan list
    return Container(
      height: MediaQuery.of(context).size.height * 0.88,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          _SheetHandle(),
          _SheetHeader(
            blockId: widget.blockId,
            isSuperAdmin: _isSuperAdmin,
            selectedProject: _selectedProject,
            availableProjects: _availableProjects,
            hasFilters: _villageFilter != null || _facilitatorFilter != null,
            showFilterMenu: _showFilterMenu,
            onClose: () => Navigator.pop(context),
            onChangeProject: _availableProjects.length > 1
                ? () => setState(() => _showProjectSelector = true)
                : null,
            onToggleFilter: () => setState(() {
              _showFilterMenu = !_showFilterMenu;
              _showVillageFilter = false;
              _showFacilitatorFilter = false;
            }),
          ),
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(
                      color: Color(0xFF592941),
                    ),
                  )
                : _buildPlanList(bottomPadding),
          ),
        ],
      ),
    );
  }

  Widget _buildPlanList(double bottomPadding) {
    final source = _isSuperAdmin ? _filteredGlobalPlans : null;

    return ListView(
      padding: EdgeInsets.only(bottom: bottomPadding + 16),
      children: [
        // Search bar
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: _SearchBar(
            query: _searchQuery,
            onChanged: (v) => setState(() => _searchQuery = v),
            onClear: () => setState(() => _searchQuery = ''),
          ),
        ),

        // Active filters
        if (_villageFilter != null || _facilitatorFilter != null)
          _ActiveFilters(
            village: _villageFilter,
            facilitator: _facilitatorFilter,
            onRemoveVillage: () => setState(() => _villageFilter = null),
            onRemoveFacilitator: () => setState(() => _facilitatorFilter = null),
          ),

        // Filter dropdown
        if (_showFilterMenu)
          _FilterMenu(
            showVillageFilter: _showVillageFilter,
            showFacilitatorFilter: _showFacilitatorFilter,
            villages: _uniqueVillages(_allPlans),
            facilitators: _uniqueFacilitators(_allPlans),
            selectedVillage: _villageFilter,
            selectedFacilitator: _facilitatorFilter,
            hasActiveFilters: _villageFilter != null || _facilitatorFilter != null,
            onSelectVillage: (v) => setState(() {
              _villageFilter = v;
              _showFilterMenu = false;
              _showVillageFilter = false;
            }),
            onSelectFacilitator: (f) => setState(() {
              _facilitatorFilter = f;
              _showFilterMenu = false;
              _showFacilitatorFilter = false;
            }),
            onShowVillage: () => setState(() => _showVillageFilter = true),
            onShowFacilitator: () => setState(() => _showFacilitatorFilter = true),
            onBackFromSub: () => setState(() {
              _showVillageFilter = false;
              _showFacilitatorFilter = false;
            }),
            onClearAll: () => setState(() {
              _villageFilter = null;
              _facilitatorFilter = null;
              _showFilterMenu = false;
            }),
          ),

        // Plans
        if (_isSuperAdmin)
          _PlansSection(
            plans: _applyFilters(source!),
            selectedPlanId: widget.selectedPlanId,
            onSelect: _selectPlan,
            onInfo: (plan) => setState(() {
              _planDetails = plan;
              _detailsProjectName =
                  _selectedProject?.name ?? plan.projectName;
            }),
            emptyMessage: 'No plans found for tehsil ${widget.blockId}',
          )
        else ...[
          for (final group in _projectPlans)
            _ProjectPlansGroup(
              projectName: group.projectName,
              plans: _applyFilters(group.plans),
              selectedPlanId: widget.selectedPlanId,
              isLast: group == _projectPlans.last,
              onSelect: _selectPlan,
              onInfo: (plan) => setState(() {
                _planDetails = plan;
                _detailsProjectName = group.projectName;
              }),
            ),
          if (_projectPlans.isEmpty)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Center(
                child: Text('No plans found.',
                    style: TextStyle(color: Colors.grey)),
              ),
            ),
        ],
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Sub-widgets
// ---------------------------------------------------------------------------

class _SheetHandle extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 4),
      child: Center(
        child: Container(
          width: 40,
          height: 4,
          decoration: BoxDecoration(
            color: Colors.grey.shade300,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ),
    );
  }
}

class _SheetHeader extends StatelessWidget {
  final String blockId;
  final bool isSuperAdmin;
  final _Project? selectedProject;
  final List<_Project> availableProjects;
  final bool hasFilters;
  final bool showFilterMenu;
  final VoidCallback onClose;
  final VoidCallback? onChangeProject;
  final VoidCallback onToggleFilter;

  const _SheetHeader({
    required this.blockId,
    required this.isSuperAdmin,
    required this.selectedProject,
    required this.availableProjects,
    required this.hasFilters,
    required this.showFilterMenu,
    required this.onClose,
    required this.onChangeProject,
    required this.onToggleFilter,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 12, 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Select Plan',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF592941),
                  ),
                ),
                if (isSuperAdmin)
                  Text(
                    'Tehsil ID: $blockId',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
              ],
            ),
          ),
          // Project switcher
          if (onChangeProject != null)
            GestureDetector(
              onTap: onChangeProject,
              child: Container(
                margin: const EdgeInsets.only(right: 8),
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFF3E5F5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      selectedProject?.name ?? 'Select Project',
                      style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF592941),
                          fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.unfold_more,
                        size: 14, color: Color(0xFF592941)),
                  ],
                ),
              ),
            ),
          // Filter button
          GestureDetector(
            onTap: onToggleFilter,
            child: Container(
              width: 36,
              height: 36,
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                color: hasFilters
                    ? const Color(0xFFF3E5F5)
                    : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.tune,
                size: 18,
                color: hasFilters ? const Color(0xFF592941) : Colors.grey,
              ),
            ),
          ),
          // Close
          GestureDetector(
            onTap: onClose,
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(10),
              ),
              child:
                  const Icon(Icons.close, size: 18, color: Colors.black54),
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchBar extends StatelessWidget {
  final String query;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  const _SearchBar(
      {required this.query,
      required this.onChanged,
      required this.onClear});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: TextField(
        onChanged: onChanged,
        style: const TextStyle(fontSize: 14),
        decoration: InputDecoration(
          hintText: 'Search plans by name…',
          hintStyle: TextStyle(color: Colors.grey.shade500, fontSize: 14),
          prefixIcon:
              Icon(Icons.search, color: Colors.grey.shade500, size: 20),
          suffixIcon: query.isNotEmpty
              ? GestureDetector(
                  onTap: onClear,
                  child: Icon(Icons.close,
                      color: Colors.grey.shade500, size: 18),
                )
              : null,
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
    );
  }
}

class _ActiveFilters extends StatelessWidget {
  final String? village;
  final String? facilitator;
  final VoidCallback onRemoveVillage;
  final VoidCallback onRemoveFacilitator;

  const _ActiveFilters({
    required this.village,
    required this.facilitator,
    required this.onRemoveVillage,
    required this.onRemoveFacilitator,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Wrap(
        spacing: 8,
        children: [
          if (village != null)
            _FilterChip(label: 'Village: $village', onRemove: onRemoveVillage),
          if (facilitator != null)
            _FilterChip(
                label: 'Facilitator: $facilitator',
                onRemove: onRemoveFacilitator),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final VoidCallback onRemove;

  const _FilterChip({required this.label, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFFF3E5F5),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF592941),
                  fontWeight: FontWeight.w500)),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: onRemove,
            child: const Icon(Icons.close,
                size: 14, color: Color(0xFF592941)),
          ),
        ],
      ),
    );
  }
}

class _FilterMenu extends StatelessWidget {
  final bool showVillageFilter;
  final bool showFacilitatorFilter;
  final List<String> villages;
  final List<String> facilitators;
  final String? selectedVillage;
  final String? selectedFacilitator;
  final bool hasActiveFilters;
  final ValueChanged<String> onSelectVillage;
  final ValueChanged<String> onSelectFacilitator;
  final VoidCallback onShowVillage;
  final VoidCallback onShowFacilitator;
  final VoidCallback onBackFromSub;
  final VoidCallback onClearAll;

  const _FilterMenu({
    required this.showVillageFilter,
    required this.showFacilitatorFilter,
    required this.villages,
    required this.facilitators,
    required this.selectedVillage,
    required this.selectedFacilitator,
    required this.hasActiveFilters,
    required this.onSelectVillage,
    required this.onSelectFacilitator,
    required this.onShowVillage,
    required this.onShowFacilitator,
    required this.onBackFromSub,
    required this.onClearAll,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 12,
              offset: const Offset(0, 4)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (showVillageFilter) ...[
              _SubMenuHeader(title: 'Village', onBack: onBackFromSub),
              _OptionList(
                  items: villages,
                  selected: selectedVillage,
                  onSelect: onSelectVillage),
            ] else if (showFacilitatorFilter) ...[
              _SubMenuHeader(title: 'Facilitator', onBack: onBackFromSub),
              _OptionList(
                  items: facilitators,
                  selected: selectedFacilitator,
                  onSelect: onSelectFacilitator),
            ] else ...[
              _FilterMenuItem(
                  label: 'Filter by Village',
                  onTap: onShowVillage),
              _FilterMenuItem(
                  label: 'Filter by Facilitator',
                  onTap: onShowFacilitator),
              if (hasActiveFilters) ...[
                Divider(height: 1, color: Colors.grey.shade200),
                _FilterMenuItem(
                  label: 'Clear all filters',
                  onTap: onClearAll,
                  color: Colors.red,
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class _SubMenuHeader extends StatelessWidget {
  final String title;
  final VoidCallback onBack;

  const _SubMenuHeader({required this.title, required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: Colors.grey.shade50,
      child: Row(
        children: [
          GestureDetector(
            onTap: onBack,
            child: const Icon(Icons.arrow_back_ios_new,
                size: 14, color: Colors.black54),
          ),
          const SizedBox(width: 8),
          Text(title,
              style: const TextStyle(
                  fontWeight: FontWeight.w600, fontSize: 14)),
        ],
      ),
    );
  }
}

class _OptionList extends StatelessWidget {
  final List<String> items;
  final String? selected;
  final ValueChanged<String> onSelect;

  const _OptionList(
      {required this.items,
      required this.selected,
      required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 220),
      child: ListView.builder(
        shrinkWrap: true,
        itemCount: items.length,
        itemBuilder: (_, i) {
          final isSelected = selected == items[i];
          return InkWell(
            onTap: () => onSelect(items[i]),
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(items[i],
                        style: TextStyle(
                            fontSize: 14,
                            color: isSelected
                                ? const Color(0xFF592941)
                                : Colors.black87,
                            fontWeight: isSelected
                                ? FontWeight.w600
                                : FontWeight.normal)),
                  ),
                  if (isSelected)
                    const Icon(Icons.check,
                        size: 16, color: Color(0xFF592941)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _FilterMenuItem extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final Color? color;

  const _FilterMenuItem(
      {required this.label, required this.onTap, this.color});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Expanded(
              child: Text(label,
                  style: TextStyle(
                      fontSize: 14,
                      color: color ?? Colors.black87)),
            ),
            if (color == null)
              const Icon(Icons.chevron_right,
                  size: 18, color: Colors.black38),
          ],
        ),
      ),
    );
  }
}

class _PlansSection extends StatelessWidget {
  final ({List<_Plan> regular, List<_Plan> test}) plans;
  final int? selectedPlanId;
  final ValueChanged<_Plan> onSelect;
  final ValueChanged<_Plan> onInfo;
  final String emptyMessage;

  const _PlansSection({
    required this.plans,
    required this.selectedPlanId,
    required this.onSelect,
    required this.onInfo,
    required this.emptyMessage,
  });

  @override
  Widget build(BuildContext context) {
    if (plans.regular.isEmpty && plans.test.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(32),
        child: Center(
          child: Text(emptyMessage,
              style: const TextStyle(color: Colors.grey),
              textAlign: TextAlign.center),
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (plans.regular.isNotEmpty)
          _PlanList(
              plans: plans.regular,
              selectedPlanId: selectedPlanId,
              onSelect: onSelect,
              onInfo: onInfo),
        if (plans.test.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(
              children: [
                const SizedBox(width: 16),
                Expanded(child: Divider(color: Colors.grey.shade300)),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Text('Test Plans',
                      style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade500,
                          fontWeight: FontWeight.w500)),
                ),
                Expanded(child: Divider(color: Colors.grey.shade300)),
                const SizedBox(width: 16),
              ],
            ),
          ),
          _PlanList(
            plans: plans.test,
            selectedPlanId: selectedPlanId,
            isTest: true,
            onSelect: onSelect,
            onInfo: onInfo,
          ),
        ],
      ],
    );
  }
}

class _ProjectPlansGroup extends StatelessWidget {
  final String projectName;
  final ({List<_Plan> regular, List<_Plan> test}) plans;
  final int? selectedPlanId;
  final bool isLast;
  final ValueChanged<_Plan> onSelect;
  final ValueChanged<_Plan> onInfo;

  const _ProjectPlansGroup({
    required this.projectName,
    required this.plans,
    required this.selectedPlanId,
    required this.isLast,
    required this.onSelect,
    required this.onInfo,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFFF3E5F5),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            projectName,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 13,
              color: Color(0xFF592941),
            ),
          ),
        ),
        _PlansSection(
          plans: plans,
          selectedPlanId: selectedPlanId,
          onSelect: onSelect,
          onInfo: onInfo,
          emptyMessage: 'No plans for $projectName',
        ),
        if (!isLast)
          Divider(
              height: 24,
              thickness: 1,
              indent: 16,
              endIndent: 16,
              color: Colors.grey.shade200),
      ],
    );
  }
}

class _PlanList extends StatelessWidget {
  final List<_Plan> plans;
  final int? selectedPlanId;
  final bool isTest;
  final ValueChanged<_Plan> onSelect;
  final ValueChanged<_Plan> onInfo;

  const _PlanList({
    required this.plans,
    required this.selectedPlanId,
    this.isTest = false,
    required this.onSelect,
    required this.onInfo,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isTest
              ? const Color(0xFFFFCDD2)
              : Colors.grey.shade200,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: plans
              .map((p) => _PlanRow(
                    plan: p,
                    isSelected: p.id == selectedPlanId,
                    isTest: isTest,
                    onSelect: () => onSelect(p),
                    onInfo: () => onInfo(p),
                  ))
              .toList(),
        ),
      ),
    );
  }
}

class _PlanRow extends StatelessWidget {
  final _Plan plan;
  final bool isSelected;
  final bool isTest;
  final VoidCallback onSelect;
  final VoidCallback onInfo;

  const _PlanRow({
    required this.plan,
    required this.isSelected,
    required this.isTest,
    required this.onSelect,
    required this.onInfo,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onSelect,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFFF3E5F5)
              : isTest
                  ? const Color(0xFFFFF8F8)
                  : Colors.white,
          border: Border(
              bottom: BorderSide(color: Colors.grey.shade100, width: 0.5)),
        ),
        child: Row(
          children: [
            Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected
                      ? const Color(0xFF592941)
                      : Colors.grey.shade400,
                  width: 2,
                ),
                color: isSelected
                    ? const Color(0xFF592941)
                    : Colors.transparent,
              ),
              child: isSelected
                  ? const Center(
                      child: Icon(Icons.check, size: 10, color: Colors.white),
                    )
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    plan.name,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isSelected
                          ? const Color(0xFF592941)
                          : Colors.black87,
                    ),
                  ),
                  if (plan.villageName.isNotEmpty ||
                      plan.facilitatorName.isNotEmpty)
                    Text(
                      [plan.villageName, plan.facilitatorName]
                          .where((s) => s.isNotEmpty)
                          .join(' · '),
                      style: TextStyle(
                          fontSize: 11, color: Colors.grey.shade600),
                    ),
                ],
              ),
            ),
            GestureDetector(
              onTap: onInfo,
              child: Container(
                padding: const EdgeInsets.all(6),
                child: Icon(Icons.info_outline,
                    size: 18, color: Colors.grey.shade500),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Project selector sheet
// ---------------------------------------------------------------------------

class _ProjectSelectorSheet extends StatelessWidget {
  final List<_Project> projects;
  final Map<int, bool> warnings;
  final bool isFiltering;
  final bool isSuperAdmin;
  final int globalPlansWithoutProject;
  final VoidCallback onBack;
  final ValueChanged<_Project> onProjectSelected;
  final VoidCallback? onSelectNoProject;
  final double bottomPadding;

  const _ProjectSelectorSheet({
    required this.projects,
    required this.warnings,
    required this.isFiltering,
    required this.isSuperAdmin,
    required this.globalPlansWithoutProject,
    required this.onBack,
    required this.onProjectSelected,
    required this.onSelectNoProject,
    required this.bottomPadding,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.88,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 4),
            child: Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2)),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 12, 16),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Select Project',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF592941),
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: onBack,
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(10)),
                    child: const Icon(Icons.close,
                        size: 18, color: Colors.black54),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: isFiltering
                ? const Center(
                    child: CircularProgressIndicator(color: Color(0xFF592941)))
                : ListView(
                    padding: EdgeInsets.fromLTRB(16, 0, 16, bottomPadding + 16),
                    children: [
                      ...projects
                          .where((p) => warnings[p.id] != true)
                          .map((p) => _ProjectCard(
                                project: p,
                                isSuperAdmin: isSuperAdmin,
                                onTap: () => onProjectSelected(p),
                              )),
                      if (isSuperAdmin && globalPlansWithoutProject > 0)
                        _ProjectCard.noProject(
                          count: globalPlansWithoutProject,
                          onTap: onSelectNoProject ?? () {},
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _ProjectCard extends StatelessWidget {
  final _Project? project;
  final int count;
  final bool isSuperAdmin;
  final VoidCallback onTap;
  final bool isNoProject;

  _ProjectCard({
    required _Project project,
    required this.isSuperAdmin,
    required this.onTap,
  })  : project = project,
        count = project.count,
        isNoProject = false;

  _ProjectCard.noProject({
    required this.count,
    required this.onTap,
  })  : project = null,
        isSuperAdmin = true,
        isNoProject = true;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isNoProject ? 'Plans without Project' : project!.name,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 15),
                  ),
                  if (!isNoProject && project!.organizationName != null)
                    Text(project!.organizationName!,
                        style: TextStyle(
                            fontSize: 12, color: Colors.grey.shade600)),
                  if (isNoProject)
                    const Text('Unassigned plans',
                        style:
                            TextStyle(fontSize: 12, color: Colors.grey)),
                ],
              ),
            ),
            if (isSuperAdmin)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFF3E5F5),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '$count plans',
                  style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF592941),
                      fontWeight: FontWeight.w600),
                ),
              )
            else
              const Icon(Icons.chevron_right,
                  color: Color(0xFF592941), size: 20),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Plan details sheet
// ---------------------------------------------------------------------------

class _PlanDetailsSheet extends StatelessWidget {
  final _Plan plan;
  final String? projectName;
  final bool isSuperAdmin;
  final VoidCallback onBack;
  final double bottomPadding;

  const _PlanDetailsSheet({
    required this.plan,
    required this.projectName,
    required this.isSuperAdmin,
    required this.onBack,
    required this.bottomPadding,
  });

  String _formatDate(String? d) {
    if (d == null) return '—';
    try {
      final dt = DateTime.parse(d);
      const months = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
      ];
      return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
    } catch (_) {
      return d;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.88,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 4),
            child: Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2)),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 12, 8),
            child: Row(
              children: [
                GestureDetector(
                  onTap: onBack,
                  child: Container(
                    width: 36,
                    height: 36,
                    margin: const EdgeInsets.only(right: 12),
                    decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(10)),
                    child: const Icon(Icons.arrow_back_ios_new,
                        size: 14, color: Colors.black54),
                  ),
                ),
                const Expanded(
                  child: Text(
                    'Plan Details',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF592941)),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: EdgeInsets.fromLTRB(16, 8, 16, bottomPadding + 16),
              children: [
                // Org / Project banner
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3E5F5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      if (plan.organizationName != null)
                        Expanded(
                          child: _DetailMini(
                            label: 'Organization',
                            value: plan.organizationName!,
                          ),
                        ),
                      if (projectName != null) ...[
                        Container(
                            width: 1,
                            height: 36,
                            color: const Color(0xFFD6D5C9),
                            margin: const EdgeInsets.symmetric(horizontal: 12)),
                        Expanded(
                          child: _DetailMini(
                              label: 'Project',
                              value: projectName!),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Plan name
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(plan.name,
                          style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87)),
                      const SizedBox(height: 12),
                      _DetailRow(label: 'Plan ID', value: '${plan.id}'),
                      _DetailRow(label: 'Village', value: plan.villageName),
                      if (plan.gramPanchayat != null && plan.gramPanchayat!.isNotEmpty)
                        _DetailRow(
                            label: 'Gram Panchayat',
                            value: plan.gramPanchayat!),
                      _DetailRow(
                          label: 'Facilitator',
                          value: plan.facilitatorName),
                      _DetailRow(
                          label: 'Created',
                          value: _formatDate(plan.createdAt)),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Status
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Status',
                          style: TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 14)),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 12,
                        runSpacing: 8,
                        children: [
                          _StatusDot(
                              label: 'Completed',
                              active: plan.isCompleted),
                          _StatusDot(
                              label: 'DPR Generated',
                              active: plan.isDprGenerated),
                          _StatusDot(
                              label: 'DPR Reviewed',
                              active: plan.isDprReviewed),
                          _StatusDot(
                              label: 'DPR Approved',
                              active: plan.isDprApproved),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Location
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Location IDs',
                          style: TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 14)),
                      const SizedBox(height: 8),
                      _DetailRow(
                          label: 'State',
                          value: plan.stateSoi?.toString() ?? '—'),
                      _DetailRow(
                          label: 'District',
                          value: plan.districtSoi?.toString() ?? '—'),
                      _DetailRow(
                          label: 'Tehsil',
                          value: plan.tehsilSoi?.toString() ?? '—'),
                    ],
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

class _DetailMini extends StatelessWidget {
  final String label;
  final String value;

  const _DetailMini({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label.toUpperCase(),
            style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: Color(0xFF592941),
                letterSpacing: 0.5)),
        const SizedBox(height: 2),
        Text(value,
            style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.black87)),
      ],
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(label,
                style: TextStyle(
                    fontSize: 13, color: Colors.grey.shade600)),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }
}

class _StatusDot extends StatelessWidget {
  final String label;
  final bool active;

  const _StatusDot({required this.label, required this.active});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: active ? const Color(0xFF4CAF50) : Colors.grey.shade300,
          ),
        ),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }
}
