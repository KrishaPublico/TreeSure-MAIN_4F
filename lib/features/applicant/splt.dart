import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:path/path.dart' as path;
import 'package:url_launcher/url_launcher.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

class SPLTFormPage extends StatefulWidget {
  final String applicantId;
  final String applicantName;
  const SPLTFormPage(
      {super.key, required this.applicantId, required this.applicantName});

  @override
  _SPLTFormPageState createState() => _SPLTFormPageState();
}


class PdfPreviewPage extends StatelessWidget {
  final String url;
  const PdfPreviewPage({super.key, required this.url});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('PDF Preview')),
      body: SfPdfViewer.network(url),
    );
  }
}
class _SPLTFormPageState extends State<SPLTFormPage> {
  // Submission state
  String? _currentSubmissionId;
  List<Map<String, dynamic>> _existingSubmissions = [];
  bool _isLoadingSubmissions = true;

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
  List<Map<String, dynamic>> _availableTemplates = []; // ✅ Store all available templates

  @override
  void initState() {
    super.initState();
    for (final label in formLabels) {
      uploadedFiles[label["title"]!] = {"file": null, "url": null};
    }
    _loadSubmissions();
  }

  /// Load all submissions for this applicant
  Future<void> _loadSubmissions() async {
    try {
      final firestore = FirebaseFirestore.instance;
      final submissionsSnapshot = await firestore
          .collection('applications')
          .doc('splt')
          .collection('applicants')
          .doc(widget.applicantId)
          .collection('submissions')
          .orderBy('createdAt', descending: true)
          .get();

      if (submissionsSnapshot.docs.isEmpty) {
        await _createNewSubmission();
      } else {
        _existingSubmissions = submissionsSnapshot.docs.map((doc) {
          final data = doc.data();
          return {
            'id': doc.id,
            'status': data['status'] ?? 'draft',
            'uploadsCount': (data['uploads'] as Map?)?.length ?? 0,
            'createdAt': data['createdAt'],
          };
        }).toList();

        setState(() {
          _currentSubmissionId = _existingSubmissions.first['id'] as String;
          _isLoadingSubmissions = false;
        });

        await _loadExistingUploads();
        await _loadDocumentComments();
        await _loadApplicationTemplates();
      }
    } catch (e) {
      print('Error loading submissions: $e');
      setState(() => _isLoadingSubmissions = false);
    }
  }

  Future<void> _createNewSubmission() async {
    try {
      final firestore = FirebaseFirestore.instance;
      final applicantDoc = firestore
          .collection('applications')
          .doc('splt')
          .collection('applicants')
          .doc(widget.applicantId);

      final submissionsSnapshot = await applicantDoc.collection('submissions').get();
      final nextNumber = submissionsSnapshot.docs.length + 1;
      final submissionId = 'SPLT-${widget.applicantId}-${nextNumber.toString().padLeft(3, '0')}';

      await applicantDoc.collection('submissions').doc(submissionId).set({
        'applicantName': widget.applicantName,
        'status': 'draft',
        'createdAt': FieldValue.serverTimestamp(),
      });

      await _loadSubmissions();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('New submission created: $submissionId')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error creating submission: $e')),
        );
      }
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

  /// ✅ Load application-level templates from Firestore
  Future<void> _loadApplicationTemplates() async {
    try {
      final templatesSnapshot = await FirebaseFirestore.instance
          .collection('applications')
          .doc('splt')
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
        print("✅ Loaded ${_availableTemplates.length} templates for SPLT");
      }
    } catch (e) {
      print("❌ Error loading application templates: $e");
    }
  }

  Future<void> _loadExistingUploads() async {
    if (_currentSubmissionId == null) return;
    
    final uploadsRef = FirebaseFirestore.instance
        .collection('applications')
        .doc('splt')
        .collection('applicants')
        .doc(widget.applicantId)
        .collection('submissions')
        .doc(_currentSubmissionId!)
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
          .doc('splt')
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
          .doc('splt')
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

        // Find matching form title (exact match or sanitized)
        String? matchingTitle;
        for (final label in formLabels) {
          final title = label["title"]!;
          final sanitizedTitle = title.replaceAll(RegExp(r'[^\w\s]+'), '');
          if (docKey == title || docKey == sanitizedTitle) {
            matchingTitle = title;
            break;
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
        const SnackBar(content: Text('⚠️ No submission selected. Please create or switch to a submission first.')),
      );
      return;
    }
    
    setState(() => _isUploading = true);

    try {
      final submissionRef = FirebaseFirestore.instance
          .collection('applications')
          .doc('splt')
          .collection('applicants')
          .doc(widget.applicantId)
          .collection('submissions')
          .doc(_currentSubmissionId);

      final sanitizedTitle = _sanitizeDocTitle(title);
      final uploadDocRef = submissionRef.collection('uploads').doc(sanitizedTitle);
      
      // Upload file logic
      final String fileName = '${widget.applicantId}_${title}_${DateTime.now().millisecondsSinceEpoch}${path.extension(file.name)}';
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('applications/splt/${widget.applicantId}/$_currentSubmissionId/$fileName');

      String? downloadUrl;

      if (kIsWeb) {
        if (file.bytes != null) {
          await storageRef.putData(file.bytes!);
          downloadUrl = await storageRef.getDownloadURL();
        }
      } else {
        if (file.path != null) {
          final uploadTask = storageRef.putFile(File(file.path!));
          final snapshot = await uploadTask;
          downloadUrl = await snapshot.ref.getDownloadURL();
        }
      }

      if (downloadUrl != null) {
        // Update Firestore with new file and clear reuploadAllowed flag
        await uploadDocRef.set({
          'title': title,
          'fileName': file.name,
          'url': downloadUrl,
          'uploadedAt': FieldValue.serverTimestamp(),
          'reuploadAllowed': false, // Clear reupload flag after successful upload
        }, SetOptions(merge: true));

        setState(() {
          uploadedFiles[title]!['url'] = downloadUrl;
          uploadedFiles[title]!['file'] = null;
          uploadedFiles[title]!['fileName'] = file.name;
          // Clear the comment data since reupload is done
          _documentComments[title]?['reuploadAllowed'] = false;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('✅ $title uploaded successfully!')),
          );
        }
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
          .doc('splt')
          .collection('applicants')
          .doc(widget.applicantId)
          .collection('submissions')
          .doc(_currentSubmissionId!);
      final userUploadsRef = firestore
          .collection('users')
          .doc(widget.applicantId)
          .collection('splt_uploads');
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

        // 2️⃣ Save inside submissions → uploads (subcollection)
        await applicantUploadsRef.doc(safeTitle).set(uploadData, SetOptions(merge: true));

        // 3️⃣ Reset reuploadAllowed in uploads field
        uploadsFieldUpdates['uploads.$safeTitle.reuploadAllowed'] = false;

        uploadedFiles[title]!["url"] = url;
        uploadedFiles[title]!["file"] = null; // Clear the selected file
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
          .doc('splt')
          .collection('applicants')
          .doc(widget.applicantId);
      
      final submissionsSnapshot = await applicantDoc.collection('submissions').get();
      await applicantDoc.set({
        'applicantName': widget.applicantName,
        'submissionsCount': submissionsSnapshot.docs.length,
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // Reload document comments and existing uploads
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

    Widget buildUploadField(Map<String, String> label) {
    final title = label["title"]!;
    final description = label["description"] ?? "";
    final file = uploadedFiles[title]!["file"] as PlatformFile?;
    final url = uploadedFiles[title]!["url"] as String?;
    final isUploaded = url != null;

    // Get per-document reuploadAllowed flag and comments
    final docData = _documentComments[title];
    final reuploadAllowed = docData?['reuploadAllowed'] as bool? ?? false;
    final hasComments = docData?['message'] != null &&
        (docData?['message'] as String?)?.isNotEmpty == true;
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
                      title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 4),
                    if ((file != null) || (isUploaded))
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          "Uploaded: ${file != null ? file.name : url != null ? url.split('/').last : ''}",
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: Colors.grey,
                          ),
                        ),
                      ),
                    if (isUploaded)
                      TextButton(
                        onPressed: () async {
                          if (url != null) {
                            final fileName = url
                                .split('/')
                                .last
                                .split('?')
                                .first; // Remove query params
                            final ext = fileName.split('.').last.toLowerCase();

                            if (ext == 'pdf') {
                              // Preview PDF in-app
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => PdfPreviewPage(url: url),
                                ),
                              );
                            } else if (ext == 'doc' || ext == 'docx') {
                              // Open DOC/DOCX in external app
                              try {
                                final uri = Uri.parse(url);
                                if (await canLaunchUrl(uri)) {
                                  await launchUrl(uri,
                                      mode: LaunchMode.externalApplication);
                                } else {
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                          content:
                                              Text("Cannot open this file.")),
                                    );
                                  }
                                }
                              } catch (e) {
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                        content:
                                            Text("Error opening file: $e")),
                                  );
                                }
                              }
                            } else {
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                        "Preview not supported for this file type."),
                                  ),
                                );
                              }
                            }
                          }
                        },
                        child: const Text("View Uploaded File"),
                      ),
                  ],
                ),
              ),
              ElevatedButton(
                onPressed: (isUploaded && !reuploadAllowed) || _isUploading
                    ? null
                    : () => pickFile(title),
                style: ElevatedButton.styleFrom(
                  backgroundColor: (isUploaded && !reuploadAllowed)
                      ? Colors.grey
                      : (isUploaded ? Colors.orange : Colors.green[700]),
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
          // Show admin comment if exists
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
                        const Icon(Icons.comment,
                            color: Colors.orange, size: 18),
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
                      style:
                          const TextStyle(fontSize: 13, color: Colors.black87),
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
                              Icon(Icons.check_circle,
                                  color: Colors.green, size: 16),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'You can re-upload this file',
                                  style: TextStyle(
                                      fontSize: 12, color: Colors.green),
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


  /// UI
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('SPLTP Application Form'),
        backgroundColor: Colors.green,
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
