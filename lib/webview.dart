import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'dart:convert';
import '../services/login_service.dart';
import 'package:flutter/services.dart';

class WebViewApp extends StatefulWidget {
  final String? url;
  final String selectedLanguage;
  const WebViewApp(
      {super.key, @required this.url, this.selectedLanguage = 'hi'});

  @override
  State<WebViewApp> createState() => _WebViewState();
}

class _WebViewState extends State<WebViewApp> {
  InAppWebViewController? webViewController;
  double loadingProgress = 0.0;
  String webviewTitle = 'Commons Connect';
  final LoginService _loginService = LoginService();
  final GlobalKey _optionsButtonKey = GlobalKey();

  // ADD THESE SETTINGS
  final InAppWebViewSettings settings = InAppWebViewSettings(
    // Critical for local server access
    allowFileAccessFromFileURLs: true,
    allowUniversalAccessFromFileURLs: true,
    allowContentAccess: true,
    
    // Mixed content for localhost
    mixedContentMode: MixedContentMode.MIXED_CONTENT_ALWAYS_ALLOW,
    
    // Security settings for local development
    mediaPlaybackRequiresUserGesture: false,
    
    // IMPORTANT: Allow loading insecure content (for localhost)
    // This is needed for Android
    useOnLoadResource: true,
    
    // Cache and offline settings
    cacheEnabled: true,
    clearCache: false,
    
    // JavaScript and DOM
    javaScriptEnabled: true,
    domStorageEnabled: true,
    databaseEnabled: true,
    
    // WebGL support (needed for OpenLayers WebGL rendering)
    hardwareAcceleration: true,
    
    // CORS
    disableContextMenu: false,
    supportZoom: true,
    
    // Resource loading
    useOnDownloadStart: true,
    useShouldInterceptRequest: true,
  );

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
            timestamp: ${position.timestamp.millisecondsSinceEpoch}
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

  Future<void> _initializeAuthentication() async {
    if (webViewController == null) return;

    try {
      final authData = await _loginService.getAuthDataForWebView();

      if (authData != null) {
        await webViewController!.evaluateJavascript(source: '''
          // Store auth data in window for React app to access
          window.flutterAuth = ${jsonEncode(authData)};
          
          // Function for React to get current auth token
          window.getAuthToken = function() {
            return window.flutterAuth ? window.flutterAuth.access_token : null;
          };
          
          // Function for React to get user data
          window.getUserData = function() {
            return window.flutterAuth ? window.flutterAuth.user : null;
          };
          
          // Function to request token refresh
          window.refreshAuthToken = async function() {
            return new Promise((resolve, reject) => {
              if (window.flutter_inappwebview && window.flutter_inappwebview.callHandler) {
                window.flutter_inappwebview.callHandler('RefreshToken')
                  .then(response => {
                    if (response && response.access_token) {
                      window.flutterAuth = response;
                      resolve(response);
                    } else {
                      reject(new Error('Token refresh failed'));
                    }
                  })
                  .catch(reject);
              } else {
                reject(new Error('Flutter bridge not available'));
              }
            });
          };
          
          // Helper function for making authenticated API calls
          window.makeAuthenticatedRequest = async function(url, options = {}) {
            let token = window.getAuthToken();
            
            // If no token or token might be expired, try refresh
            if (!token || window.isTokenExpired()) {
              try {
                const refreshResult = await window.refreshAuthToken();
                token = refreshResult.access_token;
              } catch (e) {
                console.error('Failed to refresh token:', e);
                throw new Error('Authentication failed');
              }
            }
            
            // Add authorization header
            const headers = {
              'Authorization': `Bearer \${token}`,
              'Content-Type': 'application/json',
              ...options.headers
            };
            
            return fetch(url, {
              ...options,
              headers
            });
          };
          
          // Check if token is expired (simple client-side check)
          window.isTokenExpired = function() {
            if (!window.flutterAuth || !window.flutterAuth.timestamp) return true;
            const tokenAge = Date.now() - window.flutterAuth.timestamp;
            // Consider token expired if older than 2 hours (configurable)
            return tokenAge > (2 * 60 * 60 * 1000);
          };
          
          console.log('Flutter authentication bridge initialized');
        ''');
      }
    } catch (e) {
      print('Error initializing authentication: $e');
    }
  }

  String getLocalizedText(BuildContext context, String key) {
    final currentLocale = Localizations.localeOf(context).languageCode;
    switch (key) {
      case 'returnToLocationSelection':
        return currentLocale == 'hi'
            ? 'स्थान चयन पर वापस जाएं'
            : 'Return to Location Selection';
      case 'returnToPlanSelection':
        return currentLocale == 'hi'
            ? 'योजना चयन पर वापस जाएं'
            : 'Return to Plan Selection';
      default:
        return key;
    }
  }

  Future<bool> _handlePopScope() async {
    if (webViewController != null) {
      bool canGoBack = await webViewController!.canGoBack();
      if (canGoBack) {
        await webViewController!.goBack();
        return false;
      }
    }
    return true;
  }

  void _goToHomePage() {
    print('Home button clicked - Loading URL: ${widget.url}');
    if (webViewController != null && widget.url != null) {
      webViewController!.loadUrl(
        urlRequest: URLRequest(url: WebUri(widget.url.toString())),
      );
    } else {
      print('Cannot go to home - WebViewController or URL is null');
    }
  }

  void _goToLocationSelection() {
    Navigator.of(context).pop();
  }

  Widget _buildOptionsMenu() {
    return GestureDetector(
      key: _optionsButtonKey,
      onTap: _showOptionsMenu,
      child: Container(
        width: 56,
        height: 56,
        alignment: Alignment.center,
        child: const Icon(
          Icons.more_vert,
          size: 28,
          color: Colors.white,
        ),
      ),
    );
  }

  Future<void> _showOptionsMenu() async {
    try {
      final RenderBox renderBox =
          _optionsButtonKey.currentContext?.findRenderObject() as RenderBox;
      final Offset offset = renderBox.localToGlobal(Offset.zero);
      final RelativeRect position = RelativeRect.fromLTRB(
        offset.dx,
        offset.dy + renderBox.size.height,
        offset.dx + renderBox.size.width,
        offset.dy + renderBox.size.height + 10,
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
          minWidth: 220,
          maxWidth: 280,
        ),
        items: [
          PopupMenuItem<String>(
            value: 'location',
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10.0),
                  decoration: BoxDecoration(
                    color: const Color(0xFF592941).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10.0),
                  ),
                  child: const Icon(
                    Icons.pin_drop_rounded,
                    color: Color(0xFF592941),
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
                        getLocalizedText(context, 'returnToLocationSelection'),
                        style: const TextStyle(
                          color: Color(0xFF592941),
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                      Text(
                        Localizations.localeOf(context).languageCode == 'hi'
                            ? 'स्थान चुनें'
                            : 'Helps Choose Location',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w400,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          PopupMenuItem<String>(
            value: 'home',
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10.0),
                  decoration: BoxDecoration(
                    color: const Color(0xFF592941).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10.0),
                  ),
                  child: const Icon(
                    Icons.checklist,
                    color: Color(0xFF592941),
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
                        getLocalizedText(context, 'returnToPlanSelection'),
                        style: const TextStyle(
                          color: Color(0xFF592941),
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                      Text(
                        Localizations.localeOf(context).languageCode == 'hi'
                            ? 'योजना चुनें'
                            : 'Helps Choose Plans',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w400,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      );

      if (selected != null) {
        HapticFeedback.mediumImpact();
        switch (selected) {
          case 'home':
            _goToHomePage();
            break;
          case 'location':
            _goToLocationSelection();
            break;
        }
      }
    } catch (e) {
      debugPrint('Error showing options menu: $e');
    }
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
          automaticallyImplyLeading: false,
          actions: [
            _buildOptionsMenu(),
          ],
        ),
        body: Stack(
          children: [
            InAppWebView(
              initialUrlRequest: URLRequest(
                url: WebUri(widget.url.toString()),
              ),
              initialSettings: settings, // ADD THIS LINE - Critical!
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

                webViewController!.addJavaScriptHandler(
                  handlerName: 'RefreshToken',
                  callback: (args) async {
                    print('WebView requested token refresh');
                    final refreshedAuth =
                        await _loginService.refreshTokenForWebView();
                    return refreshedAuth;
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
                await _initializeAuthentication();
              },
              onConsoleMessage: (controller, consoleMessage) {
                // ADD THIS - Log console messages for debugging
                print('WebView Console [${consoleMessage.messageLevel}]: ${consoleMessage.message}');
              },
              onLoadError: (controller, url, code, message) {
                // ADD THIS - Log load errors
                print('WebView Load Error: $message (code: $code) for $url');
              },
              onLoadHttpError: (controller, url, statusCode, description) {
                // ADD THIS - Log HTTP errors
                print('WebView HTTP Error: $description (status: $statusCode) for $url');
              },
              androidOnPermissionRequest:
                  (controller, origin, resources) async {
                return PermissionRequestResponse(
                    resources: resources,
                    action: PermissionRequestResponseAction.GRANT);
              },
              // ADD THIS - Allow localhost resource loading
              shouldOverrideUrlLoading: (controller, navigationAction) async {
                final uri = navigationAction.request.url;
                if (uri != null && uri.host == 'localhost') {
                  return NavigationActionPolicy.ALLOW;
                }
                return NavigationActionPolicy.ALLOW;
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