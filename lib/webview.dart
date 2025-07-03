import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

class WebViewApp extends StatefulWidget {
  final String? url;
  const WebViewApp({super.key, @required this.url});

  @override
  State<WebViewApp> createState() => _WebViewState();
}

class _WebViewState extends State<WebViewApp> {
  InAppWebViewController? webViewController;
  double loadingProgress = 0.0;
  String webviewTitle = 'Commons Connect';

  @override
  void initState() {
    super.initState();
  }

  Future<void> _initializeGeolocation() async {
    if (webViewController == null) return;
    try {
      final position = await Geolocator.getCurrentPosition();
      await webViewController!.evaluateJavascript(source: '''
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
    if (webViewController == null) return;
    try {
      await webViewController!.evaluateJavascript(source: '''
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
          
          if (window.flutter_inappwebview && window.flutter_inappwebview.callHandler) {
            window.flutter_inappwebview.callHandler('TitleChannel', title || 'Commons Connect');
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
    if (webViewController != null) {
      bool canGoBack = await webViewController!.canGoBack();
      if (canGoBack) {
        await webViewController!.goBack();
        return false; // Stay in webview, navigate back within web app
      }
    }
    return true; // No more web history, exit webview
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
          navigator.pop(); // Go back to location selection
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
              print('Home button clicked - Loading URL: ${widget.url}');
              webViewController?.loadUrl(
                  urlRequest: URLRequest(url: WebUri(widget.url.toString())));
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
              onWebViewCreated: (InAppWebViewController controller) {
                webViewController = controller;
                webViewController!.addJavaScriptHandler(
                  handlerName: 'TitleChannel',
                  callback: (args) {
                    setState(() {
                      if (args.isNotEmpty && args[0] is String) {
                        final title = args[0] as String;
                        webviewTitle =
                            title.isNotEmpty ? title : 'Commons Connect';
                      } else {
                        webviewTitle = 'Commons Connect';
                      }
                    });
                  },
                );
              },
              onLoadStart: (controller, url) {
                setState(() {
                  loadingProgress = 0.0;
                });
              },
              onProgressChanged: (controller, progress) {
                setState(() {
                  loadingProgress = progress / 100.0;
                });
              },
              onLoadStop: (controller, url) async {
                setState(() {
                  loadingProgress = 1.0;
                });
                await _initializeGeolocation();
                await _initializeTitleTracking();
              },
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
