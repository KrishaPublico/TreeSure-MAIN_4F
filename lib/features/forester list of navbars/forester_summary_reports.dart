import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class ForesterSummaryReports extends StatefulWidget {
  final String foresterId;

  const ForesterSummaryReports({super.key, required this.foresterId});

  @override
  State<ForesterSummaryReports> createState() => _ForesterSummaryReportsState();
}

class _ForesterSummaryReportsState extends State<ForesterSummaryReports> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final MapController _mapController = MapController();
  final GlobalKey _mapRepaintKey = GlobalKey();

  String _filterType = 'All'; // 'All', 'Appointment', 'Applicant'
  String _selectedAppointmentId = 'All';
  String _selectedApplicantId = 'All';
  String _selectedTreeStatus = 'All';
  String _mapType = 'street'; // 'street', 'satellite', 'terrain'

  List<Map<String, dynamic>> _appointments = [];
  List<Map<String, dynamic>> _applicants = [];
  bool _isLoading = true;
  bool _isCapturingScreenshot = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  /// Load all appointments and applicants for this forester
  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Get appointments where forester is assigned
      final appointmentsSnapshot = await _firestore
          .collection('appointments')
          .where('foresterIds', arrayContains: widget.foresterId)
          .get();

      final appointments = <Map<String, dynamic>>[];
      final applicantIdsSet = <String>{};

      for (var doc in appointmentsSnapshot.docs) {
        final data = doc.data();
        appointments.add({
          'id': doc.id,
          'location': data['location'] ?? 'Unknown Location',
          'applicantId': data['applicantId'],
          'appointmentType': data['appointmentType'] ?? 'Tree Tagging',
          'status': data['status'] ?? 'Pending',
          'createdAt': data['createdAt'],
        });

        if (data['applicantId'] != null) {
          applicantIdsSet.add(data['applicantId']);
        }
      }

      // Get applicant details
      final applicants = <Map<String, dynamic>>[];
      for (var applicantId in applicantIdsSet) {
        // Try to get applicant name from different collections
        String applicantName = applicantId;

        // Check in applications/ctpo/applicants
        for (var appType in ['ctpo', 'ptc', 'pltp', 'splt']) {
          try {
            final applicantDoc = await _firestore
                .collection('applications')
                .doc(appType)
                .collection('applicants')
                .doc(applicantId)
                .get();

            if (applicantDoc.exists) {
              final data = applicantDoc.data();
              applicantName =
                  data?['applicantName'] ?? data?['name'] ?? applicantId;
              break;
            }
          } catch (e) {
            // Continue to next app type
          }
        }

        applicants.add({
          'id': applicantId,
          'name': applicantName,
        });
      }

      setState(() {
        _appointments = appointments;
        _applicants = applicants;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading data: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// Get filtered trees stream
  Stream<List<Map<String, dynamic>>> _getTreesStream() async* {
    final uniqueTrees = <String, Map<String, dynamic>>{};
    final uniqueTimestamps = <String, DateTime?>{};

    try {
      // Filter appointments based on selection
      var filteredAppointments = _appointments;

      if (_filterType == 'Appointment' && _selectedAppointmentId != 'All') {
        filteredAppointments = _appointments
            .where((a) => a['id'] == _selectedAppointmentId)
            .toList();
      } else if (_filterType == 'Applicant' && _selectedApplicantId != 'All') {
        filteredAppointments = _appointments
            .where((a) => a['applicantId'] == _selectedApplicantId)
            .toList();
      }

      // Get trees from filtered appointments
      for (var appointment in filteredAppointments) {
        final appointmentCreatedAt = _extractDateTime(appointment['createdAt']);
        final treesSnapshot = await _firestore
            .collection('appointments')
            .doc(appointment['id'])
            .collection('tree_inventory')
            .get();

        for (var treeDoc in treesSnapshot.docs) {
          final treeData = treeDoc.data();
          final latValue =
              _parseCoordinate(treeData['latitude'], isLatitude: true);
          final lngValue =
              _parseCoordinate(treeData['longitude'], isLatitude: false);

            final applicantId =
              appointment['applicantId']?.toString().trim() ?? 'unknown';
            final treeIdentifier =
              (treeData['tree_no'] ?? treeDoc.id ?? '').toString().trim();
            if (treeIdentifier.isEmpty) {
            continue;
          }
            final uniqueKey = '${applicantId}_$treeIdentifier';

          final candidateTimestamp =
              _extractDateTime(treeData['updatedAt']) ??
                  _extractDateTime(treeData['taggedAt']) ??
                  _extractDateTime(treeData['timestamp']) ??
                  appointmentCreatedAt;

          final treeEntry = {
            'id': treeDoc.id,
            'tree_no': treeData['tree_no'] ?? 'N/A',
            'species': treeData['species'] ?? treeData['specie'] ?? 'Unknown',
            'diameter': treeData['diameter'] ?? 0,
            'height': treeData['height'] ?? 0,
            'volume': treeData['volume'] ?? 0,
            'tree_status': treeData['tree_status'] ?? 'Not Yet Ready',
            'latitude': latValue,
            'longitude': lngValue,
            'photo_url': treeData['photo_url'],
            'qr_url': treeData['qr_url'],
            'appointment_id': appointment['id'],
            'appointment_location': appointment['location'],
            'appointment_type': appointment['appointmentType'],
            'applicant_id': appointment['applicantId'],
            'applicant_name': _applicants.firstWhere(
              (a) => a['id'] == appointment['applicantId'],
              orElse: () => {'name': 'Unknown'},
            )['name'],
          };

          final existingTimestamp = uniqueTimestamps[uniqueKey];
          final shouldReplace = !uniqueTrees.containsKey(uniqueKey) ||
              (candidateTimestamp != null &&
                  (existingTimestamp == null ||
                      candidateTimestamp.isAfter(existingTimestamp)));

          if (shouldReplace) {
            uniqueTrees[uniqueKey] = treeEntry;
            uniqueTimestamps[uniqueKey] =
                candidateTimestamp ?? existingTimestamp;
          }
        }
      }

      var resultTrees = uniqueTrees.values.toList()
        ..sort((a, b) => (a['tree_no'] ?? 'N/A')
            .toString()
            .compareTo((b['tree_no'] ?? 'N/A').toString()));

      // Filter by tree status
      if (_selectedTreeStatus != 'All') {
        resultTrees = resultTrees
            .where((tree) => tree['tree_status'] == _selectedTreeStatus)
            .toList();
      }

      yield resultTrees;
    } catch (e) {
      print('Error loading trees: $e');
      yield [];
    }
  }

  double? _parseCoordinate(dynamic value, {required bool isLatitude}) {
    if (value == null) return null;

    if (value is num) {
      return value.toDouble();
    }

    if (value is String) {
      final parsedValue = double.tryParse(value.trim());
      if (parsedValue == null) {
        print(
            '⚠️ Failed to parse ${isLatitude ? 'latitude' : 'longitude'} string: "$value"');
      }
      return parsedValue;
    }

    if (value is GeoPoint) {
      return isLatitude ? value.latitude : value.longitude;
    }

    print('⚠️ Unsupported coordinate type: ${value.runtimeType}');
    return null;
  }

  DateTime? _extractDateTime(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is int) {
      // Assume value is a millisecond epoch
      return DateTime.fromMillisecondsSinceEpoch(value, isUtc: false);
    }
    if (value is String) {
      return DateTime.tryParse(value);
    }
    return null;
  }

  bool _isValidLatitude(double value) {
    return value.isFinite && !value.isNaN && value >= -90 && value <= 90;
  }

  bool _isValidLongitude(double value) {
    return value.isFinite && !value.isNaN && value >= -180 && value <= 180;
  }

  bool _isValidLatLng(double latitude, double longitude) {
    return _isValidLatitude(latitude) && _isValidLongitude(longitude);
  }

  LatLng? _extractTreeLatLng(Map<String, dynamic> tree) {
    final lat = tree['latitude'];
    final lng = tree['longitude'];
    final treeLabel = tree['tree_no'] ?? tree['id'] ?? 'unknown';

    if (lat == null || lng == null) {
      print('⚠️ Tree $treeLabel skipped due to missing coordinates');
      return null;
    }

    if (!_isValidLatLng(lat, lng)) {
      print(
          '⚠️ Tree $treeLabel skipped due to invalid coordinates: ($lat, $lng)');
      return null;
    }

    return LatLng(lat, lng);
  }

  String _formatCoordinate(double value) => value.toStringAsFixed(6);

  double _clampLatitude(double value) => value.clamp(-90.0, 90.0).toDouble();

  double _clampLongitude(double value) => value.clamp(-180.0, 180.0).toDouble();

  LatLngBounds _createSafeBounds(List<LatLng> points) {
    if (points.length == 1) {
      final single = points.first;
      final delta = 0.0005;
      return LatLngBounds.fromPoints([
        LatLng(single.latitude - delta, single.longitude - delta),
        LatLng(single.latitude + delta, single.longitude + delta),
      ]);
    }

    double minLat = points.first.latitude;
    double maxLat = points.first.latitude;
    double minLng = points.first.longitude;
    double maxLng = points.first.longitude;

    for (final point in points.skip(1)) {
      minLat = math.min(minLat, point.latitude);
      maxLat = math.max(maxLat, point.latitude);
      minLng = math.min(minLng, point.longitude);
      maxLng = math.max(maxLng, point.longitude);
    }

    if ((maxLat - minLat).abs() < 0.0001) {
      maxLat += 0.0005;
      minLat -= 0.0005;
    }

    if ((maxLng - minLng).abs() < 0.0001) {
      maxLng += 0.0005;
      minLng -= 0.0005;
    }

    return LatLngBounds.fromPoints([
      LatLng(minLat, minLng),
      LatLng(maxLat, maxLng),
    ]);
  }

  /// Generate map markers from trees
  List<Marker> _generateMarkers(List<Map<String, dynamic>> trees) {
    final markers = <Marker>[];

    for (final tree in trees) {
      final latLng = _extractTreeLatLng(tree);
      if (latLng == null) continue;

      Color markerColor = Colors.green;
      final status = tree['tree_status'] ?? 'Not Yet Ready';
      if (status == 'Ready to Cut') {
        markerColor = Colors.orange;
      } else if (status == 'Cut') {
        markerColor = Colors.red;
      }

      final treeLabel =
          (tree['tree_no'] ?? tree['id'] ?? 'N/A').toString().trim();

      markers.add(
        Marker(
          point: latLng,
          width: 60,
          height: 60,
          alignment: Alignment.topCenter,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.location_pin,
                color: markerColor,
                size: 40,
                shadows: const [
                  Shadow(blurRadius: 3, color: Colors.black45),
                ],
              ),
              Container(
                margin: const EdgeInsets.only(top: 2),
                padding:
                    const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(4),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 3,
                      offset: Offset(0, 1),
                    ),
                  ],
                ),
                child: Text(
                  treeLabel.isEmpty ? 'N/A' : treeLabel,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return markers;
  }

  /// Fit map to show all markers
  void _fitMapToMarkers(List<Marker> markers) {
    if (markers.isEmpty) return;

    try {
      if (markers.length == 1) {
        _mapController.move(markers.first.point, 15);
        return;
      }

      final bounds = _createSafeBounds(markers.map((m) => m.point).toList());

      _mapController.fitCamera(
        CameraFit.bounds(
          bounds: bounds,
          padding: const EdgeInsets.all(60),
        ),
      );
    } catch (e) {
      print('Error fitting map: $e');
    }
  }

  LatLng _getValidInitialCenter(List<Marker> markers) {
    if (markers.isEmpty) {
      return const LatLng(8.4542, 124.6319); // Cagayan de Oro default
    }

    final first = markers.first.point;
    return LatLng(
      _clampLatitude(first.latitude),
      _clampLongitude(first.longitude),
    );
  }

  /// Get tile layer based on map type
  TileLayer _getTileLayer() {
    switch (_mapType) {
      case 'satellite':
        return TileLayer(
          urlTemplate:
              'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}',
          userAgentPackageName: 'com.treesure.app',
          maxZoom: 19,
        );
      case 'terrain':
        return TileLayer(
          urlTemplate: 'https://tile.opentopomap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.treesure.app',
          maxZoom: 17,
        );
      case 'street':
      default:
        return TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.treesure.app',
          maxZoom: 19,
        );
    }
  }

  /// Capture screenshot of the map
  Future<void> _captureMapScreenshot() async {
    if (_isCapturingScreenshot) return;

    setState(() {
      _isCapturingScreenshot = true;
    });

    try {
      await Future.delayed(const Duration(milliseconds: 500));

      final boundaryContext = _mapRepaintKey.currentContext;
      if (boundaryContext == null) {
        throw Exception('Map is not ready yet. Please try again in a moment.');
      }

      final boundary =
          boundaryContext.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) {
        throw Exception('Unable to access map boundary for capture.');
      }

      final mediaQuery = MediaQuery.of(context);
      final pixelRatio = mediaQuery.devicePixelRatio.clamp(1.0, 3.0).toDouble();
      final ui.Image image = await boundary.toImage(pixelRatio: pixelRatio);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);

      if (byteData == null) {
        throw Exception('Failed to process screenshot bytes.');
      }

      final pngBytes = byteData.buffer.asUint8List();
      final directory = await getApplicationDocumentsDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final filePath = '${directory.path}/tree_map_report_$timestamp.png';
      final file = File(filePath);
      await file.writeAsBytes(pngBytes);

      if (!await file.exists()) {
        throw Exception('File was not saved successfully.');
      }

      if (mounted) {
        _showScreenshotSuccessDialog(filePath);
      }
    } catch (e, stackTrace) {
      print('Screenshot error: $e');
      print('Stack trace: $stackTrace');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString().split('Exception: ').last}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 6),
            action: SnackBarAction(
              label: 'Retry',
              textColor: Colors.white,
              onPressed: _captureMapScreenshot,
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isCapturingScreenshot = false;
        });
      } else {
        _isCapturingScreenshot = false;
      }
    }
  }

  /// Show dialog after successful screenshot
  void _showScreenshotSuccessDialog(String filePath) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green, size: 28),
            SizedBox(width: 8),
            Text('Screenshot Captured!'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Map screenshot has been saved successfully.'),
            const SizedBox(height: 12),
            Text(
              'Saved to: ${filePath.split('/').last}',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              Navigator.pop(context);
              await Share.shareXFiles(
                [XFile(filePath)],
                text:
                    'Tree Mapping Report - ${DateTime.now().toString().split(' ')[0]}',
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green[700],
              foregroundColor: Colors.white,
            ),
            icon: const Icon(Icons.share),
            label: const Text('Share'),
          ),
        ],
      ),
    );
  }

  /// Show detailed summary report in a scrollable dialog
  Future<void> _showSummaryDetailsDialog() async {
    // Get the current filtered trees
    final trees = await _getTreesStream().first;

    if (!mounted) return;

    if (trees.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No trees to display. Please adjust your filters.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          width: MediaQuery.of(context).size.width * 0.9,
          height: MediaQuery.of(context).size.height * 0.8,
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // Header
              Row(
                children: [
                  Icon(Icons.summarize, color: Colors.green[700], size: 28),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Summary Report Details',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const Divider(height: 24),

              // Summary Info
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildSummaryChip(
                          'Total Trees',
                          trees.length.toString(),
                          Icons.park,
                        ),
                        _buildSummaryChip(
                          'Total Volume',
                          '${trees.fold<double>(0, (sum, tree) => sum + (tree['volume'] ?? 0)).toStringAsFixed(2)} m┬│',
                          Icons.straighten,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Trees Table Header
              Container(
                padding:
                    const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                decoration: BoxDecoration(
                  color: Colors.green[700],
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(8),
                    topRight: Radius.circular(8),
                  ),
                ),
                child: const Row(
                  children: [
                    SizedBox(
                      width: 40,
                      child: Text(
                        '#',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        'Species',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        'Dia.(cm)',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        'Ht.(m)',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        'Vol.(m┬│)',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Trees List
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(8),
                      bottomRight: Radius.circular(8),
                    ),
                  ),
                  child: ListView.separated(
                    itemCount: trees.length,
                    separatorBuilder: (context, index) => Divider(
                      height: 1,
                      color: Colors.grey.shade200,
                    ),
                    itemBuilder: (context, index) {
                      final tree = trees[index];
                      return InkWell(
                        onTap: () => _showTreeDetailsInDialog(tree),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            vertical: 12,
                            horizontal: 12,
                          ),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 40,
                                child: Text(
                                  tree['tree_no']?.toString() ?? 'N/A',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green[700],
                                  ),
                                ),
                              ),
                              Expanded(
                                flex: 2,
                                child: Text(
                                  tree['species'] ?? 'Unknown',
                                  style: const TextStyle(fontSize: 12),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  tree['diameter']?.toString() ?? '0',
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  tree['height']?.toString() ?? '0',
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  (tree['volume'] ?? 0).toStringAsFixed(2),
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // Note
              Text(
                'Tap any row to view full details including GPS coordinates',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey[600],
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Show individual tree details in a dialog
  void _showTreeDetailsInDialog(Map<String, dynamic> tree) {
    final double? latValue = tree['latitude'] is num
        ? (tree['latitude'] as num).toDouble()
        : null;
    final double? lngValue = tree['longitude'] is num
        ? (tree['longitude'] as num).toDouble()
        : null;
    final hasCoordinates = latValue != null &&
        lngValue != null &&
        _isValidLatLng(latValue, lngValue);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.info_outline, color: Colors.green[700], size: 24),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Tree #${tree['tree_no']}',
                style: const TextStyle(fontSize: 18),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDetailItem(
                  'Tree Number', tree['tree_no']?.toString() ?? 'N/A'),
              _buildDetailItem('Species', tree['species'] ?? 'Unknown'),
              _buildDetailItem('Diameter', '${tree['diameter'] ?? 0} cm'),
              _buildDetailItem('Height', '${tree['height'] ?? 0} m'),
              _buildDetailItem(
                  'Volume', '${(tree['volume'] ?? 0).toStringAsFixed(2)} m┬│'),
              _buildDetailItem(
                  'Status', tree['tree_status'] ?? 'Not Yet Ready'),
              if (hasCoordinates) ...[
                const Divider(height: 24),
                const Text(
                  'GPS Location',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 8),
                _buildDetailItem(
                  'Latitude',
                  _formatCoordinate(latValue),
                ),
                _buildDetailItem(
                  'Longitude',
                  _formatCoordinate(lngValue),
                ),
              ],
              if (tree['appointment_location'] != null) ...[
                const Divider(height: 24),
                _buildDetailItem('Appointment', tree['appointment_location']),
              ],
              if (tree['applicant_name'] != null) ...[
                _buildDetailItem('Applicant', tree['applicant_name']),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close', style: TextStyle(color: Colors.green[700])),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryChip(String label, String value, IconData icon) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 20, color: Colors.green[700]),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                color: Colors.grey,
              ),
            ),
            Text(
              value,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.green[700],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDetailItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.green[800],
        title: const Text(
          "Summary Reports",
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.normal,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          if (!_isLoading)
            IconButton(
              icon: const Icon(Icons.list_alt),
              onPressed: _showSummaryDetailsDialog,
              tooltip: 'View Summary Details',
            ),
          if (!_isLoading)
            IconButton(
              icon: _isCapturingScreenshot
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(Icons.camera_alt),
              onPressed: _isCapturingScreenshot ? null : _captureMapScreenshot,
              tooltip: 'Capture Map Screenshot',
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Filter Controls
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.green[50],
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.2),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      // Filter Type Selection
                      Row(
                        children: [
                          Expanded(
                            child: _buildFilterTypeButton('All'),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildFilterTypeButton('Appointment'),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildFilterTypeButton('Applicant'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Conditional Dropdowns
                      if (_filterType == 'Appointment')
                        DropdownButtonFormField<String>(
                          value: _selectedAppointmentId,
                          decoration: InputDecoration(
                            labelText: 'Select Appointment',
                            prefixIcon: const Icon(Icons.location_on),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            filled: true,
                            fillColor: Colors.white,
                          ),
                          items: [
                            const DropdownMenuItem(
                              value: 'All',
                              child: Text('All Appointments'),
                            ),
                            ..._appointments.map((appointment) {
                              return DropdownMenuItem(
                                value: appointment['id'],
                                child: Text(appointment['location']),
                              );
                            }),
                          ],
                          onChanged: (value) {
                            setState(() {
                              _selectedAppointmentId = value!;
                            });
                          },
                        ),

                      if (_filterType == 'Applicant')
                        DropdownButtonFormField<String>(
                          value: _selectedApplicantId,
                          decoration: InputDecoration(
                            labelText: 'Select Applicant',
                            prefixIcon: const Icon(Icons.person),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            filled: true,
                            fillColor: Colors.white,
                          ),
                          items: [
                            const DropdownMenuItem(
                              value: 'All',
                              child: Text('All Applicants'),
                            ),
                            ..._applicants.map((applicant) {
                              return DropdownMenuItem(
                                value: applicant['id'],
                                child: Text(applicant['name']),
                              );
                            }),
                          ],
                          onChanged: (value) {
                            setState(() {
                              _selectedApplicantId = value!;
                            });
                          },
                        ),

                      const SizedBox(height: 12),

                      // Tree Status Filter
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _buildStatusButton('All'),
                            const SizedBox(width: 8),
                            _buildStatusButton('Not Yet Ready'),
                            const SizedBox(width: 8),
                            _buildStatusButton('Ready to Cut'),
                            const SizedBox(width: 8),
                            _buildStatusButton('Cut'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Content Area
                Expanded(
                  child: StreamBuilder<List<Map<String, dynamic>>>(
                    stream: _getTreesStream(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (snapshot.hasError) {
                        return Center(child: Text('Error: ${snapshot.error}'));
                      }
                      if (!snapshot.hasData || snapshot.data!.isEmpty) {
                        return const Center(
                          child: Text(
                            'No trees found with selected filters.',
                            style: TextStyle(fontSize: 16, color: Colors.grey),
                          ),
                        );
                      }

                      final trees = snapshot.data!;
                      final markers = _generateMarkers(trees);

                      // Calculate statistics
                      final totalTrees = trees.length;
                      final totalVolume = trees.fold<double>(
                        0,
                        (sum, tree) => sum + (tree['volume'] ?? 0),
                      );
                      final avgDiameter = trees.isEmpty
                          ? 0.0
                          : trees.fold<double>(
                                0,
                                (sum, tree) => sum + (tree['diameter'] ?? 0),
                              ) /
                              trees.length;
                      final avgHeight = trees.isEmpty
                          ? 0.0
                          : trees.fold<double>(
                                0,
                                (sum, tree) => sum + (tree['height'] ?? 0),
                              ) /
                              trees.length;

                      // Group trees by status for breakdown
                      final statusCounts = <String, int>{};
                      for (var tree in trees) {
                        final status = tree['tree_status'] ?? 'Not Yet Ready';
                        statusCounts[status] = (statusCounts[status] ?? 0) + 1;
                      }

                      // After building markers, fit map
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (markers.isNotEmpty) {
                          _fitMapToMarkers(markers);
                        }
                      });

                      return Column(
                        children: [
                          // Statistics Card
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.green[50],
                              border: Border(
                                bottom: BorderSide(
                                  color: Colors.grey.shade300,
                                  width: 1,
                                ),
                              ),
                            ),
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: _buildStatCard(
                                        'Total Trees',
                                        totalTrees.toString(),
                                        Icons.park,
                                        Colors.green,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: _buildStatCard(
                                        'Total Volume',
                                        '${totalVolume.toStringAsFixed(2)} m┬│',
                                        Icons.straighten,
                                        Colors.blue,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Expanded(
                                      child: _buildStatCard(
                                        'Avg Diameter',
                                        '${avgDiameter.toStringAsFixed(1)} cm',
                                        Icons.circle_outlined,
                                        Colors.orange,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: _buildStatCard(
                                        'Avg Height',
                                        '${avgHeight.toStringAsFixed(1)} m',
                                        Icons.height,
                                        Colors.purple,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                // Status Breakdown
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: statusCounts.entries.map((entry) {
                                    Color statusColor = Colors.grey;
                                    if (entry.key == 'Ready to Cut') {
                                      statusColor = Colors.orange;
                                    } else if (entry.key == 'Cut') {
                                      statusColor = Colors.red;
                                    }

                                    return Chip(
                                      avatar: CircleAvatar(
                                        backgroundColor: statusColor,
                                        child: Text(
                                          entry.value.toString(),
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      label: Text(entry.key),
                                      backgroundColor:
                                          statusColor.withOpacity(0.1),
                                    );
                                  }).toList(),
                                ),
                              ],
                            ),
                          ),

                          // Map View
                          Expanded(
                            child: Stack(
                              children: [
                                RepaintBoundary(
                                  key: _mapRepaintKey,
                                  child: Container(
                                    color: Colors.grey[100],
                                    width: double.infinity,
                                    height: double.infinity,
                                    child: Stack(
                                      children: [
                                        FlutterMap(
                                          mapController: _mapController,
                                          options: MapOptions(
                                            initialCenter:
                                                _getValidInitialCenter(markers),
                                            initialZoom:
                                                markers.isNotEmpty ? 14 : 13,
                                            interactionOptions:
                                                const InteractionOptions(
                                              flags: InteractiveFlag.pinchZoom |
                                                  InteractiveFlag.drag |
                                                  InteractiveFlag
                                                      .flingAnimation |
                                                  InteractiveFlag.doubleTapZoom,
                                            ),
                                          ),
                                          children: [
                                            _getTileLayer(),
                                            if (markers.isNotEmpty)
                                              MarkerLayer(markers: markers),
                                          ],
                                        ),

                                        // Tree Count Badge
                                        Positioned(
                                          top: 16,
                                          left: 16,
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 12,
                                              vertical: 8,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.white,
                                              borderRadius:
                                                  BorderRadius.circular(20),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: Colors.black
                                                      .withOpacity(0.2),
                                                  blurRadius: 6,
                                                  offset: const Offset(0, 2),
                                                ),
                                              ],
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                const Icon(
                                                  Icons.location_pin,
                                                  color: Colors.green,
                                                  size: 20,
                                                ),
                                                const SizedBox(width: 6),
                                                Text(
                                                  '$totalTrees Trees',
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 14,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),

                                        // Report Metadata (bottom) - for screenshot
                                        Positioned(
                                          bottom: 16,
                                          left: 16,
                                          right: 16,
                                          child: Container(
                                            padding: const EdgeInsets.all(12),
                                            decoration: BoxDecoration(
                                              color: Colors.white
                                                  .withOpacity(0.95),
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: Colors.black
                                                      .withOpacity(0.2),
                                                  blurRadius: 6,
                                                  offset: const Offset(0, 2),
                                                ),
                                              ],
                                            ),
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                const Row(
                                                  children: [
                                                    Icon(Icons.eco,
                                                        color: Colors.green,
                                                        size: 20),
                                                    SizedBox(width: 8),
                                                    Text(
                                                      'TreeSure - Forestry Report',
                                                      style: TextStyle(
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        fontSize: 14,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                const SizedBox(height: 8),
                                                Row(
                                                  children: [
                                                    Expanded(
                                                      child: Text(
                                                        'Total: $totalTrees trees | Volume: ${totalVolume.toStringAsFixed(2)} m┬│',
                                                        style: const TextStyle(
                                                            fontSize: 11),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  'Generated: ${DateTime.now().toString().split('.')[0]}',
                                                  style: TextStyle(
                                                    fontSize: 10,
                                                    color: Colors.grey[600],
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),

                                // Map Type Selector (outside screenshot)
                                Positioned(
                                  top: 16,
                                  right: 16,
                                  child: _buildMapTypeSelector(),
                                ),
                              ],
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildFilterTypeButton(String type) {
    final isSelected = _filterType == type;
    return ElevatedButton(
      onPressed: () {
        setState(() {
          _filterType = type;
          _selectedAppointmentId = 'All';
          _selectedApplicantId = 'All';
        });
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: isSelected ? Colors.green[700] : Colors.white,
        foregroundColor: isSelected ? Colors.white : Colors.green[700],
        elevation: isSelected ? 4 : 1,
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      child: Text(
        type,
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildStatusButton(String status) {
    final isSelected = _selectedTreeStatus == status;
    Color statusColor = Colors.grey;
    if (status == 'Ready to Cut') {
      statusColor = Colors.orange;
    } else if (status == 'Cut') {
      statusColor = Colors.red;
    }

    return ElevatedButton(
      onPressed: () {
        setState(() {
          _selectedTreeStatus = status;
        });
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: isSelected ? statusColor : Colors.white,
        foregroundColor: isSelected ? Colors.white : statusColor,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
      child: Text(status),
    );
  }

  Widget _buildStatCard(
      String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

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

  Widget _buildMapTypeButton(String type, IconData icon, String label) {
    final isSelected = _mapType == type;
    return InkWell(
      onTap: () {
        setState(() {
          _mapType = type;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
              size: 18,
              color: isSelected ? Colors.white : Colors.grey[700],
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: isSelected ? Colors.white : Colors.grey[700],
              ),
            ),
          ],
        ),
      ),
    );
  }

}
