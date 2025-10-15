import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:url_launcher/url_launcher.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'dart:ui' as ui;

import 'webview.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

import 'package:nrmflutter/db/plans_db.dart';
import 'package:nrmflutter/db/location_db.dart';
import 'package:nrmflutter/utils/constants.dart';
import 'package:nrmflutter/utils/change_log.dart';

import './server/local_server.dart';
import './container_flow/container_manager.dart';
import './container_flow/container_sheet.dart';
import './download_progress.dart';
import './ui/profile_screen.dart';
import './services/logout.dart';

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
  LocalServer? _localServer;
  List<bool> _isSelected = [true, false];
  bool _isSubmitEnabled = false;
  String _appVersion = '';
  String _deviceInfo = 'Unknown';
  late String _selectedLanguage;

  List<Map<String, dynamic>> states = [];
  List<Map<String, dynamic>> districts = [];
  List<Map<String, dynamic>> blocks = [];

  final GlobalKey _profileButtonKey = GlobalKey();
  final GlobalKey _languageButtonKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _selectedLanguage = widget.selectedLanguage ?? 'hi';

    // Set the locale BEFORE any UI builds
    WidgetsBinding.instance.addPostFrameCallback((_) {
      localeNotifier.value = Locale(_selectedLanguage);
    });

    _loadInfo();
    fetchLocationData();
  }

  List<Map<String, dynamic>> sortLocationData(List<Map<String, dynamic>> data) {
    data.sort((a, b) => (a['label'] as String).compareTo(b['label'] as String));

    for (var state in data) {
      List<Map<String, dynamic>> districts =
          List<Map<String, dynamic>>.from(state['district']);
      districts.sort(
          (a, b) => (a['label'] as String).compareTo(b['label'] as String));

      for (var district in districts) {
        List<Map<String, dynamic>> blocks =
            List<Map<String, dynamic>>.from(district['blocks']);
        blocks.sort(
            (a, b) => (a['label'] as String).compareTo(b['label'] as String));
        district['blocks'] = blocks;
      }

      state['district'] = districts;
    }

    return data;
  }

  Future<void> fetchLocationData() async {
    try {
      final connectivityResult = await Connectivity().checkConnectivity();
      if (connectivityResult != ConnectivityResult.none) {
        final response = await http.get(Uri.parse('${apiUrl}proposed_blocks/'));
        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          await LocationDatabase.instance
              .insertLocationData(List<Map<String, dynamic>>.from(data));

          await PlansDatabase.instance.syncPlans();

          setState(() {
            states = sortLocationData(List<Map<String, dynamic>>.from(data));
          });
        }
      } else {
        final data = await LocationDatabase.instance.getLocationData();
        setState(() {
          states = sortLocationData(data);
        });
      }
    } catch (e) {
      print('Error fetching location data: $e');
      try {
        final data = await LocationDatabase.instance.getLocationData();
        setState(() {
          states = sortLocationData(data);
        });
      } catch (dbError) {
        print('Error fetching from local database: $dbError');
      }
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
              padding: const EdgeInsets.all(20),
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
      onContainerSelected: (container) {
        navigateToWebViewOffline(container);
      },
    );
  }

  // MARK: - Offline
  Future<void> navigateToWebViewOffline(OfflineContainer container) async {
    final localizations = AppLocalizations.of(context)!;

    try {
      final directory = await getApplicationDocumentsDirectory();
      final persistentOfflinePath =
          path.join(directory.path, 'persistent_offline_data');

      _localServer = LocalServer(persistentOfflinePath, container.name);
      final serverUrl = await _localServer!.start();

      final plansResponse = await http.get(
        Uri.parse('$serverUrl/api/v1/watershed/plans/?block=$selectedBlockID'),
        headers: {
          "Content-Type": "application/json",
          'X-API-Key': 'xxx',
        },
      );

      if (plansResponse.statusCode != 200) {
        throw Exception('Failed to fetch plans: ${plansResponse.statusCode}');
      }

      final encodedPlans = Uri.encodeComponent(plansResponse.body);
      print("Plans are printed here !");
      print(plansResponse.body);

      String url = "$serverUrl/maps?" +
          "geoserver_url=$serverUrl" +
          "&state_name=${container.state}" +
          "&dist_name=${container.district}" +
          "&block_name=${container.block}" +
          "&block_id=$selectedBlockID" +
          "&isOffline=true" +
          "&container_name=${container.name}" +
          "&plans=$encodedPlans" +
          "&language=$_selectedLanguage" +
          "&latitude=${container.latitude}" +
          "&longitude=${container.longitude}";

      print('Offline URL: $url');

      if (mounted) {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => WebViewApp(url: url),
          ),
        );
      }
    } catch (e) {
      print('Error navigating to offline web view: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                '${localizations.errorLoadingOfflineView} ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildDropdown({
    required String? value,
    required String hint,
    required List<Map<String, dynamic>> items,
    required Function(String?) onChanged,
  }) {
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
            items: items.map((Map<String, dynamic> map) {
              return DropdownMenuItem<String>(
                value: map["label"],
                child: Text(
                  map["label"],
                  style: const TextStyle(color: Color(0xFF592941)),
                ),
              );
            }).toList(),
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(localizations.pleaseSelectStateDistrictBlock),
          backgroundColor: Theme.of(context).colorScheme.error,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
          margin: const EdgeInsets.all(16),
        ),
      );
      return;
    }

    if (isOnlineMode) {
      submitLocation();
    } else {
      ContainerSheets.showContainerList(
        context: context,
        selectedLanguage: _selectedLanguage,
        selectedState: selectedState!,
        selectedDistrict: selectedDistrict!,
        selectedBlock: selectedBlock!,
        onContainerSelected: (container) {
          if (container.isDownloaded) {
            navigateToWebViewOffline(container);
          } else {
            showAgreementSheet(container);
          }
        },
      );
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(localizations.couldNotOpenEmailClient),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
      print('Could not launch $emailLaunchUri');
    }
  }

  Widget _buildLanguageSelector() {
    return IconButton(
      key: _languageButtonKey,
      icon: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _selectedLanguage,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 4),
          const Icon(
            Icons.arrow_drop_down,
            color: Colors.white,
            size: 20,
          ),
        ],
      ),
      tooltip: 'Language Selection',
      onPressed: () => _showLanguageMenu(),
    );
  }

  void _showLanguageMenu() async {
    if (!mounted) return;

    await Future.delayed(Duration.zero);

    if (!mounted) return;

    try {
      final RenderBox? renderBox =
          _languageButtonKey.currentContext?.findRenderObject() as RenderBox?;
      if (renderBox == null || !renderBox.hasSize) {
        return;
      }

      final Offset offset = renderBox.localToGlobal(Offset.zero);
      final Size size = renderBox.size;

      final RelativeRect position = RelativeRect.fromLTRB(
        offset.dx - 150, // Adjust to center the popup better
        offset.dy + size.height,
        offset.dx + size.width + 150,
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
          minWidth: 180,
          maxWidth: 220,
        ),
        items: [
          PopupMenuItem<String>(
            value: 'en',
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8.0),
                  decoration: BoxDecoration(
                    color: _selectedLanguage == 'en'
                        ? const Color(0xFF592941).withOpacity(0.1)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                  child: Icon(
                    Icons.language,
                    color: _selectedLanguage == 'en'
                        ? const Color(0xFF592941)
                        : Colors.grey[600],
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'English',
                        style: TextStyle(
                          color: _selectedLanguage == 'en'
                              ? const Color(0xFF592941)
                              : Colors.grey[800],
                          fontWeight: _selectedLanguage == 'en'
                              ? FontWeight.w600
                              : FontWeight.w500,
                          fontSize: 15,
                        ),
                      ),
                      Text(
                        'EN',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w400,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                if (_selectedLanguage == 'en')
                  Icon(
                    Icons.check_circle,
                    color: const Color(0xFF592941),
                    size: 18,
                  ),
              ],
            ),
          ),
          PopupMenuItem<String>(
            value: 'hi',
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8.0),
                  decoration: BoxDecoration(
                    color: _selectedLanguage == 'hi'
                        ? const Color(0xFF592941).withOpacity(0.1)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                  child: Icon(
                    Icons.translate,
                    color: _selectedLanguage == 'hi'
                        ? const Color(0xFF592941)
                        : Colors.grey[600],
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'हिंदी',
                        style: TextStyle(
                          color: _selectedLanguage == 'hi'
                              ? const Color(0xFF592941)
                              : Colors.grey[800],
                          fontWeight: _selectedLanguage == 'hi'
                              ? FontWeight.w600
                              : FontWeight.w500,
                          fontSize: 15,
                        ),
                      ),
                      Text(
                        'HI',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w400,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                if (_selectedLanguage == 'hi')
                  Icon(
                    Icons.check_circle,
                    color: const Color(0xFF592941),
                    size: 18,
                  ),
              ],
            ),
          ),
        ],
      );

      if (selected != null && selected != _selectedLanguage) {
        setState(() {
          _selectedLanguage = selected;
          HapticFeedback.mediumImpact();
          // Update the global locale
          localeNotifier.value = Locale(selected);
        });
      }
    } catch (e) {
      debugPrint('Error showing language menu: $e');
    }
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
            value: 'changelogs',
            child: Row(
              children: [
                Icon(Icons.history, color: Color(0xFF592941)),
                SizedBox(width: 12),
                Text(
                  'Change Logs',
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
        );
        break;
      case 'changelogs':
        ChangeLog.showChangelogBottomSheet(context);
        break;
      case 'logout':
        LogoutService.showLogoutConfirmationDialog(context);
        break;
    }
  }

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
              leading: const Icon(Icons.history),
              title: const Text('Change Logs'),
              onTap: () {
                Navigator.pop(context);
                _handleMenuSelection('changelogs');
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
    // Use ValueListenableBuilder to ensure we rebuild when locale changes
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
                // ... rest of your existing body content ...
                child:
                    _buildLocationSelectionContent(localizations, customGrey),
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
              onChanged: (String? value) {
                if (value != null) {
                  updateSelectedBlock(value);
                }
              },
            ),
            const SizedBox(height: 35.0),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40.0),
              child: const Divider(
                height: 1,
                thickness: 1.5,
                color: Color.fromARGB(255, 211, 211, 211),
              ),
            ),
            const SizedBox(height: 15.0),
            Text(
              _isSelected[0]
                  ? localizations.onlineModeSelected
                  : localizations.offlineModeSelected,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF592941)),
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
                        onPressed: () {
                          setState(() {
                            HapticFeedback.lightImpact();
                            _isSelected = [true, false];
                          });
                        },
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
                          setState(() {
                            HapticFeedback.lightImpact();
                            _isSelected = [true, false];
                          });
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
                        onPressed: () {
                          setState(() {
                            HapticFeedback.lightImpact();
                            _isSelected = [false, true];
                          });
                        },
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
                          setState(() {
                            HapticFeedback.lightImpact();
                            _isSelected = [false, true];
                          });
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
            const SizedBox(height: 20.0),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16.0),
              child: Container(
                padding: const EdgeInsets.all(14.0),
                decoration: BoxDecoration(
                  color: Colors.grey.shade400.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12.0),
                ),
                child: Text(
                  localizations.betaOfflineNote,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w400,
                    color: Color.fromARGB(255, 77, 77, 77),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 32.0),
            Padding(
              padding: const EdgeInsets.only(bottom: 16.0),
              child: Text(
                '${localizations.version} $_appVersion',
                style: const TextStyle(
                  color: Color(0xFF592941),
                  fontSize: 14,
                ),
              ),
            ),
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
