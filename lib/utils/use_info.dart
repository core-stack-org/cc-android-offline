import 'package:flutter/material.dart';

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
                      child: const Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "How to use Commons Connect?",
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF592941),
                            ),
                          ),
                          SizedBox(height: 20),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Operate in Online mode (Requires Internet)",
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF592941),
                                ),
                              ),
                              SizedBox(height: 12),
                              Text(
                                "STEP 1: Select a State > District > Tehsil\nSTEP 2: Press Submit",
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Color(0xFF592941),
                                ),
                              ),
                              SizedBox(height: 24),
                              Text(
                                "Operate in Offline mode*",
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
                                "STEP 1: Select a State > District > Tehsil\nSTEP 2: Create a new region.\nSTEP 3: Mark the location on the map for which you are downloading the layers.\nSTEP 4: Name your region.\nSTEP 5: Download the respective layers.\nSTEP 6: Now press Offline mode* and SUBMIT\nSTEP 7: Choose the region you had created previously from the list.\nSTEP 8: Navigate to the app in offline mode (does not require internet).",
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Color(0xFF592941),
                                ),
                              ),
                            ],
                          ),
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
