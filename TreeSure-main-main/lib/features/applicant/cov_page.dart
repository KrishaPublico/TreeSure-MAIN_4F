import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as path;
import 'package:url_launcher/url_launcher.dart';

class COVUploadPage extends StatefulWidget {
  final String applicantId;
  final String applicantName;

  const COVUploadPage({
    super.key,
    required this.applicantId,
    required this.applicantName,
  });

  @override
  State<COVUploadPage> createState() => _COVUploadPageState();
}

class _COVUploadPageState extends State<COVUploadPage> {
  final List<Map<String, String>> formLabels = [
    {
      "title": "Request Letter",
      "description": "(1 original, 1 photocopy)",
    },
    {
      "title": "Barangay Certificate (for non-timber)",
      "description": "(1 original)",
    },
    {
      "title":
          "Certification that the forest products are harvested within the area of the owner (for non-timber)",
      "description": "(1 original)",
    },
    {
      "title": "Approved Tree Cutting Permit",
      "description": "(if applicable, 1 photocopy)",
    },
    {
      "title": "OR/CR of Conveyance and Driver’s License",
      "description": "(1 photocopy)",
    },
    {
      "title": "Certificate of Transport Agreement",
      "description":
          "(1 original, if owner of forest product is not the owner of conveyance)",
    },
    {
      "title": "Special Power of Attorney (SPA)",
      "description":
          "(1 original, if applicant is not the land owner)",
    },
  ];

  final Map<String, Map<String, dynamic>> uploadedFiles = {};
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    for (final label in formLabels) {
      uploadedFiles[label["title"]!] = {"file": null, "url": null};
    }
    _loadExistingUploads();
  }

  /// Load existing uploaded files from Firestore
  Future<void> _loadExistingUploads() async {
    final uploadsRef = FirebaseFirestore.instance
        .collection('users')
        .doc(widget.applicantId)
        .collection('cov_uploads');

    final snapshot = await uploadsRef.get();
    for (final doc in snapshot.docs) {
      final data = doc.data();
      final title = data['title'] as String?;
      final url = data['url'] as String?;
      if (title != null && uploadedFiles.containsKey(title)) {
        uploadedFiles[title]!["url"] = url;
      }
    }

    setState(() {});
  }

  /// Pick a file for a given requirement
  Future<void> pickFile(String title) async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx', 'jpg', 'png'],
        withData: true,
      );

      if (result == null) return;

      final PlatformFile file = result.files.single;
      final ext = path.extension(file.name).toLowerCase();

      if (!['.pdf', '.doc', '.docx', '.jpg', '.png'].contains(ext)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Please upload only PDF, DOC, or image files.")),
        );
        return;
      }

      setState(() {
        uploadedFiles[title]!["file"] = file;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error selecting file: $e")),
      );
    }
  }

  /// Upload all selected files
  Future<void> handleSubmit() async {
    setState(() => _isUploading = true);

    try {
      final uploadsRef = FirebaseFirestore.instance
          .collection('users')
          .doc(widget.applicantId)
          .collection('cov_uploads');

      for (final entry in uploadedFiles.entries) {
        final title = entry.key;
        final file = entry.value["file"] as PlatformFile?;

        if (file == null) continue;

        final cleanTitle = title.replaceAll(RegExp(r'[.#$/\[\]]'), '-').trim();
        final fileName =
            "${DateTime.now().millisecondsSinceEpoch}_${file.name}";
        final ref = FirebaseStorage.instance.ref().child("cov_uploads/$fileName");

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
        final downloadUrl = await ref.getDownloadURL();

        await uploadsRef.doc(cleanTitle).set({
          'title': title,
          'fileName': file.name,
          'url': downloadUrl,
          'uploadedAt': FieldValue.serverTimestamp(),
        });

        uploadedFiles[title]!["url"] = downloadUrl;
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

  /// UI for each upload field
  Widget buildUploadField(Map<String, String> label) {
    final title = label["title"]!;
    final description = label["description"] ?? "";
    final file = uploadedFiles[title]!["file"] as PlatformFile?;
    final url = uploadedFiles[title]!["url"] as String?;
    final isUploaded = url != null;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title +
                      (isUploaded
                          ? " ✅ (Uploaded)"
                          : file != null
                              ? " (Ready)"
                              : ""),
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: isUploaded
                        ? Colors.green
                        : file != null
                            ? Colors.orange
                            : Colors.black,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: const TextStyle(fontSize: 13, color: Colors.black87),
                ),
                if (isUploaded)
                  TextButton(
                    onPressed: () async {
                      await launchUrl(Uri.parse(url));
                    },
                    child: const Text("View Uploaded File"),
                  ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: isUploaded
                ? null
                : () => pickFile(title),
            style: ElevatedButton.styleFrom(
              backgroundColor: isUploaded
                  ? Colors.grey
                  : (file != null ? Colors.orange : Colors.green[700]),
              foregroundColor: Colors.white,
            ),
            child: Text(isUploaded
                ? "Uploaded"
                : (file != null ? "Change File" : "Select File")),
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
          'COV File Upload',
          style: TextStyle(color: Colors.white),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Upload Documents for Certificate of Verification (COV)',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            // Upload Fields
            for (final label in formLabels) buildUploadField(label),

            const SizedBox(height: 32),
            Center(
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isUploading ? null : handleSubmit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green[700],
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isUploading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                          'Submit (Upload All Files)',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
