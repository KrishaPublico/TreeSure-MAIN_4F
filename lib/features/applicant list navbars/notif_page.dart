import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_firestore/cloud_firestore.dart' show Timestamp;
import 'dart:async';

class NotifPage extends StatefulWidget {
  final String applicantId;
  final String applicantName;
  const NotifPage(
      {super.key, required this.applicantId, required this.applicantName});

  @override
  State<NotifPage> createState() => _NotifPageState();
}

class _NotifPageState extends State<NotifPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String _selectedStatus = 'All';
  bool _sortDescending = true;

  // Theme colors
  static const _primaryGreen = Color(0xFF2E7D32);
  static const _darkGreen = Color(0xFF1B5E20);
  static const _lightGreen = Color(0xFFE8F5E9);
  static const _surfaceColor = Color(0xFFF5F9F5);

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

  Stream<List<QueryDocumentSnapshot>> _combineStreams() async* {
    await for (final appointmentsSnapshot in _firestore
        .collection('appointments')
        .where('applicantId', isEqualTo: widget.applicantId)
        .snapshots()) {
      final notificationsSnapshot = await _firestore
          .collection('notifications')
          .where('recipientId', isEqualTo: widget.applicantId)
          .get();

      final combined = <QueryDocumentSnapshot>[
        ...appointmentsSnapshot.docs,
        ...notificationsSnapshot.docs,
      ];

      yield combined;
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
      case 'Walk-In':
        return const Color(0xFF1565C0);
      default:
        return _primaryGreen;
    }
  }

  IconData _statusIcon(String status, bool isWalkIn) {
    if (isWalkIn) return Icons.directions_walk_rounded;
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
                              "Stay updated with your appointments",
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
                        _buildFilterChip('Walk-In Appointment', Icons.directions_walk_rounded),
                        _buildFilterChip('Certificates', Icons.file_present_rounded),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 8),

            // Notification list
            Expanded(
              child: StreamBuilder<List<QueryDocumentSnapshot>>(
                stream: _combineStreams(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Center(
                      child: CircularProgressIndicator(
                        color: _primaryGreen,
                        strokeWidth: 3,
                      ),
                    );
                  }
                  if (snapshot.hasError) {
                    return _buildEmptyState(
                      Icons.error_outline_rounded,
                      "Something went wrong",
                      "Please try again later",
                    );
                  }
                  if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return _buildEmptyState(
                      Icons.notifications_off_rounded,
                      "No notifications yet",
                      "Your notifications will appear here",
                    );
                  }

                  final allItems = snapshot.data!;

                  final filteredItems = _selectedStatus == 'All'
                      ? allItems
                      : _selectedStatus == 'Certificates'
                          ? allItems.where((doc) {
                              final data = doc.data() as Map<String, dynamic>;
                              return data.containsKey('notificationType');
                            }).toList()
                          : _selectedStatus == 'Walk-In Appointment'
                              ? allItems.where((doc) {
                                  final data = doc.data() as Map<String, dynamic>;
                                  final appointmentType =
                                      data['appointmentType'] ?? '';
                                  return appointmentType == 'Walk-in Appointment';
                                }).toList()
                              : allItems.where((doc) {
                                  final data = doc.data() as Map<String, dynamic>;
                                  if (data.containsKey('notificationType')) {
                                    return false;
                                  }
                                  final appointmentType =
                                      data['appointmentType'] ?? '';
                                  if (appointmentType == 'Walk-in Appointment') return false;
                                  final status = data['status'];
                                  return status == _selectedStatus;
                                }).toList();

                  final sortedItems = _sortAppointments(filteredItems);

                  if (sortedItems.isEmpty) {
                    return _buildEmptyState(
                      Icons.filter_list_off_rounded,
                      _selectedStatus == 'All'
                          ? "No notifications found"
                          : _selectedStatus == 'Walk-In Appointment'
                              ? "No Walk-In appointments"
                              : _selectedStatus == 'Certificates'
                                  ? "No certificate notifications"
                                  : "No $_selectedStatus appointments",
                      "Try changing your filter",
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    itemCount: sortedItems.length,
                    itemBuilder: (context, index) {
                      final itemDoc = sortedItems[index];
                      final itemData = itemDoc.data() as Map<String, dynamic>;
                      final isCertificateNotif = itemData.containsKey('notificationType');
                      final createdAt = _parseCreatedAt(itemData['createdAt']);
                      final timeAgo = _timeAgo(createdAt);

                      if (isCertificateNotif) {
                        return _buildCertificateCard(itemData, itemDoc.id, timeAgo);
                      } else {
                        return _buildAppointmentCard(itemData, timeAgo);
                      }
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCertificateCard(Map<String, dynamic> itemData, String docId, String timeAgo) {
    final title = itemData['title'] ?? 'Certificate Ready';
    final message = itemData['message'] ?? '';
    final notifStatus = itemData['status'] ?? 'unread';
    final isUnread = notifStatus == 'unread';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: isUnread
            ? Border.all(color: _primaryGreen.withOpacity(0.3), width: 1.5)
            : null,
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
          onTap: () => _showCertificateNotificationDetails(context, itemData, docId),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: isUnread
                          ? [_primaryGreen, Colors.green[600]!]
                          : [Colors.grey[400]!, Colors.grey[500]!],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.file_present_rounded,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              title,
                              style: TextStyle(
                                fontWeight: isUnread ? FontWeight.w700 : FontWeight.w500,
                                fontSize: 15,
                                color: Colors.grey[900],
                              ),
                            ),
                          ),
                          if (isUnread)
                            Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: _primaryGreen,
                                shape: BoxShape.circle,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        message,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 13,
                          height: 1.3,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        timeAgo,
                        style: TextStyle(
                          color: Colors.grey[400],
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(Icons.chevron_right_rounded, color: Colors.grey[400], size: 22),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAppointmentCard(Map<String, dynamic> itemData, String timeAgo) {
    final appointmentType = itemData['appointmentType'] ?? 'Tree Tagging';
    final applicationType = itemData['applicationType'] ?? '';
    final isWalkIn = appointmentType == 'Walk-in Appointment';

    String displayType = appointmentType;
    if (applicationType.isNotEmpty && !isWalkIn) {
      final appTypeUpper = applicationType.toUpperCase();
      displayType = '$appTypeUpper $appointmentType';
    }

    final location = isWalkIn
        ? (itemData['location'] ?? 'DENR Office')
        : (itemData['location'] ?? 'No location');
    final status = isWalkIn ? 'Walk-In' : (itemData['status'] ?? 'Pending');
    final completedAt = itemData['completedAt'];
    final statusClr = _statusColor(status);

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
          onTap: () => _showAppointmentDetails(context, itemData, completedAt),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: statusClr.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    _statusIcon(status, isWalkIn),
                    color: statusClr,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isWalkIn ? appointmentType : displayType,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                          color: Colors.grey[900],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.location_on_rounded,
                              size: 14, color: Colors.grey[500]),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              isWalkIn
                                  ? '$location  •  ${itemData['purpose'] ?? 'N/A'}'
                                  : location,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
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
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: statusClr.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              status,
                              style: TextStyle(
                                color: statusClr,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const Spacer(),
                          Text(
                            timeAgo,
                            style: TextStyle(
                              color: Colors.grey[400],
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(Icons.chevron_right_rounded, color: Colors.grey[400], size: 22),
              ],
            ),
          ),
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
                  status == 'Walk-In Appointment' ? 'Walk-In' : status,
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

  void _showCertificateNotificationDetails(
    BuildContext context,
    Map<String, dynamic> notification,
    String notificationId,
  ) {
    _firestore.collection('notifications').doc(notificationId).update({
      'status': 'read',
    });

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _lightGreen,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(Icons.file_present_rounded, color: _primaryGreen, size: 28),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    notification['title'] ?? 'Certificate Ready',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _buildDetailRow(Icons.description_rounded, "Certificate Type",
                notification['certificateType'] ?? 'N/A'),
            _buildDetailRow(Icons.category_rounded, "Application Type",
                notification['applicationType'] ?? 'N/A'),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: _surfaceColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                notification['message'] ?? '',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[700],
                  height: 1.5,
                ),
              ),
            ),
            if (notification['remarks'] != null && notification['remarks'] != '') ...[
              const SizedBox(height: 12),
              _buildDetailRow(Icons.note_rounded, "Remarks", notification['remarks']),
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
                child: const Text("Done", style: TextStyle(fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAppointmentDetails(
    BuildContext context,
    Map<String, dynamic> appointment,
    dynamic completedAt,
  ) {
    final appointmentType = appointment['appointmentType'] ?? '';
    final isWalkIn = appointmentType == 'Walk-in Appointment';
    final status = isWalkIn ? 'Walk-In' : (appointment['status'] ?? 'Pending');

    String? formattedSchedule;
    if (isWalkIn) {
      final scheduledDate = appointment['scheduledDate'];
      final scheduledTime = appointment['scheduledTime'];
      if (scheduledDate != null && scheduledTime != null) {
        formattedSchedule = "$scheduledDate at $scheduledTime";
      }
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _statusColor(status).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    _statusIcon(status, isWalkIn),
                    color: _statusColor(status),
                    size: 28,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Appointment Details",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: _statusColor(status).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          status,
                          style: TextStyle(
                            color: _statusColor(status),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _buildDetailRow(Icons.event_rounded, "Appointment Type",
                appointment['appointmentType'] ?? 'N/A'),
            if (appointment['applicationType'] != null &&
                appointment['applicationType'] != '')
              _buildDetailRow(Icons.category_rounded, "Application Type",
                  appointment['applicationType']?.toString().toUpperCase() ?? 'N/A'),
            _buildDetailRow(Icons.location_on_rounded, "Location",
                appointment['location'] ?? 'N/A'),
            if (isWalkIn) ...[
              _buildDetailRow(Icons.flag_rounded, "Purpose",
                  appointment['purpose'] ?? 'N/A'),
              if (formattedSchedule != null)
                _buildDetailRow(Icons.calendar_today_rounded, "Scheduled",
                    formattedSchedule),
            ],
            _buildDetailRow(Icons.note_rounded, "Remarks",
                appointment['remarks'] ?? 'None'),
            if (completedAt != null)
              _buildDetailRow(Icons.done_all_rounded, "Completed At",
                  completedAt.toDate()?.toString() ?? 'N/A'),
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
                child: const Text("Done", style: TextStyle(fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String? value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
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
                const SizedBox(height: 2),
                Text(
                  value ?? 'N/A',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[800],
                    fontWeight: FontWeight.w500,
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
