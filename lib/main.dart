import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import './splash/splash_screen.dart';
import 'location_selection.dart';
import './utils/offline_asset.dart';
import './server/local_server.dart';

// Global variable to store the server URL
String? globalServerUrl;

Future<void> initializeApp() async {
  WidgetsFlutterBinding.ensureInitialized();
  await OfflineAssetsManager.copyOfflineAssets();

  // Get the persistent offline data path
  final directory = await getApplicationDocumentsDirectory();
  final persistentOfflineDataPath =
      path.join(directory.path, 'persistent_offline_data');
  print('Persistent offline path in main: $persistentOfflineDataPath');

  await OfflineAssetsManager.copyOfflineAssets();

  // Start the local server
  final localServer = LocalServer(persistentOfflineDataPath);
  globalServerUrl = await localServer.start();

  print('Local server started at anki: $globalServerUrl');
}

void main() async {
  await initializeApp();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      initialRoute: '/',
      routes: {
        '/': (context) => const SplashScreen(),
        '/location': (context) => const LocationSelection(),
      },
    );
  }
}
