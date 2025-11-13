import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as path;
import 'package:url_launcher/url_launcher.dart';

class CTPOUploadPage extends StatefulWidget {
  final String applicantId;
  final String applicantName;

  const CTPOUploadPage({
    super.key,
    required this.applicantId,
    required this.applicantName,
  });

  @override
  State<CTPOUploadPage> createState() => _CTPOUploadPageState();
}

class _CTPOUploadPageState extends State<CTPOUploadPage> {
  final List<Map<String, String>> formLabels = [
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
      "title": "Endorsement from concerned LGU interposing no objection to the cutting of trees",
      "description": "(1 original)"
    },
    {
      "title": "If the trees to be cut fall within one barangay, endorsement from the Barangay Captain",
      "description": ""
    },
    {
      "title": "If within more than one barangay, endorsement from the Municipal/City Mayor or all Captains",
      "description": ""
    },
    {
      "title": "If within more than one municipality/city, endorsement from the Provincial Governor or all Mayors",
      "description": ""
    },
    {
      "title": "Special Power of Attorney (SPA) – Applicable if the client is a representative",
      "description": "(1 original)"
    },
  ];

  final Map<String, Map<String, dynamic>> uploadedFiles = {};
  bool _isUploading = false;
  Map<String, Map<String, dynamic>> _documentComments = {}; // ✅ Store comments per document
  List<Map<String, dynamic>> _availableTemplates = []; // ✅ Store all available templates

  @override
  void initState() {
    super.initState();
    for (final label in formLabels) {
      uploadedFiles[label["title"]!] = {"file": null, "url": null};
    }
    _loadExistingUploads();
    _loadDocumentComments(); // ✅ Load comments per document
    _loadApplicationTemplates(); // ✅ Load application-level templates
  }

  /// ✅ Load application-level templates from Firestore
  Future<void> _loadApplicationTemplates() async {
    try {
      final templatesSnapshot = await FirebaseFirestore.instance
          .collection('applications')
          .doc('ctpo')
          .collection('templates')
          .get();

      if (templatesSnapshot.docs.isNotEmpty) {
        setState(() {
          _availableTemplates = templatesSnapshot.docs.map((doc) {
            final data = doc.data();
            return {
              'documentType': data['documentType'] ?? doc.id,
              'title': data['title'] ?? '',
              'description': data['description'] ?? '',
              'fileName': data['fileName'] ?? '',
              'url': data['url'] ?? '',
              'uploadedAt': data['uploadedAt'],
            };
          }).toList();
        });
        print("✅ Loaded ${_availableTemplates.length} templates for CTPO");
      }
    } catch (e) {
      print("❌ Error loading application templates: $e");
    }
  }

  /// Load already uploaded files (from applications → ctpo → applicants → uploads)
  Future<void> _loadExistingUploads() async {
    final uploadsRef = FirebaseFirestore.instance
        .collection('applications')
        .doc('ctpo')
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

  /// ✅ Load comments per document from uploads subcollection
  Future<void> _loadDocumentComments() async {
    try {
      final uploadsRef = FirebaseFirestore.instance
          .collection('applications')
          .doc('ctpo')
          .collection('applicants')
          .doc(widget.applicantId)
          .collection('uploads');

      final uploadsSnapshot = await uploadsRef.get();
      
      print("📄 Found ${uploadsSnapshot.docs.length} upload documents");
      
      // Iterate through each upload document
      for (final uploadDoc in uploadsSnapshot.docs) {
        final docKey = uploadDoc.id; // e.g., "Letter of Application"
        final docData = uploadDoc.data();
        
        print("📄 Processing document: $docKey");
        
        // Get reuploadAllowed from the upload document
        final reuploadAllowed = docData['reuploadAllowed'] as bool? ?? false;
        print("📄 reuploadAllowed: $reuploadAllowed");
        
        // Get comments from the subcollection
        final commentsSnapshot = await uploadDoc.reference
            .collection('comments')
            .orderBy('createdAt', descending: true)
            .limit(1)
            .get();
        
        Map<String, dynamic>? mostRecentComment;
        if (commentsSnapshot.docs.isNotEmpty) {
          final commentDoc = commentsSnapshot.docs.first;
          mostRecentComment = commentDoc.data();
          print("📄 Most recent comment: ${mostRecentComment['message']}");
        }
        
        // Try exact match first
        String? matchingTitle;
        if (uploadedFiles.containsKey(docKey)) {
          matchingTitle = docKey;
          print("✅ Exact match found: $docKey");
        } else {
          // Find matching form label title
          for (final label in formLabels) {
            final title = label["title"]!;
            final safeTitle = title.replaceAll(RegExp(r'[.#$/\[\]]'), '-').trim();
            
            if (docKey == safeTitle) {
              matchingTitle = title;
              print("✅ Safe title match: $docKey -> $title");
              break;
            }
          }
        }
        
        if (matchingTitle != null) {
          _documentComments[matchingTitle] = {
            'reuploadAllowed': reuploadAllowed,
            'from': mostRecentComment?['from'] as String? ?? 'Admin',
            'message': mostRecentComment?['message'] as String? ?? '',
            'createdAt': _parseCommentTimestamp(mostRecentComment?['createdAt']),
          };
          
          print("✅ Stored comment for $matchingTitle");
        } else {
          print("❌ No matching title found for docKey: $docKey");
        }
      }

      print("📄 Final _documentComments: $_documentComments");

      setState(() {});
    } catch (e) {
      print("❌ Error loading document comments: $e");
    }
  }

  /// Parse comment timestamp (can be Timestamp or String)
  Timestamp? _parseCommentTimestamp(dynamic timestamp) {
    if (timestamp == null) return null;
    
    if (timestamp is Timestamp) {
      return timestamp;
    }
    
    // If it's a string like "November 11, 2025 at 10:55:18 AM UTC+8"
    if (timestamp is String) {
      try {
        // Remove UTC timezone info and parse
        final cleanedStr = timestamp
            .replaceAll(RegExp(r'\s*at\s*'), ' ')
            .replaceAll(RegExp(r'\s*UTC[+-]\d+$'), '');
        final dateTime = DateTime.parse(cleanedStr);
        return Timestamp.fromDate(dateTime);
      } catch (e) {
        print("Error parsing timestamp string: $e");
        return null;
      }
    }
    
    return null;
  }

  /// Selects a file and automatically uploads it (for reupload scenario)
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

      // Check if this is a reupload (file already uploaded)
      final isReupload = uploadedFiles[title]!["url"] != null;
      
      if (isReupload) {
        // Auto-upload immediately for reuploads
        await uploadSingleFile(title, file);
      } else {
        // For initial uploads, just store the file
        setState(() {
          uploadedFiles[title]!["file"] = file;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error selecting file: $e")),
      );
    }
  }

  /// Upload a single file immediately
  Future<void> uploadSingleFile(String title, PlatformFile file) async {
    setState(() => _isUploading = true);

    try {
      final firestore = FirebaseFirestore.instance;
      final storage = FirebaseStorage.instance;

      // References
      final appDoc = firestore.collection('applications').doc('ctpo');
      final applicantDoc = appDoc.collection('applicants').doc(widget.applicantId);
      final userUploadsRef = firestore
          .collection('users')
          .doc(widget.applicantId)
          .collection('ctpo_uploads');
      final applicantUploadsRef = applicantDoc.collection('uploads');

      final safeTitle = title.replaceAll(RegExp(r'[.#$/\[\]]'), '-').trim();
      final fileName = "${DateTime.now().millisecondsSinceEpoch}_${file.name}";
      final ref = storage.ref().child("ctpo_uploads/$fileName");

      // Upload file
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

      // Save to all locations
      await userUploadsRef.doc(safeTitle).set(uploadData);
      await applicantUploadsRef.doc(safeTitle).set(uploadData, SetOptions(merge: true));

      // Reset reuploadAllowed flag
      await applicantDoc.set({
        'uploads.$safeTitle.reuploadAllowed': false,
      }, SetOptions(merge: true));

      // Update local state
      uploadedFiles[title]!["url"] = url;
      uploadedFiles[title]!["file"] = null;

      // Reload comments and uploads
      await _loadDocumentComments();
      await _loadExistingUploads();

      if (mounted) {
        setState(() => _isUploading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("$title uploaded successfully!")),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isUploading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error uploading file: $e")),
        );
      }
    }
  }

  /// Handles all uploads and synchronization (hybrid write)
  Future<void> handleSubmit() async {
    setState(() => _isUploading = true);

    try {
      final firestore = FirebaseFirestore.instance;
      final storage = FirebaseStorage.instance;

      // References
      final appDoc = firestore.collection('applications').doc('ctpo');
      final applicantDoc = appDoc.collection('applicants').doc(widget.applicantId);
      final userUploadsRef = firestore
          .collection('users')
          .doc(widget.applicantId)
          .collection('ctpo_uploads');
      final applicantUploadsRef = applicantDoc.collection('uploads');

      // Prepare updates for the uploads field in applicant document
      Map<String, dynamic> uploadsFieldUpdates = {};

      // Upload files one by one
      for (final entry in uploadedFiles.entries) {
        final title = entry.key;
        final file = entry.value["file"] as PlatformFile?;
        if (file == null) continue;

        final safeTitle = title.replaceAll(RegExp(r'[.#$/\[\]]'), '-').trim();
        final fileName = "${DateTime.now().millisecondsSinceEpoch}_${file.name}";
        final ref = storage.ref().child("ctpo_uploads/$fileName");

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

        // 1️⃣ Save inside user → ctpo_uploads
        await userUploadsRef.doc(safeTitle).set(uploadData);

        // 2️⃣ Save inside applications → ctpo → applicants → uploads (subcollection)
        await applicantUploadsRef.doc(safeTitle).set(uploadData, SetOptions(merge: true));

        // 3️⃣ Reset reuploadAllowed in the uploads field (where comments are stored)
        uploadsFieldUpdates['uploads.$safeTitle.reuploadAllowed'] = false;

        uploadedFiles[title]!["url"] = url;
        uploadedFiles[title]!["file"] = null; // ✅ Clear selected file after upload
      }

      // Update the applicant document with reset reuploadAllowed flags
      if (uploadsFieldUpdates.isNotEmpty) {
        await applicantDoc.set(uploadsFieldUpdates, SetOptions(merge: true));
      }

      // ✅ Reload comments to update UI with new reuploadAllowed status
      await _loadDocumentComments();
      await _loadExistingUploads();

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
    
    // ✅ Get per-document reuploadAllowed flag and comments
    final docData = _documentComments[title];
    final reuploadAllowed = docData?['reuploadAllowed'] as bool? ?? false;
    final hasComments = docData?['message'] != null && (docData?['message'] as String?)?.isNotEmpty == true;
    final comment = docData;

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
                    Text(description,
                        style: const TextStyle(fontSize: 13, color: Colors.black87)),
                    
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
                // ✅ Button disabled if already uploaded and reupload not allowed, or if there are unresolved comments
                onPressed: (isUploaded && !reuploadAllowed) || _isUploading ? null : () => pickFile(title),
                style: ElevatedButton.styleFrom(
                  backgroundColor: (isUploaded && !reuploadAllowed)
                      ? Colors.grey
                      : (isUploaded
                          ? Colors.orange
                          : Colors.green[700]),
                  foregroundColor: Colors.white,
                ),
                child: Text(
                  isUploaded
                      ? (reuploadAllowed ? "Re-upload" : "Uploaded")
                      : (file != null ? "Change File" : "Select File"),
                ),
              ),
            ],
          ),
          
          // ✅ Show admin comment if exists
          if (hasComments && comment != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange[50],
                  border: Border.all(color: Colors.orange, width: 1),
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
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.orange[700],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      comment['message'] ?? '',
                      style: const TextStyle(fontSize: 13, color: Colors.black87),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'From: ${comment['from'] ?? 'Admin'} • ${_formatTimestamp(comment['createdAt'])}',
                      style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                    ),
                    if (reuploadAllowed)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.green[50],
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.check_circle, color: Colors.green, size: 16),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'You can re-upload this file',
                                  style: TextStyle(fontSize: 12, color: Colors.green),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 8),
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
            
            // ✅ Available Templates Section
            if (_availableTemplates.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue[200]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.folder_special, color: Colors.blue[700], size: 24),
                        const SizedBox(width: 8),
                        Text(
                          'Available Templates',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue[900],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Download these templates before preparing your documents',
                      style: TextStyle(fontSize: 13, color: Colors.blue[800]),
                    ),
                    const Divider(height: 16),
                    ..._availableTemplates.map((template) => _buildTemplateCard(template)),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],
            
            const Text(
              'Upload Documents for Certificate of Tree Plantation Ownership (CTPO)',
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

  /// ✅ Build template card widget
  Widget _buildTemplateCard(Map<String, dynamic> template) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 2,
      child: ListTile(
        leading: Icon(Icons.description, color: Colors.blue[700], size: 32),
        title: Text(
          template['documentType'] ?? 'Template',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (template['title']?.isNotEmpty == true)
              Text(
                template['title'],
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
              ),
            if (template['description']?.isNotEmpty == true)
              Text(
                template['description'],
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.insert_drive_file, size: 14, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    template['fileName'] ?? '',
                    style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ),
        trailing: ElevatedButton.icon(
          onPressed: () async {
            final url = template['url'] as String?;
            if (url != null && url.isNotEmpty) {
              try {
                final uri = Uri.parse(url);
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                } else {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Cannot open template")),
                    );
                  }
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("Error opening template: $e")),
                  );
                }
              }
            }
          },
          icon: const Icon(Icons.download, size: 16),
          label: const Text("Download", style: TextStyle(fontSize: 12)),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue[700],
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          ),
        ),
        isThreeLine: true,
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
