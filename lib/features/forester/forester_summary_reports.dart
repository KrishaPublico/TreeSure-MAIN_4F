import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:screenshot/screenshot.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:permission_handler/permission_handler.dart';

class ForesterSummaryReports extends StatefulWidget {
  final String foresterId;
  
  const ForesterSummaryReports({super.key, required this.foresterId});

  @override
  State<ForesterSummaryReports> createState() => _ForesterSummaryReportsState();
}

class _ForesterSummaryReportsState extends State<ForesterSummaryReports> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final MapController _mapController = MapController();
  final ScreenshotController _screenshotController = ScreenshotController();
  
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
              applicantName = data?['applicantName'] ?? data?['name'] ?? applicantId;
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
    final allTrees = <Map<String, dynamic>>[];

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
        final treesSnapshot = await _firestore
            .collection('appointments')
            .doc(appointment['id'])
            .collection('tree_inventory')
            .get();

        for (var treeDoc in treesSnapshot.docs) {
          final treeData = treeDoc.data();
          allTrees.add({
            'id': treeDoc.id,
            'tree_no': treeData['tree_no'] ?? 'N/A',
            'species': treeData['species'] ?? treeData['specie'] ?? 'Unknown',
            'diameter': treeData['diameter'] ?? 0,
            'height': treeData['height'] ?? 0,
            'volume': treeData['volume'] ?? 0,
            'tree_status': treeData['tree_status'] ?? 'Not Yet Ready',
            'latitude': treeData['latitude'],
            'longitude': treeData['longitude'],
            'photo_url': treeData['photo_url'],
            'qr_url': treeData['qr_url'],
            'appointment_id': appointment['id'],
            'appointment_location': appointment['location'],
            'appointment_type': appointment['appointmentType'],
            'applicant_id': appointment['applicantId'],
            'applicant_name': _applicants
                .firstWhere(
                  (a) => a['id'] == appointment['applicantId'],
                  orElse: () => {'name': 'Unknown'},
                )['name'],
          });
        }
      }

      // Filter by tree status
      if (_selectedTreeStatus != 'All') {
        yield allTrees
            .where((tree) => tree['tree_status'] == _selectedTreeStatus)
            .toList();
      } else {
        yield allTrees;
      }
    } catch (e) {
      print('Error loading trees: $e');
      yield [];
    }
  }

  /// Generate map markers from trees
  List<Marker> _generateMarkers(List<Map<String, dynamic>> trees) {
    return trees.where((tree) {
      final lat = tree['latitude'];
      final lng = tree['longitude'];
      return lat != null && lng != null;
    }).map((tree) {
      final lat = (tree['latitude'] as num).toDouble();
      final lng = (tree['longitude'] as num).toDouble();
      
      Color markerColor = Colors.green;
      final status = tree['tree_status'] ?? 'Not Yet Ready';
      if (status == 'Ready to Cut') {
        markerColor = Colors.orange;
      } else if (status == 'Cut') {
        markerColor = Colors.red;
      } else if (status == 'Paid') {
        markerColor = Colors.blue;
      }

      return Marker(
        point: LatLng(lat, lng),
        width: 40,
        height: 40,
        alignment: Alignment.center,
        child: GestureDetector(
          onTap: () => _showTreeDetails(tree),
          child: Icon(
            Icons.location_pin,
            color: markerColor,
            size: 40,
            shadows: const [
              Shadow(blurRadius: 3, color: Colors.black45),
            ],
          ),
        ),
      );
    }).toList();
  }

  /// Fit map to show all markers
  void _fitMapToMarkers(List<Marker> markers) {
    if (markers.isEmpty) return;
    
    try {
      if (markers.length == 1) {
        _mapController.move(markers.first.point, 15);
        return;
      }

      final bounds = LatLngBounds.fromPoints(
        markers.map((m) => m.point).toList(),
      );
      
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

  /// Get tile layer based on map type
  TileLayer _getTileLayer() {
    switch (_mapType) {
      case 'satellite':
        return TileLayer(
          urlTemplate: 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}',
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
    setState(() {
      _isCapturingScreenshot = true;
    });

    try {
      // Request storage permission for Android
      if (Platform.isAndroid) {
        var status = await Permission.storage.status;
        if (!status.isGranted) {
          status = await Permission.storage.request();
          if (!status.isGranted) {
            throw Exception('Storage permission denied');
          }
        }
      }

      // Capture the screenshot
      final imageFile = await _screenshotController.capture();
      
      if (imageFile == null) {
        throw Exception('Failed to capture screenshot');
      }

      // Get the documents directory
      final directory = await getApplicationDocumentsDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'tree_map_report_$timestamp.png';
      final filePath = '${directory.path}/$fileName';
      
      // Save the file
      final file = File(filePath);
      await file.writeAsBytes(imageFile);

      setState(() {
        _isCapturingScreenshot = false;
      });

      // Show success dialog with options
      if (mounted) {
        _showScreenshotSuccessDialog(filePath);
      }
    } catch (e) {
      setState(() {
        _isCapturingScreenshot = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error capturing screenshot: $e'),
            backgroundColor: Colors.red,
          ),
        );
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
                text: 'Tree Mapping Report - ${DateTime.now().toString().split(' ')[0]}',
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
                            const SizedBox(width: 8),
                            _buildStatusButton('Paid'),
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
                                        '${totalVolume.toStringAsFixed(2)} m³',
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
                                    } else if (entry.key == 'Paid') {
                                      statusColor = Colors.green;
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
                                      backgroundColor: statusColor.withOpacity(0.1),
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
                                Screenshot(
                                  controller: _screenshotController,
                                  child: Stack(
                                    children: [
                                      FlutterMap(
                                        mapController: _mapController,
                                        options: MapOptions(
                                          initialCenter: markers.isEmpty
                                              ? const LatLng(8.4542, 124.6319) // Cagayan de Oro
                                              : markers.first.point,
                                          initialZoom: 13,
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
                                            borderRadius: BorderRadius.circular(20),
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.black.withOpacity(0.2),
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
                                            color: Colors.white.withOpacity(0.95),
                                            borderRadius: BorderRadius.circular(12),
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.black.withOpacity(0.2),
                                                blurRadius: 6,
                                                offset: const Offset(0, 2),
                                              ),
                                            ],
                                          ),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const Row(
                                                children: [
                                                  Icon(Icons.eco, color: Colors.green, size: 20),
                                                  SizedBox(width: 8),
                                                  Text(
                                                    'TreeSure - Forestry Report',
                                                    style: TextStyle(
                                                      fontWeight: FontWeight.bold,
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
                                                      'Total: $totalTrees trees | Volume: ${totalVolume.toStringAsFixed(2)} m³',
                                                      style: const TextStyle(fontSize: 11),
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
      floatingActionButton: !_isLoading
          ? FloatingActionButton.extended(
              onPressed: _isCapturingScreenshot ? null : _captureMapScreenshot,
              backgroundColor: Colors.green[700],
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
              label: Text(
                _isCapturingScreenshot ? 'Capturing...' : 'Capture Map',
                style: const TextStyle(color: Colors.white),
              ),
            )
          : null,
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
    } else if (status == 'Paid') {
      statusColor = Colors.green;
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

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
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

  void _showTreeDetails(Map<String, dynamic> tree) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.park, color: Colors.green, size: 28),
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
              if (tree['photo_url'] != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    tree['photo_url'],
                    height: 200,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        height: 200,
                        color: Colors.grey[200],
                        child: const Icon(Icons.park, size: 64, color: Colors.grey),
                      );
                    },
                  ),
                ),
              const SizedBox(height: 16),
              _buildDetailRow('Species', tree['species']),
              _buildDetailRow('Status', tree['tree_status']),
              _buildDetailRow('Applicant', tree['applicant_name']),
              _buildDetailRow('Appointment', tree['appointment_location']),
              _buildDetailRow('Diameter', '${tree['diameter']} cm'),
              _buildDetailRow('Height', '${tree['height']} m'),
              _buildDetailRow('Volume', '${tree['volume'].toStringAsFixed(2)} m³'),
              if (tree['latitude'] != null && tree['longitude'] != null)
                _buildDetailRow(
                  'Coordinates',
                  '${tree['latitude'].toStringAsFixed(6)}, ${tree['longitude'].toStringAsFixed(6)}',
                ),
              if (tree['qr_url'] != null) ...[
                const SizedBox(height: 12),
                const Text(
                  'QR Code:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Center(
                  child: Image.network(
                    tree['qr_url'],
                    height: 150,
                    width: 150,
                    errorBuilder: (context, error, stackTrace) {
                      return const Icon(Icons.qr_code, size: 64);
                    },
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close', style: TextStyle(color: Colors.green)),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}
