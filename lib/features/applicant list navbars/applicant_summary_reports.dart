import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ApplicantSummaryPage extends StatefulWidget {
  final String applicantId;
  final String applicantName;
  const ApplicantSummaryPage({
    super.key,
    required this.applicantId,
    required this.applicantName,
  });

  @override
  State<ApplicantSummaryPage> createState() => _ApplicantSummaryPageState();
}

class _ApplicantSummaryPageState extends State<ApplicantSummaryPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String _selectedStatus = 'All'; // Filter state
  String _selectedAppointmentId = 'All'; // Appointment filter
  List<Map<String, dynamic>> _appointments = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAppointments();
  }

  /// Load all tree tagging appointments for this applicant (excluding revisits)
  Future<void> _loadAppointments() async {
    try {
      final appointmentsSnapshot = await _firestore
          .collection('appointments')
          .where('applicantId', isEqualTo: widget.applicantId)
          .where('appointmentType', isEqualTo: 'Tree Tagging')
          .get();

      final appointments = <Map<String, dynamic>>[];
      for (var doc in appointmentsSnapshot.docs) {
        final data = doc.data();
        final appointmentType = data['appointmentType'] ?? 'Tree Tagging';
        final applicationType = data['applicationType'] ?? '';

        // Build display name: "CTPO Tree Tagging", "PLTP Tree Tagging", etc.
        String displayName = appointmentType;
        if (applicationType.isNotEmpty) {
          final appTypeUpper = applicationType.toUpperCase();
          displayName = '$appTypeUpper $appointmentType';
        }

        appointments.add({
          'id': doc.id,
          'location': data['location'] ?? 'Unknown Location',
          'applicationID': data['applicationID'] ?? 'N/A',
          'applicationType': applicationType,
          'displayName': displayName,
          'createdAt': data['createdAt'],
        });
      }

      setState(() {
        _appointments = appointments;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading appointments: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// Stream all trees from selected appointment(s)
  Stream<List<Map<String, dynamic>>> _getTreesStream() {
    if (_appointments.isEmpty) {
      return Stream.value([]);
    }

    // If "All" is selected, get trees from all appointments
    final appointmentIds = _selectedAppointmentId == 'All'
        ? _appointments.map((a) => a['id'] as String).toList()
        : [_selectedAppointmentId];

    return Stream.fromFuture(() async {
      final allTrees = <Map<String, dynamic>>[];

      for (var appointmentId in appointmentIds) {
        final treesSnapshot = await _firestore
            .collection('appointments')
            .doc(appointmentId)
            .collection('tree_inventory')
            .get();

        for (var treeDoc in treesSnapshot.docs) {
          final treeData = treeDoc.data();
          allTrees.add({
            'id': treeDoc.id,
            'tree_no': treeData['tree_no'] ?? 'N/A',
            'specie': treeData['specie'] ?? 'Unknown',
            'diameter': treeData['diameter'] ?? 0,
            'height': treeData['height'] ?? 0,
            'volume': treeData['volume'] ?? 0,
            'tree_status': treeData['tree_status'] ?? 'Not Yet Ready',
            'latitude': treeData['latitude'],
            'longitude': treeData['longitude'],
            'appointment_id': appointmentId,
            'location': _appointments
                .firstWhere((a) => a['id'] == appointmentId)['location'],
            'photo_url': treeData['photo_url'],
            'qr_url': treeData['qr_url'],
          });
        }
      }

      return allTrees;
    }());
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final screenWidth = screenSize.width;
    final screenHeight = screenSize.height;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.green[700],
        title: Text(
          "Summary Reports",
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.normal,
            fontSize: screenWidth * 0.045,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _appointments.isEmpty
              ? Center(
                  child: Padding(
                    padding: EdgeInsets.all(screenWidth * 0.05),
                    child: Text(
                      "No tree tagging appointments found.",
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: screenWidth * 0.04, color: Colors.grey),
                    ),
                  ),
                )
              : Padding(
                  padding: EdgeInsets.all(screenWidth * 0.04),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Applicant Info Header
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Colors.green[600]!, Colors.green[400]!],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.green.withOpacity(0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Padding(
                          padding: EdgeInsets.all(screenWidth * 0.04),
                          child: Row(
                            children: [
                              Container(
                                padding: EdgeInsets.all(screenWidth * 0.025),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.3),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(Icons.person,
                                    color: Colors.white, size: screenWidth * 0.08),
                              ),
                              SizedBox(width: screenWidth * 0.03),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      widget.applicantName,
                                      style: TextStyle(
                                        fontSize: screenWidth * 0.045,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    SizedBox(height: screenHeight * 0.005),
                                    Container(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: screenWidth * 0.02,
                                        vertical: screenHeight * 0.005,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.3),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        "ID: ${widget.applicantId}",
                                        style: TextStyle(
                                          fontSize: screenWidth * 0.03,
                                          color: Colors.white,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      SizedBox(height: screenHeight * 0.02),

                      // Appointment Filter Dropdown
                      DropdownButtonFormField<String>(
                        value: _selectedAppointmentId,
                        decoration: InputDecoration(
                          labelText: "Filter by Appointment",
                          labelStyle: TextStyle(fontSize: screenWidth * 0.035),
                          prefixIcon: Icon(Icons.event_note, size: screenWidth * 0.05),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: screenWidth * 0.03,
                            vertical: screenHeight * 0.01,
                          ),
                        ),
                        isExpanded: true,
                        style: TextStyle(fontSize: screenWidth * 0.035, color: Colors.black),
                        items: [
                          DropdownMenuItem(
                            value: 'All',
                            child: Text('All Appointments', style: TextStyle(fontSize: screenWidth * 0.035)),
                          ),
                          ..._appointments.map((appointment) {
                            return DropdownMenuItem(
                              value: appointment['id'],
                              child: Text(
                                '${appointment['displayName']} - ${appointment['applicationID']}',
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontSize: screenWidth * 0.035),
                              ),
                            );
                          }),
                        ],
                        onChanged: (value) {
                          setState(() {
                            _selectedAppointmentId = value!;
                          });
                        },
                      ),
                      SizedBox(height: screenHeight * 0.015),

                      // Tree Status Filter
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _buildFilterButton('All'),
                            SizedBox(width: screenWidth * 0.02),
                            _buildFilterButton('Not Yet Ready'),
                            SizedBox(width: screenWidth * 0.02),
                            _buildFilterButton('Ready to Cut'),
                            SizedBox(width: screenWidth * 0.02),
                          ],
                        ),
                      ),
                      SizedBox(height: screenHeight * 0.02),

                      // Trees List
                      Expanded(
                        child: StreamBuilder<List<Map<String, dynamic>>>(
                          stream: _getTreesStream(),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState ==
                                ConnectionState.waiting) {
                              return const Center(
                                  child: CircularProgressIndicator());
                            }
                            if (snapshot.hasError) {
                              return Center(
                                child: Text("Error: ${snapshot.error}"),
                              );
                            }
                            if (!snapshot.hasData || snapshot.data!.isEmpty) {
                              return const Center(
                                child: Text(
                                  "No trees found.",
                                  style: TextStyle(
                                      fontSize: 16, color: Colors.grey),
                                ),
                              );
                            }

                            var trees = snapshot.data!;

                            // Filter by tree status
                            if (_selectedStatus != 'All') {
                              trees = trees
                                  .where((tree) =>
                                      tree['tree_status'] == _selectedStatus)
                                  .toList();
                            }

                            if (trees.isEmpty) {
                              return Center(
                                child: Text(
                                  "No trees with status '$_selectedStatus' found.",
                                  style: const TextStyle(
                                      fontSize: 16, color: Colors.grey),
                                ),
                              );
                            }

                            // Calculate summary statistics
                            final totalVolume = trees.fold<double>(
                                0, (sum, tree) => sum + (tree['volume'] ?? 0));
                            final avgDiameter = trees.isEmpty
                                ? 0.0
                                : trees.fold<double>(
                                        0,
                                        (sum, tree) =>
                                            sum + (tree['diameter'] ?? 0)) /
                                    trees.length;
                            final avgHeight = trees.isEmpty
                                ? 0.0
                                : trees.fold<double>(
                                        0,
                                        (sum, tree) =>
                                            sum + (tree['height'] ?? 0)) /
                                    trees.length;

                            return Column(
                              children: [
                                // Summary Statistics Card
                                Container(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        Colors.green[50]!,
                                        Colors.green[100]!
                                      ],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: Colors.green.withOpacity(0.3),
                                      width: 1.5,
                                    ),
                                  ),
                                  child: Padding(
                                    padding: EdgeInsets.all(screenWidth * 0.03),
                                    child: Column(
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: _buildStatItem(
                                                "Trees",
                                                "${trees.length}",
                                                Icons.park,
                                                Colors.green,
                                              ),
                                            ),
                                            SizedBox(width: screenWidth * 0.02),
                                            Expanded(
                                              child: _buildStatItem(
                                                "Volume",
                                                "${totalVolume.toStringAsFixed(1)} m³",
                                                Icons.inventory_2,
                                                Colors.blue,
                                              ),
                                            ),
                                          ],
                                        ),
                                        SizedBox(height: screenHeight * 0.01),
                                        Row(
                                          children: [
                                            Expanded(
                                              child: _buildStatItem(
                                                "Avg Ø",
                                                "${avgDiameter.toStringAsFixed(1)} cm",
                                                Icons.circle_outlined,
                                                Colors.orange,
                                              ),
                                            ),
                                            SizedBox(width: screenWidth * 0.02),
                                            Expanded(
                                              child: _buildStatItem(
                                                "Avg H",
                                                "${avgHeight.toStringAsFixed(1)} m",
                                                Icons.height,
                                                Colors.purple,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                SizedBox(height: screenHeight * 0.015),

                                // Trees List
                                Expanded(
                                  child: ListView.builder(
                                    itemCount: trees.length,
                                    itemBuilder: (context, index) {
                                      final tree = trees[index];
                                      return _buildTreeCard(tree);
                                    },
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }

  /// Build filter button for tree status
  Widget _buildFilterButton(String status) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final isSelected = _selectedStatus == status;
    
    return ElevatedButton(
      onPressed: () {
        setState(() {
          _selectedStatus = status;
        });
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: isSelected ? Colors.green[800] : Colors.green[100],
        foregroundColor: isSelected ? Colors.white : Colors.green[800],
        padding: EdgeInsets.symmetric(
          horizontal: screenWidth * 0.04, 
          vertical: screenHeight * 0.01
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
      child: Text(status, style: TextStyle(fontSize: screenWidth * 0.032)),
    );
  }

  /// Build statistic item widget
  Widget _buildStatItem(
      String label, String value, IconData icon, Color color) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: screenWidth * 0.02, 
        vertical: screenHeight * 0.012
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: color.withOpacity(0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.15),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: screenWidth * 0.055),
          SizedBox(height: screenHeight * 0.005),
          Text(
            value,
            style: TextStyle(
              fontSize: screenWidth * 0.035,
              fontWeight: FontWeight.bold,
              color: color,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: screenWidth * 0.022,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  /// Build tree card widget
  Widget _buildTreeCard(Map<String, dynamic> tree) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final status = tree['tree_status'] ?? 'Not Yet Ready';
    Color statusColor = Colors.grey;
    if (status == 'Ready to Cut') {
      statusColor = Colors.orange;
    } else if (status == 'Cut') {
      statusColor = Colors.red;
    }

    return Card(
      elevation: 2,
      margin: EdgeInsets.only(bottom: screenHeight * 0.012),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: statusColor.withOpacity(0.3),
          width: 1.5,
        ),
      ),
      child: InkWell(
        onTap: () => _showTreeDetails(tree),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: EdgeInsets.all(screenWidth * 0.025),
          child: Row(
            children: [
              // Tree Icon/Image
              Container(
                width: screenWidth * 0.14,
                height: screenWidth * 0.14,
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: statusColor.withOpacity(0.3),
                    width: 1.5,
                  ),
                ),
                child: tree['photo_url'] != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          tree['photo_url'],
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Icon(Icons.park,
                                size: screenWidth * 0.08, color: Colors.green);
                          },
                        ),
                      )
                    : Icon(Icons.park, size: screenWidth * 0.08, color: Colors.green),
              ),
              SizedBox(width: screenWidth * 0.03),

              // Tree Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            "Tree #${tree['tree_no']}",
                            style: TextStyle(
                              fontSize: screenWidth * 0.04,
                              fontWeight: FontWeight.bold,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: screenWidth * 0.02,
                            vertical: screenHeight * 0.005,
                          ),
                          decoration: BoxDecoration(
                            color: statusColor.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            status,
                            style: TextStyle(
                              fontSize: screenWidth * 0.025,
                              fontWeight: FontWeight.bold,
                              color: statusColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: screenHeight * 0.005),
                    Text(
                      tree['specie'],
                      style: TextStyle(
                        fontSize: screenWidth * 0.035,
                        color: Colors.grey[600],
                        fontStyle: FontStyle.italic,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: screenHeight * 0.008),
                    Wrap(
                      spacing: screenWidth * 0.025,
                      runSpacing: screenHeight * 0.005,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.straighten,
                                size: screenWidth * 0.032, color: Colors.grey[600]),
                            SizedBox(width: screenWidth * 0.008),
                            Text(
                              "Ø${tree['diameter']}cm",
                              style: TextStyle(
                                fontSize: screenWidth * 0.028,
                                color: Colors.grey[700],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.height,
                                size: screenWidth * 0.032, color: Colors.grey[600]),
                            SizedBox(width: screenWidth * 0.008),
                            Text(
                              "${tree['height']}m",
                              style: TextStyle(
                                fontSize: screenWidth * 0.028,
                                color: Colors.grey[700],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.inventory_2,
                                size: screenWidth * 0.032, color: Colors.grey[600]),
                            SizedBox(width: screenWidth * 0.008),
                            Text(
                              "${tree['volume'].toStringAsFixed(1)}m³",
                              style: TextStyle(
                                fontSize: screenWidth * 0.028,
                                color: Colors.grey[700],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios, size: screenWidth * 0.04, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }

  /// Show detailed tree information dialog
  void _showTreeDetails(Map<String, dynamic> tree) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.park, color: Colors.green, size: screenWidth * 0.07),
            SizedBox(width: screenWidth * 0.02),
            Expanded(
              child: Text(
                "Tree #${tree['tree_no']}",
                style: TextStyle(fontSize: screenWidth * 0.045),
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
                SizedBox(
                  height: screenHeight * 0.5,
                  width: double.infinity,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      tree['photo_url'],
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          color: Colors.grey[200],
                          child: Icon(Icons.park,
                              size: screenWidth * 0.16, color: Colors.grey),
                        );
                      },
                    ),
                  ),
                ),
              SizedBox(height: screenHeight * 0.02),
              _buildDetailRow("Specie", tree['specie']),
              _buildDetailRow("Status", tree['tree_status']),
              _buildDetailRow("Location", tree['location']),
              _buildDetailRow("Diameter", "${tree['diameter']} cm"),
              _buildDetailRow("Height", "${tree['height']} m"),
              _buildDetailRow(
                  "Volume", "${tree['volume'].toStringAsFixed(2)} m³"),
              if (tree['latitude'] != null && tree['longitude'] != null)
                _buildDetailRow(
                  "Coordinates",
                  "${tree['latitude'].toStringAsFixed(6)}, ${tree['longitude'].toStringAsFixed(6)}",
                ),
              if (tree['qr_url'] != null) ...[
                SizedBox(height: screenHeight * 0.015),
                Text(
                  "QR Code:",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: screenWidth * 0.035,
                  ),
                ),
                SizedBox(height: screenHeight * 0.01),
                Center(
                  child: Image.network(
                    tree['qr_url'],
                    height: screenWidth * 0.4,
                    width: screenWidth * 0.4,
                    errorBuilder: (context, error, stackTrace) {
                      return Icon(Icons.qr_code, size: screenWidth * 0.16);
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
            child: Text("Close", 
              style: TextStyle(
                color: Colors.green, 
                fontSize: screenWidth * 0.04
              )),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    
    return Padding(
      padding: EdgeInsets.only(bottom: screenHeight * 0.01),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: screenWidth * 0.25,
            child: Text(
              "$label:",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: screenWidth * 0.035,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(fontSize: screenWidth * 0.035),
            ),
          ),
        ],
      ),
    );
  }
}
