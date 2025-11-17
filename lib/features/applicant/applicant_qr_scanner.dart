import 'dart:io' as io;
import 'dart:convert';
import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

class ApplicantQrScanner extends StatefulWidget {
  const ApplicantQrScanner({super.key});

  @override
  State<ApplicantQrScanner> createState() => _ApplicantQrScannerState();
}

class _ApplicantQrScannerState extends State<ApplicantQrScanner>
    with SingleTickerProviderStateMixin {
  String? scannedData;
  bool isScanning = false;
  bool isUploading = false;
  XFile? uploadedImage;
  late final MobileScannerController _scannerController;

  // Map and location variables
  LatLng? currentLocation;
  LatLng? treeLocation;
  bool isLoadingLocation = false;
  String? locationError;
  List<LatLng> routePoints = [];
  bool isLoadingRoute = false;
  final MapController _mapController = MapController();
  List<Marker> markers = [];
  List<Polyline> polylines = [];
  double? routeDistanceKm;
  Duration? routeDuration;

  // Map type selection
  String _mapType = 'street'; // 'street', 'satellite', 'terrain'

  // Animation controller for scanning line
  AnimationController? _animationController;
  Animation<double>? _animation;

  @override
  void initState() {
    super.initState();
    _scannerController = MobileScannerController();
    _getCurrentLocation();

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
    _scannerController.dispose();
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
        _scannerController.stop();
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
    _scannerController.start();
  }

  void _stopScanning() {
    setState(() {
      isScanning = false;
    });
    _scannerController.stop();
  }

  Future<void> _getCurrentLocation() async {
    setState(() {
      isLoadingLocation = true;
      locationError = null;
    });

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw Exception('Location services are disabled.');
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw Exception('Location permissions are denied.');
        }
      }
      if (permission == LocationPermission.deniedForever) {
        throw Exception('Location permissions are permanently denied.');
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      setState(() {
        currentLocation = LatLng(position.latitude, position.longitude);
        isLoadingLocation = false;
      });

      _updateMarkers();
      _updatePolylines();

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

  /// 🗺️ Fetch route using OpenStreetMap/OSRM service
  Future<void> _fetchRoute() async {
    if (currentLocation == null || treeLocation == null) {
      debugPrint('⚠️ Cannot fetch route: missing location data');
      return;
    }

    if (_locationsMatch(currentLocation, treeLocation)) {
      setState(() {
        isLoadingRoute = false;
        routePoints = [];
        polylines = [];
        routeDistanceKm = 0;
        routeDuration = Duration.zero;
      });
      _fitCameraToPoints([currentLocation!, treeLocation!]);
      return;
    }

    setState(() {
      isLoadingRoute = true;
      routePoints = [];
      routeDistanceKm = null;
      routeDuration = null;
    });

    final url = Uri.parse(
      'https://router.project-osrm.org/route/v1/driving/'
      '${currentLocation!.longitude},${currentLocation!.latitude};'
      '${treeLocation!.longitude},${treeLocation!.latitude}'
      '?overview=full&geometries=polyline',
    );

    try {
      final response = await http.get(url);
      if (response.statusCode != 200) {
        throw Exception('OSRM request failed (${response.statusCode})');
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final routes = data['routes'] as List<dynamic>?;

      if (routes == null || routes.isEmpty) {
        throw Exception('No routes found for provided coordinates');
      }

      final route = routes.first as Map<String, dynamic>;
      final geometry = route['geometry'] as String?;
      final distanceMeters = (route['distance'] as num?)?.toDouble();
      final durationSeconds = (route['duration'] as num?)?.toDouble();

      if (geometry == null) {
        throw Exception('Route geometry missing in OSRM response');
      }

      final decodedPoints = _decodePolyline(geometry);

      setState(() {
        routePoints = decodedPoints;
        polylines = [
          Polyline(
            points: decodedPoints,
            color: Colors.blueAccent,
            strokeWidth: 4,
          ),
        ];
        routeDistanceKm = distanceMeters != null ? distanceMeters / 1000 : null;
        routeDuration = durationSeconds != null
            ? Duration(seconds: durationSeconds.round())
            : null;
      });

      _fitCameraToPoints(decodedPoints);
    } catch (e) {
      debugPrint('❌ Error fetching route: $e');
      if (mounted) {
        setState(() {
          polylines = [];
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to fetch route. Please try again.'),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          isLoadingRoute = false;
        });
      }
    }
  }

  /// 📍 Decode polyline format from OSRM (compatible with Google encoding)
  List<LatLng> _decodePolyline(String encoded) {
    List<LatLng> points = [];
    int index = 0;
    int lat = 0;
    int lng = 0;

    while (index < encoded.length) {
      int b;
      int shift = 0;
      int result = 0;

      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      final int deltaLat = (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
      lat += deltaLat;

      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      final int deltaLng = (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
      lng += deltaLng;

      points.add(LatLng(lat / 1E5, lng / 1E5));
    }

    return points;
  }

  bool _locationsMatch(LatLng? a, LatLng? b, {double tolerance = 1e-5}) {
    if (a == null || b == null) return false;
    return (a.latitude - b.latitude).abs() <= tolerance &&
        (a.longitude - b.longitude).abs() <= tolerance;
  }

  bool _allPointsCoincident(List<LatLng> points, {double tolerance = 1e-6}) {
    if (points.isEmpty) return true;
    final first = points.first;
    for (final point in points.skip(1)) {
      if ((point.latitude - first.latitude).abs() > tolerance ||
          (point.longitude - first.longitude).abs() > tolerance) {
        return false;
      }
    }
    return true;
  }

  String _normalizeKey(String rawKey) {
    return rawKey.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_');
  }

  Map<String, String> _parseQrFields(String qrData) {
    final result = <String, String>{};
    final sanitized = qrData.replaceAll('\r\n', '\n').trim();
    if (sanitized.isEmpty) {
      return result;
    }

    bool parsedAsJson = false;
    if (sanitized.startsWith('{') && sanitized.endsWith('}')) {
      try {
        final dynamic decoded = jsonDecode(sanitized);
        if (decoded is Map) {
          decoded.forEach((key, value) {
            result[_normalizeKey(key.toString())] = value?.toString() ?? '';
          });
          parsedAsJson = true;
        }
      } catch (_) {
        parsedAsJson = false;
      }
    }

    if (parsedAsJson) {
      return result;
    }

    final working = sanitized.contains('\n')
        ? sanitized
        : sanitized.replaceAll(', ', '\n').replaceAll(',', '\n');

    final segments = working.split('\n');
    for (final rawSegment in segments) {
      final segment = rawSegment.trim();
      if (segment.isEmpty) continue;
      var separatorIndex = segment.indexOf(':');
      if (separatorIndex == -1) {
        separatorIndex = segment.indexOf('=');
      }
      if (separatorIndex == -1) continue;

      final key = _normalizeKey(segment.substring(0, separatorIndex));
      if (key.isEmpty) continue;

      var value = segment.substring(separatorIndex + 1).trim();
      if ((value.startsWith('"') && value.endsWith('"')) ||
          (value.startsWith("'") && value.endsWith("'"))) {
        value = value.substring(1, value.length - 1);
      }

      result[key] = value;
    }

    return result;
  }

  /// 🗺️ Update markers on the map
  void _updateMarkers() {
    final updatedMarkers = <Marker>[];

    if (currentLocation != null) {
      updatedMarkers.add(
        Marker(
          point: currentLocation!,
          width: 48,
          height: 48,
          alignment: Alignment.bottomCenter,
          child: const Tooltip(
            message: 'Your Location',
            child: Icon(Icons.my_location, color: Colors.blueAccent, size: 30),
          ),
        ),
      );
    }

    if (treeLocation != null) {
      updatedMarkers.add(
        Marker(
          point: treeLocation!,
          width: 48,
          height: 48,
          alignment: Alignment.bottomCenter,
          child: Tooltip(
            message: 'Tree Location',
            child: Icon(Icons.park, color: Colors.green.shade700, size: 32),
          ),
        ),
      );
    }

    setState(() {
      markers = updatedMarkers;
    });

    if (updatedMarkers.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _fitCameraToPoints(
            updatedMarkers.map((marker) => marker.point).toList());
      });
    }
  }

  /// 📍 Update polylines on the map
  void _updatePolylines() {
    final updatedPolylines = <Polyline>[];

    if (routePoints.isNotEmpty) {
      updatedPolylines.add(
        Polyline(
          points: routePoints,
          color: Colors.blueAccent,
          strokeWidth: 4,
        ),
      );
    } else if (currentLocation != null && treeLocation != null) {
      if (!_locationsMatch(currentLocation, treeLocation)) {
        updatedPolylines.add(
          Polyline(
            points: [currentLocation!, treeLocation!],
            color: Colors.blueGrey.withOpacity(0.6),
            strokeWidth: 3,
          ),
        );
      }
    }

    setState(() {
      polylines = updatedPolylines;
    });
  }

  /// 🗺️ Get tile layer configuration based on map type
  TileLayer _getTileLayer() {
    switch (_mapType) {
      case 'satellite':
        // Using ESRI World Imagery (satellite)
        return TileLayer(
          urlTemplate:
              'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}',
          userAgentPackageName: 'com.treesure.app',
          maxZoom: 19,
        );
      case 'terrain':
        // Using OpenTopoMap (topographic/terrain)
        return TileLayer(
          urlTemplate: 'https://tile.opentopomap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.treesure.app',
          maxZoom: 17,
        );
      case 'street':
      default:
        // Using OpenStreetMap (street map)
        return TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.treesure.app',
          maxZoom: 19,
        );
    }
  }

  void _fitCameraToPoints(List<LatLng> points) {
    if (points.isEmpty) {
      return;
    }

    if (points.length == 1) {
      _mapController.move(points.first, 15);
      return;
    }

    if (_allPointsCoincident(points)) {
      _mapController.move(points.first, 17);
      return;
    }

    final bounds = LatLngBounds.fromPoints(points);
    try {
      _mapController.fitCamera(
        CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(40)),
      );
    } catch (e) {
      debugPrint('⚠️ Failed to fit camera: $e');
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
        // Web platform: Use BarcodeCapture with the camera controller
        // Since analyzeImage() doesn't work on web, we'll use a workaround
        // Show a message to the user to use the scan tab instead
        setState(() {
          scannedData = "⚠️ Web Platform Limitation:\n\n"
              "QR code scanning from uploaded images is not supported on web browsers.\n\n"
              "Please use the 'Scan' tab to scan QR codes directly with your camera,\n"
              "or use the mobile app for full image upload functionality.";
          isUploading = false;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  '⚠️ Image QR scanning not available on web. Please use the Scan tab or mobile app.'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 4),
            ),
          );
        }
        return;
      } else {
        // Mobile platform: Use analyzeImage
        final imageController = MobileScannerController();

        try {
          final result = await imageController.analyzeImage(pickedFile.path);
          if (result != null && result.barcodes.isNotEmpty) {
            qrData = result.barcodes.first.rawValue;
          } else {
            qrData =
                "❌ No QR code found in image. Please ensure the QR code is clear and try again.";
          }
        } catch (e) {
          print('Scanning error: $e');
          qrData = "❌ Error scanning image: $e";
        } finally {
          imageController.dispose();
        }
      }

      setState(() {
        scannedData = qrData ?? "❌ No QR code found in image.";
        isUploading = false;
      });

      if (scannedData != null &&
          !scannedData!.startsWith('❌') &&
          !scannedData!.startsWith('⚠️')) {
        await _fetchTreeDataFromQR(scannedData!);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ QR code scanned from image successfully!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else if (!scannedData!.startsWith('⚠️')) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(scannedData!),
              backgroundColor:
                  scannedData!.startsWith('❌') ? Colors.red : Colors.orange,
            ),
          );
        }
      }
    } catch (e) {
      setState(() {
        scannedData = "❌ Error scanning image: $e";
        isUploading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Failed to scan image: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _fetchTreeDataFromQR(String qrData) async {
    try {
      final parsedFields = _parseQrFields(qrData);
      String? treeId = parsedFields['tree_id'] ?? parsedFields['treeid'];
      String? documentId =
          parsedFields['inventory_doc_id'] ?? parsedFields['doc_id'];
      String? appointmentId =
          parsedFields['appointment_id'] ?? parsedFields['appointmentid'];

      if (treeId == null || treeId.isEmpty) {
        final treeIdMatch =
            RegExp(r'Tree\s*ID[:=]\s*(T\w+)').firstMatch(qrData);
        if (treeIdMatch != null) {
          treeId = treeIdMatch.group(1);
        } else if (RegExp(r'^T\w+$').hasMatch(qrData.trim())) {
          treeId = qrData.trim();
        }
      }

      final lookupId =
          (documentId != null && documentId.isNotEmpty) ? documentId : treeId;

      if (lookupId != null && lookupId.isNotEmpty) {
        await _fetchTreeFromFirestore(lookupId, appointmentId);
      } else {
        setState(() {
          scannedData = '❌ Invalid QR code format. No tree_id found.';
        });
      }
    } catch (e) {
      print('Error parsing QR data: $e');
      setState(() {
        scannedData = "❌ Error parsing QR data: $e";
      });
    }
  }

  Future<void> _fetchTreeFromFirestore(String treeId,
      [String? appointmentId]) async {
    try {
      DocumentSnapshot? treeDoc;

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

      if (treeDoc == null) {
        final appointmentsSnapshot =
            await FirebaseFirestore.instance.collection('appointments').get();

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
Tree Status: ${treeData['tree_status'] ?? 'N/A'}
Location: ${lat != null ? '${lat.toStringAsFixed(6)}, ${lng!.toStringAsFixed(6)}' : 'N/A'}
''';

          if (lat != null && lng != null) {
            treeLocation = LatLng(lat, lng);
          }
        });

        _updateMarkers();
        if (currentLocation != null && treeLocation != null) {
          await _fetchRoute();
        }
      } else {
        setState(() {
          scannedData = "❌ Tree not found in database. Tree ID: $treeId";
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
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.green[800],
          iconTheme:
              const IconThemeData(color: Colors.white), // back button color
          title: const Text(
            'Tree QR Scanner',
            style: TextStyle(color: Colors.white), // title color
          ),
          bottom: const TabBar(
            labelColor: Colors.white, // selected tab text color
            unselectedLabelColor: Colors.white70, // unselected tab text color
            indicatorColor: Colors.white, // underline indicator color
            tabs: [
              Tab(icon: Icon(Icons.qr_code_scanner), text: "Scan"),
              Tab(icon: Icon(Icons.upload_file), text: "Upload"),
              Tab(icon: Icon(Icons.map), text: "Map"),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            // Scanner Tab
            _buildScannerTab(),
            // Upload Tab
            _buildUploadTab(),
            // Map Tab
            _buildMapView(),
          ],
        ),
      ),
    );
  }

  Widget _buildScannerTab() {
    final screenSize = MediaQuery.of(context).size;
    final screenWidth = screenSize.width;
    final screenHeight = screenSize.height;

    return Column(
      children: [
        if (isScanning) ...[
          Expanded(
            child: Stack(
              children: [
                MobileScanner(
                  controller: _scannerController,
                  onDetect: _onDetect,
                ),
                _buildScannerOverlay(),
                Positioned(
                  top: 8,
                  right: 8,
                  child: SafeArea(
                    child: CircleAvatar(
                      backgroundColor: Colors.black54,
                      radius: screenWidth * 0.06,
                      child: IconButton(
                        icon: const Icon(Icons.close, color: Colors.white),
                        tooltip: 'Stop scanning',
                        iconSize: screenWidth * 0.06,
                        onPressed: _stopScanning,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ] else ...[
          Expanded(
            child: SingleChildScrollView(
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: screenWidth * 0.05,
                  vertical: screenHeight * 0.05,
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.qr_code_scanner,
                          size: screenWidth * 0.25, color: Colors.grey[400]),
                      SizedBox(height: screenHeight * 0.025),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.08),
                        child: Text(
                          "Tap the scanner icon to start scanning QR codes",
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: screenWidth * 0.04),
                        ),
                      ),
                      SizedBox(height: screenHeight * 0.03),
                      ElevatedButton.icon(
                        icon: Icon(Icons.qr_code_scanner,
                            color: Colors.white, size: screenWidth * 0.05),
                        label: Text("Start Scanning",
                            style: TextStyle(
                                color: Colors.white, fontSize: screenWidth * 0.04)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green[800],
                          padding: EdgeInsets.symmetric(
                              horizontal: screenWidth * 0.06,
                              vertical: screenHeight * 0.018),
                          minimumSize: Size(screenWidth * 0.5, screenHeight * 0.06),
                        ),
                        onPressed: _startScanning,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
        if (scannedData != null) _buildScannedDataCard(),
      ],
    );
  }

  Widget _buildUploadTab() {
    final screenSize = MediaQuery.of(context).size;
    final screenWidth = screenSize.width;
    final screenHeight = screenSize.height;

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: screenWidth * 0.05,
                vertical: screenHeight * 0.05,
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.upload_file,
                        size: screenWidth * 0.25, color: Colors.grey[400]),
                    SizedBox(height: screenHeight * 0.025),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.08),
                      child: Text(
                        kIsWeb
                            ? "Upload QR images (Mobile Only)"
                            : "Upload a QR code image to scan",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: screenWidth * 0.04,
                          color: kIsWeb ? Colors.orange[800] : Colors.black87,
                        ),
                      ),
                    ),
                    if (kIsWeb) ...[
                      SizedBox(height: screenHeight * 0.01),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.08),
                        child: Text(
                          "Image QR scanning is not supported on web browsers. Please use the 'Scan' tab or the mobile app.",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: screenWidth * 0.032,
                            color: Colors.grey[600],
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                    ],
                    SizedBox(height: screenHeight * 0.03),
                    ElevatedButton.icon(
                      icon: Icon(Icons.upload_file,
                          color: Colors.white, size: screenWidth * 0.05),
                      label: Text(
                        kIsWeb ? "Upload (Not Available)" : "Upload QR Image",
                        style: TextStyle(
                            color: Colors.white, fontSize: screenWidth * 0.04),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kIsWeb ? Colors.grey : Colors.green[800],
                        padding: EdgeInsets.symmetric(
                            horizontal: screenWidth * 0.06,
                            vertical: screenHeight * 0.018),
                        minimumSize: Size(screenWidth * 0.5, screenHeight * 0.06),
                      ),
                      onPressed: (isUploading || kIsWeb) ? null : _uploadQrImage,
                    ),
                    if (isUploading) ...[
                      SizedBox(height: screenHeight * 0.025),
                      const CircularProgressIndicator(),
                      SizedBox(height: screenHeight * 0.012),
                      Text("Processing image...",
                          style: TextStyle(fontSize: screenWidth * 0.035)),
                    ],
                    if (uploadedImage != null) _buildUploadedImagePreview(),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (scannedData != null) _buildScannedDataCard(),
      ],
    );
  }

  Widget _buildScannerOverlay() {
    final screenSize = MediaQuery.of(context).size;
    final overlaySize = screenSize.width * 0.65;

    return Container(
      decoration: BoxDecoration(color: Colors.black.withOpacity(0.5)),
      child: Center(
        child: Container(
          width: overlaySize,
          height: overlaySize,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.green, width: 3),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Stack(
            children: [
              _buildCornerIndicators(),
              _buildScanningLine(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCornerIndicators() {
    final screenWidth = MediaQuery.of(context).size.width;
    final cornerSize = screenWidth * 0.08;

    return Stack(
      children: [
        Positioned(
          top: 0,
          left: 0,
          child: Container(
            width: cornerSize,
            height: cornerSize,
            decoration: const BoxDecoration(
              border: Border(
                top: BorderSide(color: Colors.green, width: 5),
                left: BorderSide(color: Colors.green, width: 5),
              ),
            ),
          ),
        ),
        Positioned(
          top: 0,
          right: 0,
          child: Container(
            width: cornerSize,
            height: cornerSize,
            decoration: const BoxDecoration(
              border: Border(
                top: BorderSide(color: Colors.green, width: 5),
                right: BorderSide(color: Colors.green, width: 5),
              ),
            ),
          ),
        ),
        Positioned(
          bottom: 0,
          left: 0,
          child: Container(
            width: cornerSize,
            height: cornerSize,
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Colors.green, width: 5),
                left: BorderSide(color: Colors.green, width: 5),
              ),
            ),
          ),
        ),
        Positioned(
          bottom: 0,
          right: 0,
          child: Container(
            width: cornerSize,
            height: cornerSize,
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Colors.green, width: 5),
                right: BorderSide(color: Colors.green, width: 5),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildScanningLine() {
    final screenSize = MediaQuery.of(context).size;
    final overlaySize = screenSize.width * 0.65;

    return AnimatedBuilder(
      animation: _animation!,
      builder: (context, child) {
        return Positioned(
          top: _animation!.value * overlaySize,
          left: 0,
          right: 0,
          child: Container(
            height: 2,
            decoration: BoxDecoration(
              color: Colors.green,
              boxShadow: [
                BoxShadow(
                  color: Colors.green.withOpacity(0.5),
                  blurRadius: 8,
                  spreadRadius: 2,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildScannedDataCard() {
    final screenSize = MediaQuery.of(context).size;
    final screenWidth = screenSize.width;
    final screenHeight = screenSize.height;

    return Container(
      padding: EdgeInsets.all(screenWidth * 0.04),
      margin: EdgeInsets.all(screenWidth * 0.04),
      constraints: BoxConstraints(
        maxHeight: screenHeight * 0.4,
      ),
      decoration: BoxDecoration(
        color: Colors.green[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green[200]!),
      ),
      child: SingleChildScrollView(
        child: Column(
          children: [
            Text("📄 Scanned Data:",
                style: TextStyle(
                    fontSize: screenWidth * 0.04, fontWeight: FontWeight.bold)),
            SizedBox(height: screenHeight * 0.01),
            Text(scannedData!,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: screenWidth * 0.035)),
          ],
        ),
      ),
    );
  }

  Widget _buildUploadedImagePreview() {
    final screenSize = MediaQuery.of(context).size;
    final screenWidth = screenSize.width;
    final screenHeight = screenSize.height;
    final imageSize = screenWidth * 0.5;

    return Container(
      padding: EdgeInsets.all(screenWidth * 0.04),
      margin: EdgeInsets.only(top: screenHeight * 0.025),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        children: [
          Text("📷 Uploaded Image:",
              style: TextStyle(
                  fontSize: screenWidth * 0.035, fontWeight: FontWeight.bold)),
          SizedBox(height: screenHeight * 0.01),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: kIsWeb
                ? Image.network(uploadedImage!.path,
                    width: imageSize, height: imageSize, fit: BoxFit.cover)
                : Image.file(io.File(uploadedImage!.path),
                    width: imageSize, height: imageSize, fit: BoxFit.cover),
          ),
        ],
      ),
    );
  }

  Widget _buildMapView() {
    return Column(
      children: [
        _buildLocationHeader(),
        Expanded(child: _buildMap()),
      ],
    );
  }

  Widget _buildLocationHeader() {
    final screenSize = MediaQuery.of(context).size;
    final screenWidth = screenSize.width;

    return Container(
      padding: EdgeInsets.all(screenWidth * 0.04),
      color: Colors.grey[100],
      child: Row(
        children: [
          Icon(Icons.location_on,
              size: screenWidth * 0.06,
              color: currentLocation != null ? Colors.green : Colors.red),
          SizedBox(width: screenWidth * 0.02),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  currentLocation != null
                      ? "Your Location: ${currentLocation!.latitude.toStringAsFixed(4)}, ${currentLocation!.longitude.toStringAsFixed(4)}"
                      : "Location: ${locationError ?? 'Loading...'}",
                  style: TextStyle(fontSize: screenWidth * 0.03),
                ),
                if (treeLocation != null)
                  Text(
                    "Tree Location: ${treeLocation!.latitude.toStringAsFixed(4)}, ${treeLocation!.longitude.toStringAsFixed(4)}",
                    style: TextStyle(
                        fontSize: screenWidth * 0.03, color: Colors.blue),
                  ),
                if (isLoadingRoute)
                  Text("🔄 Loading route...",
                      style: TextStyle(
                          fontSize: screenWidth * 0.028,
                          color: Colors.orange,
                          fontStyle: FontStyle.italic))
                else if (routePoints.isNotEmpty)
                  Text("✅ Route displayed (${routePoints.length} points)",
                      style: TextStyle(
                          fontSize: screenWidth * 0.028,
                          color: Colors.green,
                          fontStyle: FontStyle.italic)),
              ],
            ),
          ),
          if (isLoadingLocation || isLoadingRoute)
            SizedBox(
                width: screenWidth * 0.04,
                height: screenWidth * 0.04,
                child: const CircularProgressIndicator(strokeWidth: 2)),
        ],
      ),
    );
  }

  Widget _buildMap() {
    final screenSize = MediaQuery.of(context).size;
    final screenWidth = screenSize.width;
    final screenHeight = screenSize.height;

    if (isLoadingLocation) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            SizedBox(height: screenHeight * 0.02),
            Text("Loading location...",
                style: TextStyle(fontSize: screenWidth * 0.04)),
          ],
        ),
      );
    }

    if (locationError != null) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(screenWidth * 0.05),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.location_off,
                  size: screenWidth * 0.16, color: Colors.red),
              SizedBox(height: screenHeight * 0.02),
              Text("Location Error: $locationError",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: screenWidth * 0.035)),
              SizedBox(height: screenHeight * 0.02),
              ElevatedButton(
                  onPressed: _getCurrentLocation,
                  style: ElevatedButton.styleFrom(
                    padding: EdgeInsets.symmetric(
                        horizontal: screenWidth * 0.06,
                        vertical: screenHeight * 0.015),
                  ),
                  child: Text("Retry",
                      style: TextStyle(fontSize: screenWidth * 0.04))),
            ],
          ),
        ),
      );
    }

    if (currentLocation == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.location_searching,
                size: screenWidth * 0.16, color: Colors.grey),
            SizedBox(height: screenHeight * 0.02),
            Text("Unable to get current location",
                style: TextStyle(fontSize: screenWidth * 0.04)),
          ],
        ),
      );
    }

    final initialPosition = treeLocation ?? currentLocation!;

    return Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: initialPosition,
            initialZoom: treeLocation != null ? 15 : 13,
            interactionOptions: const InteractionOptions(
              flags: InteractiveFlag.pinchZoom |
                  InteractiveFlag.drag |
                  InteractiveFlag.flingAnimation |
                  InteractiveFlag.doubleTapZoom,
            ),
          ),
          children: [
            _getTileLayer(), // Dynamic tile layer based on map type
            if (polylines.isNotEmpty) PolylineLayer(polylines: polylines),
            if (markers.isNotEmpty) MarkerLayer(markers: markers),
          ],
        ),
        // Map type selector
        Positioned(
          top: screenHeight * 0.02,
          right: screenWidth * 0.04,
          child: _buildMapTypeSelector(),
        ),
      ],
    );
  }

  /// 🗺️ Build map type selector widget
  Widget _buildMapTypeSelector() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildMapTypeButton('street', Icons.map, 'Street'),
          const Divider(height: 1),
          _buildMapTypeButton('satellite', Icons.satellite_alt, 'Satellite'),
          const Divider(height: 1),
          _buildMapTypeButton('terrain', Icons.terrain, 'Terrain'),
        ],
      ),
    );
  }

  /// 🗺️ Build individual map type button
  Widget _buildMapTypeButton(String type, IconData icon, String label) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSelected = _mapType == type;

    return InkWell(
      onTap: () {
        setState(() {
          _mapType = type;
        });
      },
      child: Container(
        padding: EdgeInsets.symmetric(
            horizontal: screenWidth * 0.03, vertical: screenWidth * 0.025),
        decoration: BoxDecoration(
          color: isSelected ? Colors.green[700] : Colors.transparent,
          borderRadius: type == 'street'
              ? const BorderRadius.only(
                  topLeft: Radius.circular(8),
                  topRight: Radius.circular(8),
                )
              : type == 'terrain'
                  ? const BorderRadius.only(
                      bottomLeft: Radius.circular(8),
                      bottomRight: Radius.circular(8),
                    )
                  : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: screenWidth * 0.05,
              color: isSelected ? Colors.white : Colors.grey[700],
            ),
            SizedBox(width: screenWidth * 0.02),
            Text(
              label,
              style: TextStyle(
                fontSize: screenWidth * 0.032,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? Colors.white : Colors.grey[700],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
