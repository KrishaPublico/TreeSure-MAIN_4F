import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:path/path.dart' as path;

class CTPOUploadPage extends StatefulWidget {
  final String applicantId; // new parameter
  final String applicantName; 

  const CTPOUploadPage({
    super.key,
    required this.applicantId,
    required this.applicantName, // 👈 Also required here
  });

  @override
  State<CTPOUploadPage> createState() => _CTPOUploadPageState();
}
class _CTPOUploadPageState extends State<CTPOUploadPage> {
  /// Each item will store { "file": PlatformFile?, "url": String? }
  final Map<String, Map<String, dynamic>> uploadedFiles = {
    "1. Letter of Application (1 original, 1 photocopy)": {
      "file": null,
      "url": null
    },
    "2. OCT, TCT, Judicial Title, CLOA, Tax Declared Alienable and Disposable Lands (1 certified true copy)":
        {"file": null, "url": null},
    "3. Data on the number of seedlings planted, species and area planted": {
      "file": null,
      "url": null
    },
    "4. Endorsement from concerned LGU interposing no objection to the cutting of tree under the following conditions (1 original)":
        {"file": null, "url": null},
    "4.a If the trees to be cut falls within one barangay, an endorsement from the Barangay Captain shall be secured":
        {"file": null, "url": null},
    "4.b If the trees to be cut falls within more than one barangay, endorsement shall be secured either from the Municipal/City Mayor or all the Barangay Captains concerned":
        {"file": null, "url": null},
    "4.c If the trees to be cut fall within more than one municipality/city, endorsement shall be secured either from the Provincial Governor or all the Municipality/City Mayors concerned":
        {"file": null, "url": null},
    "5. Special Power of Attorney (SPA) (1 original) – [Applicable if the client is a representative]":
        {"file": null, "url": null},
  };

  bool _isUploading = false;

  /// File Picker (select only PDF/DOC/DOCX)
  Future<void> pickFile(String label) async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx'],
        withData: true,
      );

      if (result == null) return;

      final PlatformFile file = result.files.single;
      final ext = path.extension(file.name).toLowerCase();

      if (!['.pdf', '.doc', '.docx'].contains(ext)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Please upload only PDF or DOC files.")),
        );
        return;
      }

      setState(() {
        uploadedFiles[label]!["file"] = file;
      });
    } catch (e) {
      debugPrint("File selection failed: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error selecting file: $e")),
      );
    }
  }

  /// Upload all selected files on Submit
  Future<void> handleSubmit() async {
    setState(() => _isUploading = true);

    try {
      for (final entry in uploadedFiles.entries) {
        final label = entry.key;
        final file = entry.value["file"] as PlatformFile?;

        if (file == null) continue; // skip if not selected

        final fileName =
            "${DateTime.now().millisecondsSinceEpoch}_${file.name}";
        final ref =
            FirebaseStorage.instance.ref().child("ctpo_uploads/$fileName");

        UploadTask uploadTask;

        if (kIsWeb) {
          final fileBytes = file.bytes;
          if (fileBytes == null) throw Exception("File bytes missing");
          uploadTask = ref.putData(fileBytes);
        } else {
          final filePath = file.path;
          if (filePath == null) throw Exception("File path missing");
          uploadTask = ref.putFile(File(filePath));
        }

        await uploadTask.whenComplete(() {});
        final url = await ref.getDownloadURL();

        uploadedFiles[label]!["url"] = url;
      }

      setState(() => _isUploading = false);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("All files uploaded successfully!")),
      );
    } catch (e) {
      setState(() => _isUploading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error uploading files: $e")),
      );
    }
  }

  Widget buildUploadField(String label) {
    final isIndented = label.startsWith("4.a") ||
        label.startsWith("4.b") ||
        label.startsWith("4.c");
    final noUpload = label ==
        "4. Endorsement from concerned LGU interposing no objection to the cutting of tree under the following conditions (1 original)";

    final file = uploadedFiles[label]!["file"] as PlatformFile?;
    final url = uploadedFiles[label]!["url"] as String?;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(left: isIndented ? 24.0 : 0),
              child: Text(
                label +
                    (url != null
                        ? " ✅ (Uploaded)"
                        : file != null
                            ? " (Ready to upload)"
                            : ""),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: url != null
                      ? Colors.green
                      : file != null
                          ? Colors.orange
                          : Colors.black,
                ),
              ),
            ),
          ),
          if (!noUpload)
            ElevatedButton(
              onPressed: () => pickFile(label),
              style: ElevatedButton.styleFrom(
                backgroundColor: file != null ? Colors.orange : Colors.green,
                foregroundColor: Colors.white,
              ),
              child: Text(file != null ? "Change File" : "Select File"),
            ),
        ],
      ),
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

            // Upload fields
            for (String label in uploadedFiles.keys) buildUploadField(label),

            const SizedBox(height: 32),

            // Submit button
            Center(
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isUploading ? null : handleSubmit,
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
                  child: _isUploading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('Submit (Upload All Files)'),
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
