import 'package:flutter/material.dart';
import 'package:nrmflutter/config/geoserver_config.dart';
import 'package:nrmflutter/ui/home/planning/groundwater_screen.dart';
import 'package:nrmflutter/ui/home/planning/surface_water_screen.dart';
import 'package:nrmflutter/ui/home/planning/agriculture_screen.dart';
import 'package:nrmflutter/ui/home/planning/livelihood_screen.dart';
import 'package:nrmflutter/ui/home/planning/agrohorticulture_screen.dart';

class PlanningScreen extends StatefulWidget {
  final String district;
  final String block;
  final String blockId;
  final String geoserverUrl;

  const PlanningScreen({
    super.key,
    required this.district,
    required this.block,
    required this.blockId,
    required this.geoserverUrl,
  });

  @override
  State<PlanningScreen> createState() => _PlanningScreenState();
}

class _PlanningScreenState extends State<PlanningScreen>
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
    switch (category) {
      case PlanningCategory.groundwater:
        return GroundwaterScreen(
            district: widget.district,
            block: widget.block,
            blockId: widget.blockId,
            geoserverUrl: widget.geoserverUrl);
      case PlanningCategory.surfaceWater:
        return SurfaceWaterScreen(
            district: widget.district,
            block: widget.block,
            blockId: widget.blockId,
            geoserverUrl: widget.geoserverUrl);
      case PlanningCategory.agriculture:
        return AgricultureScreen(
            district: widget.district,
            block: widget.block,
            blockId: widget.blockId,
            geoserverUrl: widget.geoserverUrl);
      case PlanningCategory.livelihood:
        return LivelihoodScreen(
            district: widget.district,
            block: widget.block,
            blockId: widget.blockId,
            geoserverUrl: widget.geoserverUrl);
      case PlanningCategory.agrohorticulture:
        return AgrohorticultureScreen(
            district: widget.district,
            block: widget.block,
            blockId: widget.blockId,
            geoserverUrl: widget.geoserverUrl);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        centerTitle: true,
        title: const Text(
          'Planning',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          indicatorColor: const Color(0xFFD6D5C9),
          indicatorWeight: 3,
          labelStyle:
              const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          unselectedLabelStyle:
              const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
          tabs: _tabs.map((t) => Tab(text: t.label)).toList(),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: _tabs.map((t) => _screenFor(t.category)).toList(),
      ),
    );
  }
}
