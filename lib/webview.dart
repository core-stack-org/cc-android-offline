import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:geolocator/geolocator.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart'
    hide WebResourceError;

class WebViewApp extends StatefulWidget {
  final String? url;
  const WebViewApp({super.key, @required this.url});

  @override
  State<WebViewApp> createState() => _WebViewState();
}

class _WebViewState extends State<WebViewApp> {
  late final WebViewController controller;
  double loadingProgress = 0.0;
  String webviewTitle = 'Commons Connect';

  @override
  void initState() {
    super.initState();

    controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..addJavaScriptChannel(
        'TitleChannel',
        onMessageReceived: (JavaScriptMessage message) {
          setState(() {
            webviewTitle = message.message.isNotEmpty
                ? message.message
                : 'Commons Connect';
          });
        },
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (progress) {
            setState(() {
              loadingProgress = progress / 100;
            });
          },
          onPageFinished: (url) async {
            setState(() {
              loadingProgress = 1.0;
            });

            await _initializeGeolocation();
            await _initializeTitleTracking();
          },
          onWebResourceError: (WebResourceError error) {
            print('Web Resource Error: ${error.description}');
          },
        ),
      );

    // Configure platform-specific settings
    if (controller.platform is AndroidWebViewController) {
      final androidController = controller.platform as AndroidWebViewController;
      androidController.setMediaPlaybackRequiresUserGesture(false);
    }

    // Load the URL after configuration
    controller.loadRequest(WebUri(widget.url.toString()));
  }

  Future<void> _initializeGeolocation() async {
    try {
      final position = await Geolocator.getCurrentPosition();
      await controller.runJavaScript('''
        window.navigator.geolocation.getCurrentPosition = (success, error) => {
          success({
            coords: {
              latitude: ${position.latitude},
              longitude: ${position.longitude},
              accuracy: ${position.accuracy},
              altitude: ${position.altitude},
              heading: ${position.heading},
              speed: ${position.speed}
            },
            timestamp: ${position.timestamp?.millisecondsSinceEpoch ?? DateTime.now().millisecondsSinceEpoch}
          });
        };
      ''');
    } catch (e) {
      print('Error initializing geolocation: $e');
    }
  }

  Future<void> _initializeTitleTracking() async {
    try {
      await controller.runJavaScript('''
        function sendTitleToFlutter() {
          var title = document.title;
          
          if (!title || title.trim() === '' || title === 'Commons Connect') {
            var h1Elements = document.getElementsByTagName('h1');
            if (h1Elements.length > 0) {
              title = h1Elements[0].textContent || h1Elements[0].innerText;
            }
          }
          
          if (!title || title.trim() === '') {
            var headings = document.querySelectorAll('h1, h2, .title, .page-title, .header-title');
            for (var i = 0; i < headings.length; i++) {
              var headingText = headings[i].textContent || headings[i].innerText;
              if (headingText && headingText.trim() !== '') {
                title = headingText;
                break;
              }
            }
          }
          
          if (title) {
            title = title.trim().substring(0, 50);
          }
          
          if (typeof TitleChannel !== 'undefined') {
            TitleChannel.postMessage(title || 'Commons Connect');
          }
        }
        
        sendTitleToFlutter();
        
        var titleObserver = new MutationObserver(function(mutations) {
          mutations.forEach(function(mutation) {
            if (mutation.type === 'childList' || mutation.type === 'characterData') {
              sendTitleToFlutter();
            }
          });
        });
        
        var titleElement = document.querySelector('title');
        if (titleElement) {
          titleObserver.observe(titleElement, { childList: true, characterData: true });
        }
        
        titleObserver.observe(document.body, { 
          childList: true, 
          subtree: true,
          characterData: true 
        });
        
        window.addEventListener('load', sendTitleToFlutter);
        window.addEventListener('popstate', sendTitleToFlutter);
        
        setInterval(sendTitleToFlutter, 2000);
      ''');
    } catch (e) {
      print('Error initializing title tracking: $e');
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
          title: Text(
            webviewTitle,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
            overflow: TextOverflow.ellipsis,
          ),
          leading: IconButton(
            icon: const Icon(Icons.home),
            onPressed: () {
              controller.loadRequest(WebUri(widget.url.toString()));
            },
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.menu),
              onPressed: () {
                Navigator.pop(context);
              },
            ),
          ],
        ),
        body: Stack(
          children: [
            InAppWebView(
              initialUrlRequest: URLRequest(
                url: WebUri(widget.url.toString()),
              ),
              androidOnPermissionRequest:
                  (controller, origin, resources) async {
                return PermissionRequestResponse(
                    resources: resources,
                    action: PermissionRequestResponseAction.GRANT);
              },
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
