import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:http/http.dart' as http;

import 'package:nrmflutter/server/local_server.dart';
import 'package:nrmflutter/webview.dart';
import 'package:nrmflutter/container_flow/container_manager.dart';
import 'package:nrmflutter/config/api_config.dart';
import 'package:nrmflutter/l10n/app_localizations.dart';

class OfflineWebView extends StatefulWidget {
  final OfflineContainer container;
  final String selectedBlockID;
  final String selectedLanguage;

  const OfflineWebView({
    super.key,
    required this.container,
    required this.selectedBlockID,
    required this.selectedLanguage,
  });

  @override
  State<OfflineWebView> createState() => _OfflineWebViewState();
}

class _OfflineWebViewState extends State<OfflineWebView> {
  LocalServer? _localServer;
  String? _url;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _startServerAndLoad();
  }

  Future<void> _startServerAndLoad() async {
    try {
      if (mounted) {
        setState(() {
          _isLoading = true;
          _errorMessage = null;
        });
      }

      final directory = await getApplicationDocumentsDirectory();
      final persistentOfflinePath =
          path.join(directory.path, 'persistent_offline_data');

      // Stop existing server if any
      _localServer?.stop();

      // Start server SPECIFIC to this container
      _localServer = LocalServer(persistentOfflinePath, widget.container.name);
      final serverUrl = await _localServer!.start();

      // Fetch plans using the local server
      final plansResponse = await http.get(
        Uri.parse(
            '$serverUrl/api/v1/watershed/plans/?block=${widget.selectedBlockID}'),
        headers: {
          "Content-Type": "application/json",
          'X-API-Key': apiKey,
        },
      );

      if (plansResponse.statusCode != 200) {
        throw Exception('Failed to fetch plans: ${plansResponse.statusCode}');
      }

      final encodedPlans = Uri.encodeComponent(plansResponse.body);

      final url = "$serverUrl/maps?" +
          "geoserver_url=$serverUrl" +
          "&state_name=${widget.container.state}" +
          "&dist_name=${widget.container.district}" +
          "&block_name=${widget.container.block}" +
          "&block_id=${widget.selectedBlockID}" +
          "&isOffline=true" +
          "&container_name=${widget.container.name}" +
          "&plans=$encodedPlans" +
          "&language=${widget.selectedLanguage}" +
          "&latitude=${widget.container.latitude}" +
          "&longitude=${widget.container.longitude}";

      print('Offline URL constructed: $url');

      if (mounted) {
        setState(() {
          _url = url;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error starting offline mode: $e');
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    print('OfflineWebView disposing, stopping server...');
    _localServer?.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);

    if (_isLoading) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF592941)),
              ),
              const SizedBox(height: 24),
              Text(
                localizations?.pleaseWait ?? "Please wait...",
                style: const TextStyle(
                  fontSize: 16,
                  color: Color(0xFF592941),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_errorMessage != null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Error'),
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, color: Colors.red, size: 64),
                const SizedBox(height: 24),
                Text(
                  localizations?.errorLoadingOfflineView ??
                      'Error loading offline view',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF592941),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Text(
                  _errorMessage!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: _startServerAndLoad,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFD6D5C9),
                    foregroundColor: const Color(0xFF592941),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 32, vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  child: Text(localizations?.retry ?? 'Retry'),
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    'Go Back',
                    style: TextStyle(color: Colors.grey[700]),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return WebViewApp(
      url: _url,
      selectedLanguage: widget.selectedLanguage,
    );
  }
}
