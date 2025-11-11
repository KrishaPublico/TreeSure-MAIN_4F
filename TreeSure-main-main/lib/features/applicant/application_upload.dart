import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as path;
import 'package:url_launcher/url_launcher.dart';

class ApplicationUploadPage extends StatefulWidget {
  final String applicantId;
  final String applicantName;
  final String type; // 🔹 ctpo, certificate to travel, chainsaw permit, etc.

  const ApplicationUploadPage({
    super.key,
    required this.applicantId,
    required this.applicantName,
    required this.type,
  });

  @override
  State<ApplicationUploadPage> createState() => _ApplicationUploadPageState();
}

class _ApplicationUploadPageState extends State<ApplicationUploadPage> {
  final Map<String, List<Map<String, String>>> formRequirements = {
    'ctpo': [
      {"title": "Letter of Application", "description": "(1 original, 1 photocopy)"},
      {
        "title":
            "OCT, TCT, Judicial Title, CLOA, Tax Declared Alienable and Disposable Lands",
        "description": "(1 certified true copy)"
      },
      {
        "title": "Data on the number of seedlings planted, species and area planted",
        "description": ""
      },
      {
        "title":
            "Endorsement from concerned LGU interposing no objection to the cutting of trees",
        "description": "(1 original)"
      },
      {
        "title":
            "If the trees to be cut fall within one barangay, endorsement from the Barangay Captain",
        "description": ""
      },
      {
        "title":
            "If within more than one barangay, endorsement from the Municipal/City Mayor or all Captains",
        "description": ""
      },
      {
        "title":
            "If within more than one municipality/city, endorsement from the Provincial Governor or all Mayors",
        "description": ""
      },
      {
        "title":
            "Special Power of Attorney (SPA) – Applicable if the client is a representative",
        "description": "(1 original)"
      },
    ],
    'certificate to travel': [
      {"title": "Request Letter", "description": "(1 original)"},
      {"title": "Approved Cutting Permit", "description": "(1 photocopy)"},
      {"title": "Delivery Receipt", "description": "(1 original)"},
    ],
    'chainsaw permit': [
      {"title": "Letter of Application", "description": "(1 original)"},
      {"title": "Proof of Ownership", "description": "(1 certified copy)"},
      {"title": "Barangay Clearance", "description": "(1 original)"},
    ],
    'private land timber permit': [
      {"title": "Application Form", "description": "(1 original)"},
      {"title": "Proof of Land Ownership", "description": "(1 certified copy)"},
      {"title": "Inventory of Trees", "description": "(1 original)"},
    ],
    'special land timber permit': [
      {"title": "Application Form", "description": "(1 original)"},
      {"title": "DENR Clearance", "description": "(1 photocopy)"},
      {"title": "LGU Endorsement", "description": "(1 original)"},
    ],
  };

  final Map<String, Map<String, dynamic>> uploadedFiles = {};
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    final type = widget.type.toLowerCase();
    final labels = formRequirements[type] ?? [];
    for (final label in labels) {
      uploadedFiles[label["title"]!] = {"file": null, "url": null};
    }
    _loadExistingUploads();
  }

  /// 🔹 Load already uploaded files
  Future<void> _loadExistingUploads() async {
    final uploadsRef = FirebaseFirestore.instance
        .collection('applications')
        .doc(widget.type)
        .collection('applicants')
        .doc(widget.applicantId)
        .collection('uploads');

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

  /// 🔹 File picker
  Future<void> pickFile(String title) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx'],
        withData: true,
      );
      if (result == null) return;

      final file = result.files.single;
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

  /// 🔹 Upload all files (hybrid write)
  Future<void> handleSubmit() async {
    setState(() => _isUploading = true);

    try {
      final firestore = FirebaseFirestore.instance;
      final storage = FirebaseStorage.instance;
      final appType = widget.type.toLowerCase();

      // References
      final appDoc = firestore.collection('applications').doc(appType);
      final applicantDoc = appDoc.collection('applicants').doc(widget.applicantId);
      final userUploadsRef = firestore
          .collection('users')
          .doc(widget.applicantId)
          .collection('${appType}_uploads');
      final applicantUploadsRef = applicantDoc.collection('uploads');

      for (final entry in uploadedFiles.entries) {
        final title = entry.key;
        final file = entry.value["file"] as PlatformFile?;
        if (file == null) continue;

        final safeTitle = title.replaceAll(RegExp(r'[.#$/\[\]]'), '-').trim();
        final fileName = "${DateTime.now().millisecondsSinceEpoch}_${file.name}";
        final ref = storage.ref().child("${appType}_uploads/$fileName");

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

        final uploadData = {
          'title': title,
          'fileName': file.name,
          'url': url,
          'uploadedAt': FieldValue.serverTimestamp(),
        };

        // Save in both locations
        await userUploadsRef.doc(safeTitle).set(uploadData);
        await applicantUploadsRef.doc(safeTitle).set(uploadData);

        uploadedFiles[title]!["url"] = url;
      }

      // Ensure applicant metadata exists
      await applicantDoc.set({
        'applicantName': widget.applicantName,
        'uploadedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // Update main summary doc
      final applicantsSnapshot = await appDoc.collection('applicants').get();
      final uploadedCount = applicantsSnapshot.docs.length;

      await appDoc.set({
        'uploadedCount': uploadedCount,
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (mounted) {
        setState(() => _isUploading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("${widget.type.toUpperCase()} files uploaded successfully!")),
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
                Text(description,
                    style: const TextStyle(fontSize: 13, color: Colors.black87)),
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
            child: Text(
              isUploaded
                  ? "Uploaded"
                  : (file != null ? "Change File" : "Select File"),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final formLabels = formRequirements[widget.type.toLowerCase()] ?? [];

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.green[700],
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          '${widget.type.toUpperCase()} Upload',
          style: const TextStyle(color: Colors.white),
        ),
      ),
      body: formLabels.isEmpty
          ? const Center(child: Text("No requirements defined for this type."))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Applicant: ${widget.applicantName}",
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "User ID: ${widget.applicantId}",
                    style: const TextStyle(fontSize: 13, color: Colors.black54),
                  ),
                  const Divider(thickness: 1, height: 24),
                  Text(
                    'Upload Documents for ${widget.type.toUpperCase()}',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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
