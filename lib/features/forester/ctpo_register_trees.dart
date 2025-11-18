import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

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

  /// ✅ Show notification dialog
  void _showDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('OK'),
          ),
        ],
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
      final qrPayload = {
        'format': 'treesure.v2',
        'inventory_doc_id': documentId,
        'appointment_id': data['appointment_id'],
        'tree_id': data['tree_id'],
        'tree_no': data['tree_no'],
        'tree_status': data['tree_status'] ?? 'Not Yet Ready',
        'tree_tagging_appointment_id':
            data['tree_tagging_appointment_id'] ?? '',
        'specie': data['specie'],
        'diameter': data['diameter'],
        'height': data['height'],
        'volume': data['volume'],
        'latitude': data['latitude'],
        'longitude': data['longitude'],
        'forester_id': data['forester_id'],
        'forester_name': data['forester_name'],
        'photo_url': data['photo_url'] ?? '',
        'timestamp': data['timestamp'],
        'generated_at': DateTime.now().toIso8601String(),
      };

      final qrPainter = QrPainter(
        data: jsonEncode(qrPayload),
        version: QrVersions.auto,
        gapless: true,
      );
      final picData = await qrPainter.toImageData(300);
      final Uint8List bytes = picData!.buffer.asUint8List();

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

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: const Text("🌳 Tree Data Summary"),
        content: SingleChildScrollView(
          child: Column(
            children: [
              for (var entry in submittedData.entries)
                ListTile(
                  title: Text(entry.key),
                  subtitle: Text(entry.value.toString()),
                ),
              const Divider(),
              const Text("Photo Evidence",
                  style: TextStyle(fontWeight: FontWeight.bold)),
              if (photoUrl != null && photoUrl.isNotEmpty)
                Image.network(photoUrl, height: 200, fit: BoxFit.cover)
              else
                const Text("No photo available"),
              const SizedBox(height: 10),
              const Text("QR Code",
                  style: TextStyle(fontWeight: FontWeight.bold)),
              if (qrUrl != null && qrUrl!.isNotEmpty)
                Image.network(qrUrl!, height: 200, fit: BoxFit.cover)
              else
                const Text("No QR available"),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text("Close"),
          ),
        ],
      ),
    );
  }

  // ✅ UI
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Tree Inventory"),
        backgroundColor: Colors.green[800],
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: [
            Text("Forester: ${widget.foresterName}",
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 20),
            
            // ✅ Show tree dropdown only for revisit appointments
            if (appointmentType == 'Revisit') ...[
              const Text(
                "Select Existing Tree (Revisit)",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 8),
              isLoadingTrees
                  ? const Center(child: CircularProgressIndicator())
                  : existingTrees.isEmpty
                      ? const Text(
                          "No existing trees found",
                          style: TextStyle(color: Colors.grey),
                        )
                      : DropdownButtonFormField<String>(
                          value: selectedDropdownId,
                          decoration: InputDecoration(
                            labelText: "Select Tree",
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            prefixIcon: const Icon(Icons.nature, color: Colors.green),
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
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 16),
            ],
            
            buildTextField("Specie", specieController, focusNode: specieFocus),
            Row(
              children: [
                Expanded(
                  child: buildTextField("Diameter (cm)", diameterController,
                      focusNode: diameterFocus,
                      keyboardType: TextInputType.number),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: buildTextField("Height (m)", heightController,
                      focusNode: heightFocus,
                      keyboardType: TextInputType.number),
                ),
              ],
            ),
            buildTextField("Volume (CU m)", volumeController, enabled: false),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                    child: buildTextField("Latitude", latController,
                        enabled: false)),
                const SizedBox(width: 12),
                Expanded(
                    child: buildTextField("Longitude", longController,
                        enabled: false)),
              ],
            ),
            TextButton.icon(
              icon: const Icon(Icons.my_location, color: Colors.green),
              label: const Text("Get Current Location"),
              onPressed: _getLocation,
            ),
            const SizedBox(height: 20),
            const Text("Photo Evidence",
                style: TextStyle(fontWeight: FontWeight.bold)),
            if (imageFile != null)
              kIsWeb
                  ? Image.network(imageFile!.path, height: 200)
                  : Image.file(File(imageFile!.path), height: 200)
            else
              const Text("No image selected."),
            TextButton.icon(
              icon: const Icon(Icons.upload),
              label: const Text("Pick Photo"),
              onPressed: pickImage,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: handleSubmit,
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green[800],
                  padding: const EdgeInsets.symmetric(vertical: 16)),
              child: const Text("Submit",
                  style: TextStyle(color: Colors.white, fontSize: 16)),
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: viewSummaryDialog,
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green[800],
                  padding: const EdgeInsets.symmetric(vertical: 16)),
              child: const Text("View Summary",
                  style: TextStyle(color: Colors.white, fontSize: 16)),
            ),
            const SizedBox(height: 15),
            ElevatedButton(
              onPressed: _completeTreeTagging,
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange[700],
                  padding: const EdgeInsets.symmetric(vertical: 16)),
              child: const Text("Tree Tagging Completed",
                  style: TextStyle(color: Colors.white, fontSize: 16)),
            ),
          ],
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
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        enabled: enabled,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
    );
  }
}
