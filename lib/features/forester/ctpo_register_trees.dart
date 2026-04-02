import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:firebase_storage/firebase_storage.dart';
import 'package:path_provider/path_provider.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'tree_services.dart';

class CtpoRegisterTreesPage extends StatefulWidget {
  final String foresterId;
  final String foresterName;
  final String appointmentId; // ✅ appointment document ID

  const CtpoRegisterTreesPage({
    super.key,
    required this.foresterId,
    required this.foresterName,
    required this.appointmentId,
  });

  @override
  State<CtpoRegisterTreesPage> createState() => _CtpoRegisterTreesPageState();
}

class _CtpoRegisterTreesPageState extends State<CtpoRegisterTreesPage> {
  final TextEditingController specieController = TextEditingController();
  final TextEditingController diameterController = TextEditingController();
  final TextEditingController heightController = TextEditingController();
  final TextEditingController volumeController = TextEditingController();
  final TextEditingController latController = TextEditingController();
  final TextEditingController longController = TextEditingController();

  final FocusNode specieFocus = FocusNode();
  final FocusNode diameterFocus = FocusNode();
  final FocusNode heightFocus = FocusNode();

  final TreeService _treeService = TreeService();
  XFile? imageFile;
  String? lastSubmittedTreeId;
  String? qrUrl;

  // Tree dropdown variables for revisit appointments
  List<Map<String, dynamic>> existingTrees = [];
  String? selectedTreeId; // Original tree doc ID (T1, T2, etc.)
  String? selectedDropdownId; // Unique dropdown ID for UI
  bool isLoadingTrees = false;
  String appointmentType = 'Tree Tagging'; // Default to Tree Tagging

  // Theme colors
  static const Color _primaryGreen = Color(0xFF2E7D32);
  static const Color _darkGreen = Color(0xFF1B5E20);
  static const Color _lightGreen = Color(0xFFE8F5E9);
  static const Color _surfaceColor = Color(0xFFF1F8E9);

  /// ✅ Show notification dialog
  void _showDialog(String title, String message) {
    final isError = title.toLowerCase().contains('error') || message.contains('❌');
    final isSuccess = title.toLowerCase().contains('success') || message.contains('✅');
    final icon = isError
        ? Icons.error_outline_rounded
        : isSuccess
            ? Icons.check_circle_outline_rounded
            : Icons.info_outline_rounded;
    final iconColor = isError
        ? Colors.red[600]!
        : isSuccess
            ? _primaryGreen
            : Colors.blue[600]!;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, color: iconColor, size: 32),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1B5E20),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                message.replaceAll(RegExp(r'[✅❌⚠️📍⏳🌳]'), '').trim(),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primaryGreen,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: const Text('OK', style: TextStyle(fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    diameterController.addListener(_updateVolume);
    heightController.addListener(_updateVolume);
    _loadAppointmentType();
  }

  /// ✅ Load appointment type and trees if it's a revisit
  Future<void> _loadAppointmentType() async {
    try {
      final appointmentDoc = await FirebaseFirestore.instance
          .collection('appointments')
          .doc(widget.appointmentId)
          .get();

      if (appointmentDoc.exists) {
        final data = appointmentDoc.data()!;
        setState(() {
          appointmentType = data['appointmentType'] ?? 'Tree Tagging';
        });

        // Load trees only if it's a revisit appointment
        if (appointmentType == 'Revisit') {
          await _loadExistingTrees();
        }
      }
    } catch (e) {
      print('❌ Error loading appointment type: $e');
    }
  }

  /// ✅ Load existing trees from tree_revisit subcollection for revisit appointments
  Future<void> _loadExistingTrees() async {
    setState(() {
      isLoadingTrees = true;
    });

    try {
      print('✅ Loading trees from appointment: ${widget.appointmentId}');

      // For revisit appointments, load from tree_revisit subcollection
      final treeRevisitSnapshot = await FirebaseFirestore.instance
          .collection('appointments')
          .doc(widget.appointmentId)
          .collection('tree_revisit')
          .get();

      print('✅ Found ${treeRevisitSnapshot.docs.length} trees in tree_revisit');

      final allTrees = <Map<String, dynamic>>[];

      for (var treeDoc in treeRevisitSnapshot.docs) {
        final treeData = treeDoc.data();
        // Get old data from the 'old' map
        final oldData = treeData['old'] as Map<String, dynamic>?;
        
        allTrees.add({
          'docId': treeDoc.id,
          'tree_id': treeData['treeId'] ?? treeDoc.id,
          'tree_no': oldData?['tree_no'] ?? treeDoc.id,
          'specie': oldData?['specie'] ?? 'Unknown',
          'diameter': oldData?['diameter'] ?? 0.0,
          'height': oldData?['height'] ?? 0.0,
          'volume': oldData?['volume'] ?? 0.0,
          'latitude': oldData?['latitude'] ?? 0.0,
          'longitude': oldData?['longitude'] ?? 0.0,
          'tree_status': oldData?['tree_status'] ?? 'Not Yet Ready',
          'tree_tagging_ref': treeData['tree_tagging_ref'] ?? '',
        });
      }

      setState(() {
        existingTrees = allTrees;
        isLoadingTrees = false;
      });

      if (allTrees.isEmpty) {
        _showDialog('Info', '⚠️ No trees found in this appointment');
      } else {
        print('✅ Loaded ${allTrees.length} trees from tree_revisit');
      }
    } catch (e) {
      print('❌ Error loading trees: $e');
      setState(() {
        isLoadingTrees = false;
      });
      _showDialog('Error', '❌ Failed to load trees: $e');
    }
  }

  /// ✅ Auto-fill form when tree is selected from dropdown
  void _onTreeSelected(String? uniqueId) {
    if (uniqueId == null) return;

    final selectedTree = existingTrees.firstWhere(
      (tree) => tree['docId'] == uniqueId,
      orElse: () => {},
    );

    if (selectedTree.isNotEmpty) {
      setState(() {
        selectedDropdownId = uniqueId;
        selectedTreeId = selectedTree['tree_id'];
        specieController.text = selectedTree['specie'] ?? '';
        diameterController.text = selectedTree['diameter']?.toString() ?? '';
        heightController.text = selectedTree['height']?.toString() ?? '';
        volumeController.text = selectedTree['volume']?.toString() ?? '';
        latController.text = selectedTree['latitude']?.toString() ?? '';
        longController.text = selectedTree['longitude']?.toString() ?? '';
      });
      _showDialog('Success', '✅ Tree data loaded successfully!');
    }
  }

  @override
  void dispose() {
    specieController.dispose();
    diameterController.dispose();
    heightController.dispose();
    volumeController.dispose();
    latController.dispose();
    longController.dispose();
    super.dispose();
  }

  Future<void> _getLocation() async {
    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      setState(() {
        latController.text = position.latitude.toStringAsFixed(6);
        longController.text = position.longitude.toStringAsFixed(6);
      });
      _showDialog('Success', '📍 Location fetched successfully!');
    } catch (e) {
      _showDialog('Error', '⚠️ Failed to get location: $e');
    }
  }

  void _updateVolume() {
    double diameter = double.tryParse(diameterController.text) ?? 0;
    double height = double.tryParse(heightController.text) ?? 0;
    double volume = _treeService.calculateVolume(diameter, height);
    volumeController.text = volume > 0 ? volume.toStringAsFixed(2) : '';
  }

  /// ✅ Generate QR, upload to Storage, and return the download URL
  Future<String?> _generateAndUploadQr(
      String documentId, Map<String, dynamic> data) async {
    try {
      // Only encode essential lookup fields to keep QR code scannable.
      // Full tree data is fetched from Firestore using these keys.
      final qrPayload = {
        'format': 'treesure.v2',
        'inventory_doc_id': documentId,
        'appointment_id': data['appointment_id'],
        'tree_id': data['tree_id'],
      };

      final qrPainter = QrPainter(
        data: jsonEncode(qrPayload),
        version: QrVersions.auto,
        errorCorrectionLevel: QrErrorCorrectLevel.H,
        color: const Color(0xFF000000),
        emptyColor: const Color(0xFFFFFFFF),
        gapless: false,
      );

      // Render QR with quiet zone (white padding) so scanners can detect it
      const double qrSize = 504;
      const double padding = 48;
      const double totalSize = qrSize + padding * 2; // 600

      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      canvas.drawRect(
        const Rect.fromLTWH(0, 0, totalSize, totalSize),
        Paint()..color = const Color(0xFFFFFFFF),
      );
      canvas.translate(padding, padding);
      qrPainter.paint(canvas, const Size(qrSize, qrSize));

      final picture = recorder.endRecording();
      final img = await picture.toImage(totalSize.toInt(), totalSize.toInt());
      final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
      final Uint8List bytes = byteData!.buffer.asUint8List();
      img.dispose();

      // Upload bytes directly to Firebase Storage
      final ref =
          FirebaseStorage.instance.ref().child('tree_qrcodes/$documentId.png');

      UploadTask uploadTask;
      if (kIsWeb) {
        uploadTask = ref.putData(bytes);
      } else {
        // For mobile — use path_provider
        final dir = await getTemporaryDirectory();
        final file = File('${dir.path}/$documentId.png');
        await file.writeAsBytes(bytes);
        uploadTask = ref.putFile(file);
      }

      // ✅ Handle the upload task on the main thread
      await uploadTask.then((_) {
        return;
      }, onError: (error, stackTrace) {
        print('❌ QR upload error: $error');
        throw error;
      });

      return await ref.getDownloadURL();
    } catch (e) {
      print('❌ QR generation/upload failed: $e');
      return null;
    }
  }

  /// ✅ Handle form submission
  Future<void> handleSubmit() async {
    final latitude = double.tryParse(latController.text);
    final longitude = double.tryParse(longController.text);
    final specie = specieController.text.trim();
    final diameter = double.tryParse(diameterController.text);
    final height = double.tryParse(heightController.text);
    final volume = double.tryParse(volumeController.text);
    final appointmentId = widget.appointmentId;

    String treeId;
    
    // ✅ For revisit appointments, use selected tree ID or generate new one
    if (appointmentType == 'Revisit' && selectedTreeId != null) {
      treeId = selectedTreeId!;
    } else {
      // For new trees, get the count and generate ID
      final collectionName = appointmentType == 'Revisit' ? 'tree_revisit' : 'tree_inventory';
      final treeCollection = FirebaseFirestore.instance
          .collection('appointments')
          .doc(appointmentId)
          .collection(collectionName);

      final count = await treeCollection.count().get();
      treeId = 'T${(count.count ?? 0) + 1}'; // Format as T1, T2, etc.
    }

    if (latitude == null ||
        longitude == null ||
        specie.isEmpty ||
        diameter == null ||
        height == null ||
        volume == null) {
      _showDialog('Validation Error', '⚠️ Please fill out all fields.');
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: const Text('Processing'),
        content: const Text('⏳ Submitting data...'),
      ),
    );

    try {
      String newDocId;
      
      // ✅ For revisit appointments, update tree_revisit subcollection
      if (appointmentType == 'Revisit' && selectedTreeId != null) {
        newDocId = selectedDropdownId ?? selectedTreeId!;
        
        // Upload photo if provided
        String? photoUrl;
        if (imageFile != null) {
          final storageRef = FirebaseStorage.instance
              .ref()
              .child('tree_photos/${widget.appointmentId}/$newDocId.jpg');
          
          if (kIsWeb) {
            final bytes = await imageFile!.readAsBytes();
            await storageRef.putData(bytes);
          } else {
            await storageRef.putFile(File(imageFile!.path));
          }
          photoUrl = await storageRef.getDownloadURL();
        }
        
        // Update the tree_revisit document with new data
        await FirebaseFirestore.instance
            .collection('appointments')
            .doc(widget.appointmentId)
            .collection('tree_revisit')
            .doc(newDocId)
            .update({
          'specie': specie,
          'diameter': diameter,
          'height': height,
          'volume': volume,
          'forester_id': widget.foresterId,
          'forester_name': widget.foresterName,
          'updatedAt': FieldValue.serverTimestamp(),
          if (photoUrl != null) 'photo_url': photoUrl,
          // Note: old data remains in 'old' map, only updating new fields
        });
      } else {
        // ✅ For tree tagging appointments, save normally
        newDocId = await _treeService.sendTreeInfo(
          lat: latitude,
          lng: longitude,
          treeId: treeId,
          treeNo: treeId,
          specie: specie,
          diameter: diameter,
          height: height,
          volume: volume,
          foresterId: widget.foresterId,
          forester: widget.foresterName,
          imageFile: imageFile,
          appointmentId: appointmentId,
        );
      }

      // ✅ Fetch the complete tree document
      final collectionName = appointmentType == 'Revisit' ? 'tree_revisit' : 'tree_inventory';
      final treeDoc = await FirebaseFirestore.instance
          .collection('appointments')
          .doc(widget.appointmentId)
          .collection(collectionName)
          .doc(newDocId)
          .get();

      if (!treeDoc.exists) {
        throw Exception('Failed to retrieve saved tree data');
      }

      // ✅ Prepare QR data with all fields from the saved document
      final treeData = treeDoc.data()!;
      
      // For revisit appointments, use old data for QR if new data is null
      Map<String, dynamic> qrData;
      if (appointmentType == 'Revisit') {
        final oldData = treeData['old'] as Map<String, dynamic>?;
        qrData = {
          'tree_id': treeData['treeId'] ?? treeId,
          'tree_no': oldData?['tree_no'] ?? treeId,
          'appointment_id': widget.appointmentId,
          'specie': treeData['specie'] ?? oldData?['specie'] ?? specie,
          'diameter': treeData['diameter'] ?? oldData?['diameter'] ?? diameter,
          'height': treeData['height'] ?? oldData?['height'] ?? height,
          'volume': treeData['volume'] ?? oldData?['volume'] ?? volume,
          'latitude': latitude,
          'longitude': longitude,
          'forester_id': treeData['forester_id'] ?? widget.foresterId,
          'forester_name': treeData['forester_name'] ?? widget.foresterName,
          'photo_url': treeData['photo_url'] ?? '',
          'tree_status': treeData['tree_status'] ?? oldData?['tree_status'] ?? 'Not Yet Ready',
          'tree_tagging_ref': treeData['tree_tagging_ref'] ?? '',
          'timestamp': treeData['updatedAt']?.toDate().toString() ?? DateTime.now().toString(),
        };
      } else {
        qrData = {
          'tree_id': treeData['tree_id'] ?? treeId,
          'tree_no': treeData['tree_no'] ?? treeId,
          'appointment_id': treeData['appointment_id'] ?? appointmentId,
          'specie': treeData['specie'] ?? specie,
          'diameter': treeData['diameter'] ?? diameter,
          'height': treeData['height'] ?? height,
          'volume': treeData['volume'] ?? volume,
          'latitude': treeData['latitude'] ?? latitude,
          'longitude': treeData['longitude'] ?? longitude,
          'forester_id': treeData['forester_id'] ?? widget.foresterId,
          'forester_name': treeData['forester_name'] ?? widget.foresterName,
          'photo_url': treeData['photo_url'] ?? '',
          'tree_status': treeData['tree_status'] ?? 'Not Yet Ready',
          'tree_tagging_appointment_id': treeData['tree_tagging_appointment_id'] ?? '',
          'timestamp': treeData['timestamp']?.toDate().toString() ?? DateTime.now().toString(),
        };
      }

      // ✅ Generate and upload QR
      final qrDownloadUrl = await _generateAndUploadQr(newDocId, qrData);

      // ✅ Update Firestore with QR URL
      if (qrDownloadUrl != null) {
        await FirebaseFirestore.instance
            .collection('appointments')
            .doc(widget.appointmentId)
            .collection(collectionName)
            .doc(newDocId)
            .update({'qr_url': qrDownloadUrl});
      }

      // ✅ Set appointment status to 'In Progress' if there are tagged trees
      await FirebaseFirestore.instance
          .collection('appointments')
          .doc(widget.appointmentId)
          .update({'status': 'In Progress'});

      setState(() {
        lastSubmittedTreeId = newDocId;
        qrUrl = qrDownloadUrl;
      });

      // Close the "Submitting" dialog
      Navigator.of(context).pop();

      final successMessage = appointmentType == 'Revisit' 
          ? '✅ Tree revisit data updated successfully!'
          : '✅ Tree and QR successfully saved!';
      _showDialog('Success', successMessage);

      _clearFields();
    } catch (e) {
      // Close the "Submitting" dialog
      Navigator.of(context).pop();

      _showDialog('Error', '❌ Submission failed: $e');
    }
  }

  void _clearFields() {
    specieController.clear();
    diameterController.clear();
    heightController.clear();
    volumeController.clear();
    latController.clear();
    longController.clear();
    setState(() {
      imageFile = null;
      qrUrl = null;
      selectedTreeId = null;
      selectedDropdownId = null;
    });
  }

  Future<void> pickImage() async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(source: ImageSource.gallery);
      if (pickedFile != null) {
        setState(() {
          imageFile = pickedFile;
        });
      }
    } catch (e) {
      _showDialog('Error', '⚠️ Failed to pick image: $e');
    }
  }

  /// ✅ Mark tree tagging as completed by current forester
  Future<void> _completeTreeTagging() async {
    try {
      final appointmentRef = FirebaseFirestore.instance
          .collection('appointments')
          .doc(widget.appointmentId);

      final appointmentDoc = await appointmentRef.get();
      if (!appointmentDoc.exists) {
        _showDialog('Error', '❌ Appointment not found.');
        return;
      }

      final appointmentData = appointmentDoc.data()!;
      final foresterIds = List<String>.from(appointmentData['foresterIds'] ?? []);
      
      // Initialize completionStatus if it doesn't exist
      Map<String, dynamic> completionStatus = 
          Map<String, dynamic>.from(appointmentData['completionStatus'] ?? {});

      // Mark current forester as completed
      completionStatus[widget.foresterId] = {
        'completed': true,
        'completedAt': FieldValue.serverTimestamp(),
      };

      // Check if all foresters have completed
      bool allCompleted = foresterIds.every(
        (foresterId) => completionStatus[foresterId]?['completed'] == true,
      );

      // Update appointment with completion status
      if (allCompleted) {
        // All foresters completed - set the overall completedAt
        await appointmentRef.update({
          'completionStatus': completionStatus,
          'completedAt': FieldValue.serverTimestamp(),
          'status': 'Completed',
        });

        _showDialog('Success', '✅ Tree tagging completed by all foresters!');
      } else {
        // Not all completed yet
        final completedCount = completionStatus.values
            .where((v) => v['completed'] == true)
            .length;
        final totalCount = foresterIds.length;

        await appointmentRef.update({
          'completionStatus': completionStatus,
          'status': 'In Progress',
        });

        _showDialog('Info', '✅ Marked as completed. Waiting for other foresters ($completedCount/$totalCount)');
      }
    } catch (e) {
      _showDialog('Error', '❌ Error completing tree tagging: $e');
    }
  }

  Future<void> viewSummaryDialog() async {
    Map<String, dynamic> submittedData = {
      "Forester Name": widget.foresterName,
      "Specie": specieController.text,
      "Diameter (cm)": diameterController.text,
      "Height (m)": heightController.text,
      "Volume (CU m)": volumeController.text,
      "Latitude": latController.text,
      "Longitude": longController.text,
    };

    String? photoUrl;

    if (lastSubmittedTreeId != null) {
      final doc = await FirebaseFirestore.instance
          .collection('appointments')
          .doc(widget.appointmentId)
          .collection('tree_inventory')
          .doc(lastSubmittedTreeId)
          .get();

      if (doc.exists) {
        photoUrl = doc.data()?['photo_url'];
        qrUrl = doc.data()?['qr_url'];
      }
    }

    final summaryIcons = <String, IconData>{
      "Forester Name": Icons.person_rounded,
      "Specie": Icons.eco_rounded,
      "Diameter (cm)": Icons.straighten_rounded,
      "Height (m)": Icons.height_rounded,
      "Volume (CU m)": Icons.inventory_2_rounded,
      "Latitude": Icons.explore_rounded,
      "Longitude": Icons.explore_rounded,
    };

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        builder: (_, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.all(24),
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _lightGreen,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.park_rounded, color: _primaryGreen, size: 28),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Tree Data Summary',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: _darkGreen,
                          ),
                        ),
                        Text(
                          'Review submitted tree information',
                          style: TextStyle(fontSize: 13, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              ...submittedData.entries.map((entry) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: _surfaceColor,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: _primaryGreen.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              summaryIcons[entry.key] ?? Icons.info_rounded,
                              color: _primaryGreen,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  entry.key,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  entry.value.toString().isEmpty
                                      ? 'N/A'
                                      : entry.value.toString(),
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: _darkGreen,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  )),
              const SizedBox(height: 16),
              _buildMediaSection('Photo Evidence', photoUrl),
              const SizedBox(height: 12),
              _buildMediaSection('QR Code', qrUrl),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primaryGreen,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
                  ),
                  child: const Text('Done', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMediaSection(String title, String? url) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 14,
              color: _darkGreen,
            ),
          ),
          const SizedBox(height: 12),
          if (url != null && url.isNotEmpty)
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(url, height: 200, width: double.infinity, fit: BoxFit.cover),
            )
          else
            Container(
              height: 100,
              width: double.infinity,
              decoration: BoxDecoration(
                color: _surfaceColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.image_not_supported_rounded, color: Colors.grey[400], size: 32),
                  const SizedBox(height: 8),
                  Text('Not available', style: TextStyle(color: Colors.grey[500], fontSize: 13)),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // ✅ UI
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _surfaceColor,
      body: Column(
        children: [
          // Modern gradient header
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF1B5E20), Color(0xFF2E7D32), Color(0xFF43A047)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(28),
                bottomRight: Radius.circular(28),
              ),
            ),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 20, 24),
                child: Column(
                  children: [
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                          onPressed: () => Navigator.pop(context),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Tree Inventory',
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Forester: ${widget.foresterName}',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.white.withOpacity(0.85),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            appointmentType,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Form content
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                // Revisit tree selection
                if (appointmentType == 'Revisit') ...[
                  _buildSectionHeader('Select Existing Tree', Icons.nature_rounded),
                  const SizedBox(height: 12),
                  isLoadingTrees
                      ? const Center(
                          child: Padding(
                            padding: EdgeInsets.all(20),
                            child: CircularProgressIndicator(color: _primaryGreen),
                          ),
                        )
                      : existingTrees.isEmpty
                          ? _buildEmptyCard('No existing trees found')
                          : Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(14),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.04),
                                    blurRadius: 10,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: DropdownButtonFormField<String>(
                                value: selectedDropdownId,
                                decoration: InputDecoration(
                                  labelText: 'Select Tree',
                                  labelStyle: TextStyle(color: Colors.grey[600]),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    borderSide: BorderSide.none,
                                  ),
                                  filled: true,
                                  fillColor: Colors.white,
                                  prefixIcon: Container(
                                    margin: const EdgeInsets.all(8),
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: _lightGreen,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: const Icon(Icons.park_rounded, color: _primaryGreen, size: 20),
                                  ),
                                ),
                                items: existingTrees.map((tree) {
                                  final treeId = tree['tree_id'] ?? tree['docId'];
                                  final specie = tree['specie'] ?? 'Unknown';
                                  return DropdownMenuItem<String>(
                                    value: tree['docId'],
                                    child: Text('$treeId - $specie'),
                                  );
                                }).toList(),
                                onChanged: _onTreeSelected,
                              ),
                            ),
                  const SizedBox(height: 8),
                  Divider(color: Colors.grey[200]),
                  const SizedBox(height: 16),
                ],

                // Tree Details Section
                _buildSectionHeader('Tree Details', Icons.eco_rounded),
                const SizedBox(height: 12),
                _buildModernTextField('Specie', specieController,
                    icon: Icons.eco_rounded, focusNode: specieFocus),
                Row(
                  children: [
                    Expanded(
                      child: _buildModernTextField('Diameter (cm)', diameterController,
                          icon: Icons.straighten_rounded,
                          focusNode: diameterFocus,
                          keyboardType: TextInputType.number),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildModernTextField('Height (m)', heightController,
                          icon: Icons.height_rounded,
                          focusNode: heightFocus,
                          keyboardType: TextInputType.number),
                    ),
                  ],
                ),
                _buildModernTextField('Volume (CU m)', volumeController,
                    icon: Icons.inventory_2_rounded, enabled: false),
                const SizedBox(height: 20),

                // Location Section
                _buildSectionHeader('Location', Icons.location_on_rounded),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildModernTextField('Latitude', latController,
                          icon: Icons.explore_rounded, enabled: false),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildModernTextField('Longitude', longController,
                          icon: Icons.explore_rounded, enabled: false),
                    ),
                  ],
                ),
                InkWell(
                  onTap: _getLocation,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                    decoration: BoxDecoration(
                      color: _lightGreen,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.my_location_rounded, color: _primaryGreen, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'Get Current Location',
                          style: TextStyle(
                            color: _primaryGreen,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Photo Section
                _buildSectionHeader('Photo Evidence', Icons.camera_alt_rounded),
                const SizedBox(height: 12),
                GestureDetector(
                  onTap: pickImage,
                  child: Container(
                    height: imageFile != null ? 220 : 140,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: imageFile != null ? _primaryGreen : Colors.grey[300]!,
                        width: imageFile != null ? 2 : 1,
                        strokeAlign: BorderSide.strokeAlignInside,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: imageFile != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(14),
                            child: kIsWeb
                                ? Image.network(imageFile!.path, fit: BoxFit.cover)
                                : Image.file(File(imageFile!.path), fit: BoxFit.cover),
                          )
                        : Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: _lightGreen,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: const Icon(Icons.add_a_photo_rounded, color: _primaryGreen, size: 32),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Tap to add photo',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
                const SizedBox(height: 28),

                // Action buttons
                _buildGradientButton(
                  'Submit Tree Data',
                  Icons.check_circle_rounded,
                  onPressed: handleSubmit,
                ),
                const SizedBox(height: 12),
                _buildOutlinedButton(
                  'View Summary',
                  Icons.summarize_rounded,
                  onPressed: viewSummaryDialog,
                ),
                const SizedBox(height: 12),
                _buildGradientButton(
                  'Tree Tagging Completed',
                  Icons.flag_rounded,
                  onPressed: _completeTreeTagging,
                  colors: [Colors.orange[700]!, Colors.orange[500]!],
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: _primaryGreen.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: _primaryGreen, size: 18),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: _darkGreen,
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyCard(String message) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline_rounded, color: Colors.grey[400], size: 24),
          const SizedBox(width: 12),
          Text(message, style: TextStyle(color: Colors.grey[600], fontSize: 14)),
        ],
      ),
    );
  }

  Widget _buildModernTextField(
    String label,
    TextEditingController controller, {
    IconData? icon,
    FocusNode? focusNode,
    bool enabled = true,
    TextInputType? keyboardType,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        decoration: BoxDecoration(
          color: enabled ? Colors.white : Colors.grey[50],
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: TextField(
          controller: controller,
          focusNode: focusNode,
          enabled: enabled,
          keyboardType: keyboardType,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
          decoration: InputDecoration(
            labelText: label,
            labelStyle: TextStyle(color: Colors.grey[500], fontSize: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: _primaryGreen, width: 2),
            ),
            filled: true,
            fillColor: enabled ? Colors.white : Colors.grey[50],
            prefixIcon: icon != null
                ? Container(
                    margin: const EdgeInsets.all(8),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _lightGreen,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(icon, color: _primaryGreen, size: 18),
                  )
                : null,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        ),
      ),
    );
  }

  Widget _buildGradientButton(
    String label,
    IconData icon, {
    required VoidCallback onPressed,
    List<Color>? colors,
  }) {
    final btnColors = colors ?? [_darkGreen, _primaryGreen];
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: btnColors),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: btnColors.first.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 20),
        label: Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
          shadowColor: Colors.transparent,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
    );
  }

  Widget _buildOutlinedButton(
    String label,
    IconData icon, {
    required VoidCallback onPressed,
  }) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _primaryGreen, width: 2),
      ),
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 20),
        label: Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: _primaryGreen,
          shadowColor: Colors.transparent,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          elevation: 0,
        ),
      ),
    );
  }

  Widget buildTextField(
    String label,
    TextEditingController controller, {
    FocusNode? focusNode,
    bool enabled = true,
    TextInputType? keyboardType,
  }) {
    return _buildModernTextField(label, controller,
        focusNode: focusNode, enabled: enabled, keyboardType: keyboardType);
  }
}
