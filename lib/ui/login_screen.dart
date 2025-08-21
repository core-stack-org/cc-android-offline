import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import '../location_selection.dart';
import '../services/login_service.dart';
import '../main.dart';

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
  bool _isFormValid = false;
  String _selectedLanguage = 'hi';

  @override
  void initState() {
    super.initState();
    _setupFormValidation();
  }

  void _setupFormValidation() {
    _usernameController.addListener(_validateForm);
    _passwordController.addListener(_validateForm);
  }

  void _validateForm() {
    final username = _usernameController.text.trim();
    final isValid =
        username.isNotEmpty && _passwordController.text.trim().isNotEmpty;

    if (isValid != _isFormValid) {
      setState(() {
        _isFormValid = isValid;
      });
    }
  }

  @override
  void dispose() {
    _usernameController.removeListener(_validateForm);
    _passwordController.removeListener(_validateForm);
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  String _normalizePhoneNumber(String input) {
    String cleaned = input.replaceAll(RegExp(r'[\s\-\(\)]'), '');

    if (cleaned.startsWith('+')) {
      cleaned = cleaned.substring(1);

      if (cleaned.startsWith('91') && cleaned.length == 12) {
        return cleaned.substring(2);
      }
    }
    return cleaned;
  }

  bool _isPhoneNumber(String input) {
    // Check if input contains any digits and looks like a phone number
    String cleaned = input.replaceAll(RegExp(r'[\s\-\(\)+]'), '');
    // If it contains digits and is mostly numeric, treat as phone number
    return RegExp(r'^[0-9]+$').hasMatch(cleaned) && cleaned.length >= 6;
  }

  Future<void> _performLogin() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      HapticFeedback.mediumImpact();

      final rawUsername = _usernameController.text.trim();
      // Only normalize if it's a phone number, otherwise use as-is
      final username = _isPhoneNumber(rawUsername)
          ? _normalizePhoneNumber(rawUsername)
          : rawUsername;

      print('Original Username: $rawUsername');
      print('Is Phone Number: ${_isPhoneNumber(rawUsername)}');
      print('Final Username: $username');
      print('Timestamp: ${DateTime.now()}');

      try {
        final success = await _loginService.login(
          username,
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
              pageBuilder: (context, animation, secondaryAnimation) =>
                  LocationSelection(selectedLanguage: _selectedLanguage),
              transitionDuration: const Duration(milliseconds: 300),
              transitionsBuilder:
                  (context, animation, secondaryAnimation, child) {
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
        } else {
          print('=== LOGIN FAILED - SHOWING ERROR ===');
          print('Success value was: $success');
          setState(() {
            _errorMessage =
                AppLocalizations.of(context)!.invalidUsernameOrPassword;
          });
        }
      } catch (e) {
        print('=== LOGIN ERROR ===');
        print('Error details: $e');
        print('Error type: ${e.runtimeType}');
        setState(() {
          _errorMessage = AppLocalizations.of(context)!.networkErrorMessage;
        });
      } finally {
        print('=== LOGIN ATTEMPT COMPLETED ===');
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  }

  Widget _buildLanguageSelector() {
    return Center(
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedLanguage,
          onChanged: (String? newValue) {
            if (newValue != null) {
              setState(() {
                _selectedLanguage = newValue;
              });
              localeNotifier.value = Locale(newValue);
              HapticFeedback.lightImpact();
            }
          },
          dropdownColor: Colors.white,
          borderRadius: BorderRadius.circular(12),
          items: [
            DropdownMenuItem(
              value: 'hi',
              child: Text(
                AppLocalizations.of(context)!.hindi,
                style: const TextStyle(
                  color: Color(0xFF592941),
                  fontSize: 16,
                ),
              ),
            ),
            DropdownMenuItem(
              value: 'en',
              child: Text(
                AppLocalizations.of(context)!.english,
                style: const TextStyle(
                  color: Color(0xFF592941),
                  fontSize: 16,
                ),
              ),
            ),
          ],
          icon: const Icon(
            Icons.arrow_drop_down,
            color: Color(0xFF592941),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFCF4E9),
      appBar: AppBar(
        automaticallyImplyLeading: false,
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
                  AppLocalizations.of(context)!.loginTitle,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: const Color(0xFF592941),
                      ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                TextFormField(
                  controller: _usernameController,
                  decoration: InputDecoration(
                    labelText:
                        AppLocalizations.of(context)!.usernameOrPhoneNumber,
                    hintText:
                        AppLocalizations.of(context)!.usernameOrPhoneNumberHint,
                    prefixIcon: const Icon(Icons.person_outline),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12.0),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12.0),
                      borderSide: const BorderSide(
                          color: Color(0xFFD6D4C8), width: 2.0),
                    ),
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.7),
                  ),
                  keyboardType: TextInputType.text,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return AppLocalizations.of(context)!
                          .pleaseEnterUsernameOrPhoneNumber;
                    }

                    // Only apply phone number validation if input looks like a phone number
                    if (_isPhoneNumber(value)) {
                      final normalizedPhone = _normalizePhoneNumber(value);
                      if (normalizedPhone.isEmpty) {
                        return AppLocalizations.of(context)!
                            .pleaseEnterValidPhoneNumber;
                      }

                      if (normalizedPhone.length < 10) {
                        return AppLocalizations.of(context)!
                            .phoneNumberShouldBeAtLeast10Digits;
                      }
                    }
                    // For username (non-numeric input), no additional validation needed

                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _passwordController,
                  decoration: InputDecoration(
                    labelText: AppLocalizations.of(context)!.password,
                    hintText: AppLocalizations.of(context)!.passwordHint,
                    prefixIcon: const Icon(Icons.lock_outline),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12.0),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12.0),
                      borderSide: const BorderSide(
                          color: Color(0xFFD6D4C8), width: 2.0),
                    ),
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.7),
                  ),
                  obscureText: true,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return AppLocalizations.of(context)!.pleaseEnterPassword;
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                _buildLanguageSelector(),
                const SizedBox(height: 16),
                if (_errorMessage != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10.0),
                    child: Text(
                      _errorMessage!,
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                          fontSize: 14),
                      textAlign: TextAlign.center,
                    ),
                  ),
                const SizedBox(height: 16),
                _isLoading
                    ? Center(
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(
                              const Color(0xFF592941)),
                        ),
                      )
                    : Center(
                        child: SizedBox(
                          width: 200,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _isFormValid
                                  ? const Color(0xFFD6D4C8)
                                  : Colors.grey.shade300,
                              foregroundColor: _isFormValid
                                  ? const Color(0xFF592941)
                                  : Colors.grey.shade500,
                              minimumSize: const Size(200, 50),
                              padding:
                                  const EdgeInsets.symmetric(vertical: 16.0),
                              textStyle: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.5),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20.0),
                              ),
                              elevation: _isFormValid ? 1 : 0,
                            ).copyWith(
                              overlayColor:
                                  MaterialStateProperty.resolveWith<Color?>(
                                (Set<MaterialState> states) {
                                  if (states.contains(MaterialState.pressed) &&
                                      _isFormValid) {
                                    return const Color(0xFFC0BFB2);
                                  }
                                  return null;
                                },
                              ),
                            ),
                            onPressed: _isFormValid ? _performLogin : null,
                            child: Text(AppLocalizations.of(context)!.login),
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
