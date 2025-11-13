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

  /// Load all tree tagging appointments for this applicant
  Future<void> _loadAppointments() async {
    try {
      final appointmentsSnapshot = await _firestore
          .collection('appointments')
          .where('applicantId', isEqualTo: widget.applicantId)
          .where('appointmentType', isEqualTo: 'Tree Tagging')
          .get();

      final appointments = <Map<String, dynamic>>[];
      for (var doc in appointmentsSnapshot.docs) {
        appointments.add({
          'id': doc.id,
          'location': doc.data()['location'] ?? 'Unknown Location',
          'createdAt': doc.data()['createdAt'],
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
            'species': treeData['species'] ?? 'Unknown',
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
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.green[700],
        title: const Text(
          "Summary Reports",
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.normal,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _appointments.isEmpty
              ? const Center(
                  child: Text(
                    "No tree tagging appointments found.",
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                )
              : Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Applicant Info Header
                      Card(
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Row(
                            children: [
                              const Icon(Icons.person,
                                  color: Colors.green, size: 40),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      widget.applicantName,
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      "ID: ${widget.applicantId}",
                                      style: const TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Appointment Filter Dropdown
                      DropdownButtonFormField<String>(
                        value: _selectedAppointmentId,
                        decoration: InputDecoration(
                          labelText: "Filter by Appointment",
                          prefixIcon: const Icon(Icons.location_on),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
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
                      const SizedBox(height: 12),

                      // Tree Status Filter
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _buildFilterButton('All'),
                            const SizedBox(width: 8),
                            _buildFilterButton('Not Yet Ready'),
                            const SizedBox(width: 8),
                            _buildFilterButton('Ready to Cut'),
                            const SizedBox(width: 8),
                            _buildFilterButton('Cut'),
                            const SizedBox(width: 8),
                            _buildFilterButton('Paid'),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

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
                                : trees.fold<double>(0,
                                        (sum, tree) => sum + (tree['diameter'] ?? 0)) /
                                    trees.length;
                            final avgHeight = trees.isEmpty
                                ? 0.0
                                : trees.fold<double>(
                                        0, (sum, tree) => sum + (tree['height'] ?? 0)) /
                                    trees.length;

                            return Column(
                              children: [
                                // Summary Statistics Card
                                Card(
                                  elevation: 2,
                                  color: Colors.green[50],
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.all(16.0),
                                    child: Column(
                                      children: [
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            _buildStatItem(
                                              "Total Trees",
                                              trees.length.toString(),
                                              Icons.park,
                                            ),
                                            _buildStatItem(
                                              "Total Volume",
                                              "${totalVolume.toStringAsFixed(2)} m³",
                                              Icons.straighten,
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 12),
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            _buildStatItem(
                                              "Avg. Diameter",
                                              "${avgDiameter.toStringAsFixed(1)} cm",
                                              Icons.circle_outlined,
                                            ),
                                            _buildStatItem(
                                              "Avg. Height",
                                              "${avgHeight.toStringAsFixed(1)} m",
                                              Icons.height,
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 12),

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
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
      child: Text(status),
    );
  }

  /// Build statistic item widget
  Widget _buildStatItem(String label, String value, IconData icon) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: Colors.green[700], size: 28),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.green[900],
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

  /// Build tree card widget
  Widget _buildTreeCard(Map<String, dynamic> tree) {
    final status = tree['tree_status'] ?? 'Not Yet Ready';
    Color statusColor = Colors.grey;
    if (status == 'Ready to Cut') {
      statusColor = Colors.orange;
    } else if (status == 'Cut') {
      statusColor = Colors.red;
    } else if (status == 'Paid') {
      statusColor = Colors.green;
    }

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () => _showTreeDetails(tree),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            children: [
              // Tree Icon/Image
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: Colors.green[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: tree['photo_url'] != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          tree['photo_url'],
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return const Icon(Icons.park,
                                size: 32, color: Colors.green);
                          },
                        ),
                      )
                    : const Icon(Icons.park, size: 32, color: Colors.green),
              ),
              const SizedBox(width: 12),

              // Tree Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          "Tree #${tree['tree_no']}",
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: statusColor.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            status,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: statusColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      tree['species'],
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.straighten,
                            size: 14, color: Colors.grey[600]),
                        const SizedBox(width: 4),
                        Text(
                          "Ø${tree['diameter']}cm",
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Icon(Icons.height, size: 14, color: Colors.grey[600]),
                        const SizedBox(width: 4),
                        Text(
                          "${tree['height']}m",
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Icon(Icons.inventory_2,
                            size: 14, color: Colors.grey[600]),
                        const SizedBox(width: 4),
                        Text(
                          "${tree['volume'].toStringAsFixed(2)}m³",
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }

  /// Show detailed tree information dialog
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
                "Tree #${tree['tree_no']}",
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
                        child: const Icon(Icons.park,
                            size: 64, color: Colors.grey),
                      );
                    },
                  ),
                ),
              const SizedBox(height: 16),
              _buildDetailRow("Species", tree['species']),
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
                const SizedBox(height: 12),
                const Text(
                  "QR Code:",
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
            child: const Text("Close", style: TextStyle(color: Colors.green)),
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
              "$label:",
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
