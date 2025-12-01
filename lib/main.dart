import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import './l10n/app_localizations.dart';

import './splash/splash_screen.dart';
import 'location_selection.dart';
import './ui/login_screen.dart';
import './utils/offline_asset.dart';
import './services/language_service.dart';

// Global ValueNotifier for locale changes
ValueNotifier<Locale> localeNotifier = ValueNotifier(const Locale('hi'));

Future<void> checkLocationPermission(BuildContext context) async {
  LocationPermission permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.denied) {
    permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.denied) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Location permissions are required for this app'),
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  if (permission == LocationPermission.deniedForever) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
            'Location permissions are permanently denied. Please enable them in settings.'),
        duration: Duration(seconds: 3),
      ),
    );
    await Geolocator.openAppSettings();
  }
}

Future<void> initializeApp() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load saved language preference
  final languageService = LanguageService();
  final savedLanguage = await languageService.getLanguage();
  localeNotifier.value = Locale(savedLanguage);

  // Copy offline assets (webapp, etc.) to device storage
  await OfflineAssetsManager.copyOfflineAssets(forceUpdate: true);
  print('Finished copying offline assets');
}

void main() async {
  await initializeApp();
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Locale>(
      valueListenable: localeNotifier,
      builder: (context, locale, child) {
        return MaterialApp(
          locale: locale,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [
            Locale('en'), // English
            Locale('hi'), // Hindi
          ],
          debugShowCheckedModeBanner: false,
          initialRoute: '/',
          routes: {
            '/': (context) => const LocationAwareApp(),
            '/login': (context) => const LoginScreen(),
            '/location': (context) => const LocationSelection(),
          },
        );
      },
    );
  }
}

class LocationAwareApp extends StatefulWidget {
  const LocationAwareApp({super.key});

  @override
  State<LocationAwareApp> createState() => _LocationAwareAppState();
}

class _LocationAwareAppState extends State<LocationAwareApp> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      checkLocationPermission(context);
    });
  }

  @override
  Widget build(BuildContext context) {
    return const SplashScreen();
  }
}
