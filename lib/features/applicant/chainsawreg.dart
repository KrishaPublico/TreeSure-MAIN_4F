import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:path/path.dart' as path;
import 'package:url_launcher/url_launcher.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

class ChainsawRegistrationPage extends StatefulWidget {
  final String applicantId;
  final String applicantName;

  const ChainsawRegistrationPage(
      {Key? key, required this.applicantId, required this.applicantName})
      : super(key: key);

  @override
  _ChainsawRegistrationPageState createState() =>
      _ChainsawRegistrationPageState();
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

class _ChainsawRegistrationPageState extends State<ChainsawRegistrationPage> {
  final _formKey = GlobalKey<FormState>();

  // Submission state
  String? _currentSubmissionId;
  List<Map<String, dynamic>> _existingSubmissions = [];
  bool _isLoadingSubmissions = true;

  /// Documents required
  final List<Map<String, String>> documents = [
    {
      "title": "Official Receipt of Chainsaw Purchase / Affidavit of Ownership",
      "description": "(1 original, 1 certified copy)"
    },
    {"title": "SPA (if applicant is not owner)", "description": ""},
    {"title": "Stencil Serial Number of Chainsaw", "description": ""},
    {"title": "Duly Accomplished Application Form", "description": ""},
    {
      "title": "Detailed Specification of Chainsaw",
      "description": "(brand, model, engine capacity, etc.)"
    },
    {
      "title": "Notarized Deed of Absolute Sale",
      "description": "(if transfer of ownership, 1 original)"
    },
    {
      "title":
          "Certified True Copy of Forest Tenure Agreement (if Tenurial Instrument holder)",
      "description": ""
    },
    {
      "title": "Business Permit (if Business Owner)",
      "description": "(1 photocopy)"
    },
    {
      "title": "Certificate of Registration (if Private Tree Plantation Owner)",
      "description": ""
    },
    {
      "title": "Business Permit / Affidavit of Legal Use",
      "description": "(if chainsaw used legally)"
    },
    {
      "title": "Wood Processing Plant Permit (if licensed wood processor)",
      "description": "(1 photocopy)"
    },
    {
      "title":
          "Certification from Head of Office (if chainsaw owned by office)",
      "description": ""
    },
    {
      "title": "Latest Certificate of Chainsaw Registration (if renewal)",
      "description": "(1 photocopy)"
    },
  ];

  /// Holds selected file (PlatformFile), uploaded file URL, and display filename per document title.
  final Map<String, Map<String, dynamic>> uploadedFiles = {};

  /// Holds admin comment/meta per document title.
  final Map<String, Map<String, dynamic>> _documentComments = {};

  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    for (final doc in documents) {
      uploadedFiles[doc['title']!] = {
        "file": null,
        "url": null,
        "fileName": null
      };
    }
    _loadSubmissions();
  }

  /// Load all submissions for this applicant
  Future<void> _loadSubmissions() async {
    try {
      final firestore = FirebaseFirestore.instance;
      final submissionsSnapshot = await firestore
          .collection('applications')
          .doc('chainsaw')
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
          .doc('chainsaw')
          .collection('applicants')
          .doc(widget.applicantId);

      final submissionsSnapshot =
          await applicantDoc.collection('submissions').get();
      final nextNumber = submissionsSnapshot.docs.length + 1;
      final submissionId =
          'CHAINSAW-${widget.applicantId}-${nextNumber.toString().padLeft(3, '0')}';

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
      for (final doc in documents) {
        uploadedFiles[doc['title']!] = {
          "file": null,
          "url": null,
          "fileName": null
        };
      }
    });

    await _loadExistingUploads();
  }

  Future<void> _loadExistingUploads() async {
    if (_currentSubmissionId == null) return;

    try {
      final submissionDocRef = FirebaseFirestore.instance
          .collection('applications')
          .doc('chainsawreg')
          .collection('applicants')
          .doc(widget.applicantId)
          .collection('submissions')
          .doc(_currentSubmissionId);

      // Get submission document to check for uploads map
      final submissionSnapshot = await submissionDocRef.get();
      final submissionData = submissionSnapshot.data();
      final uploadsMap = submissionData?['uploads'] as Map<String, dynamic>?;

      // Load uploaded files
      final uploadsSnapshot = await submissionDocRef.collection('uploads').get();
      
      for (final uploadDoc in uploadsSnapshot.docs) {
        final data = uploadDoc.data();
        final sanitizedTitle = uploadDoc.id;
        final title = data['title'] as String? ?? sanitizedTitle;
        
        if (uploadedFiles.containsKey(title)) {
          uploadedFiles[title]!['url'] = data['url'];
          uploadedFiles[title]!['fileName'] = data['fileName'];
        }
        
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
        
        // Override with subcollection value if it exists
        reuploadAllowed = data['reuploadAllowed'] as bool? ?? reuploadAllowed;
        
        final commentsSnapshot = await uploadDoc.reference
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
          _documentComments[title] = {
            'reuploadAllowed': reuploadAllowed,
            'message': null,
          };
        }
      }
      final uploadsRef = FirebaseFirestore.instance
          .collection('applications')
          .doc('chainsaw')
          .collection('applicants')
          .doc(widget.applicantId)
          .collection('submissions')
          .doc(_currentSubmissionId!)
          .collection('uploads');

      final snapshot = await uploadsRef.get();

      for (final doc in snapshot.docs) {
        final data = doc.data();
        // Prefer the stored title field (this preserves original label with spaces)
        final titleFromData = (data['title'] as String?)?.trim();
        final fileName = data['fileName'] as String?;
        final url = data['url'] as String?;

        if (titleFromData != null && uploadedFiles.containsKey(titleFromData)) {
          uploadedFiles[titleFromData]!['url'] = url;
          uploadedFiles[titleFromData]!['fileName'] = fileName;
        } else {
          // Defensive: if title field missing, try matching by doc id (less likely to match)
          final docId = doc.id;
          if (uploadedFiles.containsKey(docId)) {
            uploadedFiles[docId]!['url'] = url;
            uploadedFiles[docId]!['fileName'] = fileName;
          }
        }

        // Load admin comment/meta if present in the upload doc
        final message = data['message'] as String?;
        final from = data['from'] as String?;
        final createdAt = data['createdAt'];
        final reuploadAllowed = data['reuploadAllowed'] as bool? ?? false;

        final key = titleFromData ?? doc.id;
        _documentComments[key] = {
          'message': message,
          'from': from,
          'createdAt': createdAt,
          'reuploadAllowed': reuploadAllowed,
        };
      }
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('Error loading existing uploads: $e');
    }
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please upload only PDF or DOC files.')),
        );
        return;
      }

      setState(() {
        uploadedFiles[title]!['file'] = file;
        uploadedFiles[title]!['fileName'] =
            file.name; // Save filename for display
      });
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error selecting file: $e')));
    }
  }

  Future<void> uploadSingleFile(String title, PlatformFile file) async {
    if (_currentSubmissionId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('⚠️ No submission selected')),
      );
      return;
    }

    setState(() => _isUploading = true);

    try {
      final submissionRef = FirebaseFirestore.instance
          .collection('applications')
          .doc('chainsawreg')
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
          .child('applications/chainsawreg/${widget.applicantId}/$_currentSubmissionId/$fileName');

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
      if (mounted) setState(() => _isUploading = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error uploading $title: $e')));
    }
  }

  Future<void> handleSubmit() async {
    if (_currentSubmissionId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No submission selected')),
      );
      return;
    }

    for (final entry in uploadedFiles.entries) {
      final title = entry.key;
      final file = entry.value['file'] as PlatformFile?;
      if (file != null) {
        await uploadSingleFile(title, file);
      }
    }

    // Update submission status
    try {
      await FirebaseFirestore.instance
          .collection('applications')
          .doc('chainsaw')
          .collection('applicants')
          .doc(widget.applicantId)
          .collection('submissions')
          .doc(_currentSubmissionId!)
          .set({
        'applicantName': widget.applicantName,
        'status': 'submitted',
        'submittedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // Update applicant document count
      final applicantDoc = FirebaseFirestore.instance
          .collection('applications')
          .doc('chainsaw')
          .collection('applicants')
          .doc(widget.applicantId);

      final submissionsSnapshot =
          await applicantDoc.collection('submissions').get();
      await applicantDoc.set({
        'applicantName': widget.applicantName,
        'submissionsCount': submissionsSnapshot.docs.length,
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Error updating submission status: $e');
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('All files uploaded successfully!')),
    );
  }

  /// Sanitize document title to be used as Firestore document ID
  String _sanitizeDocTitle(String title) {
    return title.replaceAll(RegExp(r'[.#$/\[\]]'), '-').trim();
  }

  // Helper to zero-pad minutes/hours
  String _two(int n) => n.toString().padLeft(2, '0');

  /// Formats a Firestore Timestamp or DateTime into a readable string.
  /// Returns empty string if value is null or unrecognized.
  String _formatTimestamp(dynamic ts) {
    if (ts == null) return '';
    DateTime dt;
    // Firestore Timestamp
    if (ts is Timestamp) {
      dt = ts.toDate();
    } else if (ts is DateTime) {
      dt = ts;
    } else if (ts is int) {
      // epoch millis (defensive)
      dt = DateTime.fromMillisecondsSinceEpoch(ts);
    } else {
      // fallback: try parsing string
      try {
        dt = DateTime.parse(ts.toString());
      } catch (_) {
        return ts.toString();
      }
    }

    final hour12 = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    final month = dt.month;
    final day = dt.day;
    final year = dt.year;
    final hour = _two(hour12);
    final minute = _two(dt.minute);

    // Example format: "Nov 15, 2025 · 03:05 PM"
    const monthNames = [
      '',
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    final monthStr = monthNames[month];

    return '$monthStr $day, $year · $hour:$minute $ampm';
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.green[700],
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text('Chainsaw Registration',
            style: TextStyle(color: Colors.white)),
      ),
      body: _isLoadingSubmissions
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
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
                                        '${submission['id']} ',
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
                      'APPLICATION FOR CHAINSAW REGISTRATION\nREQUIREMENTS',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const SizedBox(height: 16),

                    for (final doc in documents) buildUploadField(doc),

                    const SizedBox(height: 24),

                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isUploading ? null : handleSubmit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green[700],
                          disabledBackgroundColor: Colors.grey,
                          disabledForegroundColor: Colors.white70,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        child: _isUploading
                            ? const CircularProgressIndicator(
                                color: Colors.white)
                            : const Text(
                                'Submit All Files',
                                style: TextStyle(
                                    fontSize: 16, color: Colors.white),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
