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

  Widget _buildTemplateCard(Map<String, dynamic> template) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 2,
      child: ListTile(
        leading: Icon(Icons.description, color: Colors.blue[700], size: 32),
        title: Text(template['documentType'] ?? 'Template',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        subtitle:
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (template['title']?.isNotEmpty == true)
            Text(template['title'],
                style:
                    const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
          if (template['description']?.isNotEmpty == true)
            Text(template['description'],
                style: TextStyle(fontSize: 12, color: Colors.grey[600])),
          const SizedBox(height: 4),
          Row(children: [
            Icon(Icons.insert_drive_file, size: 14, color: Colors.grey[600]),
            const SizedBox(width: 4),
            Expanded(
                child: Text(template['fileName'] ?? '',
                    style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                    overflow: TextOverflow.ellipsis))
          ]),
        ]),
        trailing: ElevatedButton.icon(
          onPressed: () async {
            final url = template['url'] as String?;
            if (url != null) {
              final uri = Uri.parse(url);
              if (await canLaunchUrl(uri))
                await launchUrl(uri, mode: LaunchMode.externalApplication);
            }
          },
          icon: const Icon(Icons.download, size: 16),
          label: const Text('Download', style: TextStyle(fontSize: 12)),
          style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue[700], foregroundColor: Colors.white),
        ),
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
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.green[700],
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text('COV File Upload',
            style: TextStyle(color: Colors.white)),
      ),
      body: _isLoadingSubmissions
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
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
                                  Icon(Icons.folder_open,
                                      color: Colors.green[700], size: 24),
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
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 8),
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
                                border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8)),
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
                                        color:
                                            submission['status'] == 'submitted'
                                                ? Colors.green
                                                : Colors.orange,
                                        size: 18,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        '${submission['id']} (${submission['uploadsCount']} files)',
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
                              Row(children: [
                                Icon(Icons.folder_special,
                                    color: Colors.blue[700], size: 24),
                                const SizedBox(width: 8),
                                Text('Available Templates',
                                    style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.blue[900]))
                              ]),
                              const SizedBox(height: 8),
                              Text(
                                  'Download these templates before preparing your documents',
                                  style: TextStyle(
                                      fontSize: 13, color: Colors.blue[800])),
                              const Divider(height: 16),
                              ..._availableTemplates
                                  .map((t) => _buildTemplateCard(t)),
                            ]),
                      ),
                      const SizedBox(height: 24),
                    ],

                    Form(
                      key: _formKey,
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Issuance of Certificate of Verification (COV) for the Transport of Planted Trees within Private Land, Non-Timber Forest Products (except Rattan and Bamboo)',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 20),
                            const SizedBox(height: 20),
                            for (final label in formLabels)
                              buildUploadField(label),
                            const SizedBox(height: 24),
                            Center(
                              child: SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  onPressed: _isUploading ? null : handleSubmit,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green[700],
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 20),
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(12)),
                                  ),
                                  child: _isUploading
                                      ? const CircularProgressIndicator(
                                          color: Colors.white)
                                      : const Text('Submit (Upload All Files)',
                                          style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.bold)),
                                ),
                              ),
                            ),
                          ]),
                    ),
                  ]),
            ),
    );
  }
}
