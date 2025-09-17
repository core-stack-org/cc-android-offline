import 'dart:io';
import 'dart:convert';
import 'package:shelf/shelf.dart' as shelf;
import 'package:shelf/shelf_io.dart' as io;
import 'package:path/path.dart' as path;
import 'package:mime/mime.dart';
import 'package:nrmflutter/db/plans_db.dart';

class LocalServer {
  HttpServer? _server;
  final String persistentOfflineDataDirectory;
  final String? containerName;

  // Add constants for common paths and MIME types
  static const String VECTOR_LAYERS_PATH = 'vector_layers';
  static const String BASE_MAP_TILES_PATH = 'base_map_tiles';
  static const String WEBAPP_PATH = 'webapp';
  static const String CONTAINERS_PATH = 'containers';

  LocalServer(this.persistentOfflineDataDirectory, [this.containerName]) {
    print('LocalServer initialized with directory: $persistentOfflineDataDirectory${containerName != null ? ' for container: $containerName' : ''}');
    _validateOfflineData(); // Check data availability on startup
  }

  String get _basePath => containerName != null 
      ? path.join(persistentOfflineDataDirectory, CONTAINERS_PATH, containerName!)
      : persistentOfflineDataDirectory;

  // Validate offline data exists
  Future<void> _validateOfflineData() async {
    final vectorLayersDir = Directory(path.join(_basePath, VECTOR_LAYERS_PATH));
    if (!await vectorLayersDir.exists()) {
      print('Warning: Vector layers directory not found at ${vectorLayersDir.path}');
    } else {
      // List available vector layers
      final files = await vectorLayersDir.list().map((f) => path.basename(f.path)).toList();
      print('Available vector layers: $files');
    }
  }

  Future<String> start() async {
    final handler = const shelf.Pipeline()
        .addMiddleware(shelf.logRequests())
        .addMiddleware(_handleCors) // Add CORS middleware
        .addHandler(_handleRequest);

    try {
      _server = await io.serve(handler, 'localhost', 3000, shared: true);
      print('Server running on localhost:${_server!.port}');
      return 'http://localhost:${_server!.port}';
    } catch (e) {
      print('Failed to start server on port 3000: $e');
      rethrow;
    }
  }

  // Separate CORS middleware
  final shelf.Middleware _handleCors = shelf.createMiddleware(
    requestHandler: (request) => null,
    responseHandler: (response) {
      return response.change(headers: {
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
        'Access-Control-Allow-Headers': 'Origin, Content-Type, X-Auth-Token',
        'Access-Control-Max-Age': '3600',
      });
    },
  );

  Future<shelf.Response> _handlePlansRequest(String blockId) async {

    print("Handling plans request for block ID: $blockId");
    try {
      final plans =
          await PlansDatabase.instance.getPlansForBlock(int.parse(blockId));
      print("Found ${plans.length} plans for block $blockId");
      if (plans.isEmpty) {
        print("No plans found for block $blockId");
      } else {
        print("First plan: ${plans.first}");
      }

      final responseJson = json.encode({'plans': plans});
      print("Sending response with length: ${responseJson.length}");

      return shelf.Response.ok(
        responseJson,
        headers: {
          'Content-Type': 'application/json; charset=utf-8',
          'Cache-Control': 'max-age=3600',
          'Access-Control-Allow-Origin': '*',
          'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
          'Access-Control-Allow-Headers':
              'Origin, Content-Type, X-Auth-Token, ngrok-skip-browser-warning',
          'X-Content-Type-Options': 'nosniff'
        },
      );
    } catch (e) {
      print('Error serving plans: $e');
      return shelf.Response.internalServerError(
          body: json.encode({'error': e.toString()}),
          headers: {
            'Content-Type': 'application/json; charset=utf-8',
            'Access-Control-Allow-Origin': '*'
          });
    }
  }

  Future<shelf.Response> _handleRequest(shelf.Request request) async {
    final requestPath = request.url.path;
    print('Handling request for path: $requestPath');
    print('Full request URL: ${request.url}');

    try {
      // Handle OPTIONS requests for CORS
      if (request.method == 'OPTIONS') {
        return shelf.Response.ok('');
      }

      // Handle plans request first
      print('Checking for plans request...');
      print('Request path: "$requestPath"');
      final normalizedPath = requestPath.trim().toLowerCase();
      print('Normalized path: "$normalizedPath"');

      if (normalizedPath == 'api/v1/watershed' ||
          normalizedPath == 'api/v1/watershed/' ||
          normalizedPath.startsWith('api/v1/watershed')) {
        print("Found plans request");
        final blockId = request.url.queryParameters['block'];
        print("Block ID from request: $blockId");
        if (blockId != null) {
          return await _handlePlansRequest(blockId);
        }
        print("Missing block_id parameter");
        return shelf.Response.badRequest(body: 'Missing block_id parameter');
      }

      // Handle container-specific requests first
      if (requestPath.startsWith('containers/')) {
        // This is a container-specific request, serve directly from persistentOfflineDataDirectory
        return await _serveFile(requestPath, isWebApp: false);
      }

      // Handle route requests (like /maps) by serving index.html
      if (requestPath.isEmpty ||
          requestPath == '/' ||
          !requestPath.contains('.')) {
        return _serveIndexHtml();
      }

      // Special handling for CSS files
      if (requestPath.endsWith('.css')) {
        final filePath = path.join(persistentOfflineDataDirectory, WEBAPP_PATH, requestPath);
        final file = File(filePath);
        if (await file.exists()) {
          final content = await file.readAsString();
          return shelf.Response.ok(
            content,
            headers: {
              'Content-Type': 'text/css',
              'Cache-Control': 'max-age=3600',
              'Access-Control-Allow-Origin': '*',
            },
          );
        }
      }

      // For all other requests (like static assets), serve from the webapp directory
      return await _serveFile(requestPath, isWebApp: true);
    } catch (e, stackTrace) {
      print('Error handling request: $e');
      print('Stack trace: $stackTrace');
      return shelf.Response.internalServerError(
          body: 'Internal Server Error: ${e.toString()}');
    }
  }

  // Specialized handler for vector layers
  Future<shelf.Response> _serveVectorLayer(String requestPath) async {
    final filePath = path.join(_basePath, VECTOR_LAYERS_PATH, path.basename(requestPath));
    print('Serving vector layer from: $filePath');

    try {
      final file = File(filePath);
      if (!await file.exists()) {
        print('Vector layer not found: $filePath');
        return shelf.Response.notFound('Vector layer not found');
      }

      final content = await file.readAsString();
      return shelf.Response.ok(
        content,
        headers: {
          'Content-Type': 'application/json',
          'Cache-Control': 'max-age=3600',
        },
      );
    } catch (e) {
      print('Error serving vector layer: $e');
      return shelf.Response.internalServerError(
          body: 'Error serving vector layer: ${e.toString()}');
    }
  }

  // Specialized handler for base map tiles
  Future<shelf.Response> _serveBaseMapTile(String requestPath) async {
    final filePath = path.join(_basePath, BASE_MAP_TILES_PATH, requestPath.replaceFirst('$BASE_MAP_TILES_PATH/', ''));
    print('Serving base map tile from: $filePath');

    try {
      final file = File(filePath);
      if (!await file.exists()) {
        print('Base map tile not found: $filePath');
        return shelf.Response.notFound('Base map tile not found');
      }

      final bytes = await file.readAsBytes();
      return shelf.Response.ok(
        bytes,
        headers: {
          'Content-Type': 'image/png',
          'Cache-Control': 'max-age=3600',
        },
      );
    } catch (e) {
      print('Error serving base map tile: $e');
      return shelf.Response.internalServerError(
          body: 'Error serving base map tile: ${e.toString()}');
    }
  }

  Future<shelf.Response> _serveFile(String sanitizedPath, {bool isWebApp = false}) async {
    if (sanitizedPath.contains('..')) {
      return shelf.Response.forbidden('Invalid path');
    }

    final filePath = isWebApp 
        ? path.join(persistentOfflineDataDirectory, WEBAPP_PATH, sanitizedPath)
        : path.join(persistentOfflineDataDirectory, sanitizedPath);
        
    print('Attempting to serve file from: $filePath');
    final file = File(filePath);

    if (await file.exists()) {
      // Explicitly set MIME types for web assets
      String mimeType;
      if (filePath.endsWith('.js')) {
        mimeType = 'application/javascript';
      } else if (filePath.endsWith('.js.map')) {
        mimeType = 'application/json';
      } else if (filePath.endsWith('.css')) {
        mimeType = 'text/css';
      } else if (filePath.endsWith('.css.map')) {
        mimeType = 'application/json';
      } else if (filePath.endsWith('.html')) {
        mimeType = 'text/html';
      } else if (filePath.endsWith('.json')) {
        mimeType = 'application/json';
      } else if (filePath.endsWith('.png')) {
        mimeType = 'image/png';
      } else if (filePath.endsWith('.jpg') || filePath.endsWith('.jpeg')) {
        mimeType = 'image/jpeg';
      } else if (filePath.endsWith('.svg')) {
        mimeType = 'image/svg+xml';
      } else if (filePath.endsWith('.woff')) {
        mimeType = 'font/woff';
      } else if (filePath.endsWith('.woff2')) {
        mimeType = 'font/woff2';
      } else if (filePath.endsWith('.ttf')) {
        mimeType = 'font/ttf';
      } else {
        mimeType = lookupMimeType(filePath) ?? 'application/octet-stream';
      }

      print('Serving file: $filePath with MIME type: $mimeType');
      final content = await file.readAsBytes();
      
      return shelf.Response.ok(
        content,
        headers: {
          'Content-Type': mimeType,
          'Cache-Control': 'max-age=3600',
          'Access-Control-Allow-Origin': '*',
        },
      );
    }

    print('File not found: $filePath');
    return shelf.Response.notFound('File not found');
  }

  Future<shelf.Response> _serveIndexHtml() async {
    final indexPath = path.join(_basePath, WEBAPP_PATH, 'index.html');
    final indexFile = File(indexPath);
    if (await indexFile.exists()) {
      return shelf.Response.ok(
        await indexFile.readAsString(),
        headers: {
          'Content-Type': 'text/html',
          'Cache-Control': 'max-age=3600',
        },
      );
    }
    return shelf.Response.notFound('Index file not found');
  }

  void stop() {
    _server?.close();
  }
}
