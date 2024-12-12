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

  // Add constants for common paths and MIME types
  static const String VECTOR_LAYERS_PATH = 'vector_layers';
  static const String BASE_MAP_TILES_PATH = 'base_map_tiles';
  static const String WEBAPP_PATH = 'webapp';

  LocalServer(this.persistentOfflineDataDirectory) {
    print(
        'LocalServer initialized with directory: $persistentOfflineDataDirectory');
    _validateOfflineData(); // Check data availability on startup
  }

  // Validate offline data exists
  Future<void> _validateOfflineData() async {
    final vectorLayersDir = Directory(
        path.join(persistentOfflineDataDirectory, VECTOR_LAYERS_PATH));
    if (!await vectorLayersDir.exists()) {
      print(
          'Warning: Vector layers directory not found at ${vectorLayersDir.path}');
    } else {
      // List available vector layers
      final files = await vectorLayersDir
          .list()
          .map((f) => path.basename(f.path))
          .toList();
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
    print("ANkit ANkit Ankit ANkit ANkit ANkit ANkit ANkit ANkit ANkit ANkit");
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
      // Normalize the path by removing leading/trailing slashes
      final normalizedPath = requestPath.trim().toLowerCase();
      print('Normalized path: "$normalizedPath"');

      if (normalizedPath == 'api/v1/get_plans' ||
          normalizedPath == 'api/v1/get_plans/' ||
          normalizedPath.startsWith('api/v1/get_plans')) {
        print("Found plans request");
        final blockId = request.url.queryParameters['block_id'];
        print("Block ID from request: $blockId");
        if (blockId != null) {
          final response = await _handlePlansRequest(blockId);
          print('Plans response status: ${response.statusCode}');
          final responseBody = await response.readAsString();
          print('Plans response body: $responseBody');
          return shelf.Response.ok(
            responseBody,
            headers: {
              'Content-Type': 'application/json; charset=utf-8',
              'Access-Control-Allow-Origin': '*',
            },
          );
        }
        print("Missing block_id parameter");
        return shelf.Response.badRequest(body: 'Missing block_id parameter');
      }

      // Handle route requests (like /maps) by serving index.html
      if (requestPath.isEmpty ||
          requestPath == '/' ||
          !requestPath.contains('.')) {
        return _serveIndexHtml();
      }

      // Handle vector layer requests
      if (requestPath.startsWith('$VECTOR_LAYERS_PATH/')) {
        return await _serveVectorLayer(requestPath);
      }

      // Handle base map tile requests
      if (requestPath.startsWith('$BASE_MAP_TILES_PATH/')) {
        return await _serveBaseMapTile(requestPath);
      }

      // For all other requests, try to serve from the webapp directory
      return await _serveFile(path.join(WEBAPP_PATH, requestPath));
    } catch (e, stackTrace) {
      print('Error handling request: $e');
      print('Stack trace: $stackTrace');
      return shelf.Response.internalServerError(
          body: 'Internal Server Error: ${e.toString()}');
    }
  }

  // Specialized handler for vector layers
  Future<shelf.Response> _serveVectorLayer(String requestPath) async {
    final filePath = path.join(persistentOfflineDataDirectory, requestPath);
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
    final filePath = path.join(persistentOfflineDataDirectory, requestPath);

    try {
      final file = File(filePath);
      if (!await file.exists()) {
        return shelf.Response.notFound('Tile not found');
      }

      return shelf.Response.ok(
        file.openRead(),
        headers: {
          'Content-Type': 'image/png',
          'Cache-Control': 'max-age=3600',
        },
      );
    } catch (e) {
      print('Error serving tile: $e');
      return shelf.Response.internalServerError(
          body: 'Error serving tile: ${e.toString()}');
    }
  }

  Future<shelf.Response> _serveFile(String requestPath) async {
    final sanitizedPath = path.normalize(requestPath);
    if (sanitizedPath.contains('..')) {
      return shelf.Response.forbidden('Invalid path');
    }

    final filePath = path.join(persistentOfflineDataDirectory, sanitizedPath);
    final file = File(filePath);

    if (await file.exists()) {
      final mimeType = lookupMimeType(filePath) ?? 'application/octet-stream';
      return shelf.Response.ok(
        file.openRead(),
        headers: {
          'Content-Type': mimeType,
          'Cache-Control': 'max-age=3600',
        },
      );
    } else {
      print('File not found: $filePath');
      return shelf.Response.notFound(
          'File not found: ${path.basename(filePath)}');
    }
  }

  Future<shelf.Response> _serveIndexHtml() async {
    final indexPath =
        path.join(persistentOfflineDataDirectory, WEBAPP_PATH, 'index.html');
    final indexFile = File(indexPath);
    if (await indexFile.exists()) {
      return shelf.Response.ok(
        await indexFile.readAsString(),
        headers: {'Content-Type': 'text/html'},
      );
    } else {
      print('Index file not found: $indexPath');
      return shelf.Response.notFound('Index not found');
    }
  }

  void stop() {
    _server?.close();
  }
}
