import 'dart:io' as io;
import 'dart:convert';
import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

// 🗝️ Google Maps API key for Directions API
const String googleAPIKey = 'AIzaSyC8E4EJ8h5H1Csre_oHjrMP9_XbVi7-Xz0';

class QrUploadScanner extends StatefulWidget {
  const QrUploadScanner({super.key});

  @override
  State<QrUploadScanner> createState() => _QrUploadScannerState();
}

class _QrUploadScannerState extends State<QrUploadScanner>
    with SingleTickerProviderStateMixin {
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
  List<LatLng> routePoints = []; // Route polyline points
  bool isLoadingRoute = false; // Loading state for route
  Completer<GoogleMapController> _mapController = Completer();
  Set<Marker> markers = {};
  Set<Polyline> polylines = {};

  // Animation controller for scanning line
  AnimationController? _animationController;
  Animation<double>? _animation;

  @override
  void initState() {
    super.initState();
    controller = MobileScannerController();
    _getCurrentLocation();

    // Initialize animation controller
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _animation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController!, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    controller?.dispose();
    _animationController?.dispose();
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

        // Try to fetch tree data from Firestore
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

      // Update markers with new location
      _updateMarkers();
      _updatePolylines();

      // If we have both current location and tree location, fetch route
      if (treeLocation != null) {
        await _fetchRoute();
      }
    } catch (e) {
      setState(() {
        locationError = e.toString();
        isLoadingLocation = false;
      });
    }
  }

  /// 🗺️ Fetch route from Google Directions API
  Future<void> _fetchRoute() async {
    if (currentLocation == null || treeLocation == null) {
      debugPrint('⚠️ Cannot fetch route: missing location data');
      return;
    }

    setState(() {
      isLoadingRoute = true;
      routePoints = [];
    });

    try {
      debugPrint('🌐 Fetching route from API...');
      
      final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/directions/json?'
        'origin=${currentLocation!.latitude},${currentLocation!.longitude}&'
        'destination=${treeLocation!.latitude},${treeLocation!.longitude}&'
        'key=$googleAPIKey',
      );

      final response = await http.get(url);
      debugPrint('📡 API Response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        debugPrint('📊 API Response status: ${data['status']}');

        if (data['status'] == 'REQUEST_DENIED') {
          debugPrint('❌ API Error: ${data['error_message']}');
          throw Exception('API request denied: ${data['error_message']}');
        }

        if (data['status'] == 'OK' && data['routes'] != null && (data['routes'] as List).isNotEmpty) {
          // Get the overview polyline
          final polylinePoints = data['routes'][0]['overview_polyline']['points'];
          debugPrint('🔢 Encoded polyline received');

          // Decode the polyline
          final decodedPoints = _decodePolyline(polylinePoints);
          debugPrint('✅ Decoded ${decodedPoints.length} route points');

          setState(() {
            routePoints = decodedPoints;
            isLoadingRoute = false;
          });
          
          // Update polylines on map
          _updatePolylines();
        } else {
          debugPrint('❌ No routes found in response');
          setState(() {
            isLoadingRoute = false;
          });
        }
      } else {
        debugPrint('❌ HTTP Error: ${response.statusCode}');
        setState(() {
          isLoadingRoute = false;
        });
      }
    } catch (e) {
      debugPrint('❌ Error fetching route: $e');
      setState(() {
        isLoadingRoute = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Unable to fetch route: $e'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }

  /// 📍 Decode Google Maps polyline format
  List<LatLng> _decodePolyline(String encoded) {
    List<LatLng> points = [];
    int index = 0;
    int len = encoded.length;
    int lat = 0;
    int lng = 0;

    while (index < len) {
      int b;
      int shift = 0;
      int result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lat += dlat;

      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lng += dlng;

      points.add(LatLng(lat / 1E5, lng / 1E5));
    }

    return points;
  }

  /// 🗺️ Update markers on the map
  void _updateMarkers() {
    markers.clear();
    
    // Add current location marker
    if (currentLocation != null) {
      markers.add(Marker(
        markerId: const MarkerId('current_location'),
        position: currentLocation!,
        infoWindow: const InfoWindow(title: 'Your Location'),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
      ));
    }

    // Add tree location marker
    if (treeLocation != null) {
      markers.add(Marker(
        markerId: const MarkerId('tree_location'),
        position: treeLocation!,
        infoWindow: const InfoWindow(title: 'Tree Location'),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
      ));
    }
  }

  /// 📍 Update polylines on the map
  void _updatePolylines() {
    polylines.clear();
    
    if (routePoints.isNotEmpty) {
      // Display route polyline if available
      polylines.add(Polyline(
        polylineId: const PolylineId('route'),
        points: routePoints,
        width: 5,
        color: Colors.blue,
        startCap: Cap.roundCap,
        endCap: Cap.roundCap,
      ));
    } else if (currentLocation != null && treeLocation != null) {
      // Fallback: simple straight line if no route
      polylines.add(Polyline(
        polylineId: const PolylineId('straight_line'),
        points: [currentLocation!, treeLocation!],
        width: 3,
        color: Colors.blue.withOpacity(0.5),
        patterns: [PatternItem.dash(20), PatternItem.gap(10)],
      ));
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
        // For web, we'll use a different approach
        // For now, show a message that web image scanning is not fully supported
        qrData =
            "⚠️ Web image scanning is not fully supported. Please use live camera scanning.";
      } else {
        // For mobile, use a different approach since QrCodeScanner.scanImage doesn't exist
        // For now, show a message that mobile image scanning needs to be implemented
        qrData =
            "⚠️ Mobile image scanning needs to be implemented. Please use live camera scanning.";
      }

      setState(() {
        scannedData = qrData ?? "❌ No QR code found in image.";
        isUploading = false;
      });

      // If we got valid QR data, try to fetch tree information from Firestore
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
      String? appointmentId;

      // Parse the new QR format (key: value format)
      final lines = qrData.split('\n');
      for (var line in lines) {
        line = line.trim();
        if (line.isEmpty) continue;

        if (line.startsWith('tree_id:')) {
          treeId = line.substring('tree_id:'.length).trim();
        } else if (line.startsWith('appointment_id:')) {
          appointmentId = line.substring('appointment_id:'.length).trim();
        }
      }

      // Fallback: try old format or direct tree ID
      if (treeId == null) {
        final treeIdMatch = RegExp(r'Tree ID: (T\d+)').firstMatch(qrData);
        if (treeIdMatch != null) {
          treeId = treeIdMatch.group(1);
        } else if (RegExp(r'^T\d+$').hasMatch(qrData.trim())) {
          treeId = qrData.trim();
        }
      }

      if (treeId != null) {
        await _fetchTreeFromFirestore(treeId, appointmentId);
      } else {
        setState(() {
          scannedData = "❌ Invalid QR code format. No tree_id found.";
        });
      }
    } catch (e) {
      print('Error parsing QR data: $e');
      setState(() {
        scannedData = "❌ Error parsing QR data: $e";
      });
    }
  }

  Future<void> _fetchTreeFromFirestore(String treeId, [String? appointmentId]) async {
    try {
      DocumentSnapshot? treeDoc;

      // If appointment ID is provided, search directly in that appointment's tree_inventory
      if (appointmentId != null && appointmentId.isNotEmpty) {
        final doc = await FirebaseFirestore.instance
            .collection('appointments')
            .doc(appointmentId)
            .collection('tree_inventory')
            .doc(treeId)
            .get();

        if (doc.exists) {
          treeDoc = doc;
        }
      }

      // If not found or no appointmentId provided, search all appointments
      if (treeDoc == null) {
        final appointmentsSnapshot = await FirebaseFirestore.instance
            .collection('appointments')
            .get();

        for (var appointmentDoc in appointmentsSnapshot.docs) {
          final doc = await appointmentDoc.reference
              .collection('tree_inventory')
              .doc(treeId)
              .get();

          if (doc.exists) {
            treeDoc = doc;
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

Tree No: ${treeData['tree_no'] ?? 'N/A'}
Specie: ${treeData['specie'] ?? 'N/A'}
Diameter: ${treeData['diameter']?.toString() ?? 'N/A'} cm
Height: ${treeData['height']?.toString() ?? 'N/A'} m
Volume: ${treeData['volume']?.toStringAsFixed(2) ?? 'N/A'} cu.m
Forester: ${treeData['forester_name'] ?? 'N/A'}
Location: ${lat != null ? '${lat.toStringAsFixed(6)}, ${lng!.toStringAsFixed(6)}' : 'N/A'}
''';

          // Set tree location for map if coordinates are available
          if (lat != null && lng != null) {
            treeLocation = LatLng(lat, lng);
          }
        });

        // Fetch route if we have both locations
        if (lat != null && lng != null && currentLocation != null) {
          await _fetchRoute();
        } else if (lat != null && lng != null) {
          // If only tree location is available, update markers
          _updateMarkers();
          _updatePolylines();
        }

        // Show map view if location is available
        if (lat != null && lng != null) {
          Future.delayed(const Duration(milliseconds: 600), () {
            if (mounted) _showMapView();
          });
        }
      } else {
        setState(() {
          scannedData = "❌ Tree with ID '$treeId' not found in any appointment.";
        });
      }
    } catch (e) {
      print('Error fetching tree data: $e');
      setState(() {
        scannedData = "❌ Error fetching tree data: $e";
      });
    }
  }

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
            // Live Scanning Tab
            Column(
              children: [
                if (isScanning) ...[
                  Expanded(
                    child: Stack(
                      children: [
                        MobileScanner(
                          controller: controller!,
                          onDetect: _onDetect,
                        ),
                        // Overlay with scanning region
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.5),
                          ),
                          child: Center(
                            child: Container(
                              width: 250,
                              height: 250,
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: Colors.green,
                                  width: 3,
                                ),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Stack(
                                children: [
                                  // Corner indicators
                                  Positioned(
                                    top: 0,
                                    left: 0,
                                    child: Container(
                                      width: 30,
                                      height: 30,
                                      decoration: BoxDecoration(
                                        border: Border(
                                          top: BorderSide(
                                              color: Colors.green, width: 5),
                                          left: BorderSide(
                                              color: Colors.green, width: 5),
                                        ),
                                      ),
                                    ),
                                  ),
                                  Positioned(
                                    top: 0,
                                    right: 0,
                                    child: Container(
                                      width: 30,
                                      height: 30,
                                      decoration: BoxDecoration(
                                        border: Border(
                                          top: BorderSide(
                                              color: Colors.green, width: 5),
                                          right: BorderSide(
                                              color: Colors.green, width: 5),
                                        ),
                                      ),
                                    ),
                                  ),
                                  Positioned(
                                    bottom: 0,
                                    left: 0,
                                    child: Container(
                                      width: 30,
                                      height: 30,
                                      decoration: BoxDecoration(
                                        border: Border(
                                          bottom: BorderSide(
                                              color: Colors.green, width: 5),
                                          left: BorderSide(
                                              color: Colors.green, width: 5),
                                        ),
                                      ),
                                    ),
                                  ),
                                  Positioned(
                                    bottom: 0,
                                    right: 0,
                                    child: Container(
                                      width: 30,
                                      height: 30,
                                      decoration: BoxDecoration(
                                        border: Border(
                                          bottom: BorderSide(
                                              color: Colors.green, width: 5),
                                          right: BorderSide(
                                              color: Colors.green, width: 5),
                                        ),
                                      ),
                                    ),
                                  ),
                                  // Scanning line animation
                                  AnimatedBuilder(
                                    animation: _animation!,
                                    builder: (context, child) {
                                      return Positioned(
                                        top: _animation!.value * 250,
                                        left: 0,
                                        right: 0,
                                        child: Container(
                                          height: 2,
                                          decoration: BoxDecoration(
                                            color: Colors.green,
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.green
                                                    .withOpacity(0.5),
                                                blurRadius: 8,
                                                spreadRadius: 2,
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        // Instruction text
                        Positioned(
                          bottom: 100,
                          left: 0,
                          right: 0,
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 24, vertical: 12),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(0.7),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: const Text(
                                    "📱 Position QR code within the frame",
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 20, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(0.7),
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: const Text(
                                    "Hold steady for automatic scanning",
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontSize: 12,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ] else ...[
                  Expanded(
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.qr_code_scanner,
                            size: 100,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 20),
                          const Text(
                            "Tap the scanner icon to start scanning QR codes",
                            style: TextStyle(fontSize: 16),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 20),
                          ElevatedButton.icon(
                            icon: const Icon(Icons.qr_code_scanner),
                            label: const Text("Start Scanning"),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green[800],
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 24, vertical: 16),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                            ),
                            onPressed: _startScanning,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
                if (scannedData != null) ...[
                  Container(
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
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          scannedData!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 14),
                        ),
                        if (treeLocation != null) ...[
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            icon: const Icon(Icons.map),
                            label: const Text("View Tree Location"),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue[600],
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 24, vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            onPressed: _showMapView,
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ],
            ),
            // Upload Image Tab
            Column(
              children: [
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.upload_file,
                          size: 100,
                          color: Colors.grey[400],
                        ),
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
                            padding: const EdgeInsets.symmetric(
                                horizontal: 24, vertical: 16),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: isUploading ? null : _uploadQrImage,
                        ),
                        if (isUploading) ...[
                          const SizedBox(height: 20),
                          const CircularProgressIndicator(),
                          const SizedBox(height: 10),
                          const Text("Processing image..."),
                        ],
                        if (uploadedImage != null) ...[
                          const SizedBox(height: 20),
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.grey[100],
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.grey[300]!),
                            ),
                            child: Column(
                              children: [
                                const Text(
                                  "📷 Uploaded Image:",
                                  style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 8),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: kIsWeb
                                      ? Image.network(
                                          uploadedImage!.path,
                                          width: 200,
                                          height: 200,
                                          fit: BoxFit.cover,
                                        )
                                      : Image.file(
                                          io.File(uploadedImage!.path),
                                          width: 200,
                                          height: 200,
                                          fit: BoxFit.cover,
                                        ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                if (scannedData != null) ...[
                  Container(
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
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          scannedData!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 14),
                        ),
                        if (treeLocation != null) ...[
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            icon: const Icon(Icons.map),
                            label: const Text("View Tree Location"),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue[600],
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 24, vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            onPressed: _showMapView,
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ],
            ),
            // Map View Tab
            _buildMapView(),
          ],
        ),
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
                          ? "Your Location: ${currentLocation!.latitude.toStringAsFixed(4)}, ${currentLocation!.longitude.toStringAsFixed(4)}"
                          : "Location: ${locationError ?? 'Loading...'}",
                      style: const TextStyle(fontSize: 12),
                    ),
                    if (treeLocation != null)
                      Text(
                        "Tree Location: ${treeLocation!.latitude.toStringAsFixed(4)}, ${treeLocation!.longitude.toStringAsFixed(4)}",
                        style:
                            const TextStyle(fontSize: 12, color: Colors.blue),
                      ),
                    if (isLoadingRoute)
                      const Text(
                        "🔄 Loading route...",
                        style: TextStyle(fontSize: 11, color: Colors.orange, fontStyle: FontStyle.italic),
                      )
                    else if (routePoints.isNotEmpty)
                      Text(
                        "✅ Route displayed (${routePoints.length} points)",
                        style: const TextStyle(fontSize: 11, color: Colors.green, fontStyle: FontStyle.italic),
                      ),
                  ],
                ),
              ),
              if (isLoadingLocation || isLoadingRoute)
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
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green[700],
                  foregroundColor: Colors.white,
                ),
              ),
              if (currentLocation != null && treeLocation != null)
                ElevatedButton.icon(
                  icon: const Icon(Icons.route),
                  label: const Text("Show Route"),
                  onPressed: isLoadingRoute ? null : _fetchRoute,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue[700],
                    foregroundColor: Colors.white,
                  ),
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

    // Update markers and polylines
    _updateMarkers();
    _updatePolylines();

    // Determine initial camera position
    LatLng initialPosition = treeLocation ?? currentLocation!;

    return GoogleMap(
      mapType: MapType.normal,
      initialCameraPosition: CameraPosition(
        target: initialPosition,
        zoom: treeLocation != null ? 15 : 13,
      ),
      onMapCreated: (GoogleMapController controller) {
        if (!_mapController.isCompleted) {
          _mapController.complete(controller);
        }
      },
      markers: markers,
      polylines: polylines,
      myLocationEnabled: true,
      myLocationButtonEnabled: true,
      zoomControlsEnabled: true,
      mapToolbarEnabled: true,
    );
  }
}
