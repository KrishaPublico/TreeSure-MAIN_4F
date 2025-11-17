import 'dart:async';
import 'dart:convert';
import 'dart:io' as io;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:treesure_app/features/forester/forester_tree_mapping.dart';

class ForesterQrScanner extends StatefulWidget {
  final String? foresterId;

  const ForesterQrScanner({super.key, this.foresterId});

  @override
  State<ForesterQrScanner> createState() => _ForesterQrScannerState();
}

class _ForesterQrScannerState extends State<ForesterQrScanner>
    with SingleTickerProviderStateMixin {
  String? scannedData;
  bool isScanning = false;
  bool isUploading = false;
  XFile? uploadedImage;
  late final MobileScannerController _scannerController;

  AnimationController? _animationController;
  Animation<double>? _animation;

  String? _resolvedTreeInventoryId;
  String? _resolvedAppointmentId;
  String? _resolvedForesterId;
  double? _treeLatitude;
  double? _treeLongitude;

  bool get _canOpenMapping =>
      _resolvedTreeInventoryId != null &&
      (widget.foresterId != null || _resolvedForesterId != null);

  @override
  void initState() {
    super.initState();
    _scannerController = MobileScannerController();
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
    if (capture.barcodes.isEmpty) return;
    final barcode = capture.barcodes.first;
    final rawValue = barcode.rawValue;
    if (rawValue == null) return;

    setState(() {
      scannedData = rawValue;
      isScanning = false;
    });

    _scannerController.stop();
    _fetchTreeDataFromQR(rawValue);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ QR Code scanned successfully!')),
      );
    }
  }

  void _startScanning() {
    setState(() {
      isScanning = true;
      scannedData = null;
      _resolvedTreeInventoryId = null;
      _resolvedAppointmentId = null;
      _resolvedForesterId = null;
      _treeLatitude = null;
      _treeLongitude = null;
    });
    _scannerController.start();
  }

  void _stopScanning() {
    setState(() {
      isScanning = false;
    });
    _scannerController.stop();
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
        setState(() {
          scannedData = '⚠️ Web upload not supported. Use Scan tab instead.';
          isUploading = false;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content:
                  Text('Image-based QR scanning is only available on mobile.'),
            ),
          );
        }
        return;
      } else {
        final imageController = MobileScannerController();
        try {
          final result = await imageController.analyzeImage(pickedFile.path);
          if (result != null && result.barcodes.isNotEmpty) {
            qrData = result.barcodes.first.rawValue;
          }
        } catch (e) {
          qrData = '❌ Error scanning image: $e';
        } finally {
          imageController.dispose();
        }
      }

      setState(() {
        scannedData = qrData ?? '❌ No QR code found in image.';
        isUploading = false;
      });

      if (qrData != null &&
          !qrData.startsWith('❌') &&
          !qrData.startsWith('⚠️')) {
        await _fetchTreeDataFromQR(qrData);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('✅ Image scanned successfully!')),
          );
        }
      } else if (qrData != null && !qrData.startsWith('⚠️')) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(qrData),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      setState(() {
        scannedData = '❌ Error scanning image: $e';
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

  Map<String, String> _parseQrFields(String qrData) {
    final result = <String, String>{};
    final sanitized = qrData.replaceAll('\r\n', '\n').trim();
    if (sanitized.isEmpty) return result;

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

  String _normalizeKey(String rawKey) {
    return rawKey.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_');
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
        final treeIdMatch = RegExp(r'Tree\s*ID[:=]\s*(T\w+)').firstMatch(qrData);
        if (treeIdMatch != null) {
          treeId = treeIdMatch.group(1);
        } else if (RegExp(r'^T\w+', multiLine: false).hasMatch(qrData.trim())) {
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
      setState(() {
        scannedData = '❌ Error parsing QR data: $e';
      });
    }
  }

  Future<void> _fetchTreeFromFirestore(String treeId,
      [String? appointmentId]) async {
    try {
      DocumentSnapshot<Map<String, dynamic>>? treeDoc;
      String? matchedAppointmentId = appointmentId;

      if (matchedAppointmentId != null && matchedAppointmentId.isNotEmpty) {
        final doc = await FirebaseFirestore.instance
            .collection('appointments')
            .doc(matchedAppointmentId)
            .collection('tree_inventory')
            .doc(treeId)
            .get();

        if (doc.exists) {
          treeDoc = doc;
        } else {
          matchedAppointmentId = null;
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
            matchedAppointmentId = appointmentDoc.id;
            break;
          }
        }
      }

      if (treeDoc != null && treeDoc.exists) {
        final treeData = treeDoc.data()!;
        final lat = (treeData['latitude'] as num?)?.toDouble();
        final lng = (treeData['longitude'] as num?)?.toDouble();
        final foresterId = treeData['forester_id']?.toString();

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
Location: ${lat != null && lng != null ? '${lat.toStringAsFixed(6)}, ${lng.toStringAsFixed(6)}' : 'N/A'}
''';
          _resolvedTreeInventoryId = treeDoc!.id;
          _resolvedAppointmentId = matchedAppointmentId;
          _resolvedForesterId = foresterId;
          _treeLatitude = lat;
          _treeLongitude = lng;
        });
      } else {
        setState(() {
          scannedData = '❌ Tree not found in database. Tree ID: $treeId';
        });
      }
    } catch (e) {
      setState(() {
        scannedData = '❌ Error fetching tree data: $e';
      });
    }
  }

  void _navigateToTreeMapping() {
    final treeInventoryId = _resolvedTreeInventoryId;
    final targetForesterId = widget.foresterId ?? _resolvedForesterId;

    if (treeInventoryId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tree information is missing.')),
      );
      return;
    }

    if (targetForesterId == null || targetForesterId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Forester information unavailable.')),
      );
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ForesterTreeMapping(
          foresterId: targetForesterId,
          appointmentId: _resolvedAppointmentId,
          initialTreeId: treeInventoryId,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.green[800],
          iconTheme: const IconThemeData(color: Colors.white),
          title: const Text(
            'QR Scanner',
            style: TextStyle(color: Colors.white),
          ),
          bottom: const TabBar(
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            indicatorColor: Colors.white,
            tabs: [
              Tab(icon: Icon(Icons.qr_code_scanner), text: 'Scan'),
              Tab(icon: Icon(Icons.upload_file), text: 'Upload'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildScannerTab(),
            _buildUploadTab(),
          ],
        ),
      ),
    );
  }

  Widget _buildScannerTab() {
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
                  top: 16,
                  right: 16,
                  child: SafeArea(
                    child: CircleAvatar(
                      backgroundColor: Colors.black54,
                      child: IconButton(
                        icon: const Icon(Icons.close, color: Colors.white),
                        tooltip: 'Stop scanning',
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
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.qr_code_scanner, size: 100, color: Colors.grey[400]),
                  const SizedBox(height: 20),
                  const Text(
                    'Tap the scanner icon to start scanning QR codes',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.qr_code_scanner, color: Colors.white),
                    label: const Text('Start Scanning',
                        style: TextStyle(color: Colors.white)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green[800],
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 16),
                    ),
                    onPressed: _startScanning,
                  ),
                ],
              ),
            ),
          ),
        ],
        if (scannedData != null) _buildScannedDataCard(),
      ],
    );
  }

  Widget _buildUploadTab() {
    return Column(
      children: [
        Expanded(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.upload_file, size: 100, color: Colors.grey[400]),
                const SizedBox(height: 20),
                Text(
                  kIsWeb
                      ? 'Upload QR images (Mobile Only)'
                      : 'Upload a QR code image to scan',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    color: kIsWeb ? Colors.orange[800] : Colors.black87,
                  ),
                ),
                if (kIsWeb) ...[
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Text(
                      'Image QR scanning is not supported on web browsers. Please use the Scan tab or the mobile app.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[600],
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  icon: const Icon(Icons.upload_file, color: Colors.white),
                  label: Text(
                    kIsWeb ? 'Upload (Not Available)' : 'Upload QR Image',
                    style: const TextStyle(color: Colors.white),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kIsWeb ? Colors.grey : Colors.green[800],
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 16),
                  ),
                  onPressed: (isUploading || kIsWeb) ? null : _uploadQrImage,
                ),
                if (isUploading) ...[
                  const SizedBox(height: 20),
                  const CircularProgressIndicator(),
                  const SizedBox(height: 10),
                  const Text('Processing image...'),
                ],
                if (uploadedImage != null) _buildUploadedImagePreview(),
              ],
            ),
          ),
        ),
        if (scannedData != null) _buildScannedDataCard(),
      ],
    );
  }

  Widget _buildScannerOverlay() {
    return Container(
      decoration: BoxDecoration(color: Colors.black.withOpacity(0.5)),
      child: Center(
        child: Container(
          width: 250,
          height: 250,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.green, width: 3),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Stack(
            children: [
              _buildCornerIndicators(),
              if (_animation != null) _buildScanningLine(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCornerIndicators() {
    return Stack(
      children: [
        Positioned(
          top: 0,
          left: 0,
          child: Container(
            width: 30,
            height: 30,
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
            width: 30,
            height: 30,
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
            width: 30,
            height: 30,
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
            width: 30,
            height: 30,
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
    return AnimatedBuilder(
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
            '📄 Scanned Data:',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            scannedData ?? '',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 14),
          ),
          if (_treeLatitude != null && _treeLongitude != null) ...[
            const SizedBox(height: 8),
            Text(
              'Tree Coordinates: ${_treeLatitude!.toStringAsFixed(6)}, ${_treeLongitude!.toStringAsFixed(6)}',
              style: const TextStyle(fontSize: 12, color: Colors.blueGrey),
            ),
          ],
          if (_canOpenMapping) ...[
            const SizedBox(height: 16),
            ElevatedButton.icon(
              icon: const Icon(Icons.map, color: Colors.white),
              label: const Text(
                'View Tree Location',
                style: TextStyle(color: Colors.white),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green[700],
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              ),
              onPressed: _navigateToTreeMapping,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildUploadedImagePreview() {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(top: 20),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        children: [
          const Text(
            '📷 Uploaded Image:',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: kIsWeb
                ? Image.network(uploadedImage!.path,
                    width: 200, height: 200, fit: BoxFit.cover)
                : Image.file(io.File(uploadedImage!.path),
                    width: 200, height: 200, fit: BoxFit.cover),
          ),
        ],
      ),
    );
  }
}
