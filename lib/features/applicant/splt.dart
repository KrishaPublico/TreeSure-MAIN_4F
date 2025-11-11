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
  Map<String, Map<String, dynamic>> _documentComments = {}; // Per-document comments

  @override
  void initState() {
    super.initState();
    for (final label in formLabels) {
      uploadedFiles[label["title"]!] = {"file": null, "url": null};
    }
    _loadExistingUploads();
    _loadDocumentComments();
  }

  Future<void> _loadExistingUploads() async {
    final uploadsRef = FirebaseFirestore.instance
        .collection('applications')
        .doc('splt')
        .collection('applicants')
        .doc(widget.applicantId)
        .collection('uploads');

    final snapshot = await uploadsRef.get();
    
    for (final doc in snapshot.docs) {
      final data = doc.data();
      final docId = doc.id; // Document ID (e.g., "Letter of Application")
      final url = data['url'] as String?;
      
      // Try exact match first
      if (uploadedFiles.containsKey(docId)) {
        uploadedFiles[docId]!["url"] = url;
        continue;
      }
      
      // Match document ID to form label titles
      for (final label in formLabels) {
        final title = label["title"]!;
        final safeTitle = title.replaceAll(RegExp(r'[.#$/\[\]]'), '-').trim();
        
        if (docId == safeTitle || docId == title) {
          uploadedFiles[title]!["url"] = url;
          break;
        }
      }
    }
    setState(() {});
  }

  /// Load document-specific comments from Firestore uploads field
  Future<void> _loadDocumentComments() async {
    try {
      final applicantRef = FirebaseFirestore.instance
          .collection('applications')
          .doc('splt')
          .collection('applicants')
          .doc(widget.applicantId);

      final snapshot = await applicantRef.get();
      if (!snapshot.exists) return;

      final data = snapshot.data();
      final uploadsMap = data?['uploads'] as Map<String, dynamic>?;
      if (uploadsMap == null) return;

      final Map<String, Map<String, dynamic>> tempComments = {};

      for (final entry in uploadsMap.entries) {
        final documentKey = entry.key;
        final documentData = entry.value as Map<String, dynamic>?;
        
        if (documentData == null) continue;

        // Find matching form title (exact match or sanitized)
        String? matchingTitle;
        for (final label in formLabels) {
          final title = label["title"]!;
          final sanitizedTitle = title.replaceAll(RegExp(r'[^\w\s]+'), '');
          if (documentKey == title || documentKey == sanitizedTitle) {
            matchingTitle = title;
            break;
          }
        }

        if (matchingTitle != null) {
          final reuploadAllowed = documentData['reuploadAllowed'] as bool? ?? false;
          final commentsMap = documentData['comments'] as Map<String, dynamic>?;
          
          if (commentsMap != null && commentsMap.isNotEmpty) {
            final commentEntry = commentsMap.entries.first;
            final commentData = commentEntry.value as Map<String, dynamic>?;
            
            if (commentData != null) {
              tempComments[matchingTitle] = {
                'reuploadAllowed': reuploadAllowed,
                'comment': {
                  'message': commentData['message'] as String? ?? '',
                  'from': commentData['from'] as String? ?? 'Admin',
                  'createdAt': commentData['createdAt'] as Timestamp?,
                },
              };
            }
          } else if (reuploadAllowed) {
            tempComments[matchingTitle] = {
              'reuploadAllowed': true,
              'comment': null,
            };
          }
        }
      }

      setState(() {
        _documentComments = tempComments;
      });
    } catch (e) {
      print("Error loading document comments: $e");
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

      // Prepare updates map for uploads field
      Map<String, dynamic> uploadsFieldUpdates = {};

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

        // 2️⃣ Save inside applications → splt → applicants → uploads (subcollection)
        await applicantUploadsRef.doc(safeTitle).set(uploadData, SetOptions(merge: true));

        // 3️⃣ Reset reuploadAllowed in uploads field
        uploadsFieldUpdates['uploads.$safeTitle.reuploadAllowed'] = false;

        uploadedFiles[title]!["url"] = url;
      }

      // Update applicant document with metadata and reset reuploadAllowed
      await applicantDoc.set({
        'applicantName': widget.applicantName,
        'uploadedAt': FieldValue.serverTimestamp(),
        ...uploadsFieldUpdates,
      }, SetOptions(merge: true));

      // Update main summary document
      final applicantsSnapshot = await appDoc.collection('applicants').get();
      final uploadedCount = applicantsSnapshot.docs.length;

      await appDoc.set({
        'uploadedCount': uploadedCount,
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // Reload document comments
      await _loadDocumentComments();

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

    // Get per-document comment data
    final documentData = _documentComments[title];
    final reuploadAllowed = documentData?['reuploadAllowed'] as bool? ?? false;
    final comment = documentData?['comment'] as Map<String, dynamic>?;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
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
                          final Uri uri = Uri.parse(url);
                          if (!await launchUrl(uri,
                              mode: LaunchMode.externalApplication)) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text("Could not open the file")),
                              );
                            }
                          }
                        },
                        child: const Text(
                          'View Uploaded File',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton(
                onPressed: () => pickFile(title),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isUploaded
                      ? (reuploadAllowed ? Colors.orange : Colors.grey[300])
                      : Colors.green[700],
                  foregroundColor: isUploaded
                      ? (reuploadAllowed ? Colors.white : Colors.grey[600])
                      : Colors.white,
                ),
                child: Text(
                  isUploaded
                      ? (reuploadAllowed ? 'Re-upload' : 'Uploaded')
                      : file != null
                          ? 'Change'
                          : 'Choose File',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ),
            ],
          ),
          // Show comment inline if exists
          if (comment != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange[50],
                border: Border.all(color: Colors.orange, width: 1.5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.comment, color: Colors.orange, size: 18),
                      const SizedBox(width: 8),
                      Text(
                        'Admin Comment',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: Colors.orange[800],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    comment['message'] as String? ?? '',
                    style: const TextStyle(fontSize: 13, color: Colors.black87),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'From: ${comment['from'] ?? 'Admin'} ${comment['createdAt'] != null ? '• ${_formatTimestamp(comment['createdAt'])}' : ''}',
                    style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
          ],
          // Show reupload permission indicator
          if (reuploadAllowed && comment == null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.green[50],
                border: Border.all(color: Colors.green, width: 1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.green[600], size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Re-upload allowed for this document',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.green[700],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// UI
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
                    textStyle: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.bold),
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
