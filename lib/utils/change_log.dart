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
                    'Version 2.0.8',
                    [
                      "In offline usage, we added the planning forms.",
                      "Added a feature that lets you see your filled data for each form. You can also edit or update any details that were filled incorrectly.",
                      "You can either sync a single form data or select multiple forms at a time and sync them.",
                      "The submitted data creates a temporary layer which now persists.",
                      "Added a feature where you can refresh all the layers or just the plan layers for a region.",
                      "The download sheet is now non-collapsible until the Download is complete.",
                      "You can add a Lat/Lon while marking a location for download.",
                      "Few users were not able to submit images through the ODK forms. That has been fixed now.",
                    ],
                  ),
                  const SizedBox(height: 20),
                  _buildVersionSection(
                    'Coming Soon',
                    [
                      "Login functionality",
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
