import 'package:flutter/material.dart';

class SPLTFormPage extends StatefulWidget {
  const SPLTFormPage({Key? key}) : super(key: key);

  @override
  _SPLTPFormPageState createState() => _SPLTPFormPageState();
}

class _SPLTPFormPageState extends State<SPLTFormPage> {
  final Map<String, String?> uploadedFiles = {
    "1. Application Letter (1 original)": null,
    "2. LGU Endorsement/Certification of No Objection (1 original)": null,
    "3. Endorsement from concerned LGU interposing no objection to the cutting of trees under the following conditions (1 original):": null,
    "3.a. If the trees to be cut fall within one barangay, an endorsement from the Barangay Captain shall be secured": null,
    "3.b. If the trees to be cut fall within more than one barangay, endorsement shall be secured either from the Municipal/City Mayor or all the Barangay Captains concerned": null,
    "3.c. If the trees to be cut fall within more than one municipality/city, endorsement shall be secured either from the Provincial Governor or all the Municipality/City Mayors concerned": null,
    "4. Environmental Compliance Certificate (ECC)/Certificate of Non-Coverage (CNC), if applicable": null,
    "**Additional if application covers ten (10) hectares or larger**||5. Utilization Plan with at least 50% of the area covered with forest trees (1 original)": null,
    "**Additional if covered by CLOA**||6. Endorsement by local agrarian reform officer interposing no objection (1 original)": null,
    "**Additional if school/organization**||7. PTA Resolution or Resolution from any organized group of no objection and reason for cutting for School/Organization (1 original)": null,
  };

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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
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
                    // Placeholder: You can add file picker logic here
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Upload clicked for: $label'),
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
          if (uploadedFiles[label] != null)
            Padding(
              padding: EdgeInsets.only(top: 4.0, left: isIndented ? 24.0 : 0),
              child: Text(
                'Selected: ${uploadedFiles[label]}',
                style: TextStyle(fontSize: 13, color: Colors.green[700]),
              ),
            ),
        ],
      ),
    );
  }

  void handleSubmit() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text("Form submitted!"),
        backgroundColor: Colors.green[700],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('SPLTP Application Form'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Issuance of Special Private Land Timber Permit (SPLTP) for Premium/Naturally Grown Trees Within Private/Titled Lands',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            for (String label in uploadedFiles.keys) buildUploadField(label),
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
