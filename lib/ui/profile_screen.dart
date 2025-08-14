import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/login_service.dart';

class ProfileStatsScreen extends StatefulWidget {
  const ProfileStatsScreen({Key? key}) : super(key: key);

  @override
  State<ProfileStatsScreen> createState() => _ProfileStatsScreenState();
}

class _ProfileStatsScreenState extends State<ProfileStatsScreen> {
  final LoginService _loginService = LoginService();
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
        borderRadius: BorderRadius.circular(12.0),
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
                borderRadius: BorderRadius.circular(8.0),
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
                    value.isNotEmpty ? value : 'Not specified',
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
    if (_userData == null) return 'No projects';

    final projectDetails = _userData!['project_details'] as List?;
    if (projectDetails == null || projectDetails.isEmpty) {
      return 'No projects assigned';
    }

    return projectDetails.map((project) => project.toString()).join(', ');
  }

  String _getRolesText() {
    if (_userData == null) return 'No roles';

    final groups = _userData!['groups'] as List?;
    if (groups == null || groups.isEmpty) {
      return 'No roles assigned';
    }

    return groups.map((group) => group['name']).join(', ');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white, // page background color
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text(
          'Profile',
          style: TextStyle(
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
                        'Unable to load profile data',
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
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('Retry'),
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
                      _buildSectionTitle('Personal Information'),
                      Card(
                        elevation: 0,
                        color: const Color.fromARGB(255, 238, 238, 238),
                        margin: const EdgeInsets.symmetric(vertical: 8.0),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            children: [
                              _buildInfoCard(
                                title: 'Username',
                                value: _userData!['username'] as String? ?? '',
                                icon: Icons.alternate_email,
                              ),
                              _buildInfoCard(
                                title: 'Email',
                                value: _userData!['email'] as String? ?? '',
                                icon: Icons.email_outlined,
                              ),
                              _buildInfoCard(
                                title: 'Contact Number',
                                value:
                                    _userData!['contact_number'] as String? ??
                                        '',
                                icon: Icons.phone_outlined,
                              ),
                              _buildInfoCard(
                                title: 'User ID',
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
                      _buildSectionTitle('Organization & Role'),
                      Card(
                        elevation: 0,
                        color: const Color.fromARGB(255, 238, 238, 238),
                        margin: const EdgeInsets.symmetric(vertical: 8.0),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            children: [
                              _buildInfoCard(
                                title: 'Organization',
                                value: _userData!['organization_name']
                                        as String? ??
                                    '',
                                icon: Icons.business_outlined,
                              ),
                              _buildInfoCard(
                                title: 'Organization ID',
                                value:
                                    _userData!['organization'] as String? ?? '',
                                icon: Icons.fingerprint,
                              ),
                              _buildInfoCard(
                                title: 'Role(s)',
                                value: _getRolesText(),
                                icon: Icons.work_outline,
                              ),
                              _buildInfoCard(
                                title: 'Projects',
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
                        _buildSectionTitle('Admin Status'),
                        Card(
                          elevation: 0,
                          color: const Color.fromARGB(255, 238, 238, 238),
                          margin: const EdgeInsets.symmetric(vertical: 8.0),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(16.0),
                              decoration: BoxDecoration(
                                color: Colors.green.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12.0),
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
                                    'Super Administrator',
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
