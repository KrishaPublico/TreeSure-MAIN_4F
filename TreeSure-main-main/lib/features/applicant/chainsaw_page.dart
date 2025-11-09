import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as path;
import 'package:url_launcher/url_launcher.dart';

class ChainsawPermitPage extends StatefulWidget {
  final String applicantId;
  final String applicantName;

  const ChainsawPermitPage({
    super.key,
    required this.applicantId,
    required this.applicantName,
  });

  @override
  State<ChainsawPermitPage> createState() => _ChainsawPermitPageState();
}

class _ChainsawPermitPageState extends State<ChainsawPermitPage> {
  final List<Map<String, String>> formLabels = [
    {
      "title": "Official Receipt of Chainsaw Purchase",
      "description":
          "(1 certified copy and 1 original for verification) or Affidavit of Ownership in case the original copy is lost"
    },
    {
      "title": "SPA if the applicant is not the owner of the chainsaw",
      "description": ""
    },
    {"title": "Stencil Serial Number of Chainsaw", "description": ""},
    {"title": "Duly accomplished Application Form", "description": ""},
    {
      "title": "Detailed Specification of Chainsaw",
      "description": "(e.g. brand, model, engine capacity, etc.)"
    },
    {
      "title": "Notarized Deed of Absolute Sale",
      "description": "(1 original, if transfer of ownership)"
    },
    {
      "title": "Certified True Copy of Forest Tenure Agreement",
      "description": "(If Tenurial Instrument holder)"
    },
    {
      "title": "Business Permit",
      "description": "(1 photocopy, if Business Owner)"
    },
    {
      "title": "Certificate of Registration",
      "description": "(If Registered as Private Tree Plantation)"
    },
    {
      "title": "Business Permit from LGU or affidavit for legal purpose",
      "description":
          "(1 photocopy, if chainsaw is needed for profession/work and for legal use)"
    },
    {
      "title": "Wood Processing Plant Permit",
      "description": "(If licensed Wood Processor)"
    },
    {
      "title": "Certification from Head of Office",
      "description":
          "(That chainsaws are owned/possessed by the office and used for legal purposes)"
    },
    {
      "title": "Duly accomplished application form (Renewal)",
      "description": "(If for renewal of registration)"
    },
    {
      "title": "Latest Certificate of Chainsaw Registration",
      "description": "(1 photocopy, for renewal applications)"
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

  /// Load existing uploaded files
  Future<void> _loadExistingUploads() async {
    final uploadsRef = FirebaseFirestore.instance
        .collection('users')
        .doc(widget.applicantId)
        .collection('chainsaw_uploads');

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

  /// File picker
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
          const SnackBar(
              content:
                  Text("Please upload only PDF, DOC, or image files.")),
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
          .collection('chainsaw_uploads');

      for (final entry in uploadedFiles.entries) {
        final title = entry.key;
        final file = entry.value["file"] as PlatformFile?;
        if (file == null) continue;

        final cleanTitle = title.replaceAll(RegExp(r'[.#$/\[\]]'), '-').trim();
        final fileName =
            "${DateTime.now().millisecondsSinceEpoch}_${file.name}";
        final ref =
            FirebaseStorage.instance.ref().child("chainsaw_uploads/$fileName");

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

  /// Single upload field
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
                  style:
                      const TextStyle(fontSize: 13, color: Colors.black87),
                ),
                if (isUploaded)
                  TextButton(
                    onPressed: () async {
                      await launchUrl(Uri.parse(url!));
                    },
                    child: const Text("View Uploaded File"),
                  ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: isUploaded ? null : () => pickFile(title),
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

  /// Main UI
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.green[700],
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'Chainsaw Registration Upload',
          style: TextStyle(color: Colors.white),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Upload Documents for Chainsaw Registration',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

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
                    padding:
                        const EdgeInsets.symmetric(vertical: 20),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isUploading
                      ? const CircularProgressIndicator(
                          color: Colors.white)
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
