import 'package:flutter/material.dart';
import 'dart:async';
import '../services/login_service.dart';
import '../location_selection.dart';
import '../ui/login_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  SplashScreenState createState() => SplashScreenState();
}

class SplashScreenState extends State<SplashScreen> {
  final LoginService _loginService = LoginService();

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    // Wait for the splash screen duration
    await Future.delayed(const Duration(seconds: 2));

    if (!mounted) return;

    // Check if user is already logged in
    try {
      final isLoggedIn = await _loginService.isLoggedIn();

      if (!mounted) return;

      if (isLoggedIn) {
        print('User already logged in, navigating to location selection');
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => const LocationSelection(),
          ),
        );
      } else {
        print('User not logged in, navigating to login screen');
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => const LoginScreen(),
          ),
        );
      }
    } catch (e) {
      print('Error checking login status: $e');
      // On error, navigate to login screen
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => const LoginScreen(),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFCF4E9),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset('assets/cc.png'),
          ],
        ),
      ),
    );
  }
}
