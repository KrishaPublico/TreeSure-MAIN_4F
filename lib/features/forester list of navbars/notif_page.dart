import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:treesure_app/features/forester/applicant_detail_page.dart';
import 'package:cloud_firestore/cloud_firestore.dart' show Timestamp;

class NotifPage_Forester extends StatefulWidget {
  final String foresterId;
  final String foresterName;
  final String applicantName;
  const NotifPage_Forester({
    super.key,
    required this.foresterId,
    required this.foresterName,
    required this.applicantName,
  });

  @override
  State<NotifPage_Forester> createState() => _NotifPageState();
}

class _NotifPageState extends State<NotifPage_Forester> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String _selectedStatus = 'All';
  bool _sortDescending = true;
  int _refreshKey = 0;

  // Theme colors
  static const _primaryGreen = Color(0xFF2E7D32);
  static const _darkGreen = Color(0xFF1B5E20);
  static const _lightGreen = Color(0xFFE8F5E9);
  static const _surfaceColor = Color(0xFFF5F9F5);

  Future<void> _onRefresh() async {
    setState(() {
      _refreshKey++;
    });
    await Future.delayed(const Duration(milliseconds: 500));
  }

  DateTime _parseCreatedAt(dynamic createdAt) {
    if (createdAt == null) return DateTime.now();
    try {
      if (createdAt is Timestamp) return createdAt.toDate();
      if (createdAt is String) {
        final cleanedStr = createdAt.replaceAll(RegExp(r'\s*UTC[+-]\d+$'), '');
        return DateTime.parse(cleanedStr.replaceAll(RegExp(r',\s*at\s*'), ' '));
      }
      return DateTime.now();
    } catch (e) {
      return DateTime.now();
    }
  }

  List<QueryDocumentSnapshot> _sortAppointments(
      List<QueryDocumentSnapshot> appointments) {
    final sorted = List<QueryDocumentSnapshot>.from(appointments);
    sorted.sort((a, b) {
      final aData = a.data() as Map<String, dynamic>;
      final bData = b.data() as Map<String, dynamic>;
      final aDate = _parseCreatedAt(aData['createdAt'] as Timestamp?);
      final bDate = _parseCreatedAt(bData['createdAt'] as Timestamp?);
      return _sortDescending ? bDate.compareTo(aDate) : aDate.compareTo(bDate);
    });
    return sorted;
  }

  Future<String> _getApplicantName(String applicantId) async {
    try {
      final doc = await _firestore.collection('users').doc(applicantId).get();
      return doc.data()?['name'] as String? ?? 'Unknown';
    } catch (e) {
      return 'Unknown';
    }
  }

  List<QueryDocumentSnapshot> _filterAppointments(
      List<QueryDocumentSnapshot> appointments) {
    if (_selectedStatus == 'All') return appointments;
    return appointments.where((doc) {
      final status =
          (doc.data() as Map<String, dynamic>)['status'] ?? 'Pending';
      return status == _selectedStatus;
    }).toList();
  }

  String _timeAgo(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${date.day}/${date.month}/${date.year}';
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'Completed':
        return const Color(0xFF2E7D32);
      case 'In Progress':
        return const Color(0xFFF57F17);
      case 'Pending':
        return const Color(0xFFE65100);
      default:
        return _primaryGreen;
    }
  }

  IconData _statusIcon(String status) {
    switch (status) {
      case 'Completed':
        return Icons.check_circle_rounded;
      case 'In Progress':
        return Icons.sync_rounded;
      case 'Pending':
        return Icons.schedule_rounded;
      default:
        return Icons.notifications_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _surfaceColor,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
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
                          Icons.notifications_rounded,
                          color: Colors.white,
                          size: 26,
                        ),
                      ),
                      const SizedBox(width: 14),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Notifications",
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                letterSpacing: 0.5,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              "Appointments assigned to you",
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.white70,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Sort toggle
                      Material(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () {
                            setState(() {
                              _sortDescending = !_sortDescending;
                            });
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  _sortDescending
                                      ? Icons.arrow_downward_rounded
                                      : Icons.arrow_upward_rounded,
                                  color: Colors.white,
                                  size: 16,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  _sortDescending ? 'Newest' : 'Oldest',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  // Filter chips
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildFilterChip('All', Icons.all_inbox_rounded),
                        _buildFilterChip('Pending', Icons.schedule_rounded),
                        _buildFilterChip('In Progress', Icons.sync_rounded),
                        _buildFilterChip('Completed', Icons.check_circle_rounded),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 8),

            // Appointment list
            Expanded(
              child: RefreshIndicator(
                onRefresh: _onRefresh,
                color: _primaryGreen,
                child: StreamBuilder<QuerySnapshot>(
                  key: ValueKey(_refreshKey),
                  stream: _firestore
                      .collection('appointments')
                      .where('foresterIds', arrayContains: widget.foresterId)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return Center(
                        child: CircularProgressIndicator(
                          color: _primaryGreen,
                          strokeWidth: 3,
                        ),
                      );
                    }
                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: [
                          const SizedBox(height: 80),
                          _buildEmptyState(
                            Icons.assignment_rounded,
                            "No appointments yet",
                            "Appointments assigned to you will appear here",
                          ),
                        ],
                      );
                    }

                    final allAppointments = snapshot.data!.docs;
                    final filteredAppointments =
                        _filterAppointments(allAppointments);
                    final sortedAppointments =
                        _sortAppointments(filteredAppointments);

                    if (sortedAppointments.isEmpty) {
                      return ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: [
                          const SizedBox(height: 80),
                          _buildEmptyState(
                            Icons.filter_list_off_rounded,
                            _selectedStatus == 'All'
                                ? "No appointments assigned to you"
                                : "No $_selectedStatus appointments",
                            "Try changing your filter",
                          ),
                        ],
                      );
                    }

                    return ListView.builder(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                      itemCount: sortedAppointments.length,
                      itemBuilder: (context, index) {
                        final apptDoc = sortedAppointments[index];
                        final appt = apptDoc.data() as Map<String, dynamic>;
                        final applicantId = appt['applicantId'] as String?;
                        final appointmentType =
                            appt['appointmentType'] ?? 'Tree Tagging';
                        final applicationType = appt['applicationType'] ?? '';

                        String displayType = appointmentType;
                        if (applicationType.isNotEmpty) {
                          final appTypeUpper = applicationType.toUpperCase();
                          displayType = '$appTypeUpper $appointmentType';
                        }

                        final location = appt['location'] ?? 'No location';
                        final status = appt['status'] ?? 'Pending';
                        final createdAt = _parseCreatedAt(appt['createdAt']);
                        final timeAgo = _timeAgo(createdAt);
                        final statusClr = _statusColor(status);

                        return FutureBuilder<String>(
                          future: _getApplicantName(applicantId ?? ''),
                          builder: (context, nameSnapshot) {
                            final applicantName =
                                nameSnapshot.data ?? 'Loading...';

                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
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
                              child: Material(
                                color: Colors.transparent,
                                borderRadius: BorderRadius.circular(16),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(16),
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            ApplicantDetailPage(
                                          applicantName: applicantName,
                                          requirementDetails:
                                              "Location: $location\nStatus: $status",
                                          foresterName: widget.foresterName,
                                          foresterId: widget.foresterId,
                                          appointmentId: apptDoc.id,
                                          applicationType: applicationType,
                                        ),
                                      ),
                                    );
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 48,
                                          height: 48,
                                          decoration: BoxDecoration(
                                            color: statusClr.withOpacity(0.1),
                                            borderRadius:
                                                BorderRadius.circular(14),
                                          ),
                                          child: Icon(
                                            _statusIcon(status),
                                            color: statusClr,
                                            size: 24,
                                          ),
                                        ),
                                        const SizedBox(width: 14),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                displayType,
                                                style: TextStyle(
                                                  fontWeight: FontWeight.w600,
                                                  fontSize: 15,
                                                  color: Colors.grey[900],
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Row(
                                                children: [
                                                  Icon(Icons.person_rounded,
                                                      size: 14,
                                                      color: Colors.grey[500]),
                                                  const SizedBox(width: 4),
                                                  Expanded(
                                                    child: Text(
                                                      applicantName,
                                                      maxLines: 1,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                      style: TextStyle(
                                                        color: Colors.grey[600],
                                                        fontSize: 13,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 2),
                                              Row(
                                                children: [
                                                  Icon(
                                                      Icons
                                                          .location_on_rounded,
                                                      size: 14,
                                                      color: Colors.grey[500]),
                                                  const SizedBox(width: 4),
                                                  Expanded(
                                                    child: Text(
                                                      location,
                                                      maxLines: 1,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                      style: TextStyle(
                                                        color: Colors.grey[600],
                                                        fontSize: 13,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 8),
                                              Row(
                                                children: [
                                                  Container(
                                                    padding: const EdgeInsets
                                                        .symmetric(
                                                        horizontal: 10,
                                                        vertical: 4),
                                                    decoration: BoxDecoration(
                                                      color: statusClr
                                                          .withOpacity(0.1),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              20),
                                                    ),
                                                    child: Text(
                                                      status,
                                                      style: TextStyle(
                                                        color: statusClr,
                                                        fontSize: 11,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                      ),
                                                    ),
                                                  ),
                                                  const Spacer(),
                                                  Text(
                                                    timeAgo,
                                                    style: TextStyle(
                                                      color: Colors.grey[400],
                                                      fontSize: 11,
                                                      fontWeight:
                                                          FontWeight.w500,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Icon(Icons.chevron_right_rounded,
                                            color: Colors.grey[400], size: 22),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        );
                      },
                    );
                  },
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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: _lightGreen,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 48, color: Colors.green[300]),
          ),
          const SizedBox(height: 20),
          Text(
            title,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: Colors.grey[800],
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: TextStyle(fontSize: 13, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String status, IconData icon) {
    final isSelected = _selectedStatus == status;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Material(
        color: isSelected
            ? Colors.white
            : Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(24),
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: () {
            setState(() {
              _selectedStatus = status;
            });
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: 16,
                  color: isSelected ? _darkGreen : Colors.white70,
                ),
                const SizedBox(width: 6),
                Text(
                  status,
                  style: TextStyle(
                    fontSize: 12,
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
}
