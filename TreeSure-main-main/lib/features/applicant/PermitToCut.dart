import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:path/path.dart' as path;
import 'package:url_launcher/url_launcher.dart';

class PermitToCutPage extends StatefulWidget {
  final String applicantId;
  final String applicantName;
  const PermitToCutPage({
    super.key,
    required this.applicantId,
    required this.applicantName,
  });

  @override
  _PermitToCutPageState createState() => _PermitToCutPageState();
}

class _PermitToCutPageState extends State<PermitToCutPage> {
  final List<Map<String, String>> formLabels = [
    {
      "title": "Letter request",
      "description":
          " to be addressed to: FORESTER JOSELITO D. RAZON\nCENR Officer\nDENR-CENRO APARRI\nPunta, Aparri, Cagayan"
    },
    {
      "title": "Barangay Certification",
      "description": " interposing no objection on the cutting of trees"
    },
    {
      "title": "Certified copy of Title / Electronic Copy of Title",
      "description": ""
    },
    {
      "title":
          "Special Power of Attorney (SPA) / Deed of Sale from the owner of the Land Title",
      "description":
          "Required if the applicant is not the owner of the titled lot."
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

  Future<void> _loadExistingUploads() async {
    final uploadsRef = FirebaseFirestore.instance
        .collection('users')
        .doc(widget.applicantId)
        .collection('ptc_uploads');

    final snapshot = await uploadsRef.get();
    for (final doc in snapshot.docs) {
      final data = doc.data();
      final title = data['title'] as String?;
      final url = data['url'] as String?;
      if (title != null && uploadedFiles.containsKey(title)) {
        uploadedFiles[title]!["url"] = url;
      }
    }

    setState(() {}); // Refresh UI
  }

  /// Pick a file
  Future<void> pickFile(String title) async {
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
        uploadedFiles[title]!["file"] = file;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error selecting file: $e")),
      );
    }
  }

  /// Handle uploads
  /// Upload all selected files
  Future<void> handleSubmit() async {
    setState(() => _isUploading = true);

    try {
      final firestore = FirebaseFirestore.instance;
      final storage = FirebaseStorage.instance;

      // References
      final appDoc = firestore.collection('applications').doc('ptc');
      final applicantDoc =
          appDoc.collection('applicants').doc(widget.applicantId);
      final userUploadsRef = firestore
          .collection('users')
          .doc(widget.applicantId)
          .collection('ptc_uploads');
      final applicantUploadsRef = applicantDoc.collection('uploads');

      // Upload files one by one
      for (final entry in uploadedFiles.entries) {
        final title = entry.key;
        final file = entry.value["file"] as PlatformFile?;
        if (file == null) continue;

        final safeTitle = title.replaceAll(RegExp(r'[.#$/\[\]]'), '-').trim();
        final fileName =
            "${DateTime.now().millisecondsSinceEpoch}_${file.name}";
        final ref = storage.ref().child("ptc_uploads/$fileName");

        UploadTask uploadTask;
        if (kIsWeb) {
          final bytes = file.bytes;
          if (bytes == null) throw Exception("File bytes missing");
          uploadTask = ref.putData(bytes);
        } else {
          final pathStr = file.path;
          if (pathStr == null) throw Exception("File path missing");
          uploadTask = ref.putFile(File(pathStr));
        }

        await uploadTask.whenComplete(() {});
        final url = await ref.getDownloadURL();

        // Save data structure
        final uploadData = {
          'title': title,
          'fileName': file.name,
          'url': url,
          'uploadedAt': FieldValue.serverTimestamp(),
        };

        // 1️⃣ Save inside user → ptc_uploads
        await userUploadsRef.doc(safeTitle).set(uploadData);

        // 2️⃣ Save inside applications → ptc → applicants → uploads
        await applicantUploadsRef.doc(safeTitle).set(uploadData);

        uploadedFiles[title]!["url"] = url;
      }

      // Ensure applicant metadata exists
      await applicantDoc.set({
        'applicantName': widget.applicantName,
        'uploadedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // Update main summary document
      final applicantsSnapshot = await appDoc.collection('applicants').get();
      final uploadedCount = applicantsSnapshot.docs.length;

      await appDoc.set({
        'uploadedCount': uploadedCount,
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (mounted) {
        setState(() => _isUploading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("All files uploaded successfully!")),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isUploading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error uploading files: $e")),
        );
      }
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
                      // Optional: Allow viewing the file in browser
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
                : () => pickFile(title), // 🔹 Disable if already uploaded
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

  /// UI
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Issuance of Tree Cutting Permit'),
        backgroundColor: Colors.green[700],
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'ISSUANCE OF TREE CUTTING PERMIT WITHIN TITLED LOT/PRIVATE LOT',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            const Text(
              'REQUIREMENTS:',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),

            // Upload buttons
            for (final label in formLabels) buildUploadField(label),

            const SizedBox(height: 24),
            const Text(
              'Seedling Replacement as per DENR Memorandum No. 2012-02 '
              '(one (1) Tree = 50 indigenous seedlings)',
              style: TextStyle(
                fontSize: 15,
                fontStyle: FontStyle.italic,
              ),
            ),
            const SizedBox(height: 32),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isUploading ? null : handleSubmit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green[700],
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isUploading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                        'Submit (Upload All Files)',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
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
