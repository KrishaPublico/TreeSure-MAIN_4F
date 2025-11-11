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

  /// ✅ Show notification dialog
  void _showDialog(String title, String message, {bool isError = false}) {
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
      String treeId, Map<String, dynamic> data) async {
    try {
      // Generate QR data text
      final qrData = '''
Tree ID: $treeId
Tree No: ${data['tree_no']}
Specie: ${data['specie']}
Diameter: ${data['diameter']}
Height: ${data['height']}
Volume: ${data['volume']}
Location: (${data['latitude']}, ${data['longitude']})
Forester: ${data['forester_name']}
''';

      // Generate QR image as bytes
      final qrPainter = QrPainter(
        data: qrData,
        version: QrVersions.auto,
        gapless: true,
      );
      final picData = await qrPainter.toImageData(300);
      final Uint8List bytes = picData!.buffer.asUint8List();

      // Upload bytes directly to Firebase Storage
      final ref =
          FirebaseStorage.instance.ref().child('tree_qrcodes/$treeId.png');

      UploadTask uploadTask;
      if (kIsWeb) {
        uploadTask = ref.putData(bytes);
      } else {
        // For mobile — use path_provider
        final dir = await getTemporaryDirectory();
        final file = File('${dir.path}/$treeId.png');
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

    // ✅ Get the count of existing trees in the appointment and generate the new tree ID
    final treeCollection = FirebaseFirestore.instance
        .collection('appointments')
        .doc(appointmentId)
        .collection('tree_inventory');

    final count = await treeCollection.count().get();
    final treeId = 'T${(count.count ?? 0) + 1}'; // Format as T1, T2, etc.

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
      // ✅ Save the tree info first
      final newDocId = await _treeService.sendTreeInfo(
        lat: latitude,
        lng: longitude,
        treeId: treeId, // Pass the generated treeId
        treeNo: treeId, // Use the same ID as tree number
        specie: specie,
        diameter: diameter,
        height: height,
        volume: volume,
        foresterId: widget.foresterId,
        forester: widget.foresterName,
        imageFile: imageFile, appointmentId: appointmentId,
      );

      // ✅ Prepare QR data
      final data = {
        'tree_id': treeId,
        'tree_no': treeId, // Use the same ID as tree number
        'specie': specie,
        'diameter': diameter,
        'height': height,
        'volume': volume,
        'latitude': latitude,
        'longitude': longitude,
        'forester_name': widget.foresterName,
      };

      // ✅ Generate and upload QR
      final qrDownloadUrl = await _generateAndUploadQr(newDocId, data);

      // ✅ Update Firestore with QR URL
      if (qrDownloadUrl != null) {
        await FirebaseFirestore.instance
            .collection('appointments')
            .doc(widget.appointmentId)
            .collection('tree_inventory')
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

      _showDialog('Success', '✅ Tree and QR successfully saved!');

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
