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
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:path_provider/path_provider.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'tree_services.dart';

class SpltpRegisterTreesPage extends StatefulWidget {
  final String foresterId;
  final String foresterName;
  final String appointmentId; // ✅ appointment document ID (cutting appointment)

  const SpltpRegisterTreesPage({
    super.key,
    required this.foresterId,
    required this.foresterName,
    required this.appointmentId,
  });

  @override
  State<SpltpRegisterTreesPage> createState() => _SpltpRegisterTreesPageState();
}

class _SpltpRegisterTreesPageState extends State<SpltpRegisterTreesPage> {
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

  // QR Scanning variables
  MobileScannerController? scannerController;
  bool isScanning = false;
  String? scannedData;
  String? scannedTreeId;

  // Map variables
  LatLng? currentLocation;
  LatLng? scannedTreeLocation;
  bool isLoadingLocation = false;
  String? locationError;
  bool showMapView = false;

  // Tree dropdown variables
  List<Map<String, dynamic>> spltpTrees = [];
  String? selectedTreeId; // Original tree doc ID (T1, T2, etc.)
  String? selectedDropdownId; // Unique dropdown ID for UI
  String?
      selectedTreeTaggingAppointmentId; // ✅ Doc ID of tree_tagging_appointment
  String? treeStatus = 'Not Yet'; // ✅ Tree cutting status
  bool isLoadingTrees = false;

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
              Text(title,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _darkGreen)),
              const SizedBox(height: 8),
              Text(
                message.replaceAll(RegExp(r'[✅❌⚠️📍⏳🌳]'), '').trim(),
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Colors.grey[600]),
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
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
    scannerController = MobileScannerController();
    _getCurrentLocation();
    _loadSpltpTrees();
  }

  @override
  void dispose() {
    specieController.dispose();
    diameterController.dispose();
    heightController.dispose();
    volumeController.dispose();
    latController.dispose();
    longController.dispose();
    scannerController?.dispose();
    super.dispose();
  }

  Future<void> _getCurrentLocation() async {
    setState(() {
      isLoadingLocation = true;
      locationError = null;
    });

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw Exception("Location services are disabled.");
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw Exception("Location permissions are denied.");
        }
      }
      if (permission == LocationPermission.deniedForever) {
        throw Exception("Location permissions are permanently denied.");
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      setState(() {
        currentLocation = LatLng(position.latitude, position.longitude);
        latController.text = position.latitude.toStringAsFixed(6);
        longController.text = position.longitude.toStringAsFixed(6);
        isLoadingLocation = false;
      });
    } catch (e) {
      setState(() {
        locationError = e.toString();
        isLoadingLocation = false;
      });
      _showDialog('Location Error', '⚠️ Failed to get location: $e');
    }
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

  /// ✅ Load trees from the current SPLTP appointment's tree_inventory
  Future<void> _loadSpltpTrees() async {
    setState(() {
      isLoadingTrees = true;
    });

    try {
      print('✅ Loading trees from appointment: ${widget.appointmentId}');

      // Get all trees from the current appointment's tree_inventory sub-collection
      final treeInventorySnapshot = await FirebaseFirestore.instance
          .collection('appointments')
          .doc(widget.appointmentId)
          .collection('tree_inventory')
          .get();

      print(
          '✅ Found ${treeInventorySnapshot.docs.length} trees in tree_inventory');

      final allTrees = <Map<String, dynamic>>[];

      for (var treeDoc in treeInventorySnapshot.docs) {
        final treeData = treeDoc.data();
        final specie = treeData['specie'] ?? 'N/A';
        print('✅ Adding tree: ${treeDoc.id} - $specie');

        allTrees.add({
          ...treeData,
          'docId': treeDoc.id,
          'treeDocId': treeDoc.id,
          'appointmentId': widget.appointmentId,
        });
      }

      setState(() {
        spltpTrees = allTrees;
        isLoadingTrees = false;
      });

      if (allTrees.isEmpty) {
        _showDialog('Info', '⚠️ No trees found in this appointment');
      } else {
        print('✅ Total trees loaded: ${allTrees.length}');
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

    final selectedTree = spltpTrees.firstWhere(
      (tree) => tree['docId'] == uniqueId,
      orElse: () => {},
    );

    if (selectedTree.isNotEmpty) {
      setState(() {
        selectedDropdownId = uniqueId; // Store unique ID for dropdown
        selectedTreeId = selectedTree['treeDocId']; // Use original tree doc ID
        // ✅ Store the tree_tagging_appointment doc ID
        selectedTreeTaggingAppointmentId = selectedTree['appointmentId'];
        specieController.text = selectedTree['specie'] ?? '';
        diameterController.text = selectedTree['diameter']?.toString() ?? '';
        heightController.text = selectedTree['height']?.toString() ?? '';
        volumeController.text =
            selectedTree['volume']?.toStringAsFixed(2) ?? '';

        final lat = (selectedTree['latitude'] as num?)?.toDouble();
        final lng = (selectedTree['longitude'] as num?)?.toDouble();

        if (lat != null && lng != null) {
          latController.text = lat.toStringAsFixed(6);
          longController.text = lng.toStringAsFixed(6);
          scannedTreeLocation = LatLng(lat, lng);
        }
      });
    }
  }

  /// ✅ QR Code Detection Handler
  void _onDetect(BarcodeCapture capture) {
    if (capture.barcodes.isNotEmpty) {
      final barcode = capture.barcodes.first;
      if (barcode.rawValue != null) {
        setState(() {
          scannedData = barcode.rawValue!;
          isScanning = false;
        });
        scannerController?.stop();

        // Fetch tree data from the scanned QR
        _fetchTreeDataFromQR(barcode.rawValue!);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ QR Code scanned successfully!')),
        );
      }
    }
  }

  /// ✅ Fetch tree data from QR code
  Future<void> _fetchTreeDataFromQR(String qrData) async {
    try {
      String? treeId;

      // Extract tree ID from multiline format (e.g., "Tree ID: T1")
      final treeIdMatch = RegExp(r'Tree ID: (T\d+)').firstMatch(qrData);
      if (treeIdMatch != null) {
        treeId = treeIdMatch.group(1);
      } else {
        try {
          // Try parsing as JSON
          final qrInfo = json.decode(qrData);
          treeId = qrInfo['tree_id']?.toString();
        } catch (e) {
          // Check if the string itself matches tree ID format
          if (RegExp(r'^T\d+$').hasMatch(qrData.trim())) {
            treeId = qrData.trim();
          }
        }
      }

      if (treeId != null) {
        await _fetchTreeFromFirestore(treeId);
      } else {
        setState(() {
          scannedData =
              "❌ Invalid QR code format. Expected tree ID like 'T1', 'T2', etc.";
        });
      }
    } catch (e) {
      print('Error parsing QR data: $e');
      setState(() {
        scannedData = "❌ Error parsing QR data: $e";
      });
    }
  }

  /// ✅ Fetch tree from Firestore (SPLTP appointment's tree_inventory)
  Future<void> _fetchTreeFromFirestore(String treeId) async {
    try {
      // Query the tree from the SPLTP appointment's tree_inventory collection
      final treeDoc = await FirebaseFirestore.instance
          .collection('appointments')
          .doc(widget.appointmentId)
          .collection('tree_inventory')
          .doc(treeId.trim())
          .get();

      if (treeDoc.exists) {
        final treeData = treeDoc.data() as Map<String, dynamic>;
        final lat = (treeData['latitude'] as num?)?.toDouble();
        final lng = (treeData['longitude'] as num?)?.toDouble();

        // Auto-fill specie from scanned tree data
        setState(() {
          scannedTreeId = treeId;
          specieController.text = treeData['specie'] ?? '';
          diameterController.text = treeData['diameter']?.toString() ?? '';
          heightController.text = treeData['height']?.toString() ?? '';
          volumeController.text = treeData['volume']?.toStringAsFixed(2) ?? '';

          scannedData = '''
✅ Tree Found!

Tree ID: ${treeData['tree_id'] ?? treeId}
Tree No: ${treeData['tree_no'] ?? 'N/A'}
Specie: ${treeData['specie'] ?? 'N/A'}
Diameter: ${treeData['diameter']?.toString() ?? 'N/A'} cm
Height: ${treeData['height']?.toString() ?? 'N/A'} m
Volume: ${treeData['volume']?.toStringAsFixed(2) ?? 'N/A'} cu.m
Forester: ${treeData['forester_name'] ?? 'N/A'}
Location: ${lat != null ? lat.toStringAsFixed(6) : 'N/A'}, ${lng != null ? lng.toStringAsFixed(6) : 'N/A'}
Timestamp: ${treeData['timestamp'] != null ? (treeData['timestamp'] as Timestamp).toDate().toString() : 'N/A'}
''';

          // Set tree location for map
          if (lat != null && lng != null) {
            scannedTreeLocation = LatLng(lat, lng);
          }
        });

        _showDialog('Success',
            '✅ Tree data loaded successfully!\nSpecie and other details auto-filled.');
      } else {
        setState(() {
          scannedData =
              "❌ Tree with ID '$treeId' not found in this appointment.";
        });
        _showDialog('Not Found',
            "❌ Tree with ID '$treeId' not found in this appointment.");
      }
    } catch (e) {
      print('Error fetching tree data: $e');
      setState(() {
        scannedData = "❌ Error fetching tree data: $e";
      });
      _showDialog('Error', '❌ Error fetching tree data: $e');
    }
  }

  Future<String?> _generateAndUploadQr(
      String treeId, Map<String, dynamic> data) async {
    try {
      // Only encode essential lookup fields to keep QR code scannable.
      // Full tree data is fetched from Firestore using these keys.
      final qrPayload = {
        'format': 'treesure.v2',
        'inventory_doc_id': treeId,
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

      final ref =
          FirebaseStorage.instance.ref().child('tree_qrcodes/$treeId.png');

      UploadTask uploadTask;
      if (kIsWeb) {
        uploadTask = ref.putData(bytes);
      } else {
        final dir = await getTemporaryDirectory();
        final file = File('${dir.path}/$treeId.png');
        await file.writeAsBytes(bytes);
        uploadTask = ref.putFile(file);
      }

      await uploadTask.then((snapshot) {
        return snapshot;
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
      // ✅ If no tree is selected, generate a new tree ID
      String treeId;
      if (selectedTreeId == null) {
        // Generate new tree ID for manually entered tree
        final treeCollection = FirebaseFirestore.instance
            .collection('appointments')
            .doc(appointmentId)
            .collection('tree_inventory');

        final count = await treeCollection.count().get();
        treeId = 'T${(count.count ?? 0) + 1}'; // Format as T1, T2, etc.
      } else {
        // Use the selected tree ID
        treeId = selectedTreeId!;
      }

      // ✅ Get the tree_tagging_appointment doc ID to store as a field
      final treeTaggingAppointmentId = selectedTreeTaggingAppointmentId;

      // Save the tree info to the SPLTP appointment
      final newDocId = await _treeService.sendTreeInfo(
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
        treeTaggingAppointmentId: treeTaggingAppointmentId,
        treeStatus: treeStatus,
      );

      final treeDoc = await FirebaseFirestore.instance
          .collection('appointments')
          .doc(widget.appointmentId)
          .collection('tree_inventory')
          .doc(newDocId)
          .get();

      if (!treeDoc.exists) {
        throw Exception('Failed to retrieve saved tree data');
      }

      final treeData = treeDoc.data()!;
      final dynamic timestampValue = treeData['timestamp'];
      final String timestampString = timestampValue is Timestamp
          ? timestampValue.toDate().toString()
          : (timestampValue?.toString() ?? DateTime.now().toString());

      final qrPayload = {
        'tree_id': treeData['tree_id'] ?? treeId,
        'tree_no': treeData['tree_no'] ?? treeId,
        'appointment_id': treeData['appointment_id'] ?? appointmentId,
        'tree_tagging_appointment_id':
            treeData['tree_tagging_appointment_id'] ?? treeTaggingAppointmentId,
        'specie': treeData['specie'] ?? specie,
        'diameter': treeData['diameter'] ?? diameter,
        'height': treeData['height'] ?? height,
        'volume': treeData['volume'] ?? volume,
        'tree_status': treeData['tree_status'] ?? treeStatus,
        'latitude': treeData['latitude'] ?? latitude,
        'longitude': treeData['longitude'] ?? longitude,
        'forester_id': treeData['forester_id'] ?? widget.foresterId,
        'forester_name': treeData['forester_name'] ?? widget.foresterName,
        'photo_url': treeData['photo_url'] ?? '',
        'timestamp': timestampString,
      };

      final qrDownloadUrl = await _generateAndUploadQr(newDocId, qrPayload);

      if (qrDownloadUrl != null) {
        await FirebaseFirestore.instance
            .collection('appointments')
            .doc(widget.appointmentId)
            .collection('tree_inventory')
            .doc(newDocId)
            .update({'qr_url': qrDownloadUrl});
      }

      // ✅ Set appointment status to 'In Progress'
      await FirebaseFirestore.instance
          .collection('appointments')
          .doc(appointmentId)
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
      scannedData = null;
      scannedTreeId = null;
      scannedTreeLocation = null;
      selectedTreeId = null;
      selectedDropdownId = null; // ✅ Clear the dropdown ID
      selectedTreeTaggingAppointmentId = null; // ✅ Clear the appointment ID
      treeStatus = 'Not Yet'; // ✅ Reset status
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

  void _startScanning() {
    setState(() {
      isScanning = true;
      scannedData = null;
    });
    scannerController?.start();
  }

  void _stopScanning() {
    setState(() {
      isScanning = false;
    });
    scannerController?.stop();
  }

  void _hideMapView() {
    setState(() {
      showMapView = false;
    });
  }

  /// ✅ Mark tree registration as completed
  Future<void> _completeTreeRegistration() async {
    try {
      // ✅ Use the tree_tagging_appointment doc ID if available
      final appointmentIdToUse =
          selectedTreeTaggingAppointmentId ?? widget.appointmentId;

      final appointmentRef = FirebaseFirestore.instance
          .collection('appointments')
          .doc(appointmentIdToUse);

      final appointmentDoc = await appointmentRef.get();
      if (!appointmentDoc.exists) {
        _showDialog('Error', '❌ Appointment not found.');
        return;
      }

      final appointmentData = appointmentDoc.data()!;
      final foresterIds =
          List<String>.from(appointmentData['foresterIds'] ?? []);

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

        _showDialog(
            'Success', '✅ Tree registration completed by all foresters!');
      } else {
        // Not all completed yet
        final completedCount =
            completionStatus.values.where((v) => v['completed'] == true).length;
        final totalCount = foresterIds.length;

        await appointmentRef.update({
          'completionStatus': completionStatus,
          'status': 'In Progress',
        });

        _showDialog('Info',
            '✅ Marked as completed. Waiting for other foresters ($completedCount/$totalCount)');
      }
    } catch (e) {
      _showDialog('Error', '❌ Error completing tree registration: $e');
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
      "Tree Status": treeStatus,
    };

    String? photoUrl;
    String? localQrUrl = qrUrl;

    if (lastSubmittedTreeId != null) {
      final doc = await FirebaseFirestore.instance
          .collection('appointments')
          .doc(widget.appointmentId)
          .collection('tree_inventory')
          .doc(lastSubmittedTreeId)
          .get();

      if (doc.exists) {
        photoUrl = doc.data()?['photo_url'];
        localQrUrl = doc.data()?['qr_url'] ?? localQrUrl;
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
      "Tree Status": Icons.flag_rounded,
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
                child: Container(width: 40, height: 4,
                  decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: _lightGreen, borderRadius: BorderRadius.circular(14)),
                    child: const Icon(Icons.park_rounded, color: _primaryGreen, size: 28),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Tree Data Summary',
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: _darkGreen)),
                        Text('Review submitted tree information',
                          style: TextStyle(fontSize: 13, color: Colors.grey)),
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
                  decoration: BoxDecoration(color: _surfaceColor, borderRadius: BorderRadius.circular(14)),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: _primaryGreen.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(summaryIcons[entry.key] ?? Icons.info_rounded, color: _primaryGreen, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(entry.key, style: TextStyle(fontSize: 12, color: Colors.grey[600], fontWeight: FontWeight.w500)),
                            const SizedBox(height: 2),
                            Text(
                              entry.value.toString().isEmpty ? 'N/A' : entry.value.toString(),
                              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: _darkGreen),
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
              _buildMediaSection('QR Code', localQrUrl),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primaryGreen,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
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
          Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: _darkGreen)),
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
              decoration: BoxDecoration(color: _surfaceColor, borderRadius: BorderRadius.circular(12)),
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

  Widget _buildMapView() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          margin: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 2)),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: currentLocation != null ? _lightGreen : Colors.red[50],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.location_on_rounded,
                  color: currentLocation != null ? _primaryGreen : Colors.red,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      currentLocation != null
                          ? "${currentLocation!.latitude.toStringAsFixed(4)}, ${currentLocation!.longitude.toStringAsFixed(4)}"
                          : "Location not available",
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                    ),
                    if (scannedTreeLocation != null)
                      Text(
                        "Tree: ${scannedTreeLocation!.latitude.toStringAsFixed(4)}, ${scannedTreeLocation!.longitude.toStringAsFixed(4)}",
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                  ],
                ),
              ),
              if (isLoadingLocation)
                const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: _primaryGreen)),
            ],
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: _buildMap(),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: _buildGradientButton('Refresh', Icons.refresh_rounded, onPressed: _getCurrentLocation),
              ),
              if (currentLocation != null && scannedTreeLocation != null) ...[
                const SizedBox(width: 12),
                Expanded(
                  child: _buildOutlinedButton('Directions', Icons.directions_rounded, onPressed: () {}),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMap() {
    if (isLoadingLocation) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text("Loading location..."),
          ],
        ),
      );
    }

    if (locationError != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.location_off, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text("Location Error: $locationError"),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _getCurrentLocation,
              child: const Text("Retry"),
            ),
          ],
        ),
      );
    }

    if (currentLocation == null) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.location_searching, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text("Unable to get current location"),
          ],
        ),
      );
    }

    // Create markers
    List<Marker> markers = [
      Marker(
        point: currentLocation!,
        width: 60,
        height: 60,
        child:
            const Icon(Icons.person_pin_circle, color: Colors.blue, size: 40),
      ),
    ];

    if (scannedTreeLocation != null) {
      markers.add(
        Marker(
          point: scannedTreeLocation!,
          width: 60,
          height: 60,
          child: const Icon(Icons.location_on, color: Colors.red, size: 40),
        ),
      );
    }

    // Create path points
    List<LatLng> pathPoints = [currentLocation!];
    if (scannedTreeLocation != null) {
      pathPoints.add(scannedTreeLocation!);
    }

    return FlutterMap(
      options: MapOptions(
        initialCenter: scannedTreeLocation ?? currentLocation!,
        initialZoom: scannedTreeLocation != null ? 15 : 13,
      ),
      children: [
        TileLayer(
          urlTemplate: "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
          subdomains: const ['a', 'b', 'c'],
        ),
        if (scannedTreeLocation != null)
          PolylineLayer(
            polylines: [
              Polyline(
                points: pathPoints,
                strokeWidth: 4.0,
                color: Colors.blue,
              ),
            ],
          ),
        MarkerLayer(markers: markers),
      ],
    );
  }

  // ✅ UI
  @override
  Widget build(BuildContext context) {
    if (showMapView) {
      return Scaffold(
        backgroundColor: _surfaceColor,
        body: Column(
          children: [
            _buildGradientHeader('Tree Location Map'),
            Expanded(child: _buildMapView()),
          ],
        ),
      );
    }

    return DefaultTabController(
      length: 3,
      child: Scaffold(
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
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(8, 8, 20, 0),
                      child: Row(
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
                                const Text('Tree Inventory - SPLTP',
                                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
                                const SizedBox(height: 4),
                                Text('Forester: ${widget.foresterName}',
                                  style: TextStyle(fontSize: 13, color: Colors.white.withOpacity(0.85))),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Tab bar
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: TabBar(
                        indicatorSize: TabBarIndicatorSize.tab,
                        indicator: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        labelColor: _darkGreen,
                        unselectedLabelColor: Colors.white.withOpacity(0.8),
                        labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                        unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
                        dividerHeight: 0,
                        tabs: const [
                          Tab(text: 'Register'),
                          Tab(text: 'QR Scan'),
                          Tab(text: 'Map'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),

            // Tab content
            Expanded(
              child: TabBarView(
                children: [
                  // Register Tree Tab
                  _buildRegisterTab(),
                  // QR Scanner Tab (placeholder since no QR scanner tab body exists)
                  _buildQrPlaceholderTab(),
                  // Map View Tab
                  _buildMapView(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGradientHeader(String title) {
    return Container(
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
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                onPressed: _hideMapView,
              ),
              const SizedBox(width: 4),
              Text(title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQrPlaceholderTab() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: _lightGreen,
              borderRadius: BorderRadius.circular(28),
            ),
            child: const Icon(Icons.qr_code_scanner_rounded, color: _primaryGreen, size: 64),
          ),
          const SizedBox(height: 24),
          const Text('QR Scanner', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: _darkGreen)),
          const SizedBox(height: 8),
          Text('Use the QR scanner to scan tree tags', style: TextStyle(fontSize: 14, color: Colors.grey[600])),
        ],
      ),
    );
  }

  Widget _buildRegisterTab() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // Tree Selection Dropdown
        _buildSectionHeader('Select Tree (Optional)', Icons.list_alt_rounded),
        const SizedBox(height: 4),
        Text('Choose from existing trees or leave blank to register new',
          style: TextStyle(fontSize: 12, color: Colors.grey[500], fontStyle: FontStyle.italic)),
        const SizedBox(height: 12),
        isLoadingTrees
            ? const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator(color: _primaryGreen)))
            : Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 2))],
                ),
                child: DropdownButtonFormField<String>(
                  isExpanded: true,
                  value: selectedDropdownId,
                  decoration: InputDecoration(
                    hintText: 'Choose a tree or skip to register new...',
                    hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                    filled: true,
                    fillColor: Colors.white,
                    prefixIcon: Container(
                      margin: const EdgeInsets.all(8),
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: _lightGreen, borderRadius: BorderRadius.circular(10)),
                      child: const Icon(Icons.park_rounded, color: _primaryGreen, size: 20),
                    ),
                  ),
                  items: spltpTrees.map((tree) {
                    final uniqueId = tree['docId'] ?? 'Unknown';
                    final treeId = tree['treeDocId'] ?? tree['tree_id'] ?? 'Unknown';
                    final specie = tree['specie'] ?? 'N/A';
                    return DropdownMenuItem<String>(value: uniqueId, child: Text('$treeId - $specie'));
                  }).toList(),
                  onChanged: _onTreeSelected,
                ),
              ),
        if (selectedDropdownId != null)
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: InkWell(
              onTap: () {
                setState(() {
                  selectedDropdownId = null;
                  selectedTreeId = null;
                  selectedTreeTaggingAppointmentId = null;
                  specieController.clear();
                  diameterController.clear();
                  heightController.clear();
                  volumeController.clear();
                  latController.clear();
                  longController.clear();
                  scannedTreeLocation = null;
                });
              },
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                decoration: BoxDecoration(
                  color: Colors.orange[50],
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.clear_rounded, size: 16, color: Colors.orange[700]),
                    const SizedBox(width: 6),
                    Text('Clear Selection', style: TextStyle(color: Colors.orange[700], fontWeight: FontWeight.w600, fontSize: 13)),
                  ],
                ),
              ),
            ),
          ),
        const SizedBox(height: 24),

        // Tree Details
        _buildSectionHeader('Tree Details', Icons.eco_rounded),
        const SizedBox(height: 12),
        _buildModernTextField('Specie', specieController, icon: Icons.eco_rounded, focusNode: specieFocus),
        Row(
          children: [
            Expanded(child: _buildModernTextField('Diameter (cm)', diameterController, icon: Icons.straighten_rounded, keyboardType: TextInputType.number)),
            const SizedBox(width: 12),
            Expanded(child: _buildModernTextField('Height (m)', heightController, icon: Icons.height_rounded, keyboardType: TextInputType.number)),
          ],
        ),
        _buildModernTextField('Volume (CU m)', volumeController, icon: Icons.inventory_2_rounded, enabled: false),
        const SizedBox(height: 12),

        // Tree Status
        _buildSectionHeader('Tree Status', Icons.flag_rounded),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 2))],
          ),
          child: DropdownButtonFormField<String>(
            value: treeStatus,
            decoration: InputDecoration(
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
              filled: true,
              fillColor: Colors.white,
              prefixIcon: Container(
                margin: const EdgeInsets.all(8),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: _lightGreen, borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.flag_rounded, color: _primaryGreen, size: 20),
              ),
            ),
            items: const [
              DropdownMenuItem(value: 'Ready for Cutting', child: Text('Ready for Cutting')),
              DropdownMenuItem(value: 'Not Yet', child: Text('Not Yet')),
            ],
            onChanged: (value) => setState(() => treeStatus = value),
          ),
        ),
        const SizedBox(height: 20),

        // Location
        _buildSectionHeader('Location', Icons.location_on_rounded),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _buildModernTextField('Latitude', latController, icon: Icons.explore_rounded, enabled: false)),
            const SizedBox(width: 12),
            Expanded(child: _buildModernTextField('Longitude', longController, icon: Icons.explore_rounded, enabled: false)),
          ],
        ),
        InkWell(
          onTap: _getLocation,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            decoration: BoxDecoration(color: _lightGreen, borderRadius: BorderRadius.circular(12)),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.my_location_rounded, color: _primaryGreen, size: 20),
                SizedBox(width: 8),
                Text('Get Current Location', style: TextStyle(color: _primaryGreen, fontWeight: FontWeight.w600, fontSize: 14)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),

        // Photo section
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
              ),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 2))],
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
                        decoration: BoxDecoration(color: _lightGreen, borderRadius: BorderRadius.circular(16)),
                        child: const Icon(Icons.add_a_photo_rounded, color: _primaryGreen, size: 32),
                      ),
                      const SizedBox(height: 12),
                      Text('Tap to add photo', style: TextStyle(color: Colors.grey[600], fontSize: 14, fontWeight: FontWeight.w500)),
                    ],
                  ),
          ),
        ),
        const SizedBox(height: 28),

        // Action buttons
        _buildGradientButton('Submit Tree Data', Icons.check_circle_rounded, onPressed: handleSubmit),
        const SizedBox(height: 12),
        _buildOutlinedButton('View Summary', Icons.summarize_rounded, onPressed: viewSummaryDialog),
        const SizedBox(height: 12),
        _buildGradientButton('Tree Registration Completed', Icons.flag_rounded,
            onPressed: _completeTreeRegistration, colors: [Colors.orange[700]!, Colors.orange[500]!]),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: _primaryGreen.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, color: _primaryGreen, size: 18),
        ),
        const SizedBox(width: 10),
        Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: _darkGreen)),
      ],
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
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 2))],
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
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: _primaryGreen, width: 2)),
            filled: true,
            fillColor: enabled ? Colors.white : Colors.grey[50],
            prefixIcon: icon != null
                ? Container(
                    margin: const EdgeInsets.all(8),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: _lightGreen, borderRadius: BorderRadius.circular(10)),
                    child: Icon(icon, color: _primaryGreen, size: 18),
                  )
                : null,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        ),
      ),
    );
  }

  Widget _buildGradientButton(String label, IconData icon, {required VoidCallback onPressed, List<Color>? colors}) {
    final btnColors = colors ?? [_darkGreen, _primaryGreen];
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: btnColors),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: btnColors.first.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4))],
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

  Widget _buildOutlinedButton(String label, IconData icon, {required VoidCallback onPressed}) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), border: Border.all(color: _primaryGreen, width: 2)),
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
    return _buildModernTextField(label, controller, focusNode: focusNode, enabled: enabled, keyboardType: keyboardType);
  }
}
