import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Required for HapticFeedback
import '../location_selection.dart';
import '../services/login_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  static const String routeName = '/login';

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final LoginService _loginService = LoginService();
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _checkExistingLogin();
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // Check if user is already logged in
  Future<void> _checkExistingLogin() async {
    final isLoggedIn = await _loginService.isLoggedIn();
    if (isLoggedIn && mounted) {
      print('User already logged in, navigating to location selection');
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) => const LocationSelection(),
          transitionDuration: const Duration(milliseconds: 300),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            const begin = Offset(1.0, 0.0);
            const end = Offset.zero;
            const curve = Curves.ease;

            var tween = Tween(begin: begin, end: end).chain(
              CurveTween(curve: curve),
            );

            return SlideTransition(
              position: animation.drive(tween),
              child: child,
            );
          },
        ),
      );
    }
  }

  Future<void> _performLogin() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      // Haptic feedback for button press
      HapticFeedback.mediumImpact();

      print('=== LOGIN ATTEMPT STARTED ===');
      print('Username: ${_usernameController.text}');
      print('Timestamp: ${DateTime.now()}');

      try {
        print('=== CALLING LOGIN SERVICE ===');
        final success = await _loginService.login(
          _usernameController.text,
          _passwordController.text,
        );

        print('=== LOGIN SERVICE RETURNED ===');
        print('Login result: $success');
        print('Login result type: ${success.runtimeType}');

        if (success == true) {
          print('=== LOGIN SUCCESSFUL - NAVIGATING ===');
          // Navigate to LocationSelectionScreen with slide animation
          Navigator.of(context).pushReplacement(
            PageRouteBuilder(
              pageBuilder: (context, animation, secondaryAnimation) => const LocationSelection(),
              transitionDuration: const Duration(milliseconds: 300),
              transitionsBuilder: (context, animation, secondaryAnimation, child) {
                const begin = Offset(1.0, 0.0); // Start from right
                const end = Offset.zero; // End at current position
                const curve = Curves.ease;

                var tween = Tween(begin: begin, end: end).chain(
                  CurveTween(curve: curve),
                );

                return SlideTransition(
                  position: animation.drive(tween),
                  child: child,
                );
              },
            ),
          );
        } else {
          print('=== LOGIN FAILED - SHOWING ERROR ===');
          print('Success value was: $success');
          setState(() {
            _errorMessage = 'Invalid username or password. Please try again.';
          });
        }
      } catch (e) {
        print('=== LOGIN ERROR ===');
        print('Error details: $e');
        print('Error type: ${e.runtimeType}');
        setState(() {
          _errorMessage = 'Network error. Please check your connection and try again.';
        });
      } finally {
        print('=== LOGIN ATTEMPT COMPLETED ===');
        // Ensure loading state is reset even if widget is disposed during async operation
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFCF4E9),
      appBar: AppBar(
        automaticallyImplyLeading: false, // No back button to splash
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: const TextStyle(
          color: Color(0xFF592941),
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Hero(
                  tag: 'logo_image',
                  child: Container(
                    padding: const EdgeInsets.only(bottom: 32.0),
                    alignment: Alignment.center,
                    child: Image.asset(
                      'assets/cc.png',
                      height: 100,
                    ),
                  ),
                ),

                const SizedBox(height: 8),
                Text(
                  'Please login to continue',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: const Color(0xFF592941),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                TextFormField(
                  controller: _usernameController,
                  decoration: InputDecoration(
                    labelText: 'Username',
                    hintText: 'Enter your username',
                    prefixIcon: const Icon(Icons.person_outline),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12.0),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12.0),
                      borderSide: const BorderSide(color: Color(0xFFD6D4C8), width: 2.0),
                    ),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.7),
                  ),
                  keyboardType: TextInputType.text,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your username';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _passwordController,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    hintText: 'Enter your password',
                    prefixIcon: const Icon(Icons.lock_outline),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12.0),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12.0),
                      borderSide: const BorderSide(color: Color(0xFFD6D4C8), width: 2.0),
                    ),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.7),
                  ),
                  obscureText: true,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your password';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                if (_errorMessage != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10.0),
                    child: Text(
                      _errorMessage!,
                      style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 14),
                      textAlign: TextAlign.center,
                    ),
                  ),
                const SizedBox(height: 16),
                _isLoading
                    ? Center(
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(const Color(0xFF592941)),
                        ),
                      )
                    : Center(
                        child: SizedBox(
                          width: 200, // Fixed width instead of full width
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFD6D4C8),
                              foregroundColor: const Color(0xFF592941),
                              minimumSize: const Size(200, 50),
                              padding: const EdgeInsets.symmetric(vertical: 16.0),
                              textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, letterSpacing: 0.5),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20.0),
                              ),
                              elevation: 1,
                            ).copyWith(
                              overlayColor: MaterialStateProperty.resolveWith<Color?>(
                                (Set<MaterialState> states) {
                                  if (states.contains(MaterialState.pressed)) {
                                    return const Color(0xFFC0BFB2);
                                  }
                                  return null;
                                },
                              ),
                            ),
                            onPressed: _performLogin,
                            child: const Text('Login'),
                          ),
                        ),
                      ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}