import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:path/path.dart' as path;
import 'package:url_launcher/url_launcher.dart';

class SPLTFormPage extends StatefulWidget {
  final String applicantId;
  final String applicantName;
  const SPLTFormPage(
      {super.key, required this.applicantId, required this.applicantName});

  @override
  _SPLTFormPageState createState() => _SPLTFormPageState();
}

class _SPLTFormPageState extends State<SPLTFormPage> {
  final List<Map<String, String>> formLabels = [
    {"title": "Application Letter", "description": "(1 original)"},
    {
      "title": "LGU Endorsement/Certification of No Objection",
      "description": "(1 original)"
    },
    {
      "title":
          "Endorsement from concerned LGU interposing no objection to the cutting of trees under the following conditions",
      "description": "(1 original)"
    },
    {
      "title":
          "If the trees to be cut fall within one barangay, an endorsement from the Barangay Captain shall be secured",
      "description": ""
    },
    {
      "title":
          "If the trees to be cut fall within more than one barangay, endorsement shall be secured either from the Municipal/City Mayor or all the Barangay Captains concerned",
      "description": ""
    },
    {
      "title":
          "If the trees to be cut fall within more than one municipality/city, endorsement shall be secured either from the Provincial Governor or all the Municipality/City Mayors concerned",
      "description": ""
    },
    {
      "title":
          "Environmental Compliance Certificate (ECC)/Certificate of Non-Coverage (CNC)",
      "description": "If applicable."
    },
    {
      "title": "Utilization Plan",
      "description":
          "Required if the application covers ten (10) hectares or larger — must show at least 50% of the area covered with forest trees (1 original)."
    },
    {
      "title": "Endorsement by Local Agrarian Reform Officer",
      "description":
          "Required if covered by CLOA — interposing no objection (1 original)."
    },
    {
      "title": "PTA/Organization Resolution",
      "description":
          "Required if school or organization — resolution of no objection and reason for cutting (1 original)."
    },
  ];

  final Map<String, Map<String, dynamic>> uploadedFiles = {};
  bool _isUploading = false;
  bool _reuploadAllowed = false; // ✅ Track reuploadAllowed status
  List<Map<String, dynamic>> _adminComments = []; // ✅ Store admin comments

  @override
  void initState() {
    super.initState();
    for (final label in formLabels) {
      uploadedFiles[label["title"]!] = {"file": null, "url": null};
    }
    _loadExistingUploads();
    _loadReuploadStatus(); // ✅ Load reuploadAllowed status
    _loadAdminComments(); // ✅ Load admin comments
  }

  Future<void> _loadExistingUploads() async {
    final uploadsRef = FirebaseFirestore.instance
        .collection('users')
        .doc(widget.applicantId)
        .collection('sltp_uploads');

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

  /// ✅ Load reuploadAllowed status from Firestore
  Future<void> _loadReuploadStatus() async {
    try {
      final applicantRef = FirebaseFirestore.instance
          .collection('applications')
          .doc('splt')
          .collection('applicants')
          .doc(widget.applicantId);

      final snapshot = await applicantRef.get();
      if (snapshot.exists) {
        final reuploadAllowed = snapshot.data()?['reuploadAllowed'] as bool? ?? false;
        setState(() {
          _reuploadAllowed = reuploadAllowed;
        });
      }
    } catch (e) {
      print("Error loading reupload status: $e");
    }
  }

  /// ✅ Load admin comments from Firestore
  Future<void> _loadAdminComments() async {
    try {
      final applicantRef = FirebaseFirestore.instance
          .collection('applications')
          .doc('splt')
          .collection('applicants')
          .doc(widget.applicantId);

      final commentsSnapshot = await applicantRef.collection('comments').orderBy('createdAt', descending: true).get();
      
      final comments = commentsSnapshot.docs.map((doc) {
        return {
          'message': doc.data()['message'] as String? ?? '',
          'from': doc.data()['from'] as String? ?? 'Admin',
          'createdAt': doc.data()['createdAt'] as Timestamp?,
        };
      }).toList();

      setState(() {
        _adminComments = comments;
      });
    } catch (e) {
      print("Error loading admin comments: $e");
    }
  }

  /// Pick PDF/DOC/DOCX file
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

  /// Upload all selected files
  Future<void> handleSubmit() async {
    setState(() => _isUploading = true);

    try {
      final firestore = FirebaseFirestore.instance;
      final storage = FirebaseStorage.instance;

      // References
      final appDoc = firestore.collection('applications').doc('splt');
      final applicantDoc =
          appDoc.collection('applicants').doc(widget.applicantId);
      final userUploadsRef = firestore
          .collection('users')
          .doc(widget.applicantId)
          .collection('splt_uploads');
      final applicantUploadsRef = applicantDoc.collection('uploads');

      // Upload files one by one
      for (final entry in uploadedFiles.entries) {
        final title = entry.key;
        final file = entry.value["file"] as PlatformFile?;
        if (file == null) continue;

        final safeTitle = title.replaceAll(RegExp(r'[.#$/\[\]]'), '-').trim();
        final fileName =
            "${DateTime.now().millisecondsSinceEpoch}_${file.name}";
        final ref = storage.ref().child("splt_uploads/$fileName");

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

        // 1️⃣ Save inside user → splt_uploads
        await userUploadsRef.doc(safeTitle).set(uploadData);

        // 2️⃣ Save inside applications → splt → applicants → uploads
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
    // ✅ Determine button state
    final isButtonDisabled = _isUploading || (!_reuploadAllowed && _adminComments.isNotEmpty);
    final buttonColor = (_reuploadAllowed || _adminComments.isEmpty)
        ? Colors.green[700]
        : Colors.grey[400];
    final buttonText = (_reuploadAllowed || _adminComments.isEmpty)
        ? 'Submit (Upload All Files)'
        : 'Submit Disabled - Waiting for Approval';

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
            
            // ✅ Admin Comments Section
            if (_adminComments.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '💬 Admin Comments',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue[50],
                        border: Border.all(color: Colors.blue, width: 1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: _adminComments.map((comment) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  comment['message'] ?? '',
                                  style: const TextStyle(fontSize: 14),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'From: ${comment['from'] ?? 'Admin'} • ${_formatTimestamp(comment['createdAt'])}',
                                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    
                    // ✅ Status Notification
                    if (_reuploadAllowed)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.green[50],
                          border: Border.all(color: Colors.green, width: 1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.check_circle, color: Colors.green),
                            SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'You can re-upload files now.\nPlease correct the issues above.',
                                style: TextStyle(color: Colors.green, fontSize: 13),
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red[50],
                          border: Border.all(color: Colors.red, width: 1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.cancel, color: Colors.red),
                            SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'You cannot re-upload files yet.\nPlease wait for admin approval.',
                                style: TextStyle(color: Colors.red, fontSize: 13),
                              ),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            
            for (final label in formLabels) buildUploadField(label),
            const SizedBox(height: 32),
            Center(
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: isButtonDisabled ? null : handleSubmit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: buttonColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    textStyle: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.bold),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isUploading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text(buttonText),
                ),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  /// ✅ Format Firestore Timestamp to readable date format
  String _formatTimestamp(Timestamp? timestamp) {
    if (timestamp == null) return '';
    final dateTime = timestamp.toDate();
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${dateTime.month}/${dateTime.day}/${dateTime.year} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')} ${dateTime.hour >= 12 ? 'PM' : 'AM'}';
    }
  }
}
