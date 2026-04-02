import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'ctpo_register_trees.dart';
import 'pltp_register_trees.dart';
import 'spltp_register_trees.dart';

class ApplicantDetailPage extends StatefulWidget {
  final String foresterId;
  final String foresterName;
  final String applicantName;
  final String requirementDetails;
  final String appointmentId;
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
  static const _primaryGreen = Color(0xFF2E7D32);
  static const _darkGreen = Color(0xFF1B5E20);
  static const _lightGreen = Color(0xFFE8F5E9);
  static const _surfaceColor = Color(0xFFF5F5F5);

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

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

  String _formatTimestamp(dynamic timestamp) {
    if (timestamp == null) return 'N/A';
    try {
      if (timestamp is Timestamp) {
        final dt = timestamp.toDate();
        final months = [
          'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
          'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
        ];
        final hour = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
        final amPm = dt.hour >= 12 ? 'PM' : 'AM';
        return '${months[dt.month - 1]} ${dt.day}, ${dt.year} at $hour:${dt.minute.toString().padLeft(2, '0')} $amPm';
      }
      return timestamp.toString();
    } catch (e) {
      return 'N/A';
    }
  }

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

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
        return const Color(0xFF4CAF50);
      case 'in progress':
        return const Color(0xFFFF9800);
      case 'pending':
        return const Color(0xFF2196F3);
      case 'cancelled':
        return const Color(0xFFF44336);
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
        return Icons.check_circle_rounded;
      case 'in progress':
        return Icons.timelapse_rounded;
      case 'pending':
        return Icons.schedule_rounded;
      case 'cancelled':
        return Icons.cancel_rounded;
      default:
        return Icons.info_rounded;
    }
  }

  String _getButtonLabel() {
    final appType = widget.applicationType.toLowerCase();
    if (appType == 'pltp') {
      return 'Proceed to PLTP Inventory';
    } else if (appType == 'splt') {
      return 'Proceed to SPLTP Inventory';
    }
    return 'Proceed to Tree Inventory';
  }

  Widget _buildDetailRow(IconData icon, String label, String value, {Color? iconColor}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: (iconColor ?? _primaryGreen).withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 20, color: iconColor ?? _primaryGreen),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey[500],
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16, top: 8),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 20,
            decoration: BoxDecoration(
              color: _primaryGreen,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            title,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1A1A1A),
              letterSpacing: -0.3,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _surfaceColor,
      body: FutureBuilder<Map<String, dynamic>?>(
        future: _getAppointmentDetails(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: _primaryGreen),
            );
          }

          if (!snapshot.hasData || snapshot.data == null) {
            return _buildErrorState();
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
          final statusColor = _getStatusColor(status);

          return CustomScrollView(
            slivers: [
              // Gradient header
              SliverToBoxAdapter(
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF1B5E20), Color(0xFF388E3C)],
                    ),
                  ),
                  child: SafeArea(
                    bottom: false,
                    child: Column(
                      children: [
                        // App bar row
                        Padding(
                          padding: const EdgeInsets.fromLTRB(4, 8, 16, 0),
                          child: Row(
                            children: [
                              IconButton(
                                icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                                onPressed: () => Navigator.pop(context),
                              ),
                              const SizedBox(width: 4),
                              const Text(
                                'Appointment Details',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: -0.3,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Applicant name + status
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
                          child: Row(
                            children: [
                              Container(
                                width: 56,
                                height: 56,
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: Colors.white.withOpacity(0.3)),
                                ),
                                child: const Icon(
                                  Icons.person_rounded,
                                  color: Colors.white,
                                  size: 28,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      widget.applicantName,
                                      style: const TextStyle(
                                        fontSize: 22,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white,
                                        letterSpacing: -0.3,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      appointmentType,
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.white.withOpacity(0.8),
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: statusColor.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: statusColor.withOpacity(0.4)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(_getStatusIcon(status), size: 14, color: Colors.white),
                                    const SizedBox(width: 5),
                                    Text(
                                      status,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Content
              SliverToBoxAdapter(
                child: Transform.translate(
                  offset: const Offset(0, -16),
                  child: Container(
                    decoration: const BoxDecoration(
                      color: _surfaceColor,
                      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 28, 20, 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Appointment Info section
                          _buildSectionHeader('Appointment Information'),
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.04),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Column(
                              children: [
                                _buildDetailRow(Icons.category_rounded, 'Type', appointmentType),
                                _buildDetailRow(Icons.location_on_rounded, 'Location', location, iconColor: const Color(0xFFE65100)),
                                _buildDetailRow(Icons.calendar_today_rounded, 'Created', createdAt, iconColor: const Color(0xFF1565C0)),
                                _buildDetailRow(Icons.event_available_rounded, 'Completed', completedAt, iconColor: const Color(0xFF4CAF50)),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),

                          // Assignment section
                          _buildSectionHeader('Assignment Details'),
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.04),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Column(
                              children: [
                                FutureBuilder<String>(
                                  future: _getForesterNames(foresterIdsList),
                                  builder: (context, nameSnapshot) {
                                    final foresterNames = nameSnapshot.data ?? 'Loading...';
                                    return _buildDetailRow(
                                      Icons.badge_rounded,
                                      'Assigned Foresters',
                                      foresterNames,
                                      iconColor: const Color(0xFF6A1B9A),
                                    );
                                  },
                                ),
                                _buildDetailRow(
                                  Icons.park_rounded,
                                  'Trees Tagged',
                                  treeCount.toString(),
                                  iconColor: _primaryGreen,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),

                          // Remarks section
                          _buildSectionHeader('Remarks'),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: _lightGreen),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.04),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFFF3E0),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Icon(
                                    Icons.sticky_note_2_rounded,
                                    size: 20,
                                    color: Color(0xFFE65100),
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Text(
                                    remarks,
                                    style: TextStyle(
                                      color: Colors.grey[700],
                                      fontSize: 14,
                                      height: 1.6,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 32),

                          // Proceed Button
                          Container(
                            width: double.infinity,
                            height: 56,
                            decoration: BoxDecoration(
                              gradient: status == 'Completed'
                                  ? null
                                  : const LinearGradient(
                                      colors: [_darkGreen, _primaryGreen],
                                    ),
                              color: status == 'Completed' ? Colors.grey[300] : null,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: status == 'Completed'
                                  ? null
                                  : [
                                      BoxShadow(
                                        color: _primaryGreen.withOpacity(0.3),
                                        blurRadius: 12,
                                        offset: const Offset(0, 6),
                                      ),
                                    ],
                            ),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: status == 'Completed'
                                    ? null
                                    : () {
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
                                          targetPage = CtpoRegisterTreesPage(
                                            foresterId: widget.foresterId,
                                            foresterName: widget.foresterName,
                                            appointmentId: widget.appointmentId,
                                          );
                                        }
                                        Navigator.pushReplacement(
                                          context,
                                          MaterialPageRoute(builder: (context) => targetPage),
                                        );
                                      },
                                borderRadius: BorderRadius.circular(16),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.nature_rounded,
                                      color: status == 'Completed' ? Colors.grey[500] : Colors.white,
                                      size: 22,
                                    ),
                                    const SizedBox(width: 10),
                                    Text(
                                      _getButtonLabel(),
                                      style: TextStyle(
                                        fontSize: 16,
                                        color: status == 'Completed' ? Colors.grey[500] : Colors.white,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: -0.2,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.red[50],
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(Icons.error_outline_rounded, size: 40, color: Colors.red[300]),
            ),
            const SizedBox(height: 20),
            const Text(
              'Failed to load appointment',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1A1A1A),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Please check your connection and try again',
              style: TextStyle(fontSize: 14, color: Colors.grey[500]),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            TextButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.arrow_back_rounded, size: 18),
              label: const Text('Go Back'),
              style: TextButton.styleFrom(foregroundColor: _primaryGreen),
            ),
          ],
        ),
      ),
    );
  }
}
