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
import './utils/use_info.dart';
import './container_flow/container_manager.dart';
import './container_flow/container_sheet.dart';
import './download_progress.dart';

import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class LocationSelection extends StatefulWidget {
  const LocationSelection({super.key});

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
  String _modeSelectionMessage = "You have selected ONLINE mode";
  String _selectedLanguage = 'en';

  List<Map<String, dynamic>> states = [];
  List<Map<String, dynamic>> districts = [];
  List<Map<String, dynamic>> blocks = [];

  @override
  void initState() {
    super.initState();
    _loadInfo();
    fetchLocationData();
    // Initialize the mode selection message
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateModeSelectionMessage();
    });
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

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => WebViewApp(url: url),
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
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setSheetState) {
            return Container(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    getLocalizedText(
                        context, 'accessApplicationWithoutInternet'),
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF592941),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    getLocalizedText(context, 'downloadLayersMessage'),
                    style: TextStyle(
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
                        getLocalizedText(context, 'agreeAndDownloadLayers'),
                        style: TextStyle(
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
                        getLocalizedText(context, 'downloadLayers'),
                        style: TextStyle(
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

  Future<void> navigateToWebViewOffline(OfflineContainer container) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final persistentOfflinePath =
          path.join(directory.path, 'persistent_offline_data');

      _localServer = LocalServer(persistentOfflinePath, container.name);
      final serverUrl = await _localServer!.start();

      final plansResponse = await http.get(
        Uri.parse('$serverUrl/api/v1/get_plans/?block_id=$selectedBlockID'),
      );

      if (plansResponse.statusCode != 200) {
        throw Exception('Failed to fetch plans: ${plansResponse.statusCode}');
      }

      final encodedPlans = Uri.encodeComponent(plansResponse.body);

      String url = "$serverUrl/maps?" +
          "geoserver_url=$serverUrl" +
          "&state_name=${container.state}" +
          "&dist_name=${container.district}" +
          "&block_name=${container.block}" +
          "&block_id=$selectedBlockID" +
          "&isOffline=true" +
          "&container_name=${container.name}" +
          "&plans=$encodedPlans" +
          "&language=$_selectedLanguage";

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
                '${getLocalizedText(context, 'errorLoadingOfflineView')} ${e.toString()}'),
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
                  color: const Color(0xFF592941).withOpacity(0.1),
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
    HapticFeedback.mediumImpact();
    bool isOnlineMode = _isSelected[0];

    if (selectedState == null ||
        selectedDistrict == null ||
        selectedBlock == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text(getLocalizedText(context, 'pleaseSelectStateDistrictBlock')),
          backgroundColor: Theme.of(context).colorScheme.error,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
          margin: EdgeInsets.all(16),
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
          content: Text(getLocalizedText(context, 'couldNotOpenEmailClient')),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
      print('Could not launch $emailLaunchUri');
    }
  }

  Widget _buildLanguageSelector() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 8.0),
      padding: const EdgeInsets.symmetric(horizontal: 10.0),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(25),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedLanguage,
          onChanged: (String? newValue) {
            if (newValue != null) {
              setState(() {
                _selectedLanguage = newValue;
                HapticFeedback.lightImpact();
                // Update the mode selection message when language changes
                _updateModeSelectionMessage();
              });
            }
          },
          dropdownColor: Colors.black.withOpacity(0.9),
          borderRadius: BorderRadius.circular(20),
          menuMaxHeight: 200,
          items: const [
            DropdownMenuItem(
              value: 'en',
              child: Text(
                'English (en)',
                style: TextStyle(color: Colors.white, fontSize: 16),
              ),
            ),
            DropdownMenuItem(
              value: 'hi',
              child: Text(
                'हिंदी (hi)',
                style: TextStyle(color: Colors.white, fontSize: 16),
              ),
            ),
          ],
          selectedItemBuilder: (BuildContext context) {
            return <String>['en', 'hi'].map<Widget>((String item) {
              return Center(
                  child: Text(item,
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold)));
            }).toList();
          },
          icon: const Icon(Icons.arrow_drop_down, color: Colors.white),
          style: const TextStyle(color: Colors.white, fontSize: 18),
        ),
      ),
    );
  }

  String getLocalizedText(BuildContext context, String key) {
    final localizations = _selectedLanguage == 'hi'
        ? AppLocalizations.of(
            context)! // This will use Hindi if device is set to Hindi
        : AppLocalizations.of(context)!; // Or you can create a custom method

    // For now, create a simple mapping
    switch (key) {
      case 'selectLocation':
        return _selectedLanguage == 'hi' ? 'स्थान चुनें' : 'Select a location';
      case 'selectState':
        return _selectedLanguage == 'hi' ? 'राज्य चुनें' : 'Select a State';
      case 'selectDistrict':
        return _selectedLanguage == 'hi' ? 'जिला चुनें' : 'Select a District';
      case 'selectTehsil':
        return _selectedLanguage == 'hi' ? 'तहसील चुनें' : 'Select a Tehsil';
      case 'selectStateDistrictTehsil':
        return _selectedLanguage == 'hi'
            ? 'नीचे दिए गए ड्रॉप-डाउन से राज्य, जिला और तहसील का चयन करें। '
            : 'Select State, District and Tehsil from the dropdown';
      case 'onlineMode':
        return _selectedLanguage == 'hi' ? 'ऑनलाइन मोड' : 'Online mode';
      case 'offlineMode':
        return _selectedLanguage == 'hi' ? 'ऑफलाइन मोड*' : 'Offline mode*';
      case 'submit':
        return _selectedLanguage == 'hi' ? 'जमा करें' : 'SUBMIT';
      case 'onlineModeSelected':
        return _selectedLanguage == 'hi'
            ? 'आपने ऑनलाइन मोड चुना है'
            : 'You have selected ONLINE mode';
      case 'offlineModeSelected':
        return _selectedLanguage == 'hi'
            ? 'आपने ऑफलाइन मोड चुना है'
            : 'You have selected OFFLINE mode';
      case 'betaOfflineNote':
        return _selectedLanguage == 'hi'
            ? '*बीटा ऑफलाइन मोड सीमित सुविधाओं के साथ इंटरनेट के बिना दूरदराज के क्षेत्रों में काम करता है।'
            : '*BETA Offline mode works in remote areas without internet with limited features.';
      case 'version':
        return _selectedLanguage == 'hi' ? 'संस्करण:' : 'version:';
      case 'fileaBugReport':
        return _selectedLanguage == 'hi'
            ? 'बग रिपोर्ट दर्ज करें'
            : 'File a bug report';
      case 'whatsNew':
        return _selectedLanguage == 'hi' ? 'नया क्या है' : "What's New";
      case 'accessApplicationWithoutInternet':
        return _selectedLanguage == 'hi'
            ? 'इंटरनेट के बिना एप्लिकेशन तक पहुंचें'
            : 'Access Application without Internet';
      case 'downloadLayersMessage':
        return _selectedLanguage == 'hi'
            ? 'ऑफलाइन कनेक्टिविटी के लिए लेयर डाउनलोड करने हेतु, कृपया सहमत पर टिक करें और डाउनलोड बटन दबाएं। लेयर आपके फोन स्टोरेज का लगभग 300 MB लेंगे।'
            : 'To download the layers for offline connectivity, please tick off agree and press on download button. The layers will take around 300 MB of your phone storage.';
      case 'agreeAndDownloadLayers':
        return _selectedLanguage == 'hi'
            ? 'सहमत हैं और लेयर डाउनलोड करें'
            : 'Agree and Download Layers';
      case 'downloadLayers':
        return _selectedLanguage == 'hi'
            ? 'लेयर डाउनलोड करें'
            : 'Download Layers';
      case 'pleaseSelectStateDistrictBlock':
        return _selectedLanguage == 'hi'
            ? 'कृपया राज्य, जिला और ब्लॉक चुनें।'
            : 'Please select State, District, and Block.';
      case 'errorLoadingOfflineView':
        return _selectedLanguage == 'hi'
            ? 'ऑफलाइन व्यू लोड करने में त्रुटि:'
            : 'Error loading offline view:';
      case 'couldNotOpenEmailClient':
        return _selectedLanguage == 'hi'
            ? 'ईमेल क्लाइंट नहीं खोल सके। कृपया अपनी रिपोर्ट support@core-stack.org पर भेजें'
            : 'Could not open email client. Please send your report to support@core-stack.org';
      default:
        return key;
    }
  }

  void _updateModeSelectionMessage() {
    setState(() {
      if (_isSelected[0]) {
        _modeSelectionMessage = getLocalizedText(context, 'onlineModeSelected');
      } else {
        _modeSelectionMessage =
            getLocalizedText(context, 'offlineModeSelected');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    const Color customGrey = Color(0xFFD6D4C8);
    const Color darkTextColor = Colors.black87;

    return Scaffold(
      backgroundColor:
          const Color.fromARGB(255, 255, 255, 255).withValues(alpha: 1.0),
      appBar: AppBar(
        backgroundColor: Colors.black,
        centerTitle: true,
        foregroundColor: Colors.white,
        title: Text(getLocalizedText(context, 'selectLocation')),
        leading: IconButton(
          icon: const Icon(Icons.history),
          onPressed: () => ChangeLog.showChangelogBottomSheet(context),
          tooltip: getLocalizedText(context, 'whatsNew'),
        ),
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
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(height: 32.0),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 10.0),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          getLocalizedText(
                              context, 'selectStateDistrictTehsil'),
                          style: TextStyle(
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
                      hint: getLocalizedText(context, 'selectState'),
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
                      hint: getLocalizedText(context, 'selectDistrict'),
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
                      hint: getLocalizedText(context, 'selectTehsil'),
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
                      _modeSelectionMessage,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: const Color(0xFF592941)),
                    ),
                    const SizedBox(height: 15.0),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        _isSelected[0]
                            ? ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: customGrey,
                                  foregroundColor: Color(0xFF592941),
                                  padding: EdgeInsets.symmetric(
                                      horizontal: 24, vertical: 12),
                                  textStyle: TextStyle(fontSize: 15),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20.0),
                                  ),
                                ),
                                onPressed: () {
                                  setState(() {
                                    HapticFeedback.lightImpact();
                                    _isSelected = [true, false];
                                    _updateModeSelectionMessage();
                                  });
                                },
                                child: Text(
                                    getLocalizedText(context, 'onlineMode')),
                              )
                            : OutlinedButton(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: customGrey,
                                  side:
                                      BorderSide(color: customGrey, width: 1.5),
                                  padding: EdgeInsets.symmetric(
                                      horizontal: 24, vertical: 12),
                                  textStyle: TextStyle(fontSize: 15),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20.0),
                                  ),
                                ),
                                onPressed: () {
                                  setState(() {
                                    HapticFeedback.lightImpact();
                                    _isSelected = [true, false];
                                    _updateModeSelectionMessage();
                                  });
                                },
                                child: Text(
                                    getLocalizedText(context, 'onlineMode')),
                              ),
                        SizedBox(width: 16),
                        _isSelected[1]
                            ? ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: customGrey,
                                  foregroundColor: Color(0xFF592941),
                                  padding: EdgeInsets.symmetric(
                                      horizontal: 24, vertical: 12),
                                  textStyle: TextStyle(fontSize: 15),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20.0),
                                  ),
                                ),
                                onPressed: () {
                                  setState(() {
                                    HapticFeedback.lightImpact();
                                    _isSelected = [false, true];
                                    _updateModeSelectionMessage();
                                  });
                                },
                                child: Text(
                                    getLocalizedText(context, 'offlineMode')),
                              )
                            : OutlinedButton(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: customGrey,
                                  side:
                                      BorderSide(color: customGrey, width: 1.5),
                                  padding: EdgeInsets.symmetric(
                                      horizontal: 24, vertical: 12),
                                  textStyle: TextStyle(fontSize: 15),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20.0),
                                  ),
                                ),
                                onPressed: () {
                                  setState(() {
                                    HapticFeedback.lightImpact();
                                    _isSelected = [false, true];
                                    _updateModeSelectionMessage();
                                  });
                                },
                                child: Text(
                                    getLocalizedText(context, 'offlineMode')),
                              ),
                      ],
                    ),
                    SizedBox(height: 20),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _isSubmitEnabled
                              ? customGrey
                              : Colors.grey.shade400,
                          foregroundColor: _isSubmitEnabled
                              ? const Color(0xFF592941)
                              : Colors.white,
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
                        child: Text(getLocalizedText(context, 'submit')),
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
                          getLocalizedText(context, 'betaOfflineNote'),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w400,
                            color: Color.fromARGB(255, 77, 77, 77),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 32.0),
                    Padding(
                      padding: EdgeInsets.only(bottom: 16.0),
                      child: Text(
                        '${getLocalizedText(context, 'version')} $_appVersion',
                        style: TextStyle(
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
                            Icon(
                              Icons.bug_report,
                              color: Color(0xFF592941),
                              size: 16,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              getLocalizedText(context, 'fileaBugReport'),
                              style: TextStyle(
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
            ),
          ),
        ],
      ),
    );
  }
}
