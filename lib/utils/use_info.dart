import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class UseInfo {
  static void showInstructionsSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
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
                // Bottom sheet handle
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
                Expanded(
                  child: SingleChildScrollView(
                    controller: controller,
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "How to use Commons Connect?",
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF592941),
                            ),
                          ),
                          const SizedBox(height: 20),
                          const Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Operate in Online Mode (Requires Internet)",
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF592941),
                                ),
                              ),
                              SizedBox(height: 12),
                              Text(
                                "STEP 1: Select State > District > Block\nSTEP 2: Press Submit",
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Color(0xFF592941),
                                ),
                              ),
                              SizedBox(height: 24),
                              Text(
                                "Operate in Offline Mode",
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF592941),
                                ),
                              ),
                              SizedBox(height: 12),
                              Text(
                                "You need to download the layers beforehand on your mobile storage to use them without internet.",
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Color(0xFF592941),
                                ),
                              ),
                              SizedBox(height: 12),
                              Text(
                                "STEP 1: Select State > District > Block\nSTEP 2: Create a new container.\nSTEP 3: Mark the location for which you are downloading the layers.\nSTEP 4: Name your container.\nSTEP 5: Download the respective layers.\nSTEP 6: Now press Work offline\nSTEP 7: Choose the container you created from the list.\nSTEP 8: Navigate to the app in offline mode (does not require internet).",
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Color(0xFF592941),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          Center(
                            child: TextButton.icon(
                              onPressed: () async {
                                final Uri url =
                                    Uri.parse('https://forms.gle/vm86yuvNezwQC45a8');
                                try {
                                  if (!await launchUrl(url,
                                      mode: LaunchMode.externalApplication)) {
                                    throw Exception('Could not launch $url');
                                  }
                                } catch (e) {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content:
                                            Text('Could not open the bug report form'),
                                      ),
                                    );
                                  }
                                }
                              },
                              icon: const Icon(Icons.bug_report,
                                  color: Color(0xFF592941)),
                              label: const Text(
                                'File a bug report',
                                style: TextStyle(
                                  color: Color(0xFF592941),
                                  fontSize: 16,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                        ],
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
}
