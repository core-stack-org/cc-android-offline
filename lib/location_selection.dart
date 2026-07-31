import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:ui' as ui;

import 'webview.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

import 'package:nrmflutter/db/location_db.dart';
import 'package:nrmflutter/utils/constants.dart';
import './container_flow/container_manager.dart';
import './container_flow/container_sheet.dart';
import './download_progress.dart';
import './ui/profile_screen.dart';
import './services/logout.dart';
import './services/language_service.dart';
import './services/update_service.dart';
import './services/locate_me_service.dart';
import './utils/toast.dart';
import './ui/update_bottom_sheet.dart';
import './ui/offline_webview.dart';

//import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import './l10n/app_localizations.dart';
import '../main.dart'; // Import to access localeNotifier

class LocationSelection extends StatefulWidget {
  final String? selectedLanguage;

  const LocationSelection({super.key, this.selectedLanguage});

  @override
  _LocationSelectionState createState() => _LocationSelectionState();
}

class _LocationSelectionState extends State<LocationSelection> {
  String? selectedState;
  String? selectedDistrict;
  String? selectedBlock;
  String? selectedStateID;
  String? selectedDistrictID;
  String? selectedBlockID;
  bool isAgreed = false;
  List<bool> _isSelected = [true, false];
  bool _isSubmitEnabled = false;
  String _appVersion = '';
  String _deviceInfo = 'Unknown';
  String _selectedLanguage = 'en';
  final LanguageService _languageService = LanguageService();

  List<Map<String, dynamic>> states = [];
  List<Map<String, dynamic>> districts = [];
  List<Map<String, dynamic>> blocks = [];

  List<DropdownMenuItem<String>>? _cachedStateItems;
  List<DropdownMenuItem<String>>? _cachedDistrictItems;
  List<DropdownMenuItem<String>>? _cachedBlockItems;

  bool _isLoadingData = true;
  bool _isRefreshing = false;
  bool _hasCheckedUpdate = false;
  bool _showAllRegions = false;

  final GlobalKey _profileButtonKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _loadSavedLanguage();
    _loadInfo();
    _loadShowAllRegions();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      fetchLocationData();
      _checkForUpdate();
    });
  }

  Future<void> _loadShowAllRegions() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _showAllRegions = prefs.getBool(kShowAllRegionsPrefKey) ?? false;
      });
    }
  }

  Future<void> _checkForUpdate() async {
    if (_hasCheckedUpdate) return;

    try {
      final connectivityResult = await Connectivity().checkConnectivity();
      if (connectivityResult == ConnectivityResult.none) {
        return;
      }

      // MARK: Update Check
      // TEST MODE: Set to true to force show the update bottom sheet for testing
      // Change this to false when done testing
      final bool testMode = false;

      // ignore: dead_code
      final bool hasUpdate =
          testMode ? true : await UpdateService.checkForUpdate();

      _hasCheckedUpdate = true;

      if (hasUpdate && mounted) {
        await Future.delayed(const Duration(milliseconds: 500));
        if (mounted) {
          UpdateBottomSheet.showUpdateBottomSheet(context);
        }
      }
    } catch (e) {
      print('Error checking for update: $e');
    }
  }

  Future<void> _loadSavedLanguage() async {
    final savedLanguage = await _languageService.getLanguage();
    setState(() {
      _selectedLanguage = savedLanguage;
    });
    localeNotifier.value = Locale(savedLanguage);
  }

  Future<void> fetchLocationData() async {
    setState(() {
      _isLoadingData = true;
    });

    try {
      final data = await LocationDatabase.instance.getLocationData();

      if (data.isNotEmpty) {
        setState(() {
          states = data;
          _cachedStateItems = null;
          _isLoadingData = false;
        });

        _syncDataInBackground();
      } else {
        final connectivityResult = await Connectivity().checkConnectivity();
        if (connectivityResult != ConnectivityResult.none) {
          final response =
              await http.get(Uri.parse('${apiUrl}proposed_blocks/'));
          if (response.statusCode == 200) {
            final apiData = json.decode(response.body);
            final locationList = List<Map<String, dynamic>>.from(apiData);

            // Update UI immediately
            if (mounted) {
              setState(() {
                states = locationList;
                _cachedStateItems = null;
                _isLoadingData = false;
              });
            }

            // Sync DB in background
            LocationDatabase.instance
                .insertLocationData(locationList)
                .catchError((e) {
              print('Background sync error: $e');
            });
          } else {
            setState(() {
              _isLoadingData = false;
            });
          }
        } else {
          setState(() {
            _isLoadingData = false;
          });
        }
      }
    } catch (e) {
      print('Error fetching location data: $e');
      setState(() {
        _isLoadingData = false;
      });
    }
  }

  Future<void> _syncDataInBackground() async {
    try {
      final connectivityResult = await Connectivity().checkConnectivity();
      if (connectivityResult != ConnectivityResult.none) {
        final response = await http.get(Uri.parse('${apiUrl}proposed_blocks/'));
        if (response.statusCode == 200) {
          final freshStates =
              List<Map<String, dynamic>>.from(json.decode(response.body));
          await LocationDatabase.instance.insertLocationData(freshStates);

          if (!mounted) return;
          setState(() {
            states = freshStates;
            _cachedStateItems = null;
          });
          _refreshDerivedSelections(freshStates);
        }
      }
    } catch (e) {
      debugPrint('Background sync failed: $e');
    }
  }

  void _refreshDerivedSelections(List<Map<String, dynamic>> freshStates) {
    if (selectedState == null) return;

    final stateData = freshStates.cast<Map<String, dynamic>?>().firstWhere(
          (s) => s!["label"] == selectedState,
          orElse: () => null,
        );

    if (stateData == null) {
      setState(() {
        selectedState = null;
        selectedStateID = null;
        selectedDistrict = null;
        selectedDistrictID = null;
        selectedBlock = null;
        selectedBlockID = null;
        districts = [];
        blocks = [];
        _cachedStateItems = null;
        _cachedDistrictItems = null;
        _cachedBlockItems = null;
        _isSubmitEnabled = false;
      });
      return;
    }

    final freshDistricts =
        List<Map<String, dynamic>>.from(stateData["district"]);

    if (selectedDistrict == null) {
      setState(() {
        districts = freshDistricts;
        _cachedDistrictItems = null;
      });
      return;
    }

    final districtData =
        freshDistricts.cast<Map<String, dynamic>?>().firstWhere(
              (d) => d!["label"] == selectedDistrict,
              orElse: () => null,
            );

    if (districtData == null) {
      setState(() {
        districts = freshDistricts;
        selectedDistrict = null;
        selectedDistrictID = null;
        selectedBlock = null;
        selectedBlockID = null;
        blocks = [];
        _cachedDistrictItems = null;
        _cachedBlockItems = null;
        _isSubmitEnabled = false;
      });
      return;
    }

    final freshBlocks = List<Map<String, dynamic>>.from(districtData["blocks"]);

    final blockStillValid = selectedBlock == null ||
        freshBlocks.any((b) => b["label"] == selectedBlock);

    setState(() {
      districts = freshDistricts;
      blocks = freshBlocks;
      _cachedDistrictItems = null;
      _cachedBlockItems = null;
      if (!blockStillValid) {
        selectedBlock = null;
        selectedBlockID = null;
        _isSubmitEnabled = false;
      }
    });
  }

  Future<void> _refreshLocationData() async {
    final connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult == ConnectivityResult.none) {
      if (!mounted) return;
      showTopToast(context, 'No internet connection');
      return;
    }

    setState(() => _isRefreshing = true);

    try {
      final response = await http.get(Uri.parse('${apiUrl}proposed_blocks/'));
      if (!mounted) return;

      if (response.statusCode == 200) {
        final freshStates =
            List<Map<String, dynamic>>.from(json.decode(response.body));
        await LocationDatabase.instance.insertLocationData(freshStates);

        if (!mounted) return;
        setState(() {
          states = freshStates;
          _cachedStateItems = null;
          _isRefreshing = false;
        });
        _refreshDerivedSelections(freshStates);
      } else {
        setState(() => _isRefreshing = false);
      }
    } catch (e) {
      if (mounted) setState(() => _isRefreshing = false);
    }
  }

  void updateDistricts(String state) {
    final selectedStateData = states.firstWhere((s) => s["label"] == state);
    setState(() {
      selectedState = state;
      selectedStateID = selectedStateData["state_id"];
      selectedDistrict = null;
      selectedDistrictID = null;
      selectedBlock = null;
      selectedBlockID = null;
      districts =
          List<Map<String, dynamic>>.from(selectedStateData["district"]);
      _cachedDistrictItems = null;
      _cachedBlockItems = null;
      _isSubmitEnabled = selectedState != null &&
          selectedDistrict != null &&
          selectedBlock != null;
    });
  }

  void updateBlocks(String district) {
    final selectedDistrictData =
        districts.firstWhere((d) => d["label"] == district);
    setState(() {
      selectedDistrict = district;
      selectedDistrictID = selectedDistrictData["district_id"];
      selectedBlock = null;
      selectedBlockID = null;
      blocks = List<Map<String, dynamic>>.from(selectedDistrictData["blocks"]);
      _cachedBlockItems = null;
      _isSubmitEnabled = selectedState != null &&
          selectedDistrict != null &&
          selectedBlock != null;
    });
  }

  void updateSelectedBlock(String block) {
    final selectedBlockData = blocks.firstWhere((b) => b["label"] == block);
    setState(() {
      selectedBlock = block;
      selectedBlockID = selectedBlockData["block_id"].toString();
      _isSubmitEnabled = selectedState != null &&
          selectedDistrict != null &&
          selectedBlock != null;
    });
  }

  // MARK: - Online Mode
  void submitLocation() {
    HapticFeedback.mediumImpact();
    String url =
        "${ccUrl}?geoserver_url=${geoserverUrl.substring(0, geoserverUrl.length - 1)}&app_name=nrmApp&state_name=$selectedState&dist_name=$selectedDistrict&block_name=$selectedBlock&block_id=$selectedBlockID&isOffline=false&language=$_selectedLanguage";
    print('URL: $url');
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            WebViewApp(url: url, selectedLanguage: _selectedLanguage),
      ),
    );
  }

  void showAgreementSheet(OfflineContainer container) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (BuildContext context) {
        final localizations = AppLocalizations.of(context)!;

        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setSheetState) {
            return Container(
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
                    localizations.accessApplicationWithoutInternet,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF592941),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    localizations.downloadLayersMessage,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF592941),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Checkbox(
                        value: isAgreed,
                        onChanged: (bool? value) {
                          setSheetState(() {
                            isAgreed = value!;
                          });
                        },
                      ),
                      Text(
                        localizations.agreeAndDownloadLayers,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFF592941),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Center(
                    child: ElevatedButton(
                      onPressed: isAgreed
                          ? () {
                              Navigator.pop(context);
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => DownloadProgressPage(
                                    container: container,
                                    selectedDistrict: selectedDistrict,
                                    selectedBlock: selectedBlock,
                                    selectedBlockID: selectedBlockID,
                                    onDownloadComplete: showContainerList,
                                  ),
                                ),
                              );
                            }
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFD6D5C9),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 40, vertical: 15),
                      ),
                      child: Text(
                        localizations.downloadLayers,
                        style: const TextStyle(
                          color: Color(0xFF592941),
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void showContainerList() {
    ContainerSheets.showContainerList(
      context: context,
      selectedLanguage: _selectedLanguage,
      selectedState: selectedState ?? '',
      selectedDistrict: selectedDistrict ?? '',
      selectedBlock: selectedBlock ?? '',
      selectedBlockId: selectedBlockID ?? '',
      showAllRegions: _showAllRegions,
      onContainerCreated: (container) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => DownloadProgressPage(
              container: container,
              selectedDistrict: selectedDistrict,
              selectedBlock: selectedBlock,
              selectedBlockID: selectedBlockID,
              onDownloadComplete: showContainerList,
            ),
          ),
        );
      },
      onContainerSelected: (container) {
        if (container.isDownloaded) {
          navigateToWebViewOffline(container);
        } else {
          showAgreementSheet(container);
        }
      },
    );
  }

  // MARK: - Offline
  Future<void> navigateToWebViewOffline(OfflineContainer container) async {
    final localizations = AppLocalizations.of(context)!;

    if (container.planId == null) {
      showTopToast(
        context,
        'This region has no plan. Please recreate it with a selected plan.',
      );
      return;
    }

    final containerMatchesSelection = container.block == selectedBlock &&
        container.district == selectedDistrict &&
        container.state == selectedState;

    String? blockId;
    if (containerMatchesSelection) {
      blockId = selectedBlockID;
    } else {
      blockId = await ContainerSheets.getBlockId(
          container.state, container.district, container.block);
    }

    if (blockId == null) {
      if (mounted) {
        showTopToast(context, localizations.couldNotFindBlockInfo);
      }
      return;
    }

    if (mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => OfflineWebView(
            container: container,
            selectedBlockID: blockId!,
            selectedLanguage: _selectedLanguage,
          ),
        ),
      );
    }
  }

  List<DropdownMenuItem<String>> _buildDropdownItems(
      List<Map<String, dynamic>> items) {
    return items.map((Map<String, dynamic> map) {
      return DropdownMenuItem<String>(
        value: map["label"],
        child: Text(
          map["label"],
          style: const TextStyle(color: Color(0xFF592941)),
        ),
      );
    }).toList();
  }

  Widget _buildDropdown({
    required String? value,
    required String hint,
    required List<Map<String, dynamic>> items,
    required Function(String?) onChanged,
    required List<DropdownMenuItem<String>>? cachedItems,
    required Function(List<DropdownMenuItem<String>>?) updateCache,
  }) {
    final dropdownItems = cachedItems ?? _buildDropdownItems(items);
    if (cachedItems == null) {
      updateCache(dropdownItems);
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20.0),
        border: Border.all(color: const Color(0xFFD6D5C9), width: 3.0),
        boxShadow: value != null
            ? [
                BoxShadow(
                  color: const Color(0xFF592941).withValues(alpha: 0.1),
                  blurRadius: 5,
                  offset: const Offset(0, 2),
                )
              ]
            : null,
      ),
      child: Theme(
        data: Theme.of(context).copyWith(
          canvasColor: Colors.white,
          popupMenuTheme: PopupMenuThemeData(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20.0),
            ),
          ),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: value,
            hint: Text(
              hint,
              style: const TextStyle(color: Color.fromARGB(255, 163, 163, 163)),
            ),
            onChanged: (String? newValue) {
              HapticFeedback.selectionClick();
              HapticFeedback.mediumImpact();

              onChanged(newValue);
            },
            menuMaxHeight: 300,
            icon: AnimatedRotation(
              duration: const Duration(milliseconds: 300),
              turns: value != null ? 0.5 : 0,
              child:
                  const Icon(Icons.arrow_drop_down, color: Color(0xFF592941)),
            ),
            items: dropdownItems,
            isExpanded: true,
            dropdownColor: Colors.white,
            borderRadius: BorderRadius.circular(20.0),
          ),
        ),
      ),
    );
  }

  void _handleSubmit() {
    final localizations = AppLocalizations.of(context)!;
    HapticFeedback.mediumImpact();
    bool isOnlineMode = _isSelected[0];

    if (selectedState == null ||
        selectedDistrict == null ||
        selectedBlock == null) {
      showTopToast(context, localizations.pleaseSelectStateDistrictBlock);
      return;
    }

    if (isOnlineMode) {
      submitLocation();
    } else {
      showContainerList();
    }
  }

  Future<void> _loadInfo() async {
    try {
      final PackageInfo packageInfo = await PackageInfo.fromPlatform();
      _appVersion = '${packageInfo.version}+${packageInfo.buildNumber}';

      if (Platform.isAndroid) {
        final DeviceInfoPlugin deviceInfoPlugin = DeviceInfoPlugin();
        final AndroidDeviceInfo androidInfo =
            await deviceInfoPlugin.androidInfo;
        _deviceInfo =
            'Android ${androidInfo.version.release} (SDK ${androidInfo.version.sdkInt}), Model: ${androidInfo.model}, Manufacturer: ${androidInfo.manufacturer}';
      } else if (Platform.isIOS) {
        _deviceInfo = 'iOS Device (Details TBD)';
      }
    } catch (e) {
      print('Failed to load info: $e');
      _appVersion = 'Error';
      _deviceInfo = 'Error loading details';
    }
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _launchEmail() async {
    final localizations = AppLocalizations.of(context)!;
    final Uri emailLaunchUri = Uri(
      scheme: 'mailto',
      path: 'support@core-stack.org',
      queryParameters: {
        'subject': 'Bug Report - App v$_appVersion',
        'body': '''
        Please describe the bug in detail below:
        ------------------------------------------
        [Your bug description here]
        ------------------------------------------

        Device Information (auto-filled):
        App Version: $_appVersion
        Device Details: $_deviceInfo
        State: ${selectedState ?? 'Not selected'}
        District: ${selectedDistrict ?? 'Not selected'}
        Block: ${selectedBlock ?? 'Not selected'}
        Mode: ${_isSelected[0] ? 'Online' : 'Offline'}
        '''
            .trim()
            .replaceAll('        ', ''),
      },
    );

    if (await canLaunchUrl(emailLaunchUri)) {
      await launchUrl(emailLaunchUri);
    } else {
      showTopToast(context, localizations.couldNotOpenEmailClient);
      print('Could not launch $emailLaunchUri');
    }
  }

  Widget _buildLanguageSelector() {
    return GestureDetector(
      onTap: _showLanguageSheet,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: 0.5)),
          ),
          child: Text(
            _selectedLanguage.toUpperCase(),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
        ),
      ),
    );
  }

  void _showLanguageSheet() {
    final l10n = AppLocalizations.of(context)!;
    final languages = [
      ('en', l10n.english),
      ('hi', l10n.hindi),
    ];

    HapticFeedback.lightImpact();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        l10n.selectLanguage,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF592941),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(ctx),
                        color: const Color(0xFF592941),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ...languages.map((entry) {
                    final (code, label) = entry;
                    final isSelected = _selectedLanguage == code;
                    return InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () async {
                        setSheetState(() {});
                        setState(() => _selectedLanguage = code);
                        localeNotifier.value = Locale(code);
                        await _languageService.saveLanguage(code);
                        HapticFeedback.lightImpact();
                        if (ctx.mounted) Navigator.pop(ctx);
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                label,
                                style: TextStyle(
                                  fontSize: 16,
                                  color: const Color(0xFF592941),
                                  fontWeight: isSelected
                                      ? FontWeight.w600
                                      : FontWeight.normal,
                                ),
                              ),
                            ),
                            Icon(
                              isSelected
                                  ? Icons.check_box
                                  : Icons.check_box_outline_blank,
                              color: const Color(0xFF592941),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildProfileMenu() {
    return IconButton(
      key: _profileButtonKey,
      icon: const Icon(Icons.person, color: Colors.white),
      tooltip: 'Profile Menu',
      onPressed: () => _showProfileMenu(),
    );
  }

  void _showProfileMenu() async {
    if (!mounted) return;

    await Future.delayed(Duration.zero);

    if (!mounted) return;

    try {
      final RenderBox? renderBox =
          _profileButtonKey.currentContext?.findRenderObject() as RenderBox?;
      if (renderBox == null || !renderBox.hasSize) {
        return;
      }

      final Offset offset = renderBox.localToGlobal(Offset.zero);
      final Size size = renderBox.size;

      final RelativeRect position = RelativeRect.fromLTRB(
        offset.dx,
        offset.dy + size.height,
        offset.dx + size.width,
        offset.dy + size.height + 200,
      );

      HapticFeedback.lightImpact();

      final String? selected = await showMenu<String>(
        context: context,
        position: position,
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12.0),
        ),
        constraints: const BoxConstraints(
          minWidth: 200,
          maxWidth: 250,
        ),
        items: [
          const PopupMenuItem<String>(
            value: 'profile',
            child: Row(
              children: [
                Icon(Icons.person, color: Color(0xFF592941)),
                SizedBox(width: 12),
                Text(
                  'Profile',
                  style: TextStyle(
                    color: Color(0xFF592941),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const PopupMenuItem<String>(
            value: 'logout',
            child: Row(
              children: [
                Icon(Icons.logout, color: Colors.red),
                SizedBox(width: 12),
                Text(
                  'Logout',
                  style: TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      );

      // Handle the selection with proper safety checks
      if (selected != null && mounted) {
        _handleMenuSelection(selected);
      }
    } catch (e) {
      print('Error showing profile menu: $e');
      // Fallback: show a simple dialog if positioning fails
      if (mounted) {
        _showFallbackProfileMenu();
      }
    }
  }

  void _handleMenuSelection(String value) {
    switch (value) {
      case 'profile':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const ProfileStatsScreen(),
          ),
        ).then((_) => _loadShowAllRegions());
        break;
      case 'logout':
        LogoutService.showLogoutConfirmationDialog(context);
        break;
    }
  }

  void _showLocateMeOptions() {
    if (states.isEmpty) return;

    final l10n = AppLocalizations.of(context)!;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  l10n.locateMe,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF592941),
                  ),
                ),
                const SizedBox(height: 16),
                ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xFFF3E5F5),
                    child: Icon(Icons.gps_fixed, color: Color(0xFF592941)),
                  ),
                  title: Text(l10n.detectAutomatically,
                      style: const TextStyle(fontWeight: FontWeight.w500)),
                  subtitle: Text(l10n.useGpsToDetect),
                  onTap: () {
                    Navigator.pop(ctx);
                    _locateMeAutomatic();
                  },
                ),
                ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xFFF3E5F5),
                    child:
                        Icon(Icons.edit_location_alt, color: Color(0xFF592941)),
                  ),
                  title: Text(l10n.enterManually,
                      style: const TextStyle(fontWeight: FontWeight.w500)),
                  subtitle: Text(l10n.typeLatitudeLongitude),
                  onTap: () {
                    Navigator.pop(ctx);
                    _showManualLatLonDialog();
                  },
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _locateMeAutomatic() async {
    final dismiss = showLoadingToast(context, 'Detecting your location...');
    final result = await LocateMeService.fetchAdminDetailsFromLocation();
    dismiss();
    if (!mounted) return;
    _handleLocateResult(result);
  }

  void _showManualLatLonDialog() {
    final latController = TextEditingController();
    final lonController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text(
            'Enter Coordinates',
            style: TextStyle(
                color: Color(0xFF592941), fontWeight: FontWeight.bold),
          ),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: latController,
                  keyboardType: const TextInputType.numberWithOptions(
                      decimal: true, signed: true),
                  decoration: InputDecoration(
                    labelText: 'Latitude',
                    hintText: 'e.g. 28.6139',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                    prefixIcon:
                        const Icon(Icons.north, color: Color(0xFF592941)),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Required';
                    final val = double.tryParse(v.trim());
                    if (val == null || val < -90 || val > 90)
                      return 'Must be -90 to 90';
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: lonController,
                  keyboardType: const TextInputType.numberWithOptions(
                      decimal: true, signed: true),
                  decoration: InputDecoration(
                    labelText: 'Longitude',
                    hintText: 'e.g. 77.2090',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                    prefixIcon:
                        const Icon(Icons.east, color: Color(0xFF592941)),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Required';
                    final val = double.tryParse(v.trim());
                    if (val == null || val < -180 || val > 180)
                      return 'Must be -180 to 180';
                    return null;
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF592941),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () {
                if (!formKey.currentState!.validate()) return;
                final lat = double.parse(latController.text.trim());
                final lon = double.parse(lonController.text.trim());
                Navigator.pop(context);
                _locateMeManual(lat, lon);
              },
              child:
                  const Text('Submit', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  Future<void> _locateMeManual(double latitude, double longitude) async {
    final dismiss = showLoadingToast(context, 'Fetching location details...');
    final result = await LocateMeService.fetchAdminDetailsByCoordinates(
        latitude, longitude);
    dismiss();
    if (!mounted) return;
    _handleLocateResult(result);
  }

  void _handleLocateResult(LocateMeResult result) {
    if (result.error != null) {
      showTopToast(context, result.message ?? 'Could not determine location');
      return;
    }

    final admin = result.data;
    if (admin == null || !admin.hasData) {
      showTopToast(context, 'No admin details found for this location');
      return;
    }

    _autoPopulateDropdowns(admin);
  }

  void _autoPopulateDropdowns(AdminDetails admin) {
    final matchedState = states.cast<Map<String, dynamic>?>().firstWhere(
        (s) =>
            s!["label"].toString().toLowerCase() == admin.state?.toLowerCase(),
        orElse: () => null);

    if (matchedState == null) {
      _showLocationMismatch(admin);
      return;
    }

    setState(() {
      selectedState = matchedState["label"];
      selectedStateID = matchedState["state_id"];
      districts = List<Map<String, dynamic>>.from(matchedState["district"]);
      _cachedStateItems = null;
      _cachedDistrictItems = null;
      _cachedBlockItems = null;
      selectedDistrict = null;
      selectedDistrictID = null;
      selectedBlock = null;
      selectedBlockID = null;
    });

    final matchedDistrict = districts.cast<Map<String, dynamic>?>().firstWhere(
        (d) =>
            d!["label"].toString().toLowerCase() ==
            admin.district?.toLowerCase(),
        orElse: () => null);

    if (matchedDistrict == null) {
      _showPartialMatch(
          'State matched, but district not found in proposed blocks');
      return;
    }

    setState(() {
      selectedDistrict = matchedDistrict["label"];
      selectedDistrictID = matchedDistrict["district_id"];
      blocks = List<Map<String, dynamic>>.from(matchedDistrict["blocks"]);
      _cachedDistrictItems = null;
      _cachedBlockItems = null;
    });

    final matchedBlock = blocks.cast<Map<String, dynamic>?>().firstWhere(
        (b) =>
            b!["label"].toString().toLowerCase() == admin.tehsil?.toLowerCase(),
        orElse: () => null);

    if (matchedBlock != null) {
      setState(() {
        selectedBlock = matchedBlock["label"];
        selectedBlockID = matchedBlock["block_id"].toString();
        _cachedBlockItems = null;
        _isSubmitEnabled = true;
      });
      showTopToast(context,
          'Location set to ${admin.state}, ${admin.district}, ${admin.tehsil}');
    } else {
      _showPartialMatch(
          'State & district matched, please select tehsil manually');
    }
  }

  void _showLocationMismatch(AdminDetails admin) {
    showTopToast(context,
        'Your location (${admin.state ?? ''}) is not in the proposed blocks');
  }

  void _showPartialMatch(String message) {
    showTopToast(context, message);
  }

  void _showModeToast(String message) => showTopToast(context, message);

  void _showFallbackProfileMenu() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Profile Menu'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.person),
              title: const Text('Profile'),
              onTap: () {
                Navigator.pop(context);
                _handleMenuSelection('profile');
              },
            ),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text('Logout', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(context);
                _handleMenuSelection('logout');
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Locale>(
      valueListenable: localeNotifier,
      builder: (context, locale, child) {
        final localizations = AppLocalizations.of(context)!;
        const Color customGrey = Color(0xFFD6D4C8);

        return Scaffold(
          backgroundColor:
              const Color.fromARGB(255, 255, 255, 255).withValues(alpha: 1.0),
          appBar: AppBar(
            backgroundColor: Colors.black,
            centerTitle: true,
            foregroundColor: Colors.white,
            title: Text(localizations.selectLocation),
            leading: _buildProfileMenu(),
            actions: [
              _isRefreshing
                  ? const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 14),
                      child: Center(
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    )
                  : IconButton(
                      icon: const Icon(Icons.refresh),
                      tooltip: 'Refresh locations',
                      onPressed: _refreshLocationData,
                    ),
              _buildLanguageSelector(),
            ],
          ),
          body: Stack(
            children: <Widget>[
              Positioned.fill(
                child: Opacity(
                  opacity: 0.7,
                  child: Image.asset(
                    'assets/farm.jpg',
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              Positioned.fill(
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: FractionallySizedBox(
                    heightFactor: 0.5,
                    widthFactor: 1.0,
                    child: BackdropFilter(
                      filter: ui.ImageFilter.blur(sigmaX: 5.0, sigmaY: 5.0),
                      child: Container(
                        color: Colors.transparent,
                      ),
                    ),
                  ),
                ),
              ),
              Center(
                child:
                    _buildLocationSelectionContent(localizations, customGrey),
              ),
              if (_isLoadingData)
                Positioned.fill(
                  child: BackdropFilter(
                    filter: ui.ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
                    child: Container(
                      color: Colors.black.withValues(alpha: 0.3),
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.all(32.0),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20.0),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.2),
                                blurRadius: 20,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                localizations.loadingLocations,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF592941),
                                ),
                              ),
                              const SizedBox(height: 24),
                              SizedBox(
                                width: 200,
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: const LinearProgressIndicator(
                                    backgroundColor: Color(0xFFD6D5C9),
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Color(0xFF592941),
                                    ),
                                    minHeight: 8,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                localizations.pleaseWait,
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  // Extract the main content into a separate method to reduce duplication
  Widget _buildLocationSelectionContent(
      AppLocalizations localizations, Color customGrey) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 32.0),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10.0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  localizations.selectStateDistrictTehsil,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF592941),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16.0),
            _buildDropdown(
              value: selectedState,
              hint: localizations.selectState,
              items: states,
              cachedItems: _cachedStateItems,
              updateCache: (items) => _cachedStateItems = items,
              onChanged: (String? value) {
                setState(() {
                  selectedState = value;
                  updateDistricts(value!);
                });
              },
            ),
            const SizedBox(height: 16.0),
            _buildDropdown(
              value: selectedDistrict,
              hint: localizations.selectDistrict,
              items: districts,
              cachedItems: _cachedDistrictItems,
              updateCache: (items) => _cachedDistrictItems = items,
              onChanged: (String? value) {
                setState(() {
                  selectedDistrict = value;
                  updateBlocks(value!);
                });
              },
            ),
            const SizedBox(height: 16.0),
            _buildDropdown(
              value: selectedBlock,
              hint: localizations.selectTehsil,
              items: blocks,
              cachedItems: _cachedBlockItems,
              updateCache: (items) => _cachedBlockItems = items,
              onChanged: (String? value) {
                if (value != null) {
                  updateSelectedBlock(value);
                }
              },
            ),
            const SizedBox(height: 20.0),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10.0),
              child: Row(
                children: [
                  const Icon(
                    Icons.my_location,
                    size: 16,
                    color: Color(0xFF592941),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    localizations.autoFillDropdownHint,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10.0),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF592941),
                side: const BorderSide(color: Color(0xFF592941), width: 1.5),
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20.0),
                ),
              ),
              onPressed: _showLocateMeOptions,
              icon: const Icon(Icons.gps_fixed, size: 18),
              label: Text(
                localizations.locateMe,
                style:
                    const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(height: 24.0),
            const Divider(
              height: 1,
              thickness: 1.5,
              color: Color.fromARGB(255, 211, 211, 211),
            ),
            const SizedBox(height: 15.0),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                _isSelected[0]
                    ? ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: customGrey,
                          foregroundColor: const Color(0xFF592941),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 24, vertical: 12),
                          textStyle: const TextStyle(fontSize: 15),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20.0),
                          ),
                        ),
                        onPressed: () {},
                        child: Text(localizations.onlineMode),
                      )
                    : OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: customGrey,
                          side: BorderSide(color: customGrey, width: 1.5),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 24, vertical: 12),
                          textStyle: const TextStyle(fontSize: 15),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20.0),
                          ),
                        ),
                        onPressed: () {
                          HapticFeedback.lightImpact();
                          setState(() => _isSelected = [true, false]);
                          _showModeToast(localizations.onlineModeSelected);
                        },
                        child: Text(localizations.onlineMode),
                      ),
                const SizedBox(width: 16),
                _isSelected[1]
                    ? ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: customGrey,
                          foregroundColor: const Color(0xFF592941),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 24, vertical: 12),
                          textStyle: const TextStyle(fontSize: 15),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20.0),
                          ),
                        ),
                        onPressed: () {},
                        child: Text(localizations.offlineMode),
                      )
                    : OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: customGrey,
                          side: BorderSide(color: customGrey, width: 1.5),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 24, vertical: 12),
                          textStyle: const TextStyle(fontSize: 15),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20.0),
                          ),
                        ),
                        onPressed: () {
                          HapticFeedback.lightImpact();
                          setState(() => _isSelected = [false, true]);
                          _showModeToast(localizations.offlineModeSelected);
                        },
                        child: Text(localizations.offlineMode),
                      ),
              ],
            ),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      _isSubmitEnabled ? customGrey : Colors.grey.shade400,
                  foregroundColor:
                      _isSubmitEnabled ? const Color(0xFF592941) : Colors.white,
                  minimumSize: const Size(200.0, 24),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  textStyle: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20.0),
                  ),
                ),
                onPressed: _isSubmitEnabled ? _handleSubmit : null,
                child: Text(localizations.submit),
              ),
            ),
            const SizedBox(height: 32.0),
            Padding(
              padding: const EdgeInsets.only(bottom: 16.0, top: 4.0),
              child: InkWell(
                onTap: _launchEmail,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    const Icon(
                      Icons.bug_report,
                      color: Color(0xFF592941),
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      localizations.fileaBugReport,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF592941),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
