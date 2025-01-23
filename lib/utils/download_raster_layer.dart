import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

class RasterLayerDownloader {
  bool cancelRasterDownload = false;
  final Function(double) onProgressUpdate;
  final String geoserverUrl = 'https://geoserver.core-stack.org:8443/geoserver';

  RasterLayerDownloader({required this.onProgressUpdate});

  Future<void> downloadRasterLayer(
      String workspace,
      String layerName,
      String styleName,
      String containerName) async {
    try {
      if (cancelRasterDownload) {
        onProgressUpdate(-1.0);
        return;
      }

      final url = '$geoserverUrl/$workspace/wcs?service=WCS&version=2.0.1'
          '&request=GetCoverage&coverageId=$layerName'
          '&format=image/geotiff';

      print("Downloading raster layer from URL: $url");

      final request = await http.Client().send(http.Request('GET', Uri.parse(url)));
      
      if (request.statusCode == 200) {
        final directory = await getApplicationDocumentsDirectory();
        final containerPath = '${directory.path}/persistent_offline_data/containers/$containerName';
        final filePath = '$containerPath/raster_layers/$layerName.tiff';
        print("Saving raster layer to: $filePath");

        final file = File(filePath);
        await file.create(recursive: true);

        final totalBytes = request.contentLength ?? 0;
        var receivedBytes = 0;

        final sink = file.openWrite();
        await request.stream.listen(
          (List<int> chunk) {
            if (cancelRasterDownload) {
              sink.close();
              file.delete();
              onProgressUpdate(-1.0);
              return;
            }
            receivedBytes += chunk.length;
            sink.add(chunk);
            if (totalBytes > 0) {
              final progress = receivedBytes / totalBytes;
              onProgressUpdate(progress);
            }
          },
          onDone: () async {
            await sink.close();
            onProgressUpdate(1.0);
            print("Raster layer download completed: $layerName");
          },
          onError: (error) {
            print("Error downloading raster layer: $error");
            sink.close();
            file.delete();
            onProgressUpdate(-1.0);
          },
          cancelOnError: true,
        ).asFuture(); // Convert the StreamSubscription to a Future
      } else {
        print("Failed to download raster layer. Status code: ${request.statusCode}");
        onProgressUpdate(-1.0);
      }
    } catch (e) {
      print("Error downloading raster layer: $e");
      onProgressUpdate(-1.0);
    }
  }

  void cancelDownload() {
    cancelRasterDownload = true;
  }
}
