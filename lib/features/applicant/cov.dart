import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as path;
import 'package:url_launcher/url_launcher.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

class CovFormPage extends StatefulWidget {
  final String applicantId;
  final String applicantName;

  const CovFormPage(
      {Key? key, required this.applicantId, required this.applicantName})
      : super(key: key);

  @override
  _CovFormPageState createState() => _CovFormPageState();
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

class _CovFormPageState extends State<CovFormPage> {
  final _formKey = GlobalKey<FormState>();

  // Submission state
  String? _currentSubmissionId;
  List<Map<String, dynamic>> _existingSubmissions = [];
  bool _isLoadingSubmissions = true;

  /// List of documents required for COV (title and short description)
  final List<Map<String, String>> formLabels = [
    {"title": "Request Letter", "description": "(1 original, 1 photocopy)"},
    {
      "title": "Barangay Certificate (for non-timber)",
      "description": "(1 original)"
    },
    {
      "title":
          "Certification that forest products are harvested within owner's area",
      "description": "(for timber)"
    },
    {"title": "Approved Tree Cutting Permit", "description": "(if applicable)"},
    {"title": "OR/CR of Conveyance and Driver's License", "description": ""},
    {
      "title": "Certificate of Transport Agreement",
      "description": "(if conveyance not owned by forest product owner)"
    },
    {
      "title": "Special Power of Attorney (SPA)",
      "description": "(if applicant is not land owner)"
    },
  ];

  /// Local state to keep selected file objects and uploaded urls
  final Map<String, Map<String, dynamic>> uploadedFiles = {};
  bool _isUploading = false;

  /// Comments and flags per document
  Map<String, Map<String, dynamic>> _documentComments = {};

  /// Templates available for the application (optional)
  List<Map<String, dynamic>> _availableTemplates = [];

  @override
  void initState() {
    super.initState();
    for (final label in formLabels) {
      uploadedFiles[label['title']!] = {"file": null, "url": null};
    }

    _loadSubmissions();
  }

  /// Load all submissions for this applicant
  Future<void> _loadSubmissions() async {
    try {
      final firestore = FirebaseFirestore.instance;
      final submissionsSnapshot = await firestore
          .collection('applications')
          .doc('cov')
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
          .doc('cov')
          .collection('applicants')
          .doc(widget.applicantId);

      final submissionsSnapshot =
          await applicantDoc.collection('submissions').get();
      final nextNumber = submissionsSnapshot.docs.length + 1;
      final submissionId =
          'COV-${widget.applicantId}-${nextNumber.toString().padLeft(3, '0')}';

      await applicantDoc.collection('submissions').doc(submissionId).set({
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
        uploadedFiles[label['title']!] = {"file": null, "url": null};
      }
    });

    await _loadExistingUploads();
    await _loadDocumentComments();
  }

  /// Load templates saved under applications/cov/templates
  Future<void> _loadApplicationTemplates() async {
    try {
      final templatesSnapshot = await FirebaseFirestore.instance
          .collection('applications')
          .doc('cov')
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
      }
    } catch (e) {
      debugPrint('Error loading templates: $e');
    }
  }

  /// Load already uploaded file metadata for this applicant
  Future<void> _loadExistingUploads() async {
    if (_currentSubmissionId == null) return;

    try {
      final uploadsRef = FirebaseFirestore.instance
          .collection('applications')
          .doc('cov')
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

        if (uploadedFiles.containsKey(docId)) {
          uploadedFiles[docId]!['url'] = url;
          continue;
        }

        for (final label in formLabels) {
          final title = label['title']!;
          final safeTitle = title.replaceAll(RegExp(r'[.#$/\[\]]'), '-').trim();
          if (docId == safeTitle || docId == title) {
            uploadedFiles[title]!['url'] = url;
            break;
          }
        }
      }

      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('Error loading existing uploads: $e');
    }
  }

  /// Load the most recent comment and reuploadAllowed flag for each document
  Future<void> _loadDocumentComments() async {
    if (_currentSubmissionId == null) return;

    try {
      final submissionDocRef = FirebaseFirestore.instance
          .collection('applications')
          .doc('cov')
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
          .doc('cov')
          .collection('applicants')
          .doc(widget.applicantId)
          .collection('submissions')
          .doc(_currentSubmissionId!)
          .collection('uploads');

      final uploadsSnapshot = await uploadsRef.get();

      for (final uploadDoc in uploadsSnapshot.docs) {
        final docKey = uploadDoc.id;
        final docData = uploadDoc.data();

        final reuploadAllowed = docData['reuploadAllowed'] as bool? ?? false;

        final commentsSnapshot = await uploadDoc.reference
            .collection('comments')
            .orderBy('createdAt', descending: true)
            .limit(1)
            .get();

        Map<String, dynamic>? mostRecentComment;
        if (commentsSnapshot.docs.isNotEmpty) {
          mostRecentComment = commentsSnapshot.docs.first.data();
        }

        String? matchingTitle;
        if (uploadedFiles.containsKey(docKey)) {
          matchingTitle = docKey;
        } else {
          for (final label in formLabels) {
            final title = label['title']!;
            final safeTitle =
                title.replaceAll(RegExp(r'[.#$/\[\]]'), '-').trim();
            if (docKey == safeTitle) {
              matchingTitle = title;
              break;
            }
          }
        }

        if (matchingTitle != null) {
          _documentComments[matchingTitle] = {
            'reuploadAllowed': reuploadAllowed,
            'from': mostRecentComment?['from'] as String? ?? 'Admin',
            'message': mostRecentComment?['message'] as String? ?? '',
            'createdAt':
                _parseCommentTimestamp(mostRecentComment?['createdAt']),
          };
        }
      }

      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('Error loading document comments: $e');
    }
  }

  /// Sanitize document title to be used as Firestore document ID
  String _sanitizeDocTitle(String title) {
    return title.replaceAll(RegExp(r'[.#$/\[\]]'), '-').trim();
  }

  Timestamp? _parseCommentTimestamp(dynamic timestamp) {
    if (timestamp == null) return null;
    if (timestamp is Timestamp) return timestamp;
    if (timestamp is String) {
      try {
        final dateTime = DateTime.parse(timestamp);
        return Timestamp.fromDate(dateTime);
      } catch (_) {
        return null;
      }
    }
    return null;
  }

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
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Please upload only PDF or DOC files.')),
          );
        }
        return;
      }

      final isReupload = uploadedFiles[title]!['url'] != null;

      if (isReupload) {
        await uploadSingleFile(title, file);
      } else {
        setState(() {
          uploadedFiles[title]!['file'] = file;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error selecting file: $e')));
      }
    }
  }

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
          .doc('cov')
          .collection('applicants')
          .doc(widget.applicantId)
          .collection('submissions')
          .doc(_currentSubmissionId!);
      final userUploadsRef = firestore
          .collection('users')
          .doc(widget.applicantId)
          .collection('cov_uploads');
      final applicantUploadsRef = submissionDoc.collection('uploads');

      final safeTitle = title.replaceAll(RegExp(r'[.#$/\[\]]'), '-').trim();
      final fileName = '${DateTime.now().millisecondsSinceEpoch}_${file.name}';
      final ref = storage.ref().child('cov_uploads/$fileName');

      UploadTask uploadTask;
      if (kIsWeb) {
        final bytes = file.bytes;
        if (bytes == null) throw Exception('File bytes missing');
        uploadTask = ref.putData(bytes);
      } else {
        final pathStr = file.path;
        if (pathStr == null) throw Exception('File path missing');
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
        'applicantName': widget.applicantName,
        'uploads.$safeTitle.reuploadAllowed': false,
        'lastUpdated': FieldValue.serverTimestamp()
      }, SetOptions(merge: true));

      uploadedFiles[title]!['url'] = url;
      uploadedFiles[title]!['file'] = null;

      await _loadDocumentComments();
      await _loadExistingUploads();

      if (mounted) {
        setState(() => _isUploading = false);
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('$title uploaded successfully!')));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isUploading = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error uploading file: $e')));
      }
    }
  }

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
          .doc('cov')
          .collection('applicants')
          .doc(widget.applicantId)
          .collection('submissions')
          .doc(_currentSubmissionId!);

      final userUploadsRef = firestore
          .collection('users')
          .doc(widget.applicantId)
          .collection('cov_uploads');

      final applicantUploadsRef = submissionDoc.collection('uploads');

      Map<String, dynamic> uploadsFieldUpdates = {};

      for (final entry in uploadedFiles.entries) {
        final title = entry.key;
        final file = entry.value['file'] as PlatformFile?;

        if (file == null) continue;

        final safeTitle = title.replaceAll(RegExp(r'[.#$/\[\]]'), '-').trim();
        final fileName =
            '${DateTime.now().millisecondsSinceEpoch}_${file.name}';
        final ref = storage.ref().child('cov_uploads/$fileName');

        UploadTask uploadTask;

        if (kIsWeb) {
          uploadTask = ref.putData(file.bytes!);
        } else {
          uploadTask = ref.putFile(File(file.path!));
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

        uploadedFiles[title]!['url'] = url;
        uploadedFiles[title]!['file'] = null;
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
          .doc('cov')
          .collection('applicants')
          .doc(widget.applicantId);

      final submissionsSnapshot =
          await applicantDoc.collection('submissions').get();
      await applicantDoc.set({
        'applicantName': widget.applicantName,
        'submissionsCount': submissionsSnapshot.docs.length,
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      await _loadDocumentComments();
      await _loadExistingUploads();

      if (mounted) {
        setState(() => _isUploading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('All files uploaded successfully!')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isUploading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error uploading files: $e')),
        );
      }
    }
  }

  // Modern color constants
  static const _primaryGreen = Color(0xFF2E7D32);
  static const _darkGreen = Color(0xFF1B5E20);
  static const _lightGreen = Color(0xFFE8F5E9);
  static const _surfaceColor = Color(0xFFF1F8E9);

  Widget buildUploadField(Map<String, String> label, int index) {
    final title = label["title"]!;
    final description = label["description"] ?? "";
    final file = uploadedFiles[title]!["file"] as PlatformFile?;
    final url = uploadedFiles[title]!["url"] as String?;
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
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 2)),
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
                  width: 32, height: 32,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: isUploaded
                          ? [const Color(0xFF43A047), _primaryGreen]
                          : [Colors.grey[300]!, Colors.grey[400]!],
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: isUploaded
                        ? const Icon(Icons.check, color: Colors.white, size: 18)
                        : Text('$index', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: _darkGreen)),
                      if (description.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(description, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (file != null || isUploaded)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(color: _lightGreen, borderRadius: BorderRadius.circular(8)),
                child: Row(
                  children: [
                    const Icon(Icons.attach_file, size: 14, color: _primaryGreen),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        file != null ? file.name : url!.split('/').last.split('?').first,
                        style: const TextStyle(fontSize: 12, color: _primaryGreen),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isUploaded)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(color: _primaryGreen, borderRadius: BorderRadius.circular(10)),
                        child: const Text('Uploaded', style: TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.w600)),
                      ),
                  ],
                ),
              ),
            const SizedBox(height: 10),
            Row(
              children: [
                if (isUploaded)
                  Expanded(
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(10),
                        onTap: () async {
                          if (url != null) {
                            final fileName = url.split('/').last.split('?').first;
                            final ext = fileName.split('.').last.toLowerCase();
                            if (ext == 'pdf') {
                              Navigator.push(context, MaterialPageRoute(builder: (_) => PdfPreviewPage(url: url)));
                            } else if (ext == 'doc' || ext == 'docx') {
                              try {
                                final uri = Uri.parse(url);
                                if (await canLaunchUrl(uri)) {
                                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                                } else {
                                  if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Cannot open this file.")));
                                }
                              } catch (e) {
                                if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error opening file: $e")));
                              }
                            } else {
                              if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Preview not supported for this file type.")));
                            }
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            border: Border.all(color: _primaryGreen.withOpacity(0.3)),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.visibility_outlined, size: 16, color: _primaryGreen),
                              SizedBox(width: 6),
                              Text('View', style: TextStyle(fontSize: 13, color: _primaryGreen, fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                if (isUploaded) const SizedBox(width: 8),
                Expanded(
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: (isUploaded && !reuploadAllowed) || _isUploading ? null : () => pickFile(title),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          gradient: (isUploaded && !reuploadAllowed) ? null : const LinearGradient(colors: [_darkGreen, _primaryGreen]),
                          color: (isUploaded && !reuploadAllowed) ? Colors.grey[300] : null,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              isUploaded ? (reuploadAllowed ? Icons.refresh : Icons.check) : Icons.upload_file,
                              size: 16,
                              color: (isUploaded && !reuploadAllowed) ? Colors.grey[600] : Colors.white,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              isUploaded ? (reuploadAllowed ? 'Re-upload' : 'Uploaded') : (file != null ? 'Change' : 'Select File'),
                              style: TextStyle(fontSize: 13, color: (isUploaded && !reuploadAllowed) ? Colors.grey[600] : Colors.white, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            if (hasComments && comment != null)
              Container(
                margin: const EdgeInsets.only(top: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF3E0),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.orange.withOpacity(0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(color: Colors.orange.withOpacity(0.15), borderRadius: BorderRadius.circular(6)),
                          child: const Icon(Icons.comment_outlined, color: Colors.orange, size: 14),
                        ),
                        const SizedBox(width: 8),
                        Text('Admin Comment', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.orange[800])),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(comment['message'] ?? '', style: const TextStyle(fontSize: 13, color: Colors.black87)),
                    const SizedBox(height: 4),
                    Text('From: ${comment['from'] ?? 'Admin'} • ${_formatTimestamp(comment['createdAt'])}', style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                    if (reuploadAllowed)
                      Container(
                        margin: const EdgeInsets.only(top: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(color: _lightGreen, borderRadius: BorderRadius.circular(8)),
                        child: const Row(
                          children: [
                            Icon(Icons.check_circle, color: _primaryGreen, size: 14),
                            SizedBox(width: 6),
                            Expanded(child: Text('You can re-upload this file', style: TextStyle(fontSize: 12, color: _primaryGreen))),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTemplateCard(Map<String, dynamic> template) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Row(
        children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFFE3F2FD),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.description_outlined, color: Color(0xFF1565C0), size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(template['documentType'] ?? 'Template', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF1B5E20))),
                if (template['fileName']?.isNotEmpty == true)
                  Text(template['fileName'] ?? '', style: TextStyle(fontSize: 11, color: Colors.grey[600]), overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () async {
                final url = template['url'] as String?;
                if (url != null) {
                  final uri = Uri.parse(url);
                  if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFE3F2FD),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.download, size: 14, color: Color(0xFF1565C0)),
                    SizedBox(width: 4),
                    Text('Download', style: TextStyle(fontSize: 12, color: Color(0xFF1565C0), fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatTimestamp(Timestamp? timestamp) {
    if (timestamp == null) return '';
    final dt = timestamp.toDate();
    return '${dt.month}/${dt.day}/${dt.year} ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final uploadedCount = uploadedFiles.values.where((v) => v["url"] != null).length;
    final totalCount = formLabels.length;
    final progress = totalCount > 0 ? uploadedCount / totalCount : 0.0;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: _isLoadingSubmissions
          ? const Center(child: CircularProgressIndicator(color: _primaryGreen))
          : CustomScrollView(
              slivers: [
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
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            GestureDetector(
                              onTap: () => Navigator.pop(context),
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(Icons.arrow_back, color: Colors.white, size: 22),
                              ),
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'COV Application',
                              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Certificate of Verification',
                              style: TextStyle(fontSize: 14, color: Colors.white.withOpacity(0.85)),
                            ),
                            const SizedBox(height: 16),
                            // Submission selector
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: _existingSubmissions.isEmpty
                                        ? Text('No submissions yet', style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 13))
                                        : Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 12),
                                            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
                                            child: DropdownButton<String>(
                                              value: _currentSubmissionId,
                                              isExpanded: true,
                                              underline: const SizedBox(),
                                              style: const TextStyle(fontSize: 13, color: _darkGreen, fontWeight: FontWeight.w600),
                                              items: _existingSubmissions.map((s) {
                                                return DropdownMenuItem<String>(
                                                  value: s['id'] as String,
                                                  child: Row(
                                                    children: [
                                                      Icon(s['status'] == 'submitted' ? Icons.check_circle : Icons.edit_note, color: s['status'] == 'submitted' ? _primaryGreen : Colors.orange, size: 16),
                                                      const SizedBox(width: 8),
                                                      Expanded(child: Text('${s['id']}', overflow: TextOverflow.ellipsis)),
                                                    ],
                                                  ),
                                                );
                                              }).toList(),
                                              onChanged: (value) { if (value != null) _switchSubmission(value); },
                                            ),
                                          ),
                                  ),
                                  const SizedBox(width: 8),
                                  GestureDetector(
                                    onTap: _createNewSubmission,
                                    child: Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(10)),
                                      child: const Icon(Icons.add, color: Colors.white, size: 20),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 14),
                            // Progress bar
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text('Progress', style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 12, fontWeight: FontWeight.w600)),
                                    Text('$uploadedCount / $totalCount files', style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 12)),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: LinearProgressIndicator(
                                    value: progress,
                                    minHeight: 6,
                                    backgroundColor: Colors.white.withOpacity(0.2),
                                    valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      // Templates section
                      if (_availableTemplates.isNotEmpty) ...[
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Row(
                            children: [
                              Container(width: 4, height: 20, decoration: BoxDecoration(color: const Color(0xFF1565C0), borderRadius: BorderRadius.circular(2))),
                              const SizedBox(width: 8),
                              const Text('Available Templates', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1565C0))),
                            ],
                          ),
                        ),
                        ..._availableTemplates.map((t) => _buildTemplateCard(t)),
                        const SizedBox(height: 20),
                      ],
                      // Documents section header
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Row(
                          children: [
                            Container(width: 4, height: 20, decoration: BoxDecoration(color: _primaryGreen, borderRadius: BorderRadius.circular(2))),
                            const SizedBox(width: 8),
                            const Text('Required Documents', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: _darkGreen)),
                          ],
                        ),
                      ),
                      for (int i = 0; i < formLabels.length; i++)
                        buildUploadField(formLabels[i], i + 1),
                      const SizedBox(height: 24),
                      // Submit button
                      GestureDetector(
                        onTap: _isUploading ? null : handleSubmit,
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          decoration: BoxDecoration(
                            gradient: _isUploading ? null : const LinearGradient(colors: [_darkGreen, _primaryGreen]),
                            color: _isUploading ? Colors.grey[300] : null,
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: _isUploading ? [] : [BoxShadow(color: _primaryGreen.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4))],
                          ),
                          child: Center(
                            child: _isUploading
                                ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                                : const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.cloud_upload_outlined, color: Colors.white, size: 20),
                                      SizedBox(width: 8),
                                      Text('Submit All Files', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                                    ],
                                  ),
                          ),
                        ),
                      ),
                    ]),
                  ),
                ),
              ],
            ),
    );
  }
}
