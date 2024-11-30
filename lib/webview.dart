import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

class WebViewApp extends StatefulWidget {
  final String? url;
  const WebViewApp({super.key, @required this.url});

  @override
  State<WebViewApp> createState() => _WebViewState();
}

class _WebViewState extends State<WebViewApp> {
  late final WebViewController controller;
  double loadingProgress = 0.0;

  @override
  void initState() {
    super.initState();
    controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (progress) {
            setState(() {
              loadingProgress = progress / 100;
            });
          },
          onPageFinished: (url) {
            setState(() {
              loadingProgress = 1.0;
            });
          },
          onWebResourceError: (WebResourceError error) {
            print('Web Resource Error: ${error.description}');
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.url.toString()));

    // Enable loading of local content
    if (WebViewPlatform.instance is AndroidWebViewController) {
      AndroidWebViewController.enableDebugging(true);
      (controller.platform as AndroidWebViewController)
          .setMediaPlaybackRequiresUserGesture(false);
    }
  }

  Future<bool> _handlePopScope() async {
    if (await controller.canGoBack()) {
      await controller.goBack();
      return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (didPop) return;
        final navigator = Navigator.of(context);
        final shouldPop = await _handlePopScope();
        if (shouldPop) {
          navigator.pop();
        }
      },
      child: Scaffold(
        extendBodyBehindAppBar: false,
        appBar: AppBar(
          backgroundColor: Colors.black.withOpacity(1.0),
          foregroundColor: Colors.white,
          centerTitle: true,
          elevation: 0,
          title: const Text(
            'Commons Connect',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          leading: IconButton(
            icon: const Icon(Icons.home),
            onPressed: () {
              controller.loadRequest(Uri.parse(widget.url.toString()));
            },
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.location_on),
              onPressed: () {
                Navigator.pop(context);
              },
            ),
          ],
        ),
        body: Stack(
          children: [
            WebViewWidget(
              controller: controller,
            ),
            if (loadingProgress < 1.0)
              LinearProgressIndicator(
                value: loadingProgress,
                backgroundColor: Colors.grey[200],
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.blue),
              ),
          ],
        ),
      ),
    );
  }
}
