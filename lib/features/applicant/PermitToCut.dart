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
  Map<String, Map<String, dynamic>> _documentComments =
      {}; // Per-document comments
  List<Map<String, dynamic>> _availableTemplates = []; // ✅ Store all available templates

  @override
  void initState() {
    super.initState();
    for (final label in formLabels) {
      uploadedFiles[label["title"]!] = {"file": null, "url": null};
    }
    _loadExistingUploads();
    _loadDocumentComments();
    _loadApplicationTemplates(); // ✅ Load application-level templates
  }

  /// ✅ Load application-level templates from Firestore
  Future<void> _loadApplicationTemplates() async {
    try {
      final templatesSnapshot = await FirebaseFirestore.instance
          .collection('applications')
          .doc('ptc')
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
        print("✅ Loaded ${_availableTemplates.length} templates for PTC");
      }
    } catch (e) {
      print("❌ Error loading application templates: $e");
    }
  }

  Future<void> _loadExistingUploads() async {
    final uploadsRef = FirebaseFirestore.instance
        .collection('applications')
        .doc('ptc')
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

  /// Load document-specific comments from uploads subcollection
  Future<void> _loadDocumentComments() async {
    try {
      final uploadsRef = FirebaseFirestore.instance
          .collection('applications')
          .doc('ptc')
          .collection('applicants')
          .doc(widget.applicantId)
          .collection('uploads');

      final uploadsSnapshot = await uploadsRef.get();
      
      print("📄 Found ${uploadsSnapshot.docs.length} upload documents");
      
      final Map<String, Map<String, dynamic>> tempComments = {};

      for (final uploadDoc in uploadsSnapshot.docs) {
        final docKey = uploadDoc.id;
        final docData = uploadDoc.data();

        final reuploadAllowed = docData['reuploadAllowed'] as bool? ?? false;
        
        print("📄 Processing document: $docKey, reuploadAllowed: $reuploadAllowed");

        // Get comments from the subcollection
        final commentsSnapshot = await uploadDoc.reference
            .collection('comments')
            .orderBy('createdAt', descending: true)
            .limit(1)
            .get();

        Map<String, dynamic>? mostRecentComment;
        if (commentsSnapshot.docs.isNotEmpty) {
          mostRecentComment = commentsSnapshot.docs.first.data();
          print("📄 Most recent comment: ${mostRecentComment['message']}");
        }

        // Try exact match first
        String? matchingTitle;
        if (uploadedFiles.containsKey(docKey)) {
          matchingTitle = docKey;
        } else {
          // Find matching form label title
          for (final label in formLabels) {
            final title = label["title"]!;
            final safeTitle = title.replaceAll(RegExp(r'[.#$/\[\]]'), '-').trim();
            
            if (docKey == safeTitle) {
              matchingTitle = title;
              break;
            }
          }
        }

        if (matchingTitle != null) {
          tempComments[matchingTitle] = {
            'reuploadAllowed': reuploadAllowed,
            'comment': mostRecentComment != null ? {
              'message': mostRecentComment['message'] as String? ?? '',
              'from': mostRecentComment['from'] as String? ?? 'Admin',
              'createdAt': _parseCommentTimestamp(mostRecentComment['createdAt']),
            } : null,
          };
        }
      }

      setState(() {
        _documentComments = tempComments;
      });
    } catch (e) {
      print("Error loading document comments: $e");
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
      final appDoc = firestore.collection('applications').doc('ptc');
      final applicantDoc = appDoc.collection('applicants').doc(widget.applicantId);
      final userUploadsRef = firestore
          .collection('users')
          .doc(widget.applicantId)
          .collection('ptc_uploads');
      final applicantUploadsRef = applicantDoc.collection('uploads');

      final safeTitle = title.replaceAll(RegExp(r'[.#$/\[\]]'), '-').trim();
      final fileName = "${DateTime.now().millisecondsSinceEpoch}_${file.name}";
      final ref = storage.ref().child("ptc_uploads/$fileName");

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

        // 2️⃣ Save inside applications → ptc → applicants → uploads (subcollection)
        await applicantUploadsRef.doc(safeTitle).set(uploadData, SetOptions(merge: true));

        // 3️⃣ Reset reuploadAllowed in uploads field
        uploadsFieldUpdates['uploads.$safeTitle.reuploadAllowed'] = false;

        uploadedFiles[title]!["url"] = url;
        uploadedFiles[title]!["file"] = null; // ✅ Clear selected file after upload
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

      // ✅ Reload comments and existing uploads to update UI
      await _loadDocumentComments();
      await _loadExistingUploads();

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
                      style:
                          const TextStyle(fontSize: 13, color: Colors.black87),
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
                // ✅ Disable button if uploaded and reupload NOT allowed, or if currently uploading
                onPressed: (isUploaded && !reuploadAllowed) || _isUploading 
                    ? null 
                    : () => pickFile(title),
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
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 12),
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

  /// Format timestamp to readable string
  String _formatTimestamp(dynamic timestamp) {
    if (timestamp == null) return '';
    if (timestamp is Timestamp) {
      final DateTime dateTime = timestamp.toDate();
      return '${dateTime.month}/${dateTime.day}/${dateTime.year}';
    }
    return '';
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
