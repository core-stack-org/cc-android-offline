import 'package:flutter/material.dart';

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

class ChangelogBottomSheet extends StatelessWidget {
  const ChangelogBottomSheet({super.key});

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
                    'Version 2.0.7',
                    [
                      'New flow for downloading the region for offline use',
                      "Revamped UI for better user experience",
                      "Translation fixes across the analysis screens",
                      "NREGA asset fixes across Home Screen and Surface Waterbodies",
                      "Asset info across Planning section",
                      "New screen while downloading the layers for a region -- offline use",
                      "New logo for the app",
                      "Fixed issues with the offline data and sync",
                    ],
                  ),
                  const SizedBox(height: 20),
                  _buildVersionSection(
                    'Coming Soon',
                    [
                      "Version 2.1.0",
                      "UI and UX improvements",
                      "Minimum latency while loading layers",
                      "Login"
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
        ...changes
            .map((change) => Padding(
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