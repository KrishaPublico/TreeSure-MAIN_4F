import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as path;
import 'package:url_launcher/url_launcher.dart';

class ApplicationUploadPage extends StatefulWidget {
  final String applicantId;
  final String applicantName;
  final String type; // 🔹 ctpo, certificate to travel, chainsaw permit, etc.

  const ApplicationUploadPage({
    super.key,
    required this.applicantId,
    required this.applicantName,
    required this.type,
  });

  @override
  State<ApplicationUploadPage> createState() => _ApplicationUploadPageState();
}

class _ApplicationUploadPageState extends State<ApplicationUploadPage> {
  final Map<String, List<Map<String, String>>> formRequirements = {
    'ctpo': [
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
    ],
    'certificate to travel': [
      {"title": "Request Letter", "description": "(1 original)"},
      {"title": "Approved Cutting Permit", "description": "(1 photocopy)"},
      {"title": "Delivery Receipt", "description": "(1 original)"},
    ],
    'chainsaw permit': [
      {"title": "Letter of Application", "description": "(1 original)"},
      {"title": "Proof of Ownership", "description": "(1 certified copy)"},
      {"title": "Barangay Clearance", "description": "(1 original)"},
    ],
    'private land timber permit': [
      {"title": "Application Form", "description": "(1 original)"},
      {"title": "Proof of Land Ownership", "description": "(1 certified copy)"},
      {"title": "Inventory of Trees", "description": "(1 original)"},
    ],
    'special land timber permit': [
      {"title": "Application Form", "description": "(1 original)"},
      {"title": "DENR Clearance", "description": "(1 photocopy)"},
      {"title": "LGU Endorsement", "description": "(1 original)"},
    ],
  };

  final Map<String, Map<String, dynamic>> uploadedFiles = {};
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    final type = widget.type.toLowerCase();
    final labels = formRequirements[type] ?? [];
    for (final label in labels) {
      uploadedFiles[label["title"]!] = {"file": null, "url": null};
    }
    _loadExistingUploads();
  }

  /// 🔹 Load already uploaded files
  Future<void> _loadExistingUploads() async {
    final uploadsRef = FirebaseFirestore.instance
        .collection('applications')
        .doc(widget.type)
        .collection('applicants')
        .doc(widget.applicantId)
        .collection('uploads');

    final snapshot = await uploadsRef.get();
    for (final doc in snapshot.docs) {
      final data = doc.data();
      final title = data['title'] as String?;
      final url = data['url'] as String?;
      if (title != null && uploadedFiles.containsKey(title)) {
        uploadedFiles[title]!["url"] = url;
      }
    }
    setState(() {});
  }

  /// 🔹 File picker
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

      setState(() {
        uploadedFiles[title]!["file"] = file;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error selecting file: $e")),
      );
    }
  }

  /// 🔹 Upload all files (hybrid write)
  Future<void> handleSubmit() async {
    setState(() => _isUploading = true);

    try {
      final firestore = FirebaseFirestore.instance;
      final storage = FirebaseStorage.instance;
      final appType = widget.type.toLowerCase();

      // References
      final appDoc = firestore.collection('applications').doc(appType);
      final applicantDoc = appDoc.collection('applicants').doc(widget.applicantId);
      final userUploadsRef = firestore
          .collection('users')
          .doc(widget.applicantId)
          .collection('${appType}_uploads');
      final applicantUploadsRef = applicantDoc.collection('uploads');

      for (final entry in uploadedFiles.entries) {
        final title = entry.key;
        final file = entry.value["file"] as PlatformFile?;
        if (file == null) continue;

        final safeTitle = title.replaceAll(RegExp(r'[.#$/\[\]]'), '-').trim();
        final fileName = "${DateTime.now().millisecondsSinceEpoch}_${file.name}";
        final ref = storage.ref().child("${appType}_uploads/$fileName");

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

        // Save in both locations
        await userUploadsRef.doc(safeTitle).set(uploadData);
        await applicantUploadsRef.doc(safeTitle).set(uploadData);

        uploadedFiles[title]!["url"] = url;
      }

      // Ensure applicant metadata exists
      await applicantDoc.set({
        'applicantName': widget.applicantName,
        'uploadedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // Update main summary doc
      final applicantsSnapshot = await appDoc.collection('applicants').get();
      final uploadedCount = applicantsSnapshot.docs.length;

      await appDoc.set({
        'uploadedCount': uploadedCount,
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (mounted) {
        setState(() => _isUploading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("${widget.type.toUpperCase()} files uploaded successfully!")),
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
    final isUploaded = url != null;

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
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: _primaryGreen,
                                ),
                              ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1A1A1A),
                        ),
                      ),
                      if (description.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          description,
                          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Status + action row
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
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.file_present_rounded, color: Colors.orange, size: 14),
                        const SizedBox(width: 4),
                        Text(
                          file.name.length > 20 ? '${file.name.substring(0, 20)}...' : file.name,
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.orange),
                        ),
                      ],
                    ),
                  ),
                const Spacer(),
                if (isUploaded)
                  TextButton.icon(
                    onPressed: () async {
                      await launchUrl(Uri.parse(url!));
                    },
                    icon: const Icon(Icons.visibility_rounded, size: 16),
                    label: const Text('View', style: TextStyle(fontSize: 12)),
                    style: TextButton.styleFrom(
                      foregroundColor: _primaryGreen,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    ),
                  ),
                const SizedBox(width: 4),
                Material(
                  color: isUploaded
                      ? Colors.grey[200]
                      : file != null
                          ? Colors.orange
                          : _primaryGreen,
                  borderRadius: BorderRadius.circular(12),
                  child: InkWell(
                    onTap: isUploaded ? null : () => pickFile(title),
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isUploaded ? Icons.lock_rounded : Icons.upload_file_rounded,
                            size: 16,
                            color: isUploaded ? Colors.grey[500] : Colors.white,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            isUploaded ? 'Done' : file != null ? 'Change' : 'Select File',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: isUploaded ? Colors.grey[500] : Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final formLabels = formRequirements[widget.type.toLowerCase()] ?? [];
    final uploadProgress = formLabels.isEmpty
        ? 0.0
        : formLabels.where((l) => uploadedFiles[l['title']]?['url'] != null).length / formLabels.length;

    return Scaffold(
      backgroundColor: _surfaceColor,
      body: formLabels.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: _lightGreen,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Icon(Icons.info_outline_rounded, color: _primaryGreen, size: 40),
                  ),
                  const SizedBox(height: 16),
                  const Text("No requirements defined for this type.",
                      style: TextStyle(fontSize: 16, color: Colors.grey)),
                ],
              ),
            )
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
                                      Text(
                                        '${widget.type.toUpperCase()} Upload',
                                        style: const TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'Document Requirements',
                                        style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.8)),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),
                            // Applicant info card
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 44,
                                    height: 44,
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Icon(Icons.person_rounded, color: Colors.white, size: 24),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          widget.applicantName,
                                          style: const TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          'ID: ${widget.applicantId}',
                                          style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.7)),
                                        ),
                                      ],
                                    ),
                                  ),
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
                                Text(
                                  '${(uploadProgress * 100).toInt()}%',
                                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                // Body content
                SliverPadding(
                  padding: const EdgeInsets.all(16),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      // Section header
                      Row(
                        children: [
                          Container(
                            width: 4,
                            height: 20,
                            decoration: BoxDecoration(
                              color: _primaryGreen,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          const SizedBox(width: 10),
                          const Text(
                            'Required Documents',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1A1A1A),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: _lightGreen,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '${formLabels.length}',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _primaryGreen),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      for (int i = 0; i < formLabels.length; i++) buildUploadField(formLabels[i], i),
                      const SizedBox(height: 24),
                      // Submit button
                      Container(
                        width: double.infinity,
                        height: 56,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [_darkGreen, _primaryGreen],
                          ),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: _primaryGreen.withValues(alpha: 0.3),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: _isUploading ? null : handleSubmit,
                            borderRadius: BorderRadius.circular(16),
                            child: Center(
                              child: _isUploading
                                  ? const SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                                    )
                                  : const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.cloud_upload_rounded, color: Colors.white, size: 20),
                                        SizedBox(width: 10),
                                        Text(
                                          'Submit All Documents',
                                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                                        ),
                                      ],
                                    ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                    ]),
                  ),
                ),
              ],
            ),
    );
  }
}
