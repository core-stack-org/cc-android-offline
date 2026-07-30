import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nrmflutter/utils/constants.dart';
import 'package:nrmflutter/db/location_db.dart';
import 'package:nrmflutter/utils/layers_config.dart';
import 'package:http/http.dart' as http;
import 'package:connectivity_plus/connectivity_plus.dart';
//import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import '../l10n/app_localizations.dart';
import '../ui/profile_screen.dart' show kRefreshPlanLayersOnNavigatePrefKey;
import '../utils/toast.dart';

import 'dart:io';
import 'container_manager.dart';
import 'plan_selection_sheet.dart';
import '../services/plans_service.dart';
import './../utils/mark_location.dart';
import './../download_progress.dart';

class ContainerSheets {
  /// Shows bottom sheet for creating a new container
  static void showCreateContainer({
    required BuildContext context,
    required String selectedLanguage,
    required String selectedState,
    required String selectedDistrict,
    required String selectedBlock,
    required String selectedBlockId,
    required Function(OfflineContainer) onContainerCreated,
  }) {
    final containerNameController = TextEditingController();
    final plansService = PlansService();
    List<WatershedPlan>? availablePlans;
    double? selectedLat;
    double? selectedLon;
    bool locationSelected = false;
    WatershedPlan? selectedPlan;

    bool _isValidRegionName(String name) {
      if (name.isEmpty) return false;
      if (name.contains(' ')) return false;
      if (name.contains('-')) return false;
      return true;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (BuildContext sheetContext) {
        final localizations = AppLocalizations.of(sheetContext)!;

        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Container(
                padding: EdgeInsets.only(
                  left: 20,
                  right: 20,
                  top: 20,
                  bottom: 20 + MediaQuery.of(context).viewPadding.bottom,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      localizations.createNewRegion,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF592941),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Step 1: Location Selection
                    ElevatedButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => MapLocationSelector(
                              blockName: selectedBlock,
                              districtName: selectedDistrict,
                              geoserverUrl: geoserverUrl,
                              onLocationSelect: (lat, lon, villageName) async {
                                setState(() {
                                  selectedLat = lat;
                                  selectedLon = lon;
                                  locationSelected = true;
                                  selectedPlan = null;
                                  if (villageName != null &&
                                      villageName.isNotEmpty) {
                                    containerNameController.text = villageName
                                        .replaceAll(' ', '_')
                                        .replaceAll('-', '_');
                                  }
                                });

                                if (villageName == null ||
                                    villageName.isEmpty) {
                                  return;
                                }

                                try {
                                  availablePlans ??=
                                      await plansService.fetchPlans(
                                    tehsilId: selectedBlockId,
                                  );
                                  final matchingPlan = findPlanForVillage(
                                    availablePlans!,
                                    villageName,
                                  );
                                  if (sheetContext.mounted &&
                                      matchingPlan != null) {
                                    setState(() => selectedPlan = matchingPlan);
                                  }
                                } catch (_) {}
                              },
                            ),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFD6D5C9),
                        minimumSize: const Size(double.infinity, 50),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        alignment: Alignment.centerLeft,
                      ),
                      child: Container(
                        width: double.infinity,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          locationSelected
                              ? '${localizations.latitude}: ${selectedLat?.toStringAsFixed(4)}, ${localizations.longitude}: ${selectedLon?.toStringAsFixed(4)}'
                              : localizations.markLocationOnMap,
                          style: const TextStyle(
                            color: Color(0xFF592941),
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    ElevatedButton(
                      onPressed: () async {
                        final plan = await PlanSelectionSheet.show(
                          context: context,
                          tehsilId: selectedBlockId,
                          plansService: plansService,
                          initialPlans: availablePlans,
                          selectedPlanId: selectedPlan?.id,
                        );
                        if (plan != null) {
                          setState(() => selectedPlan = plan);
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFD6D5C9),
                        minimumSize: const Size(double.infinity, 50),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        alignment: Alignment.centerLeft,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              selectedPlan?.name ?? 'Select Plan',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Color(0xFF592941),
                                fontSize: 16,
                              ),
                            ),
                          ),
                          const Icon(
                            Icons.chevron_right,
                            color: Color(0xFF592941),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            color: locationSelected
                                ? const Color(0xFFD6D5C9)
                                : const Color(0xFFddd8e0),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: TextField(
                            controller: containerNameController,
                            enabled: locationSelected,
                            style: const TextStyle(
                              color: Color(0xFF592941),
                            ),
                            decoration: InputDecoration(
                              hintText: localizations.nameYourRegion,
                              hintStyle: const TextStyle(
                                color: Color(0xFF592941),
                                fontSize: 16,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(20),
                                borderSide: BorderSide.none,
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 15,
                              ),
                              enabled: locationSelected,
                            ),
                            onChanged: (value) {
                              setState(() {});
                            },
                          ),
                        ),
                        const SizedBox(height: 8),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (containerNameController.text.isNotEmpty &&
                                  !_isValidRegionName(
                                      containerNameController.text))
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: Text(
                                    containerNameController.text.contains(' ')
                                        ? '⚠ Name cannot contain spaces'
                                        : containerNameController.text
                                                .contains('-')
                                            ? '⚠ Name cannot contain dashes'
                                            : '⚠ Invalid name format',
                                    style: const TextStyle(
                                      color: Colors.red,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              Text(
                                'Examples: Sidpahari, Belpahari, Amra_Kamat',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Use underscores only (no spaces or dashes)',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),
                    Center(
                      child: ElevatedButton(
                        onPressed: locationSelected &&
                                selectedPlan != null &&
                                _isValidRegionName(containerNameController.text)
                            ? () async {
                                final regionName = containerNameController.text;

                                try {
                                  final container = OfflineContainer(
                                    name: regionName,
                                    state: selectedState,
                                    district: selectedDistrict,
                                    block: selectedBlock,
                                    planId: selectedPlan!.id,
                                    planName: selectedPlan!.name,
                                    projectId: selectedPlan!.projectId,
                                    projectName: selectedPlan!.projectName,
                                    createdAt: DateTime.now(),
                                    latitude: selectedLat!,
                                    longitude: selectedLon!,
                                  );

                                  await ContainerManager.saveContainer(
                                      container);
                                  if (!context.mounted) return;
                                  Navigator.pop(context);
                                  onContainerCreated(container);
                                } catch (e) {
                                  if (sheetContext.mounted) {
                                    showTopToast(sheetContext, e.toString());
                                  }
                                }
                              }
                            : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFD6D5C9),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 40,
                            vertical: 15,
                          ),
                        ),
                        child: Text(
                          localizations.createRegion,
                          style: const TextStyle(
                            color: Color(0xFF592941),
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  /// Shows bottom sheet for selecting an existing container
  static void showContainerList({
    required BuildContext context,
    required String selectedLanguage,
    required String selectedState,
    required String selectedDistrict,
    required String selectedBlock,
    required String selectedBlockId,
    required Function(OfflineContainer) onContainerSelected,
    Function(OfflineContainer)? onContainerCreated,
    bool showAllRegions = false,
  }) {
    String? selectedContainerId;
    String? _refreshingContainerName;
    bool _isNavigating = false;
    double _navigateProgress = 0.0;
    Future<List<OfflineContainer>> containersFuture =
        ContainerManager.getContainers();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          final localizations = AppLocalizations.of(context)!;

          return Container(
            height: MediaQuery.of(context).size.height * 0.9,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Row(
                    children: [
                      Text(
                        localizations.selectARegion,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF592941),
                        ),
                      ),
                    ],
                  ),
                ),
                if (showAllRegions)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF592941).withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.layers_outlined,
                              size: 16, color: Color(0xFF592941)),
                          const SizedBox(width: 8),
                          Text(
                            'All downloaded regions are shown',
                            style: TextStyle(
                              fontSize: 13,
                              color: const Color(0xFF592941)
                                  .withValues(alpha: 0.8),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                if (_refreshingContainerName != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    child: LinearProgressIndicator(
                      color: Colors.blue,
                      backgroundColor: Colors.blue.withOpacity(0.2),
                    ),
                  ),
                Expanded(
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    child: FutureBuilder<List<OfflineContainer>>(
                      future: containersFuture,
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) {
                          return const Center(
                              child: CircularProgressIndicator());
                        }

                        final allContainers = snapshot.data!;
                        final containers = showAllRegions
                            ? allContainers
                            : allContainers
                                .where((c) =>
                                    c.state == selectedState &&
                                    c.district == selectedDistrict &&
                                    c.block == selectedBlock)
                                .toList();

                        if (containers.isEmpty) {
                          return Align(
                            alignment: Alignment.centerLeft,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  localizations.looksLikeNoRegionsCreated,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Color.fromARGB(255, 129, 129, 129),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  localizations.pleaseCreateRegionToStart,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }

                        // Group by tehsil key, sort groups then items within
                        final Map<String, List<OfflineContainer>> grouped = {};
                        for (final c in containers) {
                          final key = '${c.state} › ${c.district} › ${c.block}';
                          grouped.putIfAbsent(key, () => []).add(c);
                        }
                        for (final group in grouped.values) {
                          group.sort(
                              (a, b) => b.createdAt.compareTo(a.createdAt));
                        }
                        final sortedKeys = grouped.keys.toList()..sort();
                        final List<dynamic> listItems = [];
                        for (final key in sortedKeys) {
                          listItems.add(key);
                          listItems.addAll(grouped[key]!);
                        }

                        return ListView.builder(
                          itemCount: listItems.length,
                          itemBuilder: (context, index) {
                            final item = listItems[index];

                            // Section header for grouped (showAllRegions) mode
                            if (item is String) {
                              final parts = item.split(' › ');
                              final tehsilName =
                                  parts.length == 3 ? parts[2] : item;
                              final locationPath = parts.length == 3
                                  ? '${parts[0]} › ${parts[1]}'
                                  : '';
                              return Padding(
                                padding:
                                    const EdgeInsets.only(top: 16, bottom: 6),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      tehsilName,
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF592941),
                                      ),
                                    ),
                                    if (locationPath.isNotEmpty)
                                      Text(
                                        locationPath,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey[600],
                                          fontWeight: FontWeight.w400,
                                        ),
                                      ),
                                  ],
                                ),
                              );
                            }

                            final container = item as OfflineContainer;
                            final isSelected =
                                container.name == selectedContainerId;

                            return Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? const Color(0xFFDBEFF2)
                                    : Colors.white,
                                border: Border.all(
                                    color: const Color(0xFF8DCBD5), width: 1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: ListTile(
                                onTap: () {
                                  setState(() {
                                    selectedContainerId = container.name;
                                  });
                                },
                                trailing: PopupMenuButton<String>(
                                  color: Colors.black.withAlpha(215),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(15.0),
                                  ),
                                  onSelected: (value) async {
                                    if (value == 'redownload') {
                                      _handleRedownload(context, container);
                                    } else if (value == 'refresh') {
                                      setState(() {
                                        _refreshingContainerName =
                                            container.name;
                                      });
                                      await _refreshPlanLayers(
                                          context, container);
                                      if (context.mounted) {
                                        setState(() {
                                          _refreshingContainerName = null;
                                        });
                                      }
                                    } else if (value == 'delete') {
                                      bool confirm = await showDialog(
                                            context: context,
                                            builder: (context) => AlertDialog(
                                              title: Text(localizations
                                                  .deleteRegionConfirmTitle),
                                              content: Text(localizations
                                                  .deleteRegionConfirmMessage(
                                                      container.name)),
                                              actions: [
                                                TextButton(
                                                  child: Text(
                                                      localizations.cancel),
                                                  onPressed: () =>
                                                      Navigator.pop(
                                                          context, false),
                                                ),
                                                TextButton(
                                                  child: Text(
                                                      localizations.delete),
                                                  onPressed: () =>
                                                      Navigator.pop(
                                                          context, true),
                                                ),
                                              ],
                                            ),
                                          ) ??
                                          false;

                                      if (confirm && context.mounted) {
                                        await _deleteContainerAndData(
                                            container.name);
                                        showTopToast(
                                            context,
                                            localizations
                                                .regionDeleted(container.name));
                                        setState(() {
                                          containersFuture =
                                              ContainerManager.getContainers();
                                          if (selectedContainerId ==
                                              container.name) {
                                            selectedContainerId = null;
                                          }
                                        });
                                      }
                                    }
                                  },
                                  itemBuilder: (BuildContext context) =>
                                      <PopupMenuEntry<String>>[
                                    PopupMenuItem<String>(
                                      value: 'redownload',
                                      child: Text(
                                        localizations.refreshAllLayers,
                                        style: const TextStyle(
                                            color: Colors.white),
                                      ),
                                    ),
                                    PopupMenuItem<String>(
                                      value: 'refresh',
                                      child: Text(
                                        localizations.refreshPlanLayersOnly,
                                        style: const TextStyle(
                                            color: Colors.white),
                                      ),
                                    ),
                                    PopupMenuItem<String>(
                                      value: 'delete',
                                      child: Text(
                                        localizations.deleteRegion,
                                        style:
                                            const TextStyle(color: Colors.red),
                                      ),
                                    ),
                                  ],
                                ),
                                contentPadding: const EdgeInsets.all(16),
                                title: Text(
                                  container.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                subtitle: Padding(
                                  padding: const EdgeInsets.only(top: 6),
                                  child: Text(
                                    container.isDownloaded
                                        ? localizations.readyForOfflineUse
                                        : localizations.notYetDownloaded,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: container.isDownloaded
                                          ? Colors.green
                                          : Colors.orange,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ),
                Container(
                  padding: EdgeInsets.only(
                    left: 16,
                    right: 16,
                    top: 16,
                    bottom: 16 + MediaQuery.of(context).viewPadding.bottom,
                  ),
                  decoration: BoxDecoration(
                    border: Border(
                      top: BorderSide(
                        color: Colors.grey.shade300,
                        width: 1,
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.add, color: Color(0xFF592941)),
                          label: Text(localizations.newRegion),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFD6D5C9),
                            foregroundColor: const Color(0xFF592941),
                            side: const BorderSide(
                                color: Color(0xFFD6D5C9), width: 2),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(25),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          onPressed: () {
                            Navigator.pop(context);
                            ContainerSheets.showCreateContainer(
                              context: context,
                              selectedLanguage: selectedLanguage,
                              selectedState: selectedState,
                              selectedDistrict: selectedDistrict,
                              selectedBlock: selectedBlock,
                              selectedBlockId: selectedBlockId,
                              onContainerCreated: (container) {
                                (onContainerCreated ??
                                    onContainerSelected)(container);
                              },
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: SizedBox(
                          height: 48,
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              return ClipRRect(
                                borderRadius: BorderRadius.circular(25),
                                child: Stack(
                                  children: [
                                    Container(
                                      color: selectedContainerId != null
                                          ? const Color(0xFFD6D5C9)
                                          : const Color(0xFFD6D5C9)
                                              .withValues(alpha: 0.5),
                                    ),
                                    if (_isNavigating)
                                      AnimatedContainer(
                                        duration:
                                            const Duration(milliseconds: 300),
                                        width: constraints.maxWidth *
                                            _navigateProgress,
                                        color: const Color(0xFF592941)
                                            .withValues(alpha: 0.25),
                                      ),
                                    Material(
                                      color: Colors.transparent,
                                      child: InkWell(
                                        onTap: selectedContainerId != null &&
                                                !_isNavigating
                                            ? () async {
                                                final container =
                                                    await ContainerManager
                                                        .getContainer(
                                                            selectedContainerId!);
                                                if (container == null ||
                                                    !context.mounted) return;

                                                final locationMatches =
                                                    container.state ==
                                                            selectedState &&
                                                        container.district ==
                                                            selectedDistrict &&
                                                        container.block ==
                                                            selectedBlock;

                                                if (!locationMatches &&
                                                    !showAllRegions) {
                                                  showDialog(
                                                    context: context,
                                                    builder: (context) =>
                                                        AlertDialog(
                                                      title: Text(localizations
                                                          .regionMismatch),
                                                      content: Text(localizations
                                                          .regionMismatchMessage),
                                                      actions: [
                                                        TextButton(
                                                          child: Text(
                                                              localizations.ok),
                                                          onPressed: () =>
                                                              Navigator.pop(
                                                                  context),
                                                        ),
                                                      ],
                                                    ),
                                                  );
                                                  return;
                                                }

                                                if (!container.isDownloaded) {
                                                  bool? confirm =
                                                      await showDialog(
                                                    context: context,
                                                    builder: (context) =>
                                                        AlertDialog(
                                                      title: Text(localizations
                                                          .refreshLayers),
                                                      content: Text(localizations
                                                          .layersNotDownloaded),
                                                      actions: [
                                                        TextButton(
                                                          child: Text(
                                                              localizations
                                                                  .cancel),
                                                          onPressed: () =>
                                                              Navigator.pop(
                                                                  context,
                                                                  false),
                                                        ),
                                                        TextButton(
                                                          child: Text(
                                                              localizations
                                                                  .refresh),
                                                          onPressed: () =>
                                                              Navigator.pop(
                                                                  context,
                                                                  true),
                                                        ),
                                                      ],
                                                    ),
                                                  );
                                                  if (confirm == true &&
                                                      context.mounted) {
                                                    _handleRedownload(
                                                        context, container);
                                                  }
                                                  return;
                                                }

                                                final prefs =
                                                    await SharedPreferences
                                                        .getInstance();
                                                final refreshEnabled =
                                                    prefs.getBool(
                                                            kRefreshPlanLayersOnNavigatePrefKey) ??
                                                        false;
                                                if (!context.mounted) return;

                                                if (!refreshEnabled) {
                                                  Navigator.pop(context);
                                                  onContainerSelected(
                                                      container);
                                                  return;
                                                }

                                                final strongNetwork =
                                                    await _hasStrongNetwork();
                                                if (!context.mounted) return;

                                                if (!strongNetwork) {
                                                  Navigator.pop(context);
                                                  onContainerSelected(
                                                      container);
                                                  return;
                                                }

                                                setState(() {
                                                  _isNavigating = true;
                                                  _navigateProgress = 0.0;
                                                });

                                                final refreshed =
                                                    await _refreshPlanLayersWithProgress(
                                                  container,
                                                  onProgress: (progress) {
                                                    if (context.mounted) {
                                                      setState(() {
                                                        _navigateProgress =
                                                            progress;
                                                      });
                                                    }
                                                  },
                                                );

                                                if (!context.mounted) return;

                                                if (!refreshed) {
                                                  showTopToast(
                                                      context,
                                                      localizations
                                                          .planLayersNotRefreshed);
                                                }

                                                Navigator.pop(context);
                                                onContainerSelected(container);
                                              }
                                            : null,
                                        child: Center(
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              if (_isNavigating)
                                                const SizedBox(
                                                  width: 18,
                                                  height: 18,
                                                  child:
                                                      CircularProgressIndicator(
                                                    strokeWidth: 2,
                                                    color: Color(0xFF592941),
                                                  ),
                                                )
                                              else
                                                Transform.rotate(
                                                  angle: 1.5708,
                                                  child: Icon(
                                                    Icons.navigation_rounded,
                                                    color:
                                                        selectedContainerId !=
                                                                null
                                                            ? const Color(
                                                                0xFF592941)
                                                            : const Color(
                                                                    0xFF592941)
                                                                .withValues(
                                                                    alpha: 0.4),
                                                  ),
                                                ),
                                              const SizedBox(width: 8),
                                              Text(
                                                localizations.navigate,
                                                style: TextStyle(
                                                  color: selectedContainerId !=
                                                          null
                                                      ? const Color(0xFF592941)
                                                      : const Color(0xFF592941)
                                                          .withValues(
                                                              alpha: 0.4),
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  static Future<void> _handleRedownload(
      BuildContext context, OfflineContainer container) async {
    final localizations = AppLocalizations.of(context)!;

    final blockId =
        await getBlockId(container.state, container.district, container.block);
    if (blockId == null) {
      if (context.mounted) {
        showTopToast(context, localizations.couldNotFindBlockInfo);
      }
      return;
    }

    if (context.mounted) {
      Navigator.pop(context); // close sheet
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => DownloadProgressPage(
            container: container,
            selectedDistrict: container.district,
            selectedBlock: container.block,
            selectedBlockID: blockId,
          ),
        ),
      );
    }
  }

  // TODO: Remove this function
  static Future<void> _handleRefresh(
      BuildContext context, OfflineContainer container) async {
    await _refreshPlanLayers(context, container);
  }

  static Future<void> _refreshPlanLayers(
      BuildContext context, OfflineContainer container) async {
    final localizations = AppLocalizations.of(context)!;

    showTopToast(context, localizations.refreshingPlanData(container.name));

    final blockId =
        await getBlockId(container.state, container.district, container.block);
    if (blockId == null) {
      if (context.mounted) {
        showTopToast(context, localizations.couldNotFindBlockInfoRefresh);
      }
      return;
    }

    try {
      final allLayers = await LayersConfig.getLayers(
          container.district, container.block,
          blockId: blockId, planId: container.planId);

      const planLayerPrefixes = [
        'settlement_',
        'well_',
        'waterbody_',
        'cropping_',
        'main_swb_',
        'plan_agri_',
        'plan_gw_',
        'livelihood_'
      ];
      final planLayers = allLayers
          .where((layer) => planLayerPrefixes
              .any((prefix) => layer['name']!.startsWith(prefix)))
          .toList();

      if (planLayers.isEmpty) {
        if (context.mounted) {
          showTopToast(context, localizations.noPlanLayersToRefresh);
        }
        return;
      }

      for (var layer in planLayers) {
        await _downloadVectorLayer(
            layer['name']!, layer['geoserverPath']!, container);
      }
      if (context.mounted) {
        showTopToast(context,
            localizations.successfullyRefreshedPlanData(container.name));
      }
    } catch (e) {
      if (context.mounted) {
        showTopToast(context, localizations.errorRefreshingData(e.toString()));
      }
    }
  }

  static Future<String?> getBlockId(
      String stateName, String districtName, String blockName) async {
    final List<Map<String, dynamic>> states =
        await LocationDatabase.instance.getLocationData();
    for (var state in states) {
      if (state['label'] == stateName) {
        final List<Map<String, dynamic>> districts =
            List<Map<String, dynamic>>.from(state['district']);
        for (var district in districts) {
          if (district['label'] == districtName) {
            final List<Map<String, dynamic>> blocks =
                List<Map<String, dynamic>>.from(district['blocks']);
            for (var block in blocks) {
              if (block['label'] == blockName) {
                return block['block_id'].toString();
              }
            }
          }
        }
      }
    }
    return null;
  }

  static String _formatLayerName(String layerName) {
    return layerName.toLowerCase().replaceAll(' ', '_');
  }

  static Future<void> _downloadVectorLayer(String layerName,
      String geoserverPath, OfflineContainer container) async {
    try {
      print(
          "Starting download of vector layer: $layerName for container: ${container.name}");

      final url =
          '${geoserverUrl}geoserver/wfs?service=WFS&version=1.0.0&request=GetFeature&typeName=$geoserverPath&outputFormat=application/json';
      print("Downloading from URL: $url");

      final request =
          await http.Client().send(http.Request('GET', Uri.parse(url)));

      if (request.statusCode == 200) {
        final directory = await getApplicationDocumentsDirectory();
        final formattedLayerName = _formatLayerName(layerName);

        final containerPath =
            '${directory.path}/persistent_offline_data/containers/${container.name}';

        final filePath =
            '$containerPath/vector_layers/$formattedLayerName.geojson';
        print("Saving layer to: $filePath");

        final file = File(filePath);
        await file.create(recursive: true);

        final sink = file.openWrite();

        await for (final chunk in request.stream) {
          sink.add(chunk);
        }

        await sink.close();
        print("Successfully saved layer $layerName");
      } else {
        print(
            "Failed to download $layerName. Status code: ${request.statusCode}");
        throw Exception(
            'Failed to download $layerName. Status code: ${request.statusCode}');
      }
    } catch (e) {
      print('Error downloading $layerName: $e');
      rethrow;
    }
  }

  static Future<bool> _hasStrongNetwork() async {
    final result = await Connectivity().checkConnectivity();
    if (result == ConnectivityResult.none) return false;
    try {
      final response = await http
          .head(Uri.parse(apiUrl))
          .timeout(const Duration(seconds: 5));
      return response.statusCode < 500;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> _refreshPlanLayersWithProgress(
    OfflineContainer container, {
    required void Function(double) onProgress,
  }) async {
    final blockId =
        await getBlockId(container.state, container.district, container.block);
    if (blockId == null) return false;

    try {
      final allLayers = await LayersConfig.getLayers(
          container.district, container.block,
          blockId: blockId, planId: container.planId);

      const planLayerPrefixes = [
        'settlement_',
        'well_',
        'waterbody_',
        'cropping_',
        'main_swb_',
        'plan_agri_',
        'plan_gw_',
        'livelihood_'
      ];
      final planLayers = allLayers
          .where((layer) => planLayerPrefixes
              .any((prefix) => layer['name']!.startsWith(prefix)))
          .toList();

      if (planLayers.isEmpty) return true;

      for (int i = 0; i < planLayers.length; i++) {
        await _downloadVectorLayer(
            planLayers[i]['name']!, planLayers[i]['geoserverPath']!, container);
        onProgress((i + 1) / planLayers.length);
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<void> _deleteContainerAndData(String containerName) async {
    final directory = await getApplicationDocumentsDirectory();

    // Container-specific path
    final containerPath =
        '${directory.path}/persistent_offline_data/containers/$containerName';
    final containerDir = Directory(containerPath);

    // Delete the container directory if it exists
    if (await containerDir.exists()) {
      await containerDir.delete(recursive: true);
    }

    // Delete container from storage
    await ContainerManager.deleteContainer(containerName);
  }
}
