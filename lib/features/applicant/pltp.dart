import 'package:flutter/material.dart';

class PLTPFormPage extends StatefulWidget {
  const PLTPFormPage({Key? key}) : super(key: key);

  @override
  _PLTPFormPageState createState() => _PLTPFormPageState();
}

class _PLTPFormPageState extends State<PLTPFormPage> {
  final List<String> formLabels = [
    "1. Application Letter (1 original)",
    "2. LGU Endorsement/Certification of No Objection (1 original)",
    "3. Endorsement from concerned LGU interposing no objection to the cutting of trees under the following conditions (1 original):",
    "3.a. If the trees to be cut fall within one barangay, an endorsement from the Barangay Captain shall be secured",
    "3.b. If the trees to be cut fall within more than one barangay, endorsement shall be secured either from the Municipal/City Mayor or all the Barangay Captains concerned",
    "3.c. If the trees to be cut fall within more than one municipality/city, endorsement shall be secured either from the Provincial Governor or all the Municipality/City Mayors concerned",
    "4. Environmental Compliance Certificate (ECC)/Certificate of Non-Coverage (CNC), if applicable",
    "**Additional if application covers ten (10) hectares or larger**||5. Utilization Plan with at least 50% of the area covered with forest trees (1 original)",
    "**Additional if covered by CLOA**||6. Endorsement by local agrarian reform officer interposing no objection (1 original)",
    "**Additional if school/organization**||7. PTA Resolution or Resolution from any organized group of no objection and reason for cutting for School/Organization (1 original)",
  ];

  Widget buildUploadField(String label) {
    final isIndented = label.startsWith("3.a") || label.startsWith("3.b") || label.startsWith("3.c");
    final noUpload = label.startsWith("3. Endorsement from concerned LGU");

    String? boldText;
    String displayText = label;

    if (label.contains("**") && label.contains("||")) {
      final parts = label.split("||");
      boldText = parts[0].replaceAll("**", "");
      displayText = parts[1];
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(left: isIndented ? 24.0 : 0),
              child: boldText != null
                  ? RichText(
                      text: TextSpan(
                        children: [
                          TextSpan(
                            text: "$boldText\n",
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                            ),
                          ),
                          TextSpan(
                            text: displayText,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: Colors.black,
                            ),
                          ),
                        ],
                      ),
                    )
                  : Text(
                      label,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                    ),
            ),
          ),
          if (!noUpload)
            ElevatedButton(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text("Upload clicked for: $label"),
                    backgroundColor: Colors.green[700],
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green[700],
                foregroundColor: Colors.white,
              ),
              child: const Text("Upload File"),
            ),
        ],
      ),
    );
  }

  void handleSubmit() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text("Form submitted! (Upload disabled)"),
        backgroundColor: Colors.green[700],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('PLTP Application Form'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Issuance of Private Land Timber Permit (PLTP) for Non-Premium Species',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            for (String label in formLabels) buildUploadField(label),
            const SizedBox(height: 32),
            Center(
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: handleSubmit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green[700],
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Submit'),
                ),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}
