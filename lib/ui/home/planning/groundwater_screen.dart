import 'package:flutter/material.dart';
import 'package:nrmflutter/config/geoserver_config.dart';
import 'planning_category_screen.dart';

class GroundwaterScreen extends StatelessWidget {
  final String district;
  final String block;
  final String blockId;
  final String geoserverUrl;

  const GroundwaterScreen({
    super.key,
    required this.district,
    required this.block,
    required this.blockId,
    required this.geoserverUrl,
  });

  @override
  Widget build(BuildContext context) {
    return PlanningCategoryScreen(
      category: PlanningCategory.groundwater,
      categoryTitle: 'Groundwater',
      district: district,
      block: block,
      blockId: blockId,
      geoserverUrl: geoserverUrl,
    );
  }
}
