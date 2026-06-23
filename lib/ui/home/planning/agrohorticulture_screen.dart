import 'package:flutter/material.dart';
import 'package:nrmflutter/config/geoserver_config.dart';
import 'planning_category_screen.dart';

class AgrohorticultureScreen extends StatelessWidget {
  final String district;
  final String block;
  final String blockId;
  final String geoserverUrl;

  const AgrohorticultureScreen({
    super.key,
    required this.district,
    required this.block,
    required this.blockId,
    required this.geoserverUrl,
  });

  @override
  Widget build(BuildContext context) {
    return PlanningCategoryScreen(
      category: PlanningCategory.agrohorticulture,
      categoryTitle: 'Agrohorticulture',
      district: district,
      block: block,
      blockId: blockId,
      geoserverUrl: geoserverUrl,
    );
  }
}
