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
