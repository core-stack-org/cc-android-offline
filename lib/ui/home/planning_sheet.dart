import 'package:flutter/material.dart';
import 'package:nrmflutter/config/geoserver_config.dart';
import 'package:nrmflutter/ui/home/planning/groundwater_screen.dart';
import 'package:nrmflutter/ui/home/planning/surface_water_screen.dart';
import 'package:nrmflutter/ui/home/planning/agriculture_screen.dart';
import 'package:nrmflutter/ui/home/planning/livelihood_screen.dart';
import 'package:nrmflutter/ui/home/planning/agrohorticulture_screen.dart';

class PlanningSheet extends StatelessWidget {
  final String district;
  final String block;
  final String blockId;
  final String geoserverUrl;

  const PlanningSheet({
    super.key,
    required this.district,
    required this.block,
    required this.blockId,
    required this.geoserverUrl,
  });

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Container(
      height: MediaQuery.of(context).size.height * 0.72,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          _SheetHandle(),
          const SizedBox(height: 4),
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Planning',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF592941),
                ),
              ),
            ),
          ),
          Expanded(
            child: _PlanningSubtabs(
              district: district,
              block: block,
              blockId: blockId,
              geoserverUrl: geoserverUrl,
              bottomPadding: bottomPadding,
            ),
          ),
        ],
      ),
    );
  }
}

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

class _PlanningSubtabs extends StatefulWidget {
  final String district;
  final String block;
  final String blockId;
  final String geoserverUrl;
  final double bottomPadding;

  const _PlanningSubtabs({
    required this.district,
    required this.block,
    required this.blockId,
    required this.geoserverUrl,
    required this.bottomPadding,
  });

  @override
  State<_PlanningSubtabs> createState() => _PlanningSubtabsState();
}

class _PlanningSubtabsState extends State<_PlanningSubtabs>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  static const _tabs = [
    (label: 'Groundwater', category: PlanningCategory.groundwater),
    (label: 'Surface Water', category: PlanningCategory.surfaceWater),
    (label: 'Agriculture', category: PlanningCategory.agriculture),
    (label: 'Livelihood', category: PlanningCategory.livelihood),
    (label: 'Agrohorticulture', category: PlanningCategory.agrohorticulture),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Widget _screenFor(PlanningCategory category) {
    final ctx = (
      district: widget.district,
      block: widget.block,
      blockId: widget.blockId,
      geoserverUrl: widget.geoserverUrl,
    );
    switch (category) {
      case PlanningCategory.groundwater:
        return GroundwaterScreen(
            district: ctx.district,
            block: ctx.block,
            blockId: ctx.blockId,
            geoserverUrl: ctx.geoserverUrl);
      case PlanningCategory.surfaceWater:
        return SurfaceWaterScreen(
            district: ctx.district,
            block: ctx.block,
            blockId: ctx.blockId,
            geoserverUrl: ctx.geoserverUrl);
      case PlanningCategory.agriculture:
        return AgricultureScreen(
            district: ctx.district,
            block: ctx.block,
            blockId: ctx.blockId,
            geoserverUrl: ctx.geoserverUrl);
      case PlanningCategory.livelihood:
        return LivelihoodScreen(
            district: ctx.district,
            block: ctx.block,
            blockId: ctx.blockId,
            geoserverUrl: ctx.geoserverUrl);
      case PlanningCategory.agrohorticulture:
        return AgrohorticultureScreen(
            district: ctx.district,
            block: ctx.block,
            blockId: ctx.blockId,
            geoserverUrl: ctx.geoserverUrl);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: TabBar(
            controller: _tabController,
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            labelColor: const Color(0xFF592941),
            unselectedLabelColor: Colors.grey,
            indicatorColor: const Color(0xFF592941),
            indicatorWeight: 2.5,
            labelStyle: const TextStyle(
                fontWeight: FontWeight.w600, fontSize: 13),
            unselectedLabelStyle: const TextStyle(
                fontWeight: FontWeight.w500, fontSize: 13),
            tabs: _tabs.map((t) => Tab(text: t.label)).toList(),
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: _tabs.map((t) => _screenFor(t.category)).toList(),
          ),
        ),
      ],
    );
  }
}
