import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/login_service.dart';
import '../services/cache_service.dart';
import '../ui/login_screen.dart';
import '../l10n/app_localizations.dart';

class ProfileStatsScreen extends StatefulWidget {
  const ProfileStatsScreen({Key? key}) : super(key: key);

  @override
  State<ProfileStatsScreen> createState() => _ProfileStatsScreenState();
}

class _ProfileStatsScreenState extends State<ProfileStatsScreen> {
  final LoginService _loginService = LoginService();
  final CacheService _cacheService = CacheService();
  Map<String, dynamic>? _userData;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    try {
      final userData = await _loginService.getUserData();
      setState(() {
        _userData = userData;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading user data: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Widget _buildInfoCard({
    required String title,
    required String value,
    required IconData icon,
  }) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16.0),
      ),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10.0),
              decoration: BoxDecoration(
                color: const Color(0xFFD6D4C8).withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(12.0),
              ),
              child: Icon(
                icon,
                color: const Color(0xFF592941),
                size: 22,
              ),
            ),
            const SizedBox(width: 16.0),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4.0),
                  Text(
                    value.isNotEmpty
                        ? value
                        : AppLocalizations.of(context)!.notSpecified,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNameCard() {
    if (_userData == null) return const SizedBox.shrink();

    final firstName = _userData!['first_name'] as String? ?? '';
    final lastName = _userData!['last_name'] as String? ?? '';
    final username = _userData!['username'] as String? ?? '';
    final fullName =
        '${firstName.isNotEmpty ? firstName : ''} ${lastName.isNotEmpty ? lastName : ''}'
            .trim();

    return Column(
      children: [
        const SizedBox(height: 24.0),
        Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: const Color(0xFFD6D4C8),
              width: 4.0,
            ),
          ),
          child: CircleAvatar(
            radius: 50,
            backgroundColor: const Color(0xFFD6D4C8).withValues(alpha: 0.5),
            child: Icon(
              Icons.person,
              size: 50,
              color: const Color(0xFF592941).withValues(alpha: 0.9),
            ),
          ),
        ),
        const SizedBox(height: 16.0),
        Text(
          fullName.isNotEmpty ? fullName : '@$username',
          style: const TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.bold,
            color: Color(0xFF592941),
          ),
          textAlign: TextAlign.center,
        ),
        if (fullName.isNotEmpty && username.isNotEmpty) ...[
          const SizedBox(height: 4.0),
          Text(
            '@$username',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[700],
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
        const SizedBox(height: 24.0),
      ],
    );
  }

  String _getProjectsText() {
    if (_userData == null)
      return AppLocalizations.of(context)!.noProjectsAssigned;

    final projectDetails = _userData!['project_details'] as List?;
    if (projectDetails == null || projectDetails.isEmpty) {
      return AppLocalizations.of(context)!.noProjectsAssigned;
    }

    return projectDetails
        .map((project) =>
            project['project_name'] as String? ??
            AppLocalizations.of(context)!.unknownProject)
        .join(', ');
  }

  String _getRolesText() {
    if (_userData == null) return AppLocalizations.of(context)!.noRolesAssigned;

    final groups = _userData!['groups'] as List?;
    if (groups == null || groups.isEmpty) {
      return AppLocalizations.of(context)!.noRolesAssigned;
    }

    return groups.map((group) => group['name']).join(', ');
  }

  void _showChangePasswordDialog() {
    final oldPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    bool obscureOldPassword = true;
    bool obscureNewPassword = true;
    bool obscureConfirmPassword = true;
    bool isLoading = false;
    String? errorMessage;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return WillPopScope(
          onWillPop: () async => !isLoading,
          child: StatefulBuilder(
            builder: (context, setState) {
              return Dialog(
                backgroundColor: Colors.white,
                surfaceTintColor: Colors.transparent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20.0),
                ),
                insetPadding: const EdgeInsets.symmetric(
                    horizontal: 24.0, vertical: 24.0),
                child: SingleChildScrollView(
                  child: Container(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          AppLocalizations.of(context)!.changePassword,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w600,
                            color: Colors.black,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.orange.shade200),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.info_outline,
                                color: Colors.orange.shade700,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  AppLocalizations.of(context)!
                                      .youWillBeLoggedOut,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.orange.shade900,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        TextField(
                          controller: oldPasswordController,
                          obscureText: obscureOldPassword,
                          decoration: InputDecoration(
                            labelText:
                                AppLocalizations.of(context)!.currentPassword,
                            prefixIcon: const Icon(Icons.lock_outline),
                            suffixIcon: IconButton(
                              icon: Icon(
                                obscureOldPassword
                                    ? Icons.visibility_off
                                    : Icons.visibility,
                              ),
                              onPressed: () {
                                setState(() {
                                  obscureOldPassword = !obscureOldPassword;
                                });
                              },
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: newPasswordController,
                          obscureText: obscureNewPassword,
                          decoration: InputDecoration(
                            labelText:
                                AppLocalizations.of(context)!.newPassword,
                            prefixIcon: const Icon(Icons.lock),
                            suffixIcon: IconButton(
                              icon: Icon(
                                obscureNewPassword
                                    ? Icons.visibility_off
                                    : Icons.visibility,
                              ),
                              onPressed: () {
                                setState(() {
                                  obscureNewPassword = !obscureNewPassword;
                                });
                              },
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            helperText: AppLocalizations.of(context)!
                                .minPasswordRequirements,
                            helperStyle: const TextStyle(fontSize: 11),
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: confirmPasswordController,
                          obscureText: obscureConfirmPassword,
                          decoration: InputDecoration(
                            labelText: AppLocalizations.of(context)!
                                .confirmNewPassword,
                            prefixIcon: const Icon(Icons.lock),
                            suffixIcon: IconButton(
                              icon: Icon(
                                obscureConfirmPassword
                                    ? Icons.visibility_off
                                    : Icons.visibility,
                              ),
                              onPressed: () {
                                setState(() {
                                  obscureConfirmPassword =
                                      !obscureConfirmPassword;
                                });
                              },
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                        if (errorMessage != null) ...[
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.red.shade50,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.red.shade200),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.error_outline,
                                  color: Colors.red.shade700,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    errorMessage!,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.red.shade900,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: 24),
                        Row(
                          children: [
                            Expanded(
                              child: TextButton(
                                style: TextButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  foregroundColor: const Color(0xFF592941),
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(25.0),
                                    side: const BorderSide(
                                      color: Color(0xFF592941),
                                      width: 2.0,
                                    ),
                                  ),
                                ),
                                onPressed: isLoading
                                    ? null
                                    : () {
                                        Navigator.of(dialogContext).pop();
                                      },
                                child: Text(
                                  AppLocalizations.of(context)!.cancel,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: TextButton(
                                style: TextButton.styleFrom(
                                  backgroundColor: const Color(0xFF592941),
                                  foregroundColor: Colors.white,
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(25.0),
                                  ),
                                ),
                                onPressed: isLoading
                                    ? null
                                    : () async {
                                        setState(() {
                                          errorMessage = null;
                                          isLoading = true;
                                        });

                                        final oldPassword =
                                            oldPasswordController.text;
                                        final newPassword =
                                            newPasswordController.text;
                                        final confirmPassword =
                                            confirmPasswordController.text;

                                        if (oldPassword.isEmpty ||
                                            newPassword.isEmpty ||
                                            confirmPassword.isEmpty) {
                                          setState(() {
                                            errorMessage =
                                                AppLocalizations.of(context)!
                                                    .allFieldsRequired;
                                            isLoading = false;
                                          });
                                          return;
                                        }

                                        if (newPassword != confirmPassword) {
                                          setState(() {
                                            errorMessage =
                                                AppLocalizations.of(context)!
                                                    .newPasswordsDoNotMatch;
                                            isLoading = false;
                                          });
                                          return;
                                        }

                                        if (newPassword.length < 8) {
                                          setState(() {
                                            errorMessage =
                                                AppLocalizations.of(context)!
                                                    .passwordMustBeAtLeast8;
                                            isLoading = false;
                                          });
                                          return;
                                        }

                                        if (!RegExp(
                                                r'^(?=.*[A-Za-z])(?=.*\d)(?=.*[@$!%*#?&])')
                                            .hasMatch(newPassword)) {
                                          setState(() {
                                            errorMessage = AppLocalizations.of(
                                                    context)!
                                                .passwordMustContainLettersNumbersSpecial;
                                            isLoading = false;
                                          });
                                          return;
                                        }

                                        try {
                                          final response = await _loginService
                                              .makeAuthenticatedRequest(
                                            'users/change_password/',
                                            method: 'POST',
                                            body: {
                                              'old_password': oldPassword,
                                              'new_password': newPassword,
                                              'new_password_confirm':
                                                  confirmPassword,
                                            },
                                          );

                                          if (response == null) {
                                            setState(() {
                                              errorMessage =
                                                  AppLocalizations.of(context)!
                                                      .networkErrorOccurred;
                                              isLoading = false;
                                            });
                                            return;
                                          }

                                          if (response.statusCode == 200) {
                                            Navigator.of(dialogContext).pop();
                                            await _showSuccessDialog();
                                          } else if (response.statusCode ==
                                              400) {
                                            setState(() {
                                              errorMessage =
                                                  AppLocalizations.of(context)!
                                                      .invalidCurrentPassword;
                                              isLoading = false;
                                            });
                                          } else if (response.statusCode ==
                                              401) {
                                            setState(() {
                                              errorMessage =
                                                  AppLocalizations.of(context)!
                                                      .currentPasswordIncorrect;
                                              isLoading = false;
                                            });
                                          } else {
                                            setState(() {
                                              errorMessage =
                                                  AppLocalizations.of(context)!
                                                      .failedToChangePassword;
                                              isLoading = false;
                                            });
                                          }
                                        } catch (e) {
                                          setState(() {
                                            errorMessage =
                                                'An error occurred: ${e.toString()}';
                                            isLoading = false;
                                          });
                                        }
                                      },
                                child: isLoading
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                                  Colors.white),
                                        ),
                                      )
                                    : Text(
                                        AppLocalizations.of(context)!
                                            .changePassword,
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    ).then((_) {
      oldPasswordController.dispose();
      newPasswordController.dispose();
      confirmPasswordController.dispose();
    });
  }

  Future<void> _showSuccessDialog() async {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20.0),
          ),
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 24.0, vertical: 24.0),
          child: Container(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.check_circle,
                  color: Colors.green.shade600,
                  size: 48,
                ),
                const SizedBox(height: 16),
                Text(
                  AppLocalizations.of(context)!.passwordChanged,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  AppLocalizations.of(context)!.passwordUpdatedSuccessfully,
                  style: const TextStyle(
                    fontSize: 16,
                    color: Colors.black87,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.orange.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: Colors.orange.shade700,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          AppLocalizations.of(context)!
                              .youWillBeLoggedOutPleaseLogin,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.orange.shade900,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    style: TextButton.styleFrom(
                      backgroundColor: const Color(0xFF592941),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(25.0),
                      ),
                    ),
                    onPressed: () async {
                      await _loginService.clearStoredCredentials();
                      if (mounted) {
                        Navigator.of(context).pushAndRemoveUntil(
                          MaterialPageRoute(
                            builder: (context) => const LoginScreen(),
                          ),
                          (route) => false,
                        );
                      }
                    },
                    child: Text(
                      AppLocalizations.of(context)!.ok,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showClearCacheDialog() {
    bool isLoading = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return WillPopScope(
          onWillPop: () async => !isLoading,
          child: StatefulBuilder(
            builder: (context, setState) {
              return Dialog(
                backgroundColor: Colors.white,
                surfaceTintColor: Colors.transparent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20.0),
                ),
                insetPadding: const EdgeInsets.symmetric(
                    horizontal: 24.0, vertical: 24.0),
                child: Container(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        AppLocalizations.of(context)!.clearCacheTitle,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w600,
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        AppLocalizations.of(context)!.clearCacheMessage,
                        style: const TextStyle(
                          fontSize: 16,
                          color: Colors.black87,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.orange.shade200),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.info_outline,
                              color: Colors.orange.shade700,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                AppLocalizations.of(context)!
                                    .thisActionCannotBeUndone,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.orange.shade900,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          Expanded(
                            child: TextButton(
                              style: TextButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: const Color(0xFF592941),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(25.0),
                                  side: const BorderSide(
                                    color: Color(0xFF592941),
                                    width: 2.0,
                                  ),
                                ),
                              ),
                              onPressed: isLoading
                                  ? null
                                  : () {
                                      Navigator.of(dialogContext).pop();
                                    },
                              child: Text(
                                AppLocalizations.of(context)!.cancel,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: TextButton(
                              style: TextButton.styleFrom(
                                backgroundColor: const Color(0xFF592941),
                                foregroundColor: Colors.white,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(25.0),
                                ),
                              ),
                              onPressed: isLoading
                                  ? null
                                  : () async {
                                      setState(() {
                                        isLoading = true;
                                      });

                                      try {
                                        final success = await _cacheService
                                            .clearAllWebViewData();

                                        if (success) {
                                          Navigator.of(dialogContext).pop();
                                          if (mounted) {
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(
                                              SnackBar(
                                                content: Row(
                                                  children: [
                                                    const Icon(
                                                      Icons.check_circle,
                                                      color: Colors.white,
                                                    ),
                                                    const SizedBox(width: 12),
                                                    Expanded(
                                                      child: Text(
                                                        AppLocalizations.of(
                                                                context)!
                                                            .cacheClearedSuccessfully,
                                                        style: const TextStyle(
                                                          fontSize: 15,
                                                          fontWeight:
                                                              FontWeight.w500,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                backgroundColor: Colors.green,
                                                behavior:
                                                    SnackBarBehavior.floating,
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(10),
                                                ),
                                                duration:
                                                    const Duration(seconds: 3),
                                              ),
                                            );
                                          }
                                        } else {
                                          setState(() {
                                            isLoading = false;
                                          });
                                          if (mounted) {
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(
                                              SnackBar(
                                                content: Row(
                                                  children: [
                                                    const Icon(
                                                      Icons.error_outline,
                                                      color: Colors.white,
                                                    ),
                                                    const SizedBox(width: 12),
                                                    Expanded(
                                                      child: Text(
                                                        AppLocalizations.of(
                                                                context)!
                                                            .failedToClearCache,
                                                        style: const TextStyle(
                                                          fontSize: 15,
                                                          fontWeight:
                                                              FontWeight.w500,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                backgroundColor: Colors.red,
                                                behavior:
                                                    SnackBarBehavior.floating,
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(10),
                                                ),
                                                duration:
                                                    const Duration(seconds: 3),
                                              ),
                                            );
                                          }
                                        }
                                      } catch (e) {
                                        setState(() {
                                          isLoading = false;
                                        });
                                        if (mounted) {
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(
                                            SnackBar(
                                              content: Row(
                                                children: [
                                                  const Icon(
                                                    Icons.error_outline,
                                                    color: Colors.white,
                                                  ),
                                                  const SizedBox(width: 12),
                                                  Expanded(
                                                    child: Text(
                                                      'Error: ${e.toString()}',
                                                      style: const TextStyle(
                                                        fontSize: 15,
                                                        fontWeight:
                                                            FontWeight.w500,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              backgroundColor: Colors.red,
                                              behavior:
                                                  SnackBarBehavior.floating,
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                              ),
                                              duration:
                                                  const Duration(seconds: 3),
                                            ),
                                          );
                                        }
                                      }
                                    },
                              child: isLoading
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                                Colors.white),
                                      ),
                                    )
                                  : Text(
                                      AppLocalizations.of(context)!.clearCache,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white, // page background color
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        centerTitle: true,
        title: Text(
          AppLocalizations.of(context)!.profile,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
          ),
        ),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            HapticFeedback.lightImpact();
            Navigator.of(context).pop();
          },
        ),
      ),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(
                    Theme.of(context).colorScheme.primary),
              ),
            )
          : _userData == null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.error_outline,
                        size: 64,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        AppLocalizations.of(context)!.unableToLoadProfile,
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: _loadUserData,
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              Theme.of(context).colorScheme.primary,
                          foregroundColor:
                              Theme.of(context).colorScheme.onPrimary,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: Text(AppLocalizations.of(context)!.retry),
                      ),
                    ],
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(child: _buildNameCard()),
                      _buildSectionTitle(
                          AppLocalizations.of(context)!.personalInformation),
                      Card(
                        elevation: 0,
                        color: const Color.fromARGB(255, 238, 238, 238),
                        margin: const EdgeInsets.symmetric(vertical: 8.0),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20)),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            children: [
                              _buildInfoCard(
                                title: AppLocalizations.of(context)!.username,
                                value: _userData!['username'] as String? ?? '',
                                icon: Icons.alternate_email,
                              ),
                              _buildInfoCard(
                                title: AppLocalizations.of(context)!.email,
                                value: _userData!['email'] as String? ?? '',
                                icon: Icons.email_outlined,
                              ),
                              _buildInfoCard(
                                title:
                                    AppLocalizations.of(context)!.contactNumber,
                                value:
                                    _userData!['contact_number'] as String? ??
                                        '',
                                icon: Icons.phone_outlined,
                              ),
                              _buildInfoCard(
                                title: AppLocalizations.of(context)!.userId,
                                value: _userData!['id']?.toString() ?? '',
                                icon: Icons.badge_outlined,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16.0),
                      Divider(
                          thickness: 1,
                          indent: 16,
                          endIndent: 16,
                          color: Colors.grey.withOpacity(0.3)),
                      const SizedBox(height: 16.0),
                      _buildSectionTitle(
                          AppLocalizations.of(context)!.organizationAndRole),
                      Card(
                        elevation: 0,
                        color: const Color.fromARGB(255, 238, 238, 238),
                        margin: const EdgeInsets.symmetric(vertical: 8.0),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20)),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            children: [
                              _buildInfoCard(
                                title:
                                    AppLocalizations.of(context)!.organization,
                                value: _userData!['organization_name']
                                        as String? ??
                                    '',
                                icon: Icons.business_outlined,
                              ),
                              _buildInfoCard(
                                title: AppLocalizations.of(context)!
                                    .organizationId,
                                value:
                                    _userData!['organization'] as String? ?? '',
                                icon: Icons.fingerprint,
                              ),
                              _buildInfoCard(
                                title: AppLocalizations.of(context)!.roles,
                                value: _getRolesText(),
                                icon: Icons.work_outline,
                              ),
                              _buildInfoCard(
                                title: AppLocalizations.of(context)!.projects,
                                value: _getProjectsText(),
                                icon: Icons.folder_outlined,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16.0),
                      if (_userData!['is_superadmin'] == true) ...[
                        Divider(
                            thickness: 1,
                            indent: 16,
                            endIndent: 16,
                            color: Colors.grey.withOpacity(0.3)),
                        const SizedBox(height: 16.0),
                        _buildSectionTitle(
                            AppLocalizations.of(context)!.adminStatus),
                        Card(
                          elevation: 0,
                          color: const Color.fromARGB(255, 238, 238, 238),
                          margin: const EdgeInsets.symmetric(vertical: 8.0),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20)),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(16.0),
                              decoration: BoxDecoration(
                                color: Colors.green.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(16.0),
                                border: Border.all(
                                  color: Colors.green.withOpacity(0.3),
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.admin_panel_settings,
                                    color: Colors.green[700],
                                    size: 24,
                                  ),
                                  const SizedBox(width: 12.0),
                                  Text(
                                    AppLocalizations.of(context)!
                                        .superAdministrator,
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.green[800],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 16.0),
                      Divider(
                          thickness: 1,
                          indent: 16,
                          endIndent: 16,
                          color: Colors.grey.withOpacity(0.3)),
                      const SizedBox(height: 16.0),
                      _buildSectionTitle(
                          AppLocalizations.of(context)!.security),
                      Card(
                        elevation: 0,
                        color: const Color.fromARGB(255, 238, 238, 238),
                        margin: const EdgeInsets.symmetric(vertical: 8.0),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20)),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: InkWell(
                            onTap: () {
                              HapticFeedback.lightImpact();
                              _showChangePasswordDialog();
                            },
                            borderRadius: BorderRadius.circular(16),
                            child: Container(
                              padding: const EdgeInsets.all(16.0),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(10.0),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF592941)
                                          .withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(12.0),
                                    ),
                                    child: const Icon(
                                      Icons.lock_reset,
                                      color: Color(0xFF592941),
                                      size: 22,
                                    ),
                                  ),
                                  const SizedBox(width: 16.0),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          AppLocalizations.of(context)!
                                              .changePassword,
                                          style: const TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w600,
                                            color: Color(0xFF592941),
                                          ),
                                        ),
                                        const SizedBox(height: 4.0),
                                        Text(
                                          AppLocalizations.of(context)!
                                              .updateYourAccountPassword,
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: Colors.grey[600],
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Icon(
                                    Icons.arrow_forward_ios,
                                    size: 16,
                                    color: Colors.grey[400],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16.0),
                      Divider(
                          thickness: 1,
                          indent: 16,
                          endIndent: 16,
                          color: Colors.grey.withOpacity(0.3)),
                      const SizedBox(height: 16.0),
                      _buildSectionTitle(AppLocalizations.of(context)!.appData),
                      Card(
                        elevation: 0,
                        color: const Color.fromARGB(255, 238, 238, 238),
                        margin: const EdgeInsets.symmetric(vertical: 8.0),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20)),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: InkWell(
                            onTap: () {
                              HapticFeedback.lightImpact();
                              _showClearCacheDialog();
                            },
                            borderRadius: BorderRadius.circular(16),
                            child: Container(
                              padding: const EdgeInsets.all(16.0),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(10.0),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF592941)
                                          .withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(12.0),
                                    ),
                                    child: const Icon(
                                      Icons.clear_all,
                                      color: Color(0xFF592941),
                                      size: 22,
                                    ),
                                  ),
                                  const SizedBox(width: 16.0),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          AppLocalizations.of(context)!
                                              .clearCache,
                                          style: const TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w600,
                                            color: Color(0xFF592941),
                                          ),
                                        ),
                                        const SizedBox(height: 4.0),
                                        Text(
                                          AppLocalizations.of(context)!
                                              .clearWebViewCacheAndCookies,
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: Colors.grey[600],
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Icon(
                                    Icons.arrow_forward_ios,
                                    size: 16,
                                    color: Colors.grey[400],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 32.0),
                    ],
                  ),
                ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding:
          const EdgeInsets.only(top: 8.0, bottom: 12.0, left: 4.0, right: 4.0),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: Color(0xFF592941),
        ),
        textAlign: TextAlign.left,
      ),
    );
  }
}
