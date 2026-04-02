import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as path;
import 'package:url_launcher/url_launcher.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
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
class _CTPOUploadPageState extends State<CTPOUploadPage> {
  String? _currentSubmissionId;
  List<Map<String, dynamic>> _existingSubmissions = [];
  bool _isLoadingSubmissions = true;
  
  final List<Map<String, String>> formLabels = [
    {
      "title": "Letter of Application",
      "description": "(1 original, 1 photocopy)"
    },
    {
      "title":
          "OCT, TCT, Judicial Title, CLOA, Tax Declared Alienable and Disposable Lands",
      "description": "(1 certified true copy)"
    },
    {
      "title":
          "Data on the number of seedlings planted, species and area planted",
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
  ];

  final Map<String, Map<String, dynamic>> uploadedFiles = {};
  bool _isUploading = false;

  // Store comments per document
  Map<String, Map<String, dynamic>> _documentComments = {};

  // Store all available templates
  List<Map<String, dynamic>> _availableTemplates = [];

  @override
  void initState() {
    super.initState();
    for (final label in formLabels) {
      uploadedFiles[label["title"]!] = {
        "file": null,
        "url": null,
        "fileName": null
      };
    }
    _loadSubmissions();
    _loadApplicationTemplates();
  }

  /// Load all submissions for this applicant
  Future<void> _loadSubmissions() async {
    setState(() => _isLoadingSubmissions = true);
    try {
      final submissionsSnapshot = await FirebaseFirestore.instance
          .collection('applications')
          .doc('ctpo')
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
      
      // If no submissions exist, create the first one
      if (_existingSubmissions.isEmpty) {
        await _createNewSubmission();
      } else {
        // Load the most recent submission by default
        _currentSubmissionId = _existingSubmissions.first['id'];
        await _loadExistingUploads();
        await _loadDocumentComments();
      }
    } catch (e) {
      print('❌ Error loading submissions: $e');
      setState(() => _isLoadingSubmissions = false);
    }
  }
  
  /// Create a new submission for this applicant
  Future<void> _createNewSubmission() async {
    try {
      final submissionCount = _existingSubmissions.length + 1;
      final newSubmissionId = 'CTPO-${widget.applicantId}-${submissionCount.toString().padLeft(3, '0')}';
      
      final submissionRef = FirebaseFirestore.instance
          .collection('applications')
          .doc('ctpo')
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
      print('❌ Error creating submission: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error creating submission: $e')),
        );
      }
    }
  }
  
  /// Switch to a different submission
  Future<void> _switchSubmission(String submissionId) async {
    setState(() {
      _currentSubmissionId = submissionId;
      // Clear current uploads
      for (final label in formLabels) {
        uploadedFiles[label["title"]!] = {
          "file": null,
          "url": null,
          "fileName": null
        };
      }
    });
    await _loadExistingUploads();
    await _loadDocumentComments();
  }

  /// Load application-level templates from Firestore
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

  /// Load already uploaded files (from applications → ctpo → applicants → submissions → uploads)
  Future<void> _loadExistingUploads() async {
    if (_currentSubmissionId == null) return;
    
    final uploadsRef = FirebaseFirestore.instance
        .collection('applications')
        .doc('ctpo')
        .collection('applicants')
        .doc(widget.applicantId)
        .collection('submissions')
        .doc(_currentSubmissionId!)
        .collection('uploads');
    final snapshot = await uploadsRef.get();
    for (final doc in snapshot.docs) {
      final data = doc.data();
      final docId = doc.id;
      final url = data['url'] as String?;
      final fileName = data['fileName'] as String?;
      // Try exact match first
      if (uploadedFiles.containsKey(docId)) {
        uploadedFiles[docId]!["url"] = url;
        uploadedFiles[docId]!["fileName"] = fileName;
        continue;
      }
      // Match document ID to form label titles
      for (final label in formLabels) {
        final title = label["title"]!;
        final safeTitle = title.replaceAll(RegExp(r'[.#$/\[\]]'), '-').trim();
        if (docId == safeTitle || docId == title) {
          uploadedFiles[title]!["url"] = url;
          uploadedFiles[title]!["fileName"] = fileName;
          break;
        }
      }
    }
    setState(() {});
  }

  /// Load comments per document from uploads subcollection
  Future<void> _loadDocumentComments() async {
    if (_currentSubmissionId == null) return;
    
    try {
      final submissionDocRef = FirebaseFirestore.instance
          .collection('applications')
          .doc('ctpo')
          .collection('applicants')
          .doc(widget.applicantId)
          .collection('submissions')
          .doc(_currentSubmissionId);

      // Get submission document to check for uploads map
      final submissionSnapshot = await submissionDocRef.get();
      final submissionData = submissionSnapshot.data();
      final uploadsMap = submissionData?['uploads'] as Map<String, dynamic>?;
      
      print("📄 uploadsMap keys: ${uploadsMap?.keys.toList()}");
      print("📄 uploadsMap full content: $uploadsMap");

      // Load each document's comments and reuploadAllowed flag
      for (final label in formLabels) {
        final title = label['title']!;
        final sanitizedTitle = _sanitizeDocTitle(title);
        
        print("📄 Checking document: $title (sanitized: $sanitizedTitle)");
        
        // Check reuploadAllowed from submission document's uploads map first
        // Try both original title and sanitized title as keys
        bool reuploadAllowed = false;
        if (uploadsMap != null) {
          Map<String, dynamic>? uploadMapData;
          
          // Try original title first
          if (uploadsMap.containsKey(title)) {
            uploadMapData = uploadsMap[title] as Map<String, dynamic>?;
            print("📄 Found using original title: $title");
          }
          // Try sanitized title if original not found
          else if (uploadsMap.containsKey(sanitizedTitle)) {
            uploadMapData = uploadsMap[sanitizedTitle] as Map<String, dynamic>?;
            print("📄 Found using sanitized title: $sanitizedTitle");
          }
          
          if (uploadMapData != null) {
            reuploadAllowed = uploadMapData['reuploadAllowed'] as bool? ?? false;
            print("📄 Found in uploads map - reuploadAllowed: $reuploadAllowed");
          } else {
            print("📄 Not found in uploads map (tried both '$title' and '$sanitizedTitle')");
          }
        } else {
          print("📄 Not found in uploads map (sanitizedTitle: $sanitizedTitle)");
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
      
      print("📄 Final _documentComments: $_documentComments");
      setState(() {});
    } catch (e) {
      print("❌ Error loading document comments: $e");
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
    if (timestamp is String) {
      try {
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

      final isReupload = uploadedFiles[title]!["url"] != null;
      if (isReupload) {
        // Auto-upload immediately for reuploads
        await uploadSingleFile(title, file);
      } else {
        // For initial uploads, just store the file
        setState(() {
          uploadedFiles[title]!["file"] = file;
          uploadedFiles[title]!["fileName"] = file.name;
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
          .doc('ctpo')
          .collection('applicants')
          .doc(widget.applicantId)
          .collection('submissions')
          .doc(_currentSubmissionId!);
      final userUploadsRef = firestore
          .collection('users')
          .doc(widget.applicantId)
          .collection('ctpo_uploads');
      final applicantUploadsRef = submissionDoc.collection('uploads');

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

      final uploadData = {
        'title': title,
        'fileName': file.name,
        'url': url,
        'uploadedAt': FieldValue.serverTimestamp(),
      };

      await userUploadsRef.doc(safeTitle).set(uploadData);
      await applicantUploadsRef
          .doc(safeTitle)
          .set(uploadData, SetOptions(merge: true));

      await submissionDoc.set({
        'uploads.$safeTitle.reuploadAllowed': false,
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      uploadedFiles[title]!["url"] = url;
      uploadedFiles[title]!["file"] = null;
      uploadedFiles[title]!["fileName"] = file.name;

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
          .doc('ctpo')
          .collection('applicants')
          .doc(widget.applicantId)
          .collection('submissions')
          .doc(_currentSubmissionId!);
      final userUploadsRef = firestore
          .collection('users')
          .doc(widget.applicantId)
          .collection('ctpo_uploads');
      final applicantUploadsRef = submissionDoc.collection('uploads');

      Map<String, dynamic> uploadsFieldUpdates = {};

      for (final entry in uploadedFiles.entries) {
        final title = entry.key;
        final file = entry.value["file"] as PlatformFile?;
        if (file == null) continue;

        final safeTitle = title.replaceAll(RegExp(r'[.#$/\[\]]'), '-').trim();
        final fileName =
            "${DateTime.now().millisecondsSinceEpoch}_${file.name}";
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

        final uploadData = {
          'title': title,
          'fileName': file.name,
          'url': url,
          'uploadedAt': FieldValue.serverTimestamp(),
        };

        await userUploadsRef.doc(safeTitle).set(uploadData);
        await applicantUploadsRef
            .doc(safeTitle)
            .set(uploadData, SetOptions(merge: true));

        uploadsFieldUpdates['uploads.$safeTitle.reuploadAllowed'] = false;

        uploadedFiles[title]!["url"] = url;
        uploadedFiles[title]!["file"] = null;
        uploadedFiles[title]!["fileName"] = file.name;
      }

      if (uploadsFieldUpdates.isNotEmpty) {
        await submissionDoc.set(uploadsFieldUpdates, SetOptions(merge: true));
      }

      await _loadDocumentComments();
      await _loadExistingUploads();

      await submissionDoc.set({
        'applicantName': widget.applicantName,
        'status': 'submitted',
        'submittedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // Update the applicant document count
      final applicantDoc = firestore
          .collection('applications')
          .doc('ctpo')
          .collection('applicants')
          .doc(widget.applicantId);
      
      final submissionsSnapshot = await applicantDoc.collection('submissions').get();
      await applicantDoc.set({
        'applicantName': widget.applicantName,
        'submissionsCount': submissionsSnapshot.docs.length,
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // ✅ Mark that all documents should now render in GREEN
      if (mounted) {
        setState(() {
          _isUploading = false;
        });
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

  static const Color _primaryGreen = Color(0xFF2E7D32);
  static const Color _darkGreen = Color(0xFF1B5E20);
  static const Color _lightGreen = Color(0xFFE8F5E9);
  static const Color _surfaceColor = Color(0xFFF1F8E9);

  Widget buildUploadField(Map<String, String> label, int index) {
  final title = label["title"]!;
  final description = label["description"] ?? "";
  final file = uploadedFiles[title]!["file"] as PlatformFile?;
  final url = uploadedFiles[title]!["url"] as String?;
  final fileName = uploadedFiles[title]!["fileName"] as String?;
  final isUploaded = url != null;

  final docData = _documentComments[title];
  final reuploadAllowed = docData?['reuploadAllowed'] as bool? ?? false;
  final hasComments = docData?['message'] != null &&
      (docData?['message'] as String?)?.isNotEmpty == true;
  final comment = docData;

  return Container(
    margin: const EdgeInsets.only(bottom: 12),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(
        color: isUploaded
            ? _primaryGreen.withValues(alpha: 0.3)
            : file != null
                ? Colors.orange.withValues(alpha: 0.3)
                : Colors.grey.withValues(alpha: 0.15),
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.04),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ],
    ),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: isUploaded
                      ? _primaryGreen.withValues(alpha: 0.1)
                      : file != null
                          ? Colors.orange.withValues(alpha: 0.1)
                          : _lightGreen,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: isUploaded
                      ? const Icon(Icons.check_circle_rounded, color: _primaryGreen, size: 20)
                      : file != null
                          ? const Icon(Icons.hourglass_bottom_rounded, color: Colors.orange, size: 20)
                          : Text(
                              '${index + 1}',
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: _primaryGreen),
                            ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF1A1A1A))),
                    if (description.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(description, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                    ],
                    if (fileName != null && fileName.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text('File: $fileName', style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              if (isUploaded)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _primaryGreen.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.cloud_done_rounded, color: _primaryGreen, size: 14),
                      SizedBox(width: 4),
                      Text('Uploaded', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: _primaryGreen)),
                    ],
                  ),
                )
              else if (file != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.file_present_rounded, color: Colors.orange, size: 14),
                      SizedBox(width: 4),
                      Text('Ready', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.orange)),
                    ],
                  ),
                ),
              const Spacer(),
              if (isUploaded)
                TextButton.icon(
                  onPressed: () {
                    if (url != null) {
                      final ext = (fileName ?? url).split('.').last.toLowerCase().split('?').first;
                      if (ext == 'pdf') {
                        Navigator.push(context, MaterialPageRoute(builder: (_) => PdfPreviewPage(url: url)));
                      } else {
                        launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
                      }
                    }
                  },
                  icon: const Icon(Icons.visibility_rounded, size: 16),
                  label: const Text('View', style: TextStyle(fontSize: 12)),
                  style: TextButton.styleFrom(foregroundColor: _primaryGreen, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6)),
                ),
              const SizedBox(width: 4),
              Material(
                color: (isUploaded && !reuploadAllowed)
                    ? Colors.grey[200]
                    : isUploaded
                        ? Colors.orange
                        : file != null
                            ? Colors.orange
                            : _primaryGreen,
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  onTap: (isUploaded && !reuploadAllowed) || _isUploading ? null : () => pickFile(title),
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          (isUploaded && !reuploadAllowed) ? Icons.lock_rounded : Icons.upload_file_rounded,
                          size: 16,
                          color: (isUploaded && !reuploadAllowed) ? Colors.grey[500] : Colors.white,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          isUploaded ? (reuploadAllowed ? 'Re-upload' : 'Done') : file != null ? 'Change' : 'Select',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: (isUploaded && !reuploadAllowed) ? Colors.grey[500] : Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          // Admin comment section
          if (hasComments && comment != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.orange.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Icon(Icons.comment_rounded, color: Colors.orange, size: 14),
                      ),
                      const SizedBox(width: 8),
                      Text('Admin Comment', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.orange[700])),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(comment['message'] ?? '', style: const TextStyle(fontSize: 13, color: Colors.black87)),
                  const SizedBox(height: 4),
                  Text(
                    'From: ${comment['from'] ?? 'Admin'} • ${_formatTimestamp(comment['createdAt'])}',
                    style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                  ),
                  if (reuploadAllowed) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: _lightGreen,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.check_circle_rounded, color: _primaryGreen, size: 16),
                          SizedBox(width: 8),
                          Expanded(child: Text('You can re-upload this file', style: TextStyle(fontSize: 12, color: _primaryGreen))),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    ),
  );
}

  @override
  Widget build(BuildContext context) {
    final uploadProgress = formLabels.isEmpty
        ? 0.0
        : formLabels.where((l) => uploadedFiles[l['title']]?['url'] != null).length / formLabels.length;

    return Scaffold(
      backgroundColor: _surfaceColor,
      body: _isLoadingSubmissions
          ? const Center(child: CircularProgressIndicator(color: _primaryGreen))
          : CustomScrollView(
        slivers: [
          // Gradient Header
          SliverToBoxAdapter(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [_darkGreen, _primaryGreen, Color(0xFF43A047)],
                ),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(28),
                  bottomRight: Radius.circular(28),
                ),
              ),
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          InkWell(
                            onTap: () => Navigator.pop(context),
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 22),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('CTPO Upload', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
                                const SizedBox(height: 2),
                                Text('Certificate of Tree Plantation Ownership', style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.8))),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // Submission selector
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.folder_open_rounded, color: Colors.white, size: 20),
                                const SizedBox(width: 8),
                                const Expanded(
                                  child: Text('Submissions', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white)),
                                ),
                                Material(
                                  color: Colors.white.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(10),
                                  child: InkWell(
                                    onTap: _createNewSubmission,
                                    borderRadius: BorderRadius.circular(10),
                                    child: const Padding(
                                      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.add_rounded, color: Colors.white, size: 16),
                                          SizedBox(width: 4),
                                          Text('New', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white)),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            if (_existingSubmissions.isNotEmpty) ...[
                              const SizedBox(height: 10),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<String>(
                                    value: _currentSubmissionId,
                                    isExpanded: true,
                                    icon: const Icon(Icons.expand_more_rounded, color: _primaryGreen),
                                    items: _existingSubmissions.map((submission) {
                                      return DropdownMenuItem<String>(
                                        value: submission['id'] as String,
                                        child: Row(
                                          children: [
                                            Icon(
                                              submission['status'] == 'submitted' ? Icons.check_circle_rounded : Icons.edit_note_rounded,
                                              color: submission['status'] == 'submitted' ? _primaryGreen : Colors.orange,
                                              size: 18,
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(child: Text('${submission['id']}', style: const TextStyle(fontSize: 13))),
                                          ],
                                        ),
                                      );
                                    }).toList(),
                                    onChanged: (value) {
                                      if (value != null) _switchSubmission(value);
                                    },
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Progress bar
                      Row(
                        children: [
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: uploadProgress,
                                backgroundColor: Colors.white.withValues(alpha: 0.2),
                                valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                                minHeight: 6,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text('${(uploadProgress * 100).toInt()}%', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          // Body
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // Templates section
                if (_availableTemplates.isNotEmpty) ...[
                  _buildSectionHeader(Icons.file_download_rounded, 'Available Templates', Colors.blue),
                  const SizedBox(height: 12),
                  ..._availableTemplates.map((t) => _buildTemplateCard(t)),
                  const SizedBox(height: 20),
                ],
                // Documents section
                _buildSectionHeader(Icons.description_rounded, 'Required Documents', _primaryGreen),
                const SizedBox(height: 12),
                for (int i = 0; i < formLabels.length; i++) buildUploadField(formLabels[i], i),
                const SizedBox(height: 24),
                // Submit button
                _buildGradientButton(
                  onTap: _isUploading ? null : handleSubmit,
                  isLoading: _isUploading,
                  icon: Icons.cloud_upload_rounded,
                  label: 'Submit All Documents',
                ),
                const SizedBox(height: 24),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(IconData icon, String title, Color color) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(width: 10),
        Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1A1A1A))),
      ],
    );
  }

  Widget _buildGradientButton({VoidCallback? onTap, required bool isLoading, required IconData icon, required String label}) {
    return Container(
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [_darkGreen, _primaryGreen]),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: _primaryGreen.withValues(alpha: 0.3), blurRadius: 12, offset: const Offset(0, 4)),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Center(
            child: isLoading
                ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(icon, color: Colors.white, size: 20),
                      const SizedBox(width: 10),
                      Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildTemplateCard(Map<String, dynamic> template) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.description_rounded, color: Colors.blue, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(template['documentType'] ?? 'Template', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  if (template['fileName']?.isNotEmpty == true)
                    Text(template['fileName'], style: TextStyle(fontSize: 11, color: Colors.grey[500]), overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Material(
              color: Colors.blue,
              borderRadius: BorderRadius.circular(10),
              child: InkWell(
                onTap: () async {
                  final url = template['url'] as String?;
                  if (url != null && url.isNotEmpty) {
                    try {
                      final uri = Uri.parse(url);
                      if (await canLaunchUrl(uri)) {
                        await launchUrl(uri, mode: LaunchMode.externalApplication);
                      }
                    } catch (_) {}
                  }
                },
                borderRadius: BorderRadius.circular(10),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.download_rounded, size: 16, color: Colors.white),
                      SizedBox(width: 4),
                      Text('Get', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white)),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Format Firestore Timestamp to readable date format
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
