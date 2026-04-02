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

  // Theme colors matching notification page
  static const _primaryGreen = Color(0xFF2E7D32);
  static const _darkGreen = Color(0xFF1B5E20);
  static const _lightGreen = Color(0xFFE8F5E9);
  static const _surfaceColor = Color(0xFFF5F9F5);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _surfaceColor,
      body: SafeArea(
        child: Column(
          children: [
            // Modern gradient header
            Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.green[800]!, Colors.green[600]!],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(28),
                  bottomRight: Radius.circular(28),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.green.withOpacity(0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(
                          Icons.assessment_rounded,
                          color: Colors.white,
                          size: 26,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "Summary Reports",
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              widget.applicantName,
                              style: const TextStyle(
                                fontSize: 13,
                                color: Colors.white70,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (!_isLoading && _appointments.isNotEmpty) ...[
                    const SizedBox(height: 18),
                    // Filter chips
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildFilterChip('All', Icons.all_inbox_rounded),
                          _buildFilterChip('Not Yet Ready', Icons.schedule_rounded),
                          _buildFilterChip('Ready to Cut', Icons.content_cut_rounded),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // Body content
            Expanded(
              child: _isLoading
                  ? Center(
                      child: CircularProgressIndicator(
                        color: _primaryGreen,
                        strokeWidth: 3,
                      ),
                    )
                  : _appointments.isEmpty
                      ? _buildEmptyState(
                          Icons.park_rounded,
                          "No Appointments Found",
                          "No tree tagging appointments available yet.",
                        )
                      : Padding(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                          child: Column(
                            children: [
                              // Appointment Filter Dropdown
                              Container(
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.04),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: DropdownButtonFormField<String>(
                                  value: _selectedAppointmentId,
                                  decoration: InputDecoration(
                                    labelText: "Filter by Appointment",
                                    labelStyle: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey[600],
                                    ),
                                    prefixIcon: Icon(
                                      Icons.event_note_rounded,
                                      color: _primaryGreen,
                                      size: 22,
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(16),
                                      borderSide: BorderSide.none,
                                    ),
                                    filled: true,
                                    fillColor: Colors.white,
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 14,
                                    ),
                                  ),
                                  isExpanded: true,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: Colors.black87,
                                  ),
                                  items: [
                                    const DropdownMenuItem(
                                      value: 'All',
                                      child: Text('All Appointments'),
                                    ),
                                    ..._appointments.map((appointment) {
                                      return DropdownMenuItem(
                                        value: appointment['id'],
                                        child: Text(
                                          '${appointment['displayName']} - ${appointment['applicationID']}',
                                          overflow: TextOverflow.ellipsis,
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
                              ),
                              const SizedBox(height: 14),

                              // Trees List
                              Expanded(
                                child: StreamBuilder<List<Map<String, dynamic>>>(
                                  stream: _getTreesStream(),
                                  builder: (context, snapshot) {
                                    if (snapshot.connectionState ==
                                        ConnectionState.waiting) {
                                      return Center(
                                        child: CircularProgressIndicator(
                                          color: _primaryGreen,
                                          strokeWidth: 3,
                                        ),
                                      );
                                    }
                                    if (snapshot.hasError) {
                                      return Center(
                                        child: Text("Error: ${snapshot.error}"),
                                      );
                                    }
                                    if (!snapshot.hasData ||
                                        snapshot.data!.isEmpty) {
                                      return _buildEmptyState(
                                        Icons.forest_rounded,
                                        "No Trees Found",
                                        "No trees registered yet.",
                                      );
                                    }

                                    var trees = snapshot.data!;
                                    if (_selectedStatus != 'All') {
                                      trees = trees
                                          .where((tree) =>
                                              tree['tree_status'] ==
                                              _selectedStatus)
                                          .toList();
                                    }

                                    if (trees.isEmpty) {
                                      return _buildEmptyState(
                                        Icons.filter_alt_rounded,
                                        "No Results",
                                        "No trees with status '$_selectedStatus' found.",
                                      );
                                    }

                                    final totalVolume = trees.fold<double>(
                                        0,
                                        (sum, tree) =>
                                            sum + (tree['volume'] ?? 0));
                                    final avgDiameter = trees.fold<double>(
                                            0,
                                            (sum, tree) =>
                                                sum +
                                                (tree['diameter'] ?? 0)) /
                                        trees.length;
                                    final avgHeight = trees.fold<double>(
                                            0,
                                            (sum, tree) =>
                                                sum + (tree['height'] ?? 0)) /
                                        trees.length;

                                    return Column(
                                      children: [
                                        // Stats row
                                        _buildStatsRow(
                                          trees.length,
                                          totalVolume,
                                          avgDiameter,
                                          avgHeight,
                                        ),
                                        const SizedBox(height: 14),
                                        Expanded(
                                          child: ListView.builder(
                                            itemCount: trees.length,
                                            itemBuilder: (context, index) {
                                              return _buildTreeCard(
                                                  trees[index]);
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
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(IconData icon, String title, String subtitle) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: _lightGreen,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 48, color: _primaryGreen),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF37474F),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsRow(
      int count, double volume, double avgDiameter, double avgHeight) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: IntrinsicHeight(
        child: Row(
          children: [
            _buildStatItem("Trees", "$count", Icons.park_rounded, _primaryGreen),
            const SizedBox(width: 8),
            _buildStatItem("Volume", "${volume.toStringAsFixed(1)} m³",
                Icons.inventory_2_rounded, Colors.blue[700]!),
            const SizedBox(width: 8),
            _buildStatItem("Avg Ø", "${avgDiameter.toStringAsFixed(1)} cm",
                Icons.circle_outlined, Colors.orange[700]!),
            const SizedBox(width: 8),
            _buildStatItem("Avg H", "${avgHeight.toStringAsFixed(1)} m",
                Icons.height_rounded, Colors.purple[600]!),
          ],
        ),
      ),
    );
  }

  /// Build filter chip for header (matching notif page style)
  Widget _buildFilterChip(String label, IconData icon) {
    final isSelected = _selectedStatus == label;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Material(
        color: isSelected ? Colors.white : Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () {
            setState(() {
              _selectedStatus = label;
            });
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: 16,
                  color: isSelected ? _darkGreen : Colors.white,
                ),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isSelected ? _darkGreen : Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Build statistic item widget
  Widget _buildStatItem(
      String label, String value, IconData icon, Color color) {
    return Container(
        width: 85,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 22),
          const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 14,
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
                fontSize: 11,
                color: Colors.grey[500],
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
    final status = tree['tree_status'] ?? 'Not Yet Ready';
    Color statusColor = _primaryGreen;
    if (status == 'Ready to Cut') {
      statusColor = Colors.orange[700]!;
    } else if (status == 'Cut') {
      statusColor = Colors.red[700]!;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: () => _showTreeDetails(tree),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                // Tree Icon/Image
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: tree['photo_url'] != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: Image.network(
                            tree['photo_url'],
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Icon(Icons.park_rounded,
                                  size: 28, color: statusColor);
                            },
                          ),
                        )
                      : Icon(Icons.park_rounded, size: 28, color: statusColor),
                ),
                const SizedBox(width: 12),

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
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF263238),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: statusColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              status,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: statusColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        tree['specie'],
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[500],
                          fontStyle: FontStyle.italic,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 12,
                        runSpacing: 4,
                        children: [
                          _buildMiniStat(Icons.straighten_rounded,
                              "Ø${tree['diameter']}cm"),
                          _buildMiniStat(Icons.height_rounded,
                              "${tree['height']}m"),
                          _buildMiniStat(Icons.inventory_2_rounded,
                              "${tree['volume'].toStringAsFixed(1)}m³"),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(Icons.chevron_right_rounded,
                    size: 22, color: Colors.grey[300]),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMiniStat(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: Colors.grey[400]),
        const SizedBox(width: 3),
        Text(
          text,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  /// Show detailed tree information in bottom sheet
  void _showTreeDetails(Map<String, dynamic> tree) {
    final status = tree['tree_status'] ?? 'Not Yet Ready';
    Color statusColor = _primaryGreen;
    if (status == 'Ready to Cut') statusColor = Colors.orange[700]!;
    if (status == 'Cut') statusColor = Colors.red[700]!;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.4,
        maxChildSize: 0.92,
        builder: (context, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // Drag handle
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(Icons.park_rounded,
                          color: statusColor, size: 24),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Tree #${tree['tree_no']}",
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 3),
                            decoration: BoxDecoration(
                              color: statusColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              status,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: statusColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                  children: [
                    if (tree['photo_url'] != null)
                      Container(
                        height: 220,
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Image.network(
                            tree['photo_url'],
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                color: _lightGreen,
                                child: const Icon(Icons.park_rounded,
                                    size: 64, color: _primaryGreen),
                              );
                            },
                          ),
                        ),
                      ),
                    _buildDetailRow(
                        Icons.eco_rounded, "Species", tree['specie']),
                    _buildDetailRow(
                        Icons.straighten_rounded, "Diameter", "${tree['diameter']} cm"),
                    _buildDetailRow(
                        Icons.height_rounded, "Height", "${tree['height']} m"),
                    _buildDetailRow(Icons.inventory_2_rounded, "Volume",
                        "${tree['volume'].toStringAsFixed(2)} m³"),
                    _buildDetailRow(
                        Icons.location_on_rounded, "Location", tree['location'] ?? 'N/A'),
                    if (tree['latitude'] != null && tree['longitude'] != null)
                      _buildDetailRow(
                        Icons.gps_fixed_rounded,
                        "Coordinates",
                        "${tree['latitude'].toStringAsFixed(6)}, ${tree['longitude'].toStringAsFixed(6)}",
                      ),
                    if (tree['qr_url'] != null) ...[
                      const SizedBox(height: 12),
                      const Text(
                        "QR Code",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Center(
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: _lightGreen,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Image.network(
                            tree['qr_url'],
                            height: 150,
                            width: 150,
                            errorBuilder: (context, error, stackTrace) {
                              return const Icon(Icons.qr_code_rounded,
                                  size: 64, color: _primaryGreen);
                            },
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _primaryGreen,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          elevation: 0,
                        ),
                        child: const Text(
                          "Done",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
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
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _lightGreen,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: _primaryGreen),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[500],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF263238),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
