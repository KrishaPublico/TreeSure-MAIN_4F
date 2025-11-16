import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'ctpo_register_trees.dart';
import 'pltp_register_trees.dart';
import 'spltp_register_trees.dart';

class ApplicantDetailPage extends StatefulWidget {
  final String foresterId; // comes from login
  final String foresterName; // comes from login
  final String applicantName;
  final String requirementDetails;
  final String appointmentId; // ✅ appointment document ID
  final String applicationType;

  const ApplicantDetailPage({
    super.key,
    required this.applicantName,
    required this.requirementDetails,
    required this.foresterId,
    required this.foresterName,
    required this.appointmentId,
    required this.applicationType,
  });

  @override
  State<ApplicantDetailPage> createState() => _ApplicantDetailPageState();
}

class _ApplicantDetailPageState extends State<ApplicantDetailPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// ✅ Fetch appointment details from Firestore
  Future<Map<String, dynamic>?> _getAppointmentDetails() async {
    try {
      final doc = await _firestore
          .collection('appointments')
          .doc(widget.appointmentId)
          .get();
      return doc.data();
    } catch (e) {
      print('Error fetching appointment: $e');
      return null;
    }
  }

  /// ✅ Format Timestamp to readable string
  String _formatTimestamp(dynamic timestamp) {
    if (timestamp == null) return 'N/A';
    try {
      if (timestamp is Timestamp) {
        return timestamp.toDate().toString().split('.')[0];
      }
      return timestamp.toString();
    } catch (e) {
      return 'N/A';
    }
  }

  /// ✅ Fetch forester names from users collection by their IDs
  Future<String> _getForesterNames(List<dynamic>? foresterIds) async {
    if (foresterIds == null || foresterIds.isEmpty) {
      return 'No foresters assigned';
    }
    try {
      final names = <String>[];
      for (final id in foresterIds) {
        final doc =
            await _firestore.collection('users').doc(id as String).get();
        final name = doc.data()?['name'] as String? ?? 'Unknown';
        names.add(name);
      }
      return names.join(', ');
    } catch (e) {
      return 'Error loading foresters';
    }
  }

  /// ✅ Build info card widget
  Widget _buildInfoCard(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey[300]!, width: 1),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              flex: 2,
              child: Text(
                label,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                  fontSize: 14,
                ),
              ),
            ),
            Expanded(
              flex: 3,
              child: Text(
                value,
                style: const TextStyle(
                  color: Colors.black54,
                  fontSize: 14,
                ),
                textAlign: TextAlign.right,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// ✅ Get button label based on applicationType
  String _getButtonLabel() {
    final appType = widget.applicationType.toLowerCase();
    if (appType == 'pltp') {
      return 'Proceed to PLTP Inventory';
    } else if (appType == 'splt') {
      return 'Proceed to SPLTP Inventory';
    }
    return 'Proceed to Tree Inventory';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Appointment Details',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.green,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: FutureBuilder<Map<String, dynamic>?>(
        future: _getAppointmentDetails(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Colors.green),
            );
          }

          if (!snapshot.hasData || snapshot.data == null) {
            return const Center(
              child: Text('Failed to load appointment details'),
            );
          }

          final appointment = snapshot.data!;
          final appointmentType = appointment['appointmentType'] ?? 'N/A';
          final location = appointment['location'] ?? 'N/A';
          final status = appointment['status'] ?? 'Pending';
          final createdAt = _formatTimestamp(appointment['createdAt']);
          final remarks = appointment['remarks'] ?? 'No remarks';
          final completedAt = _formatTimestamp(appointment['completedAt']);
          final foresterIdsList = appointment['foresterIds'] as List<dynamic>?;
          final treeCount = appointment['treeCount'] ?? 0;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ✅ Header Section
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.green[600]!, Colors.green[400]!],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.applicantName,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white24,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          status,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // ✅ Appointment Information Section
                const Text(
                  'Appointment Information',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 12),
                _buildInfoCard('Type', appointmentType),
                _buildInfoCard('Location', location),
                _buildInfoCard('Created At', createdAt),
                _buildInfoCard('Completed At', completedAt),

                const SizedBox(height: 20),

                // ✅ Additional Details Section
                const Text(
                  'Additional Details',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 12),
                FutureBuilder<String>(
                  future: _getForesterNames(foresterIdsList),
                  builder: (context, nameSnapshot) {
                    final foresterNames = nameSnapshot.data ?? 'Loading...';
                    return _buildInfoCard('Assigned Foresters', foresterNames);
                  },
                ),
                _buildInfoCard('Trees Tagged', treeCount.toString()),

                const SizedBox(height: 20),

                // ✅ Remarks Section
                const Text(
                  'Remarks',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue[300]!, width: 1),
                  ),
                  child: Text(
                    remarks,
                    style: const TextStyle(
                      color: Colors.black54,
                      fontSize: 14,
                      height: 1.5,
                    ),
                  ),
                ),

                const SizedBox(height: 30),

                // ✅ Proceed Button - Routes to PLTP, SPLTP or CTPO based on permitType
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: status == 'Completed'
                        ? null
                        : () {
                            // Route based on applicationType from appointment
                            final appType = widget.applicationType.toLowerCase();

                            late Widget targetPage;

                            if (appType == 'pltp') {
                              targetPage = PltpRegisterTreesPage(
                                foresterId: widget.foresterId,
                                foresterName: widget.foresterName,
                                appointmentId: widget.appointmentId,
                              );
                            } else if (appType == 'splt') {
                              targetPage = SpltpRegisterTreesPage(
                                foresterId: widget.foresterId,
                                foresterName: widget.foresterName,
                                appointmentId: widget.appointmentId,
                              );
                            } else {
                              // Default to CTPO for Tree Tagging or Revisit
                              targetPage = CtpoRegisterTreesPage(
                                foresterId: widget.foresterId,
                                foresterName: widget.foresterName,
                                appointmentId: widget.appointmentId,
                              );
                            }

                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                  builder: (context) => targetPage),
                            );
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: status == 'Completed'
                          ? Colors.grey[400]
                          : Colors.green,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(Icons.nature),
                    label: Text(
                      _getButtonLabel(),
                      style: const TextStyle(
                        fontSize: 16,
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
