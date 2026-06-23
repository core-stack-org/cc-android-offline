import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:http/http.dart' as http;
import 'package:nrmflutter/utils/utility.dart';
import 'package:nrmflutter/utils/toast.dart';

/// Resource type strings used by the add_resources API.
abstract final class OdkResourceType {
  static const settlement = 'settlement';
  static const well = 'well';
  static const waterStructure = 'waterbody';
  static const cropping = 'cropping';
}

/// Opens an ODK/Enketo form in a full-screen in-app WebView.
///
/// When the user presses Done or navigates back, the `add_resources` API
/// is called to publish/refresh the GeoServer layer for the submitted data.
class OdkFormScreen extends StatefulWidget {
  final String url;
  final String title;

  // Context for the add_resources API call.
  // If resourceType is null the API call is skipped (e.g. dry-run screens).
  final String? resourceType;
  final String? planId;
  final String? planName;
  final String? district;
  final String? block;

  const OdkFormScreen({
    super.key,
    required this.url,
    required this.title,
    this.resourceType,
    this.planId,
    this.planName,
    this.district,
    this.block,
  });

  @override
  State<OdkFormScreen> createState() => _OdkFormScreenState();
}

class _OdkFormScreenState extends State<OdkFormScreen> {
  InAppWebViewController? _controller;
  bool _isLoading = true;
  bool _isSubmitting = false;

  bool get _hasResourceContext =>
      widget.resourceType != null &&
      widget.planId != null &&
      widget.district != null &&
      widget.block != null;

  Future<void> _submitAndClose() async {
    if (_isSubmitting) return;
    setState(() => _isSubmitting = true);

    if (_hasResourceContext) {
      try {
        await _callAddResources();
        if (mounted) showTopToast(context, 'Layer refreshed');
      } catch (_) {
        // Non-fatal — still dismiss
        if (mounted) showTopToast(context, 'Could not refresh layer');
      }
    }

    if (mounted) {
      setState(() => _isSubmitting = false);
      Navigator.pop(context);
    }
  }

  Future<void> _callAddResources() async {
    const endpoint = 'https://geoserver.core-stack.org/api/v1/add_resources/';
    await http
        .post(
          Uri.parse(endpoint),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'layer_name': widget.resourceType,
            'resource_type': widget.resourceType,
            'plan_id': widget.planId,
            'plan_name': widget.planName ?? '',
            'district_name': formatNameForGeoServer(widget.district!),
            'block_name': formatNameForGeoServer(widget.block!),
          }),
        )
        .timeout(const Duration(seconds: 30));
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _submitAndClose();
      },
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: const Color(0xFF592941),
          foregroundColor: Colors.white,
          title: Text(
            widget.title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          elevation: 0,
          actions: [
            if (_isSubmitting)
              const Center(
                child: Padding(
                  padding: EdgeInsets.only(right: 16),
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  ),
                ),
              )
            else ...[
              IconButton(
                icon: const Icon(Icons.refresh, color: Colors.white),
                onPressed: () => _controller?.reload(),
                tooltip: 'Reload form',
              ),
              TextButton(
                onPressed: _submitAndClose,
                child: const Text(
                  'Done',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ],
        ),
        body: Stack(
          children: [
            InAppWebView(
              initialUrlRequest: URLRequest(url: WebUri(widget.url)),
              initialSettings: InAppWebViewSettings(
                javaScriptEnabled: true,
                domStorageEnabled: true,
                mediaPlaybackRequiresUserGesture: false,
                allowsInlineMediaPlayback: true,
              ),
              onWebViewCreated: (c) => _controller = c,
              onLoadStart: (_, __) {
                if (mounted) setState(() => _isLoading = true);
              },
              onLoadStop: (_, __) {
                if (mounted) setState(() => _isLoading = false);
              },
            ),
            if (_isLoading)
              const LinearProgressIndicator(
                minHeight: 3,
                backgroundColor: Colors.transparent,
                color: Color(0xFF592941),
              ),
            if (_isSubmitting)
              Container(
                color: Colors.black.withValues(alpha: 0.35),
                child: const Center(
                  child: Card(
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 18, height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Color(0xFF592941),
                            ),
                          ),
                          SizedBox(width: 12),
                          Text('Refreshing layer…',
                              style: TextStyle(
                                  fontWeight: FontWeight.w500,
                                  color: Color(0xFF592941))),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
