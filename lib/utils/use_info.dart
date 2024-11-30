import 'package:flutter/material.dart';

class UseInfo {
  static void showInstructionsSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // Enable full screen modal
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (BuildContext context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: SingleChildScrollView(
            child: Container(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "How to use Commons Connect?",
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF592941),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      )
                    ],
                  ),
                  const SizedBox(height: 20),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: EdgeInsets.only(bottom: 16),
                        child: Text(
                          "• You can operate the application in either online mode or offline mode",
                          style: TextStyle(
                            fontSize: 16,
                            color: Color(0xFF592941),
                          ),
                        ),
                      ),
                      Padding(
                        padding: EdgeInsets.only(bottom: 8),
                        child: Text(
                          "• To operate in offline mode:",
                          style: TextStyle(
                            fontSize: 16,
                            color: Color(0xFF592941),
                          ),
                        ),
                      ),
                      Padding(
                        padding: EdgeInsets.only(left: 16, bottom: 8),
                        child: Text(
                          "• Step 1: Download collection of layers for an area",
                          style: TextStyle(
                            fontSize: 16,
                            color: Color(0xFF592941),
                          ),
                        ),
                      ),
                      Padding(
                        padding: EdgeInsets.only(left: 16, bottom: 8),
                        child: Text(
                          "• Step 2: Name your collection",
                          style: TextStyle(
                            fontSize: 16,
                            color: Color(0xFF592941),
                          ),
                        ),
                      ),
                      Padding(
                        padding: EdgeInsets.only(left: 16, bottom: 8),
                        child: Text(
                          "• Step 3: After selecting the state, dist and block, click on Offline button and select your collection to use the downloaded layers",
                          style: TextStyle(
                            fontSize: 16,
                            color: Color(0xFF592941),
                          ),
                        ),
                      ),
                      Padding(
                        padding: EdgeInsets.only(left: 16, bottom: 8),
                        child: Text(
                          "• Step 4: Now, you can operate offline while being in remote areas",
                          style: TextStyle(
                            fontSize: 16,
                            color: Color(0xFF592941),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20), // Add bottom padding
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
