import 'dart:io' as io;
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';

class QrUploadScanner extends StatefulWidget {
  const QrUploadScanner({super.key});

  @override
  State<QrUploadScanner> createState() => _QrUploadScannerState();
}

class _QrUploadScannerState extends State<QrUploadScanner> {
  String? scannedData;
  bool isScanning = false;
  bool isUploading = false;
  XFile? uploadedImage;
  MobileScannerController? controller;

  // Map and location variables
  LatLng? currentLocation;
  LatLng? treeLocation;
  bool isLoadingLocation = false;
  String? locationError;
  bool showMapView = false;

  @override
  void initState() {
    super.initState();
    controller = MobileScannerController();
    _getCurrentLocation();
  }

  @override
  void dispose() {
    controller?.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (capture.barcodes.isNotEmpty) {
      final barcode = capture.barcodes.first;
      if (barcode.rawValue != null) {
        setState(() {
          scannedData = barcode.rawValue!;
          isScanning = false;
        });
        controller?.stop();

        _fetchTreeDataFromQR(barcode.rawValue!);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ QR Code scanned successfully!')),
        );
      }
    }
  }

  void _startScanning() {
    setState(() {
      isScanning = true;
      scannedData = null;
    });
  }

  void _stopScanning() {
    setState(() {
      isScanning = false;
    });
    controller?.stop();
  }

  void _showMapView() {
    setState(() {
      showMapView = true;
    });
  }

  void _hideMapView() {
    setState(() {
      showMapView = false;
    });
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
        isLoadingLocation = false;
      });
    } catch (e) {
      setState(() {
        locationError = e.toString();
        isLoadingLocation = false;
      });
    }
  }

  Future<void> _uploadQrImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile == null) return;

    setState(() {
      uploadedImage = pickedFile;
      isUploading = true;
      scannedData = null;
    });

    try {
      String? qrData;

      if (kIsWeb) {
        qrData =
            "⚠️ Web image scanning is not fully supported. Please use live camera scanning.";
      } else {
        qrData =
            "⚠️ Mobile image scanning needs to be implemented. Please use live camera scanning.";
      }

      setState(() {
        scannedData = qrData ?? "❌ No QR code found in image.";
        isUploading = false;
      });

      if (scannedData != null &&
          !scannedData!.startsWith('❌') &&
          !scannedData!.startsWith('⚠️')) {
        await _fetchTreeDataFromQR(scannedData!);
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              scannedData!.startsWith('❌') || scannedData!.startsWith('⚠️')
                  ? scannedData!
                  : '✅ QR code scanned from image!'),
        ),
      );
    } catch (e) {
      setState(() {
        scannedData = "❌ Error scanning image: $e";
        isUploading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ Failed to scan image: $e')),
      );
    }
  }

  Future<void> _fetchTreeDataFromQR(String qrData) async {
    try {
      String? treeId;

      final treeIdMatch = RegExp(r'Tree ID: (T\d+)').firstMatch(qrData);
      if (treeIdMatch != null) {
        treeId = treeIdMatch.group(1);
      } else {
        try {
          final qrInfo = json.decode(qrData);
          treeId = qrInfo['tree_id']?.toString();
        } catch (e) {
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
      setState(() {
        scannedData = "❌ Error parsing QR data: $e";
      });
    }
  }

  Future<void> _fetchTreeFromFirestore(String treeId) async {
    try {
      final usersSnapshot =
          await FirebaseFirestore.instance.collection('users').get();
      DocumentSnapshot? treeDoc;
      String? foresterId;

      for (var userDoc in usersSnapshot.docs) {
        final treesRef = userDoc.reference.collection('tree_inventory');
        final doc = await treesRef.doc(treeId.trim()).get();
        if (doc.exists) {
          treeDoc = doc;
          foresterId = userDoc.id;
          break;
        }
      }

      if (treeDoc == null) {
        for (var userDoc in usersSnapshot.docs) {
          final treesRef = userDoc.reference.collection('tree_inventory');
          final querySnapshot = await treesRef
              .where('tree_id', isEqualTo: treeId.trim())
              .limit(1)
              .get();

          if (querySnapshot.docs.isNotEmpty) {
            treeDoc = querySnapshot.docs.first;
            foresterId = userDoc.id;
            break;
          }
        }
      }

      if (treeDoc != null && treeDoc.exists) {
        final treeData = treeDoc.data() as Map<String, dynamic>;
        final lat = (treeData['latitude'] as num?)?.toDouble();
        final lng = (treeData['longitude'] as num?)?.toDouble();

        setState(() {
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

          if (lat != null && lng != null) {
            treeLocation = LatLng(lat, lng);
          }
        });

        if (lat != null && lng != null) {
          Future.delayed(const Duration(milliseconds: 600), () {
            if (mounted) _showMapView();
          });
        }
      } else {
        setState(() {
          scannedData = "❌ Tree with ID '$treeId' not found in database.";
        });
      }
    } catch (e) {
      setState(() {
        scannedData = "❌ Error fetching tree data: $e";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
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
        body: _buildMapView(),
      );
    }

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text("QR Code Scanner"),
          backgroundColor: Colors.green[800],
          foregroundColor: Colors.white,
          bottom: const TabBar(
            labelColor: Colors.white, // ✅ Text color for selected tab
            unselectedLabelColor: Colors.white70, // ✅ Unselected tab color
            indicatorColor: Colors.white, // ✅ White underline indicator
            tabs: [
              Tab(icon: Icon(Icons.qr_code_scanner), text: "Live Scan"),
              Tab(icon: Icon(Icons.upload_file), text: "Upload Image"),
              Tab(icon: Icon(Icons.map), text: "Map View"),
            ],
          ),
          actions: [
            if (isScanning)
              IconButton(
                icon: const Icon(Icons.stop),
                onPressed: _stopScanning,
              ),
          ],
        ),
        body: TabBarView(
          children: [
            _buildLiveScanTab(),
            _buildUploadImageTab(),
            _buildMapView(),
          ],
        ),
      ),
    );
  }

Widget _buildLiveScanTab() {
  return Column(
    children: [
      if (isScanning)
        Expanded(
          child: MobileScanner(
            controller: controller!,
            onDetect: _onDetect,
          ),
        )
      else
        Expanded(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.qr_code_scanner, size: 100, color: Colors.white), // changed color
                const SizedBox(height: 20),
                const Text(
                  "Tap the scanner icon to start scanning QR codes",
                  style: TextStyle(fontSize: 16, color: Colors.white), // changed color
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  icon: const Icon(Icons.qr_code_scanner),
                  label: const Text("Start Scanning"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green[800],
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _startScanning,
                ),
              ],
            ),
          ),
        ),
      if (scannedData != null)
        _buildScannedDataSection(),
    ],
  );
}

  Widget _buildUploadImageTab() {
    return Column(
      children: [
        Expanded(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.upload_file, size: 100, color: Colors.grey[400]),
                const SizedBox(height: 20),
                const Text(
                  "Upload a QR code image to scan",
                  style: TextStyle(fontSize: 16),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  icon: const Icon(Icons.upload_file),
                  label: const Text("Upload QR Image"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green[800],
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: isUploading ? null : _uploadQrImage,
                ),
                if (isUploading)
                  const Padding(
                    padding: EdgeInsets.all(20),
                    child: Column(
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 10),
                        Text("Processing image..."),
                      ],
                    ),
                  ),
                if (uploadedImage != null)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: kIsWeb
                          ? Image.network(uploadedImage!.path, width: 200, height: 200, fit: BoxFit.cover)
                          : Image.file(io.File(uploadedImage!.path), width: 200, height: 200, fit: BoxFit.cover),
                    ),
                  ),
              ],
            ),
          ),
        ),
        if (scannedData != null) _buildScannedDataSection(),
      ],
    );
  }

  Widget _buildScannedDataSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.green[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green[200]!),
      ),
      child: Column(
        children: [
          const Text(
            "📄 Scanned Data:",
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            scannedData!,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 14),
          ),
          if (treeLocation != null)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: ElevatedButton.icon(
                icon: const Icon(Icons.map),
                label: const Text("View Tree Location"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue[600],
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: _showMapView,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMapView() {
    // same as your previous map code
    return Column(
      children: [
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
                          ? "Your Location: ${currentLocation!.latitude.toStringAsFixed(4)}, ${currentLocation!.longitude.toStringAsFixed(4)}"
                          : "Location: ${locationError ?? 'Loading...'}",
                      style: const TextStyle(fontSize: 12),
                    ),
                    if (treeLocation != null)
                      Text(
                        "Tree Location: ${treeLocation!.latitude.toStringAsFixed(4)}, ${treeLocation!.longitude.toStringAsFixed(4)}",
                        style: const TextStyle(fontSize: 12, color: Colors.blue),
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
        Expanded(child: _buildMap()),
      ],
    );
  }

  Widget _buildMap() {
    if (currentLocation == null) {
      return const Center(child: CircularProgressIndicator());
    }

    List<Marker> markers = [
      Marker(
        point: currentLocation!,
        width: 60,
        height: 60,
        child: const Icon(Icons.person_pin_circle, color: Colors.blue, size: 40),
      ),
    ];

    if (treeLocation != null) {
      markers.add(
        Marker(
          point: treeLocation!,
          width: 60,
          height: 60,
          child: const Icon(Icons.location_on, color: Colors.red, size: 40),
        ),
      );
    }

    return FlutterMap(
      options: MapOptions(
        initialCenter: treeLocation ?? currentLocation!,
        initialZoom: 15,
      ),
      children: [
        TileLayer(
          urlTemplate: "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
        ),
        MarkerLayer(markers: markers),
      ],
    );
  }
}
