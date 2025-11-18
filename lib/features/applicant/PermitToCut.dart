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
  String? _currentSubmissionId;
  List<Map<String, dynamic>> _existingSubmissions = [];
  bool _isLoadingSubmissions = true;
  
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
    _loadSubmissions();
    _loadApplicationTemplates();
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

  Future<void> _loadSubmissions() async {
    setState(() => _isLoadingSubmissions = true);
    try {
      final submissionsSnapshot = await FirebaseFirestore.instance
          .collection('applications')
          .doc('ptc')
          .collection('applicants')
          .doc(widget.applicantId)
          .collection('submissions')
          .orderBy('createdAt', descending: true)
          .get();
      
      setState(() {
        _existingSubmissions = submissionsSnapshot.docs.map((doc) {
          final data = doc.data();
          return {
            'id': doc.id,
            'createdAt': data['createdAt'],
            'status': data['status'] ?? 'pending',
            'uploadsCount': (data['uploads'] as Map?)?.length ?? 0,
          };
        }).toList();
        _isLoadingSubmissions = false;
      });
      
      if (_existingSubmissions.isEmpty) {
        await _createNewSubmission();
      } else {
        _currentSubmissionId = _existingSubmissions.first['id'];
        await _loadExistingUploads();
        await _loadDocumentComments();
      }
    } catch (e) {
      print('Error loading submissions: $e');
      setState(() => _isLoadingSubmissions = false);
    }
  }
  
  Future<void> _createNewSubmission() async {
    try {
      final submissionCount = _existingSubmissions.length + 1;
      final newSubmissionId = 'PTC-${widget.applicantId}-${submissionCount.toString().padLeft(3, '0')}';
      
      final submissionRef = FirebaseFirestore.instance
          .collection('applications')
          .doc('ptc')
          .collection('applicants')
          .doc(widget.applicantId)
          .collection('submissions')
          .doc(newSubmissionId);
      
      await submissionRef.set({
        'applicantName': widget.applicantName,
        'createdAt': FieldValue.serverTimestamp(),
        'status': 'draft',
        'uploads': {},
      });
      
      setState(() {
        _currentSubmissionId = newSubmissionId;
        _existingSubmissions.insert(0, {
          'id': newSubmissionId,
          'createdAt': Timestamp.now(),
          'status': 'draft',
          'uploadsCount': 0,
        });
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('New submission created: $newSubmissionId')),
        );
      }
    } catch (e) {
      print('Error creating submission: $e');
    }
  }
  
  Future<void> _switchSubmission(String submissionId) async {
    setState(() {
      _currentSubmissionId = submissionId;
      for (final label in formLabels) {
        uploadedFiles[label["title"]!] = {"file": null, "url": null};
      }
    });
    await _loadExistingUploads();
    await _loadDocumentComments();
  }

  Future<void> _loadExistingUploads() async {
    if (_currentSubmissionId == null) return;
    
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
    if (_currentSubmissionId == null) return;
    
    try {
      final submissionDocRef = FirebaseFirestore.instance
          .collection('applications')
          .doc('ptc')
          .collection('applicants')
          .doc(widget.applicantId)
          .collection('submissions')
          .doc(_currentSubmissionId);

      // Get submission document to check for uploads map
      final submissionSnapshot = await submissionDocRef.get();
      final submissionData = submissionSnapshot.data();
      final uploadsMap = submissionData?['uploads'] as Map<String, dynamic>?;

      // Load each document's comments and reuploadAllowed flag
      for (final label in formLabels) {
        final title = label['title']!;
        final sanitizedTitle = _sanitizeDocTitle(title);
        
        // Check reuploadAllowed from submission document's uploads map first
        // Try both original title and sanitized title as keys
        bool reuploadAllowed = false;
        if (uploadsMap != null) {
          Map<String, dynamic>? uploadMapData;
          
          // Try original title first
          if (uploadsMap.containsKey(title)) {
            uploadMapData = uploadsMap[title] as Map<String, dynamic>?;
          }
          // Try sanitized title if original not found
          else if (uploadsMap.containsKey(sanitizedTitle)) {
            uploadMapData = uploadsMap[sanitizedTitle] as Map<String, dynamic>?;
          }
          
          if (uploadMapData != null) {
            reuploadAllowed = uploadMapData['reuploadAllowed'] as bool? ?? false;
          }
        }
        
        // Get the upload document metadata from subcollection
        final uploadDoc = await submissionDocRef.collection('uploads').doc(sanitizedTitle).get();
        
        if (uploadDoc.exists) {
          final uploadData = uploadDoc.data();
          // Override with subcollection value if it exists
          reuploadAllowed = uploadData?['reuploadAllowed'] as bool? ?? reuploadAllowed;
        }
        
        // Get the most recent comment from subcollection
        final commentsSnapshot = await submissionDocRef
            .collection('uploads')
            .doc(sanitizedTitle)
            .collection('comments')
            .orderBy('commentedAt', descending: true)
            .limit(1)
            .get();
        
        if (commentsSnapshot.docs.isNotEmpty) {
          final commentDoc = commentsSnapshot.docs.first;
          final commentData = commentDoc.data();
          
          _documentComments[title] = {
            'reuploadAllowed': reuploadAllowed,
            'message': commentData['comment'] as String?,
            'commentedAt': commentData['commentedAt'],
            'commenterId': commentData['commenterId'] as String?,
          };
        } else if (reuploadAllowed) {
          // Has reuploadAllowed flag but no comments
          _documentComments[title] = {
            'reuploadAllowed': reuploadAllowed,
            'message': null,
          };
        }
      }
      final uploadsRef = FirebaseFirestore.instance
          .collection('applications')
          .doc('ptc')
          .collection('applicants')
          .doc(widget.applicantId)
          .collection('submissions')
          .doc(_currentSubmissionId!)
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

  /// Sanitize document title to be used as Firestore document ID
  String _sanitizeDocTitle(String title) {
    return title.replaceAll(RegExp(r'[.#$/\[\]]'), '-').trim();
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
    if (_currentSubmissionId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No submission selected')),
      );
      return;
    }
    
    setState(() => _isUploading = true);

    try {
      final firestore = FirebaseFirestore.instance;
      final storage = FirebaseStorage.instance;

      final submissionDoc = firestore
          .collection('applications')
          .doc('ptc')
          .collection('applicants')
          .doc(widget.applicantId)
          .collection('submissions')
          .doc(_currentSubmissionId!);
      final userUploadsRef = firestore
          .collection('users')
          .doc(widget.applicantId)
          .collection('ptc_uploads');
      final applicantUploadsRef = submissionDoc.collection('uploads');

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

      // Reset reuploadAllowed flag in submission
      await submissionDoc.set({
        'uploads.$safeTitle.reuploadAllowed': false,
        'lastUpdated': FieldValue.serverTimestamp(),
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
    if (_currentSubmissionId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No submission selected')),
      );
      return;
    }
    
    setState(() => _isUploading = true);

    try {
      final firestore = FirebaseFirestore.instance;
      final storage = FirebaseStorage.instance;

      final submissionDoc = firestore
          .collection('applications')
          .doc('ptc')
          .collection('applicants')
          .doc(widget.applicantId)
          .collection('submissions')
          .doc(_currentSubmissionId!);
      final userUploadsRef = firestore
          .collection('users')
          .doc(widget.applicantId)
          .collection('ptc_uploads');
      final applicantUploadsRef = submissionDoc.collection('uploads');

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

      // Update submission document
      await submissionDoc.set({
        'applicantName': widget.applicantName,
        'status': 'submitted',
        'submittedAt': FieldValue.serverTimestamp(),
        ...uploadsFieldUpdates,
      }, SetOptions(merge: true));

      // Update applicant document count
      final applicantDoc = firestore
          .collection('applications')
          .doc('ptc')
          .collection('applicants')
          .doc(widget.applicantId);
      
      final submissionsSnapshot = await applicantDoc.collection('submissions').get();
      await applicantDoc.set({
        'applicantName': widget.applicantName,
        'submissionsCount': submissionsSnapshot.docs.length,
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
      body: _isLoadingSubmissions
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Submission Selector
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.green[200]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.folder_open, color: Colors.green[700], size: 24),
                          const SizedBox(width: 8),
                          Text(
                            'Your Submissions',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.green[900],
                            ),
                          ),
                        ],
                      ),
                      ElevatedButton.icon(
                        onPressed: _createNewSubmission,
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('New'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green[700],
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (_existingSubmissions.isEmpty)
                    const Text('No submissions yet.')
                  else
                    DropdownButtonFormField<String>(
                      value: _currentSubmissionId,
                      decoration: InputDecoration(
                        labelText: 'Select Submission',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                      items: _existingSubmissions.map((submission) {
                        return DropdownMenuItem<String>(
                          value: submission['id'] as String,
                          child: Row(
                            children: [
                              Icon(
                                submission['status'] == 'submitted'
                                    ? Icons.check_circle
                                    : Icons.edit_note,
                                color: submission['status'] == 'submitted'
                                    ? Colors.green
                                    : Colors.orange,
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '${submission['id']}',
                                style: const TextStyle(fontSize: 14),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: (value) {
                        if (value != null) {
                          _switchSubmission(value);
                        }
                      },
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),
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
