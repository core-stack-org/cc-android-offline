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

  static const String VECTOR_LAYERS_PATH = 'vector_layers';
  static const String BASE_MAP_TILES_PATH = 'base_map_tiles';
  static const String WEBAPP_PATH = 'webapp';
  static const String CONTAINERS_PATH = 'containers';
  static const String S3_DATA_PATH = 's3_data';
  static const String IMAGE_LAYERS_PATH = 'image_layers';

  LocalServer(this.persistentOfflineDataDirectory, [this.containerName]) {
    print(
        'LocalServer initialized with directory: $persistentOfflineDataDirectory${containerName != null ? ' for container: $containerName' : ''}');
    _validateOfflineData();
  }

  String get _basePath => containerName != null
      ? path.join(
          persistentOfflineDataDirectory, CONTAINERS_PATH, containerName!)
      : persistentOfflineDataDirectory;

  Future<void> _validateOfflineData() async {
    final vectorLayersDir = Directory(path.join(_basePath, VECTOR_LAYERS_PATH));
    if (!await vectorLayersDir.exists()) {
      print(
          'Warning: Vector layers directory not found at ${vectorLayersDir.path}');
    } else {
      final files = await vectorLayersDir
          .list()
          .map((f) => path.basename(f.path))
          .toList();
      print('Available vector layers: $files');
    }

    final s3DataDir = Directory(path.join(_basePath, S3_DATA_PATH));
    if (!await s3DataDir.exists()) {
      print('Warning: S3 data directory not found at ${s3DataDir.path}');
    } else {
      final files =
          await s3DataDir.list().map((f) => path.basename(f.path)).toList();
      print('Available S3 data files: $files');
    }

    // ADD THIS: Validate image layers
    final imageLayersDir = Directory(path.join(_basePath, IMAGE_LAYERS_PATH));
    if (!await imageLayersDir.exists()) {
      print(
          'Warning: Image layers directory not found at ${imageLayersDir.path}');
    } else {
      final files = await imageLayersDir
          .list()
          .map((f) => path.basename(f.path))
          .toList();
      print('Available image layers: $files');
    }
  }

  Future<String> start() async {
    final handler = const shelf.Pipeline()
        .addMiddleware(shelf.logRequests())
        .addMiddleware(_handleCors)
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

  final shelf.Middleware _handleCors = shelf.createMiddleware(
    requestHandler: (request) => null,
    responseHandler: (response) {
      return response.change(headers: {
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
        'Access-Control-Allow-Headers':
            'Origin, Content-Type, X-Auth-Token, Range', // ADD Range
        'Access-Control-Max-Age': '3600',
        'Access-Control-Expose-Headers':
            'Accept-Ranges, Content-Length, Content-Range', // ADD THIS
      });
    },
  );

  Future<shelf.Response> _handlePlansRequest(String blockId) async {
    print("Handling plans request for block ID: $blockId");
    try {
      final plans =
          await PlansDatabase.instance.getPlansForBlock(int.parse(blockId));
      print("Found ${plans.length} plans for block $blockId");

      final responseJson = json.encode({'plans': plans});

      return shelf.Response.ok(
        responseJson,
        headers: {
          'Content-Type': 'application/json; charset=utf-8',
          'Cache-Control': 'max-age=3600',
          'Access-Control-Allow-Origin': '*',
        },
      );
    } catch (e) {
      print('Error serving plans: $e');
      return shelf.Response.internalServerError(
          body: json.encode({'error': e.toString()}),
          headers: {'Content-Type': 'application/json; charset=utf-8'});
    }
  }

  Future<shelf.Response> _handleS3DataRequest(String? formName) async {
    print("Handling S3 data request for form: ${formName ?? 'list all'}");

    try {
      final s3DataDir = Directory(path.join(_basePath, S3_DATA_PATH));

      if (!await s3DataDir.exists()) {
        return shelf.Response.notFound(
            json.encode({'error': 'S3 data directory not found'}),
            headers: {'Content-Type': 'application/json; charset=utf-8'});
      }

      if (formName == null || formName.isEmpty) {
        final files = await s3DataDir
            .list()
            .where((entity) => entity is File && entity.path.endsWith('.json'))
            .map((entity) => path.basename(entity.path))
            .toList();

        return shelf.Response.ok(
          json.encode({'forms': files, 'count': files.length}),
          headers: {
            'Content-Type': 'application/json; charset=utf-8',
            'Access-Control-Allow-Origin': '*',
          },
        );
      }

      final fileName = formName.endsWith('.json') ? formName : '$formName.json';
      final filePath = path.join(_basePath, S3_DATA_PATH, fileName);

      final file = File(filePath);
      if (!await file.exists()) {
        return shelf.Response.notFound(
            json.encode({'error': 'Form not found: $formName'}),
            headers: {'Content-Type': 'application/json; charset=utf-8'});
      }

      final content = await file.readAsString();

      return shelf.Response.ok(
        content,
        headers: {
          'Content-Type': 'application/json; charset=utf-8',
          'Access-Control-Allow-Origin': '*',
        },
      );
    } catch (e) {
      print('Error serving S3 data: $e');
      return shelf.Response.internalServerError(
          body: json.encode({'error': e.toString()}),
          headers: {'Content-Type': 'application/json; charset=utf-8'});
    }
  }

  Future<shelf.Response> _handleImageLayersRequest() async {
    print("Handling image layers list request");

    try {
      final imageLayersDir = Directory(path.join(_basePath, IMAGE_LAYERS_PATH));

      if (!await imageLayersDir.exists()) {
        return shelf.Response.ok(
          json.encode({'layers': [], 'count': 0}),
          headers: {
            'Content-Type': 'application/json; charset=utf-8',
            'Access-Control-Allow-Origin': '*',
          },
        );
      }

      final pngFiles = await imageLayersDir
          .list()
          .where((entity) => entity is File && entity.path.endsWith('.png'))
          .toList();

      final layers = <Map<String, dynamic>>[];

      for (final pngFile in pngFiles) {
        final baseName = path.basenameWithoutExtension(pngFile.path);
        final jsonPath = path.join(imageLayersDir.path, '$baseName.json');
        final jsonFile = File(jsonPath);

        if (await jsonFile.exists()) {
          try {
            final metadataContent = await jsonFile.readAsString();
            final metadata =
                json.decode(metadataContent) as Map<String, dynamic>;

            final relativeImagePath = containerName != null
                ? 'containers/$containerName/$IMAGE_LAYERS_PATH/$baseName.png'
                : '$IMAGE_LAYERS_PATH/$baseName.png';

            layers.add({
              'id': baseName,
              'name': metadata['layerName'] ?? baseName,
              'imagePath': relativeImagePath,
              'bbox': metadata['bbox'],
              'crs': metadata['crs'] ?? 'EPSG:4326',
              'projection': metadata['projection'] ?? 'EPSG:4326',
              'imageExtent': metadata['imageExtent'] ?? metadata['bbox'],
              'width': metadata['width'],
              'height': metadata['height'],
              'format': metadata['format'] ?? 'png',
              'downloadedAt': metadata['downloadedAt'],
            });
          } catch (e) {
            print('Error parsing metadata for $baseName: $e');
          }
        } else {
          final relativeImagePath = containerName != null
              ? 'containers/$containerName/$IMAGE_LAYERS_PATH/$baseName.png'
              : '$IMAGE_LAYERS_PATH/$baseName.png';

          layers.add({
            'id': baseName,
            'name': baseName,
            'imagePath': relativeImagePath,
            'format': 'png',
          });
        }
      }

      return shelf.Response.ok(
        json.encode({'layers': layers, 'count': layers.length}),
        headers: {
          'Content-Type': 'application/json; charset=utf-8',
          'Access-Control-Allow-Origin': '*',
          'Cache-Control': 'no-cache',
        },
      );
    } catch (e) {
      print('Error serving image layers list: $e');
      return shelf.Response.internalServerError(
          body: json.encode({'error': e.toString()}),
          headers: {'Content-Type': 'application/json; charset=utf-8'});
    }
  }

  Future<shelf.Response> _handleRequest(shelf.Request request) async {
    final requestPath = request.url.path;
    print('Handling request for path: $requestPath');

    try {
      if (request.method == 'OPTIONS') {
        return shelf.Response.ok('');
      }

      final normalizedPath = requestPath.trim().toLowerCase();

      // Handle plans
      if (normalizedPath.startsWith('api/v1/watershed')) {
        final blockId = request.url.queryParameters['block'];
        if (blockId != null) {
          return await _handlePlansRequest(blockId);
        }
        return shelf.Response.badRequest(body: 'Missing block_id parameter');
      }

      // Handle S3 forms
      if (normalizedPath.startsWith('api/v1/forms')) {
        final pathSegments = requestPath.split('/');
        final formIndex = pathSegments.indexOf('forms');
        String? formName;
        if (formIndex != -1 && formIndex + 1 < pathSegments.length) {
          formName = pathSegments[formIndex + 1];
        }
        return await _handleS3DataRequest(formName);
      }

      // Handle image layers API
      if (normalizedPath.startsWith('api/v1/image_layers')) {
        return await _handleImageLayersRequest();
      }

      // FIX: Handle container-specific requests (image layers, vector layers, etc.)
      if (requestPath.startsWith('containers/')) {
        print('Container-specific request: $requestPath');

        // Check if it's an image layer request (GeoTIFF)
        if (requestPath.contains('/image_layers/')) {
          print('Image layer request detected');
          return await _serveImageLayer(request, requestPath);
        }

        // For other container files
        return await _serveFile(requestPath, isWebApp: false);
      }

      // FIX: Handle root-level webapp requests
      if (requestPath.isEmpty ||
          requestPath == '/' ||
          !requestPath.contains('.')) {
        return _serveIndexHtml();
      }

      // Serve static assets from webapp directory
      return await _serveFile(requestPath, isWebApp: true);
    } catch (e, stackTrace) {
      print('Error handling request: $e');
      print('Stack trace: $stackTrace');
      return shelf.Response.internalServerError(
          body: 'Internal Server Error: ${e.toString()}');
    }
  }

  // NEW: Specialized handler for image layers with correct MIME and Range support only for TIFF
  Future<shelf.Response> _serveImageLayer(
      shelf.Request request, String requestPath) async {
    final filePath = path.join(persistentOfflineDataDirectory, requestPath);
    print('Serving image layer from: $filePath');

    try {
      final file = File(filePath);
      if (!await file.exists()) {
        print('Image layer not found: $filePath');
        return shelf.Response.notFound('Image layer not found');
      }

      final ext = path.extension(filePath).toLowerCase();
      final isTiff = ext == '.tif' || ext == '.tiff';
      final isPng = ext == '.png';
      final isJson = ext == '.json';

      final fileLength = await file.length();
      final rangeHeader = request.headers['range'];

      print('File size: $fileLength bytes');
      print('Range header: $rangeHeader');

      if (isTiff) {
        // Handle range requests for GeoTIFF streaming
        if (rangeHeader != null && rangeHeader.startsWith('bytes=')) {
          return await _serveRangeRequest(file, fileLength, rangeHeader);
        }

        final bytes = await file.readAsBytes();
        return shelf.Response.ok(
          bytes,
          headers: {
            'Content-Type': 'image/tiff',
            'Content-Length': fileLength.toString(),
            'Accept-Ranges': 'bytes',
            'Cache-Control': 'max-age=3600',
            'Access-Control-Allow-Origin': '*',
          },
        );
      }

      if (isPng) {
        final bytes = await file.readAsBytes();
        return shelf.Response.ok(
          bytes,
          headers: {
            'Content-Type': 'image/png',
            'Content-Length': fileLength.toString(),
            'Cache-Control': 'max-age=3600',
            'Access-Control-Allow-Origin': '*',
          },
        );
      }

      if (isJson) {
        final content = await file.readAsString();
        return shelf.Response.ok(
          content,
          headers: {
            'Content-Type': 'application/json; charset=utf-8',
            'Cache-Control': 'max-age=3600',
            'Access-Control-Allow-Origin': '*',
          },
        );
      }

      // Fallback: serve with detected MIME
      final bytes = await file.readAsBytes();
      return shelf.Response.ok(
        bytes,
        headers: {
          'Content-Type':
              lookupMimeType(filePath) ?? 'application/octet-stream',
          'Content-Length': fileLength.toString(),
          'Cache-Control': 'max-age=3600',
          'Access-Control-Allow-Origin': '*',
        },
      );
    } catch (e) {
      print('Error serving image layer: $e');
      return shelf.Response.internalServerError(
          body: 'Error serving image layer: ${e.toString()}');
    }
  }

  // NEW: Handle HTTP Range requests
  Future<shelf.Response> _serveRangeRequest(
      File file, int fileLength, String rangeHeader) async {
    try {
      // Parse range header: "bytes=0-1023" or "bytes=1024-"
      final rangeMatch = RegExp(r'bytes=(\d+)-(\d*)').firstMatch(rangeHeader);

      if (rangeMatch == null) {
        return shelf.Response(416, body: 'Invalid range header');
      }

      final start = int.parse(rangeMatch.group(1)!);
      final endStr = rangeMatch.group(2);
      final end = endStr != null && endStr.isNotEmpty
          ? int.parse(endStr)
          : fileLength - 1;

      if (start >= fileLength || end >= fileLength || start > end) {
        return shelf.Response(416,
            headers: {'Content-Range': 'bytes */$fileLength'},
            body: 'Range not satisfiable');
      }

      final length = end - start + 1;

      // Read only the requested byte range
      final randomAccessFile = await file.open();
      await randomAccessFile.setPosition(start);
      final bytes = await randomAccessFile.read(length);
      await randomAccessFile.close();

      print('Serving range: $start-$end/$fileLength ($length bytes)');

      return shelf.Response(
        206, // 206 Partial Content
        body: bytes,
        headers: {
          'Content-Type': 'image/tiff',
          'Content-Length': length.toString(),
          'Content-Range': 'bytes $start-$end/$fileLength',
          'Accept-Ranges': 'bytes',
          'Access-Control-Allow-Origin': '*',
        },
      );
    } catch (e) {
      print('Error serving range request: $e');
      return shelf.Response.internalServerError(
          body: 'Error serving range: ${e.toString()}');
    }
  }

  Future<shelf.Response> _serveFile(String sanitizedPath,
      {bool isWebApp = false}) async {
    if (sanitizedPath.contains('..')) {
      return shelf.Response.forbidden('Invalid path');
    }

    final filePath = isWebApp
        ? path.join(persistentOfflineDataDirectory, WEBAPP_PATH, sanitizedPath)
        : path.join(persistentOfflineDataDirectory, sanitizedPath);

    print('Attempting to serve file from: $filePath');
    final file = File(filePath);

    if (await file.exists()) {
      String mimeType;
      if (filePath.endsWith('.js')) {
        mimeType = 'application/javascript';
      } else if (filePath.endsWith('.css')) {
        mimeType = 'text/css';
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
      } else if (filePath.endsWith('.geojson')) {
        mimeType = 'application/geo+json';
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

  // FIX: Serve index.html from root webapp directory, not container
  Future<shelf.Response> _serveIndexHtml() async {
    // CHANGED: Always serve from root webapp directory
    final indexPath =
        path.join(persistentOfflineDataDirectory, WEBAPP_PATH, 'index.html');
    print('Serving index.html from: $indexPath');

    final indexFile = File(indexPath);
    if (await indexFile.exists()) {
      return shelf.Response.ok(
        await indexFile.readAsString(),
        headers: {
          'Content-Type': 'text/html',
          'Cache-Control': 'max-age=3600',
          'Access-Control-Allow-Origin': '*',
        },
      );
    }

    print('Index file not found at: $indexPath');
    return shelf.Response.notFound('Index file not found');
  }

  void stop() {
    _server?.close();
  }
}
