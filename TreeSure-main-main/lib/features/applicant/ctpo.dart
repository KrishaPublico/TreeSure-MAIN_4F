import 'dart:io';
import 'dart:convert'; // for Base64
import 'package:firebase_database/firebase_database.dart'; // Realtime DB
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

class CTPOUploadPage extends StatefulWidget {
  final String applicantId; // ID of the applicant uploading
  final String applicantName; // Name of applicant

  const CTPOUploadPage({
    super.key,
    required this.applicantId,
    required this.applicantName,
  });

  @override
  State<CTPOUploadPage> createState() => _CTPOUploadPageState();
}

class _CTPOUploadPageState extends State<CTPOUploadPage> {
  final Map<String, String?> uploadedFiles = {
    "1. Letter of Application (1 original, 1 photocopy)": null,
    "2. OCT, TCT, Judicial Title, CLOA, Tax Declared Alienable and Disposable Lands (1 certified true copy)": null,
    "3. Data on the number of seedlings planted, species and area planted": null,
    "4. Endorsement from concerned LGU interposing no objection to the cutting of tree under the following conditions (1 original)": null,
    "4.a If the trees to be cut falls within one barangay, an endorsement from the Barangay Captain shall be secured": null,
    "4.b If the trees to be cut falls within more than one barangay, endorsement shall be secured either from the Municipal/City Mayor or all the Barangay Captains concerned": null,
    "4.c If the trees to be cut fall within more than one municipality/city, endorsement shall be secured either from the Provincial Governor or all the Municipality/City Mayors concerned": null,
    "5. Special Power of Attorney (SPA) (1 original) – [Applicable if the client is a representative]": null,
  };

  /// Pick file and upload to Realtime Database as Base64
  Future<void> pickAndUploadFile(String label) async {
    try {
      final result = await FilePicker.platform.pickFiles(type: FileType.any);
      if (result != null && result.files.single.path != null) {
        File file = File(result.files.single.path!);
        String fileName = result.files.single.name;

        // Convert file to Base64
        String base64File = base64Encode(await file.readAsBytes());

        // Save Base64 + meta info to Realtime Database
        DatabaseReference dbRef = FirebaseDatabase.instance
            .ref()
            .child("applicants")
            .child(widget.applicantId)
            .child("ctpo_uploads")
            .child(label);

        await dbRef.set({
          "file_name": fileName,
          "file_data": base64File, // 🔥 Base64 file
          "uploaded_at": DateTime.now().toIso8601String(),
          "applicant_name": widget.applicantName,
        });

        setState(() {
          uploadedFiles[label] = fileName;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$fileName uploaded successfully!')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to upload file: $e')),
      );
    }
  }

  /// Builds each upload field row
  Widget buildUploadField(String label) {
    final isIndented =
        label.startsWith("4.a") || label.startsWith("4.b") || label.startsWith("4.c");
    final noUpload = label ==
        "4. Endorsement from concerned LGU interposing no objection to the cutting of tree under the following conditions (1 original)";

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(left: isIndented ? 24.0 : 0),
              child: Text(
                label,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
              ),
            ),
          ),
          if (!noUpload)
            ElevatedButton(
              onPressed: () => pickAndUploadFile(label),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
              child: Text(uploadedFiles[label] != null ? "Re-upload" : "Upload File"),
            ),
        ],
      ),
    );
  }

  /// Handles the form submission
  void handleSubmit() {
    // Determine endorsement level
    String type = "barangay"; // default

    if (uploadedFiles["4.c If the trees to be cut fall within more than one municipality/city, endorsement shall be secured either from the Provincial Governor or all the Municipality/City Mayors concerned"] != null) {
      type = "province";
    } else if (uploadedFiles["4.b If the trees to be cut falls within more than one barangay, endorsement shall be secured either from the Municipal/City Mayor or all the Barangay Captains concerned"] != null) {
      type = "municipality";
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('CTPO submitted. Level: $type')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.green[700],
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'CTPO File Upload',
          style: TextStyle(color: Colors.white),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Upload Documents for Certificate of Tree Plantation Ownership (CTPO)',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            // Build fields
            for (String label in uploadedFiles.keys) buildUploadField(label),

            const SizedBox(height: 32),

            // Submit button
            Center(
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: handleSubmit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green[700],
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    textStyle: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
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
