import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

class ChangeLog {
  static void showChangelogBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const ChangelogBottomSheet(),
    );
  }
}

class ChangelogBottomSheet extends StatefulWidget {
  const ChangelogBottomSheet({super.key});

  @override
  State<ChangelogBottomSheet> createState() => _ChangelogBottomSheetState();
}

class _ChangelogBottomSheetState extends State<ChangelogBottomSheet> {
  String _appVersion = '';

  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    final PackageInfo packageInfo = await PackageInfo.fromPlatform();
    if (mounted) {
      setState(() {
        _appVersion = '${packageInfo.version}+${packageInfo.buildNumber}';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (_, controller) => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(51),
              blurRadius: 10,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: Column(
          children: [
            // Bottom sheet handle and close button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),
            // Title
            const Padding(
              padding: EdgeInsets.all(16),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Change Logs',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF592941),
                  ),
                ),
              ),
            ),
            // Changelog content
            Expanded(
              child: ListView(
                controller: controller,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  _buildVersionSection(
                    'Version $_appVersion',
                    [
                      "Mark Location in offline mode now includes a search village option that automatically zooms to the specified village.",
                      "Introduced remote equivalent ODK forms download for offline mode forms using s3 storage",
                      "Enabled remote download of Webview, allowing updates without requiring a full app release",
                      "Raster layers are now available in offline mode",
                      "Fixed download progress issues where it previously got stuck at 98.2%.",
                      "Improved base map downloading with a proper retry mechanism and clear messaging.",
                      "Added a manual retry button for layer downloads in case of failure.",
                      "Integrated Wake Plus to keep the screen awake during download progress.",
                      "Made various UX improvements around marking location for offline use and language selection in the app.",
                      "Resolved GPS location issues",
                      "Fixed forms and the synchronization of questionnaires between online and offline forms.",
                      "Added a naming convention for regions to prevent path issues in certain Android OEMs.",
                      "Ensured asset information across the application shows correct details.",
                      "Added a 'Change Password' option in the profile section.",
                      "Included a 'Cache data removal' option in the profile section.",
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVersionSection(String version, List<String> changes) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          version,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFF592941),
          ),
        ),
        const SizedBox(height: 8),
        ...changes.map((change) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 8),
                    width: 4,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[600],
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      change,
                      style: const TextStyle(
                        fontSize: 16,
                        color: Color(0xFF592941),
                      ),
                    ),
                  ),
                ],
              ),
            ))
      ],
    );
  }
}
