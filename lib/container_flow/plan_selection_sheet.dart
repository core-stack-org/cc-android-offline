import 'package:flutter/material.dart';

import '../services/plans_service.dart';

class PlanSelectionSheet extends StatefulWidget {
  final String tehsilId;
  final PlansService plansService;
  final List<WatershedPlan>? initialPlans;
  final int? selectedPlanId;

  const PlanSelectionSheet({
    super.key,
    required this.tehsilId,
    required this.plansService,
    this.initialPlans,
    this.selectedPlanId,
  });

  static Future<WatershedPlan?> show({
    required BuildContext context,
    required String tehsilId,
    PlansService? plansService,
    List<WatershedPlan>? initialPlans,
    int? selectedPlanId,
  }) {
    return showModalBottomSheet<WatershedPlan>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: const Color(0xFFFAFAF7),
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (_) => PlanSelectionSheet(
        tehsilId: tehsilId,
        plansService: plansService ?? PlansService(),
        initialPlans: initialPlans,
        selectedPlanId: selectedPlanId,
      ),
    );
  }

  @override
  State<PlanSelectionSheet> createState() => _PlanSelectionSheetState();
}

class _PlanSelectionSheetState extends State<PlanSelectionSheet> {
  late Future<List<WatershedPlan>> _plansFuture;
  Future<String>? _roleFuture;
  final _searchController = TextEditingController();
  final _plansScrollController = ScrollController();
  int? _selectedProjectId;
  _PlanSearchField _searchField = _PlanSearchField.all;
  bool _detailsVisible = false;
  bool _showScrollToTop = false;
  bool _filtersTouched = false;
  String? _matchedFacilitatorName;

  @override
  void initState() {
    super.initState();
    _plansFuture = widget.initialPlans == null
        ? widget.plansService.fetchPlans(tehsilId: widget.tehsilId)
        : Future.value(widget.initialPlans);
    _roleFuture = widget.plansService.getUserRoleLabel();
    _plansScrollController.addListener(_handlePlanScroll);
    _applyUserFacilitatorFilter(_plansFuture);
  }

  void _retry() {
    final plansFuture = widget.plansService.fetchPlans(
      tehsilId: widget.tehsilId,
    );
    setState(() {
      _plansFuture = plansFuture;
    });
    _applyUserFacilitatorFilter(plansFuture);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _plansScrollController.dispose();
    super.dispose();
  }

  void _handlePlanScroll() {
    final shouldShow = _plansScrollController.offset > 240;
    if (shouldShow != _showScrollToTop) {
      setState(() => _showScrollToTop = shouldShow);
    }
  }

  void _scrollToTop() {
    _plansScrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _applyUserFacilitatorFilter(
    Future<List<WatershedPlan>> plansFuture,
  ) async {
    try {
      final results = await Future.wait([
        plansFuture,
        widget.plansService.getUserFullName(),
      ]);
      final plans = results[0] as List<WatershedPlan>;
      final userFullName = results[1] as String?;
      if (!mounted ||
          _filtersTouched ||
          userFullName == null ||
          !plans.any(
            (plan) =>
                !plan.isTestPlan && planMatchesFacilitator(plan, userFullName),
          )) {
        return;
      }

      setState(() {
        _searchController.text = userFullName;
        _searchField = _PlanSearchField.facilitator;
        _matchedFacilitatorName = userFullName;
      });
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: AnimatedSlide(
        offset: _detailsVisible ? const Offset(0, 0.025) : Offset.zero,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
        child: AnimatedScale(
          scale: _detailsVisible ? 0.97 : 1,
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOutCubic,
          child: SizedBox(
            height: MediaQuery.sizeOf(context).height * 0.85,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Select Plan',
                    style: TextStyle(
                      color: Color(0xFF592941),
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Choose the watershed plan for this region',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                  ),
                  const SizedBox(height: 10),
                  FutureBuilder<String>(
                    future: _roleFuture ??=
                        widget.plansService.getUserRoleLabel(),
                    builder: (context, snapshot) => _RoleChip(
                      role: snapshot.data ?? 'Loading role…',
                      isLoading:
                          snapshot.connectionState == ConnectionState.waiting,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: FutureBuilder<List<WatershedPlan>>(
                      future: _plansFuture,
                      builder: (context, snapshot) {
                        final Widget content;
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          content = const _LoadingView(
                            key: ValueKey('loading'),
                          );
                        } else if (snapshot.hasError) {
                          content = _ErrorView(
                            key: const ValueKey('error'),
                            message: snapshot.error.toString(),
                            onRetry: _retry,
                          );
                        } else {
                          final plans = snapshot.data ?? const [];
                          content = plans.isEmpty
                              ? const _EmptyView(
                                  key: ValueKey('empty'),
                                  icon: Icons.assignment_outlined,
                                  message:
                                      'No plans are available for this user.',
                                )
                              : KeyedSubtree(
                                  key: const ValueKey('plans'),
                                  child: _buildPlanList(plans),
                                );
                        }
                        return AnimatedSwitcher(
                          duration: const Duration(milliseconds: 280),
                          child: content,
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPlanList(List<WatershedPlan> plans) {
    final projects = <int, String>{
      for (final plan in plans)
        if (plan.projectId != null)
          plan.projectId!: plan.projectName.isEmpty
              ? 'Project ${plan.projectId}'
              : plan.projectName,
    };
    final projectPlans = _selectedProjectId == null
        ? plans
        : plans.where((plan) => plan.projectId == _selectedProjectId).toList();
    final regularCandidates =
        projectPlans.where((plan) => !plan.isTestPlan).toList();
    final query = _searchController.text.trim().toLowerCase();
    final regularPlans = query.isEmpty
        ? regularCandidates
        : regularCandidates.where((plan) {
            if (_matchedFacilitatorName != null &&
                _searchField == _PlanSearchField.facilitator) {
              return planMatchesFacilitator(
                plan,
                _matchedFacilitatorName!,
              );
            }
            final values = switch (_searchField) {
              _PlanSearchField.all => [
                  plan.name,
                  plan.villageName,
                  plan.facilitatorName,
                  plan.projectName,
                ],
              _PlanSearchField.facilitator => [plan.facilitatorName],
              _PlanSearchField.village => [plan.villageName],
            };
            return values.any((value) => value.toLowerCase().contains(query));
          }).toList();
    final testPlans = plans.where((plan) => plan.isTestPlan).toList();
    final visiblePlans = [...regularPlans, ...testPlans];
    final showScrollToTop = _showScrollToTop && visiblePlans.isNotEmpty;

    return Column(
      children: [
        if (projects.length > 1) ...[
          _ProjectSelector(
            label: _selectedProjectId == null
                ? 'All projects'
                : projects[_selectedProjectId] ?? 'All projects',
            onTap: () => _showProjectPicker(projects),
          ),
          const SizedBox(height: 12),
        ],
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _searchController,
                onChanged: (_) => setState(() {
                  _filtersTouched = true;
                  _matchedFacilitatorName = null;
                }),
                decoration: InputDecoration(
                  hintText: 'Search plans',
                  prefixIcon: const Icon(
                    Icons.search,
                    color: Color(0xFF592941),
                  ),
                  suffixIcon: _searchController.text.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () {
                            _searchController.clear();
                            setState(() {
                              _filtersTouched = true;
                              _matchedFacilitatorName = null;
                            });
                          },
                        ),
                  filled: true,
                  fillColor: const Color(0xFFD6D5C9).withValues(alpha: 0.55),
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              decoration: BoxDecoration(
                color: _searchField == _PlanSearchField.all
                    ? const Color(0xFFD6D5C9).withValues(alpha: 0.55)
                    : const Color(0xFF592941),
                borderRadius: BorderRadius.circular(16),
                boxShadow: _searchField == _PlanSearchField.all
                    ? null
                    : [
                        BoxShadow(
                          color:
                              const Color(0xFF592941).withValues(alpha: 0.22),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: _showSearchFilter,
                  child: SizedBox(
                    width: 52,
                    height: 52,
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 180),
                      child: Icon(
                        Icons.tune,
                        key: ValueKey(_searchField),
                        color: _searchField == _PlanSearchField.all
                            ? const Color(0xFF592941)
                            : Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              child: Text(
                '${visiblePlans.length} ${visiblePlans.length == 1 ? 'plan' : 'plans'}',
                key: ValueKey(visiblePlans.length),
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const Spacer(),
            if (_searchField != _PlanSearchField.all)
              _FilterChip(
                label: _searchField.label,
                onClear: () => setState(() {
                  _filtersTouched = true;
                  _matchedFacilitatorName = null;
                  _searchField = _PlanSearchField.all;
                }),
              ),
          ],
        ),
        const SizedBox(height: 10),
        Expanded(
          child: Stack(
            children: [
              Positioned.fill(
                child: visiblePlans.isEmpty
                    ? const _EmptyView(
                        icon: Icons.search_off,
                        message: 'No matching plans found.',
                      )
                    : ListView(
                        controller: _plansScrollController,
                        padding: const EdgeInsets.only(bottom: 76),
                        children: [
                          ...regularPlans.indexed.map(
                            (entry) => _buildPlanTile(entry.$2, entry.$1),
                          ),
                          if (testPlans.isNotEmpty) ...[
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 10),
                              child: Row(
                                children: [
                                  Expanded(child: Divider()),
                                  Padding(
                                    padding:
                                        EdgeInsets.symmetric(horizontal: 12),
                                    child: Text(
                                      'Test / Demo Plans',
                                      style: TextStyle(
                                        color: Color(0xFF592941),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  Expanded(child: Divider()),
                                ],
                              ),
                            ),
                            ...testPlans.indexed.map(
                              (entry) => _buildPlanTile(
                                entry.$2,
                                regularPlans.length + entry.$1,
                              ),
                            ),
                          ],
                        ],
                      ),
              ),
              Positioned(
                right: 8,
                bottom: 16,
                child: IgnorePointer(
                  ignoring: !showScrollToTop,
                  child: AnimatedSlide(
                    offset:
                        showScrollToTop ? Offset.zero : const Offset(0, 0.35),
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOutCubic,
                    child: AnimatedOpacity(
                      opacity: showScrollToTop ? 1 : 0,
                      duration: const Duration(milliseconds: 180),
                      child: Material(
                        color: Colors.black,
                        elevation: 6,
                        shadowColor: Colors.black38,
                        shape: const CircleBorder(),
                        child: IconButton(
                          tooltip: 'Back to top',
                          onPressed: _scrollToTop,
                          icon: const Icon(
                            Icons.arrow_upward_rounded,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _showProjectPicker(Map<int, String> projects) async {
    final selectedProject = await showModalBottomSheet<int>(
      context: context,
      useRootNavigator: true,
      showDragHandle: true,
      backgroundColor: const Color(0xFFFAFAF7),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (context) => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Select Project',
                style: TextStyle(
                  color: Color(0xFF592941),
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    _projectOption(context, -1, 'All projects'),
                    ...projects.entries.map(
                      (project) =>
                          _projectOption(context, project.key, project.value),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (!mounted || selectedProject == null) return;
    final projectId = selectedProject == -1 ? null : selectedProject;
    if (projectId == _selectedProjectId) return;
    setState(() {
      _filtersTouched = true;
      _selectedProjectId = projectId;
    });
  }

  Widget _projectOption(BuildContext context, int id, String name) {
    final isSelected =
        id == -1 ? _selectedProjectId == null : id == _selectedProjectId;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
      title: Text(name),
      trailing: isSelected
          ? const Icon(Icons.check_circle, color: Color(0xFF592941))
          : null,
      onTap: () => Navigator.pop(context, id),
    );
  }

  Future<void> _showSearchFilter() async {
    final field = await showModalBottomSheet<_PlanSearchField>(
      context: context,
      useRootNavigator: true,
      showDragHandle: true,
      backgroundColor: const Color(0xFFFAFAF7),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (context) => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Search plans by',
                style: TextStyle(
                  color: Color(0xFF592941),
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              ..._PlanSearchField.values.map(
                (field) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(field.label),
                  trailing: field == _searchField
                      ? const Icon(
                          Icons.check_circle,
                          color: Color(0xFF592941),
                        )
                      : null,
                  onTap: () => Navigator.pop(context, field),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (field != null && mounted) {
      setState(() {
        _filtersTouched = true;
        _matchedFacilitatorName = null;
        _searchField = field;
      });
    }
  }

  Widget _buildPlanTile(WatershedPlan plan, int index) {
    final isSelected = plan.id == widget.selectedPlanId;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(
        milliseconds: 260 + (index > 5 ? 5 : index) * 45,
      ),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) => Opacity(
        opacity: value,
        child: Transform.translate(
          offset: Offset(0, 10 * (1 - value)),
          child: child,
        ),
      ),
      child: Card(
        margin: const EdgeInsets.only(bottom: 12),
        elevation: isSelected ? 2 : 0,
        shadowColor: Colors.black.withValues(alpha: 0.12),
        color: isSelected ? const Color(0xFFF1FAFC) : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(
            color:
                isSelected ? const Color(0xFF8DCBD5) : const Color(0xFFE1E1E1),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => Navigator.pop(context, plan),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: Colors.black,
                        borderRadius: BorderRadius.circular(13),
                      ),
                      child: const Icon(
                        Icons.description_outlined,
                        color: Colors.white,
                        size: 21,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            plan.projectName.isEmpty
                                ? 'WATERSHED PLAN'
                                : plan.projectName.toUpperCase(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.7,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            plan.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.black,
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                              height: 1.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Material(
                      color: const Color(0xFFF2F2F2),
                      shape: const CircleBorder(),
                      child: IconButton(
                        tooltip: 'Plan details',
                        visualDensity: VisualDensity.compact,
                        icon: const Icon(
                          Icons.info_outline,
                          color: Colors.black,
                          size: 20,
                        ),
                        onPressed: () => _showPlanDetails(plan),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 7,
                  runSpacing: 7,
                  children: [
                    _metadataPill(
                      Icons.location_on_outlined,
                      plan.villageName,
                    ),
                    _metadataPill(
                      Icons.person_outline,
                      plan.facilitatorName,
                    ),
                    _metadataPill(Icons.tag, 'Plan ${plan.id}'),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _metadataPill(IconData icon, String value) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 220),
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F3F3),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.black54),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              value.isEmpty ? '—' : value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.black87,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showPlanDetails(WatershedPlan plan) async {
    setState(() => _detailsVisible = true);
    try {
      await showModalBottomSheet<void>(
        context: context,
        useRootNavigator: true,
        isScrollControlled: true,
        showDragHandle: true,
        backgroundColor: const Color(0xFFFAFAF7),
        barrierColor: Colors.black54,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
        ),
        builder: (context) => FutureBuilder<Map<String, dynamic>>(
          future: widget.plansService.fetchPlanDetails(plan),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const SizedBox(
                height: 240,
                child: Center(child: CircularProgressIndicator()),
              );
            }
            if (snapshot.hasError) {
              return SizedBox(
                height: 240,
                child: Center(child: Text(snapshot.error.toString())),
              );
            }
            return _PlanDetails(plan: plan, details: snapshot.data ?? const {});
          },
        ),
      );
    } finally {
      if (mounted) setState(() => _detailsVisible = false);
    }
  }
}

class _PlanDetails extends StatelessWidget {
  final WatershedPlan plan;
  final Map<String, dynamic> details;

  const _PlanDetails({required this.plan, required this.details});

  @override
  Widget build(BuildContext context) {
    final overview = <(String, dynamic)>[
      ('Plan ID', plan.id),
      ('Project', details['project_name'] ?? plan.projectName),
      ('Organization', details['organization_name']),
      ('Facilitator', details['facilitator_name'] ?? plan.facilitatorName),
      ('Created by', details['created_by_name']),
    ];
    final location = <(String, dynamic)>[
      (
        'State',
        _firstValue(['state_name', 'state_soi_name', 'state_soi', 'state'])
      ),
      (
        'District',
        _firstValue([
          'district_name',
          'district_soi_name',
          'district_soi',
          'district',
        ])
      ),
      (
        'Tehsil',
        _firstValue([
          'tehsil_name',
          'tehsil_soi_name',
          'tehsil_soi',
          'tehsil',
          'block_name',
          'block',
        ])
      ),
      ('Village', details['village_name']),
      ('Gram Panchayat', details['gram_panchayat']),
    ];
    final status = <(String, dynamic)>[
      ('Completed', details['is_completed']),
      ('DPR generated', details['is_dpr_generated']),
      ('DPR reviewed', details['is_dpr_reviewed']),
      ('DPR approved', details['is_dpr_approved']),
    ];

    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'PLAN DETAILS',
                style: TextStyle(
                  color: Colors.black54,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.4,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                plan.name,
                style: const TextStyle(
                  color: Colors.black,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              _detailsCard(
                title: 'Plan overview',
                icon: Icons.assignment_outlined,
                rows: overview,
              ),
              const SizedBox(height: 12),
              _detailsCard(
                title: 'Location',
                icon: Icons.location_on_outlined,
                rows: location,
              ),
              if (_hasValues(status)) ...[
                const SizedBox(height: 12),
                _detailsCard(
                  title: 'Status',
                  icon: Icons.fact_check_outlined,
                  rows: status,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _detailsCard({
    required String title,
    required IconData icon,
    required List<(String, dynamic)> rows,
  }) {
    final visibleRows = rows.where(_hasValue).toList();

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) => Opacity(
        opacity: value,
        child: Transform.translate(
          offset: Offset(0, 8 * (1 - value)),
          child: child,
        ),
      ),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFD4D4D4)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.07),
              blurRadius: 18,
              offset: const Offset(0, 7),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: const BoxDecoration(
                    color: Colors.black,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: Colors.white, size: 17),
                ),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.black,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: visibleRows
                  .map(
                    (row) => _detailChip(row.$1, _displayValue(row.$2)),
                  )
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _detailChip(String label, String value) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 280),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: const Color(0xFF262626),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF3D3D3D)),
      ),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(fontSize: 12, height: 1.25),
          children: [
            TextSpan(
              text: '$label  ',
              style: const TextStyle(
                color: Color(0xFFAAAAAA),
                fontWeight: FontWeight.w500,
              ),
            ),
            TextSpan(
              text: value,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool _hasValues(List<(String, dynamic)> rows) => rows.any(_hasValue);

  bool _hasValue((String, dynamic) row) {
    return row.$2 != null && row.$2.toString().isNotEmpty;
  }

  String _displayValue(dynamic value) {
    if (value is bool) return value ? 'Yes' : 'No';
    return value.toString();
  }

  dynamic _firstValue(List<String> keys) {
    for (final key in keys) {
      final value = details[key];
      if (value != null && value.toString().isNotEmpty) return value;
    }
    return null;
  }
}

class _ProjectSelector extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _ProjectSelector({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFD6D5C9).withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF592941).withValues(alpha: 0.12),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: const BoxDecoration(
                    color: Color(0xFFDBEFF2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.folder_outlined,
                    color: Color(0xFF592941),
                    size: 18,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF592941),
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const Icon(
                  Icons.keyboard_arrow_down,
                  color: Color(0xFF592941),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RoleChip extends StatelessWidget {
  final String role;
  final bool isLoading;

  const _RoleChip({required this.role, required this.isLoading});

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: isLoading ? 0.55 : 1,
      duration: const Duration(milliseconds: 180),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 300),
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.admin_panel_settings_outlined,
              color: Colors.white,
              size: 15,
            ),
            const SizedBox(width: 6),
            const Text(
              'ROLE',
              style: TextStyle(
                color: Colors.white54,
                fontSize: 9,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                role,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum _PlanSearchField {
  all('All fields'),
  facilitator('Facilitator name'),
  village('Village name');

  final String label;

  const _PlanSearchField(this.label);
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorView({
    super.key,
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          ElevatedButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}

class _LoadingView extends StatelessWidget {
  const _LoadingView({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: SizedBox(
        width: 28,
        height: 28,
        child: CircularProgressIndicator(
          strokeWidth: 3,
          color: Color(0xFF592941),
        ),
      ),
    );
  }
}

class _EmptyView extends StatelessWidget {
  final IconData icon;
  final String message;

  const _EmptyView({
    super.key,
    required this.icon,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: const BoxDecoration(
              color: Color(0xFFDBEFF2),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: const Color(0xFF397D8A), size: 28),
          ),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final VoidCallback onClear;

  const _FilterChip({required this.label, required this.onClear});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFDBEFF2),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onClear,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 5, 7, 5),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: Color(0xFF397D8A),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.close, size: 14, color: Color(0xFF397D8A)),
            ],
          ),
        ),
      ),
    );
  }
}
