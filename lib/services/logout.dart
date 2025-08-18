import 'package:flutter/material.dart';
import 'login_service.dart';

class LogoutService {
  static final LoginService _loginService = LoginService();

  static Future<void> showLogoutConfirmationDialog(BuildContext context) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20.0),
          ),
          child: Container(
            width: MediaQuery.of(context).size.width * 0.85,
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Logout',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Do you want to Logout?',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    // Cancel Button with border
                    Expanded(
                      child: TextButton(
                        style: TextButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: const Color(0xFF592941),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(25.0),
                            side: const BorderSide(
                              color: Color(0xFF592941),
                              width: 2.0,
                            ),
                          ),
                        ),
                        child: const Text(
                          'Cancel',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        onPressed: () {
                          Navigator.of(context).pop();
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    // Logout Button - more rounded
                    Expanded(
                      child: TextButton(
                        style: TextButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(25.0),
                          ),
                        ),
                        child: const Text(
                          'Logout',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        onPressed: () async {
                          Navigator.of(context).pop(); // Close dialog
                          await performLogout(context);
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  static Future<void> performLogout(BuildContext context) async {
    // Store multiple references for better reliability
    final navigator = Navigator.of(context);
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    bool dialogShown = false;

    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext dialogContext) {
          dialogShown = true;
          return WillPopScope(
            onWillPop: () async => false,
            child: const AlertDialog(
              backgroundColor: Colors.white,
              surfaceTintColor: Colors.transparent,
              content: Padding(
                padding: EdgeInsets.all(20.0),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(width: 20),
                    Text(
                      'Logging out...',
                      style: TextStyle(color: Colors.black87),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );

      print('Starting logout process...');

      await Future.any([
        _loginService.logout(),
        Future.delayed(const Duration(seconds: 8), () {
          throw Exception('Logout timeout - please check your connection');
        }),
      ]);

      print('Logout completed successfully');
    } catch (e) {
      print('Logout error: $e');
      await _loginService.clearStoredCredentials();
    }

    try {
      if (dialogShown) {
        navigator.pop();
        print('Dialog closed');
      }
    } catch (e) {
      print('Error closing dialog: $e');
    }

    await Future.delayed(const Duration(milliseconds: 300));

    try {
      print('Attempting navigation to login screen...');

      await navigator.pushNamedAndRemoveUntil(
        '/login',
        (Route<dynamic> route) => false,
      );

      print('Navigation successful');

      // Show success message
      try {
        scaffoldMessenger.showSnackBar(
          const SnackBar(
            content: Text('Logged out successfully'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      } catch (e) {
        print('Error showing snackbar: $e');
      }
    } catch (e) {
      print('Navigation error: $e');

      // Fallback: Try alternative navigation method
      try {
        print('Trying fallback navigation...');

        // Clear the entire navigation stack and push login
        await navigator.pushReplacementNamed('/login');

        print('Fallback navigation successful');
      } catch (fallbackError) {
        print('Fallback navigation also failed: $fallbackError');

        // Last resort: Show error message and let user manually navigate
        try {
          scaffoldMessenger.showSnackBar(
            const SnackBar(
              content: Text('Logged out. Please restart the app.'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 5),
            ),
          );
        } catch (e) {
          print('Error showing fallback snackbar: $e');
        }
      }
    }
  }
}
