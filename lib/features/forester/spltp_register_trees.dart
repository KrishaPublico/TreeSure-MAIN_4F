import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

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
      final qrPayload = {
        'format': 'treesure.v2',
        'inventory_doc_id': treeId,
        'appointment_id': data['appointment_id'],
        'tree_id': data['tree_id'],
        'tree_no': data['tree_no'],
        'tree_status': data['tree_status'] ?? 'Not Yet Ready',
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
              if (localQrUrl != null && localQrUrl.isNotEmpty)
                Image.network(localQrUrl, height: 200, fit: BoxFit.cover)
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

  Widget _buildMapView() {
    return Column(
      children: [
        // Location status header
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.grey[100],
          child: Row(
            children: [
              Icon(
                Icons.location_on,
                color: currentLocation != null ? Colors.green : Colors.red,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      currentLocation != null
                          ? "Current Location: ${currentLocation!.latitude.toStringAsFixed(4)}, ${currentLocation!.longitude.toStringAsFixed(4)}"
                          : "Location not available",
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    if (scannedTreeLocation != null)
                      Text(
                        "Tree Location: ${scannedTreeLocation!.latitude.toStringAsFixed(4)}, ${scannedTreeLocation!.longitude.toStringAsFixed(4)}",
                        style: const TextStyle(fontSize: 12),
                      ),
                  ],
                ),
              ),
              if (isLoadingLocation)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
        ),
        // Map
        Expanded(
          child: _buildMap(),
        ),
        // Action buttons
        Container(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              ElevatedButton.icon(
                icon: const Icon(Icons.refresh),
                label: const Text("Refresh Location"),
                onPressed: _getCurrentLocation,
              ),
              if (currentLocation != null && scannedTreeLocation != null)
                ElevatedButton.icon(
                  icon: const Icon(Icons.directions),
                  label: const Text("Get Directions"),
                  onPressed: () {
                    // Implement direction logic if needed
                  },
                ),
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
    // If map view is shown, display full screen map
    if (showMapView) {
      return Scaffold(
        appBar: AppBar(
          title: const Text("Tree Location Map"),
          backgroundColor: Colors.green[800],
          foregroundColor: Colors.white,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: _hideMapView,
          ),
        ),
      );
    }

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text("Tree Inventory - SPLTP"),
          backgroundColor: Colors.green[800],
          foregroundColor: Colors.white,
        ),
        body: TabBarView(
          children: [
            // Register Tree Tab
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: ListView(
                children: [
                  Text("Forester: ${widget.foresterName}",
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 20),

                  // ✅ Tree Selection Dropdown
                  const Text(
                    'Select Tree (Optional)',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Choose from existing trees or leave blank to register a new tree',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                  const SizedBox(height: 8),
                  isLoadingTrees
                      ? const Padding(
                          padding: EdgeInsets.all(16.0),
                          child: CircularProgressIndicator(color: Colors.green),
                        )
                      : Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey[400]!),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: DropdownButton<String>(
                            isExpanded: true,
                            value: selectedDropdownId,
                            hint: const Text(
                                'Choose a tree or skip to register new...'),
                            items: spltpTrees.map((tree) {
                              final uniqueId = tree['docId'] ?? 'Unknown';
                              final treeId = tree['treeDocId'] ??
                                  tree['tree_id'] ??
                                  'Unknown';
                              final specie = tree['specie'] ?? 'N/A';
                              return DropdownMenuItem<String>(
                                value: uniqueId,
                                child: Text('$treeId - $specie'),
                              );
                            }).toList(),
                            onChanged: _onTreeSelected,
                            underline: const SizedBox(),
                          ),
                        ),
                  if (selectedDropdownId != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: TextButton.icon(
                        icon: const Icon(Icons.clear, size: 16),
                        label:
                            const Text('Clear Selection & Register New Tree'),
                        onPressed: () {
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
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.orange[700],
                        ),
                      ),
                    ),
                  const SizedBox(height: 20),

                  buildTextField("Specie", specieController,
                      focusNode: specieFocus),
                  Row(
                    children: [
                      Expanded(
                        child: buildTextField(
                            "Diameter (cm)", diameterController,
                            keyboardType: TextInputType.number),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: buildTextField("Height (m)", heightController,
                            keyboardType: TextInputType.number),
                      ),
                    ],
                  ),
                  buildTextField("Volume (CU m)", volumeController,
                      enabled: false),
                  const SizedBox(height: 12),

                  // ✅ Tree Status Dropdown
                  const Text(
                    'Tree Status',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey[400]!),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: DropdownButton<String>(
                      isExpanded: true,
                      value: treeStatus,
                      items: const [
                        DropdownMenuItem(
                          value: 'Ready for Cutting',
                          child: Text('Ready for Cutting'),
                        ),
                        DropdownMenuItem(
                          value: 'Not Yet',
                          child: Text('Not Yet'),
                        ),
                      ],
                      onChanged: (value) {
                        setState(() {
                          treeStatus = value;
                        });
                      },
                      underline: const SizedBox(),
                    ),
                  ),
                  const SizedBox(height: 12),

                  Row(
                    children: [
                      Expanded(
                        child: buildTextField("Latitude", latController,
                            enabled: false, keyboardType: TextInputType.number),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: buildTextField("Longitude", longController,
                            enabled: false, keyboardType: TextInputType.number),
                      ),
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
                    onPressed: _completeTreeRegistration,
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange[700],
                        padding: const EdgeInsets.symmetric(vertical: 16)),
                    child: const Text("Tree Registration Completed",
                        style: TextStyle(color: Colors.white, fontSize: 16)),
                  ),
                ],
              ),
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
