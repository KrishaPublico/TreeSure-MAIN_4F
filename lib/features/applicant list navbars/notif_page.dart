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
  String _selectedStatus = 'All'; // ✅ Filter state
  bool _sortDescending =
      true; // ✅ Sort state (true = newest first, false = oldest first)

  /// ✅ Parse createdAt (Timestamp or String) to DateTime
  DateTime _parseCreatedAt(dynamic createdAt) {
    if (createdAt == null) {
      return DateTime.now(); // Default to now if not found
    }
    try {
      // If it's a Firestore Timestamp
      if (createdAt is Timestamp) {
        return createdAt.toDate();
      }
      // If it's a String: 'November 4, 2025, at 9:39:58PM UTC+8'
      if (createdAt is String) {
        final cleanedStr = createdAt.replaceAll(RegExp(r'\s*UTC[+-]\d+$'), '');
        return DateTime.parse(cleanedStr.replaceAll(RegExp(r',\s*at\s*'), ' '));
      }
      return DateTime.now();
    } catch (e) {
      return DateTime.now();
    }
  }

  /// ✅ Combine streams from appointments and notifications collections
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

  /// ✅ Sort appointments by createdAt field
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              "Notifications",
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
            SizedBox(width: 5),
            Icon(Icons.notifications, color: Colors.green, size: 24),
          ],
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: Column(
          children: [
            // Search Bar
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.green[100],
                borderRadius: BorderRadius.circular(20),
              ),
              child: const TextField(
                decoration: InputDecoration(
                  hintText: "Search",
                  border: InputBorder.none,
                  icon: Icon(Icons.search),
                ),
              ),
            ),

            // ✅ Status Filter Tabs + Sort Toggle
            Column(
              children: [
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildFilterButton('All'),
                      const SizedBox(width: 8),
                      _buildFilterButton('Pending'),
                      const SizedBox(width: 8),
                      _buildFilterButton('In Progress'),
                      const SizedBox(width: 8),
                      _buildFilterButton('Completed'),
                      const SizedBox(width: 8),
                      _buildFilterButton('Walk-In Appointment'),
                      const SizedBox(width: 8),
                      _buildFilterButton('Certificates'),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                // ✅ Sort Toggle Button
                Align(
                  alignment: Alignment.centerRight,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      setState(() {
                        _sortDescending = !_sortDescending;
                      });
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue[600],
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    icon: Icon(
                      _sortDescending
                          ? Icons.arrow_downward
                          : Icons.arrow_upward,
                      size: 16,
                    ),
                    label: Text(
                      _sortDescending ? 'Newest First' : 'Oldest First',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // 🔹 Real-time Stream of Notifications (Appointments + Certificate Notifications)
            Expanded(
              child: StreamBuilder<List<QueryDocumentSnapshot>>(
                stream: _combineStreams(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return Center(
                      child: Text("Error: ${snapshot.error}"),
                    );
                  }
                  if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return const Center(child: Text("No notifications yet."));
                  }

                  final allItems = snapshot.data!;

                  // ✅ Filter appointments by status or type
                  if (allItems.isEmpty) {
                    return const Center(child: Text("No notifications yet."));
                  }

                  // ✅ Filter items by status or type
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
                                  // Check if it's a certificate notification
                                  if (data.containsKey('notificationType')) {
                                    return false; // Skip notifications for status filters
                                  }
                                  final appointmentType =
                                      data['appointmentType'] ?? '';
                                  // Skip walk-in appointments for status filters
                                  if (appointmentType == 'Walk-in Appointment') return false;
                                  final status = data['status'];
                                  return status == _selectedStatus;
                                }).toList();

                  // ✅ Sort items by createdAt
                  final sortedItems = _sortAppointments(filteredItems);

                  if (sortedItems.isEmpty) {
                    return Center(
                      child: Text(
                        _selectedStatus == 'All'
                            ? "No notifications found."
                            : _selectedStatus == 'Walk-In Appointment'
                                ? "No Walk-In appointments."
                                : _selectedStatus == 'Certificates'
                                    ? "No certificate notifications."
                                    : "No $_selectedStatus appointments.",
                        style: const TextStyle(color: Colors.grey),
                      ),
                    );
                  }

                  return ListView.builder(
                    itemCount: sortedItems.length,
                    itemBuilder: (context, index) {
                      final itemDoc = sortedItems[index];
                      final itemData = itemDoc.data() as Map<String, dynamic>;
                      
                      // Check if it's a certificate notification
                      final isCertificateNotif = itemData.containsKey('notificationType');
                      
                      if (isCertificateNotif) {
                        // Display certificate notification
                        final title = itemData['title'] ?? 'Certificate Ready';
                        final message = itemData['message'] ?? '';
                        final notifStatus = itemData['status'] ?? 'unread';
                        
                        return Card(
                          elevation: 2,
                          margin: const EdgeInsets.symmetric(vertical: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: notifStatus == 'read' 
                                  ? Colors.grey 
                                  : Colors.green,
                              child: Icon(
                                Icons.file_present,
                                color: Colors.white,
                              ),
                            ),
                            title: Text(
                              title,
                              style: TextStyle(
                                fontWeight: notifStatus == 'unread' 
                                    ? FontWeight.bold 
                                    : FontWeight.normal,
                                color: Colors.black,
                              ),
                            ),
                            subtitle: Text(
                              message,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: Colors.black54),
                            ),
                            trailing: const Icon(Icons.info, color: Colors.green),
                            onTap: () => _showCertificateNotificationDetails(
                              context,
                              itemData,
                              itemDoc.id,
                            ),
                          ),
                        );
                      } else {
                        // Display appointment
                        final appointmentType =
                            itemData['appointmentType'] ?? 'Tree Tagging';
                        final applicationType = itemData['applicationType'] ?? '';
                        final isWalkIn = appointmentType == 'Walk-in Appointment';
                        
                        // Build display type: "CTPO Tree Tagging", "PLTP Revisit", etc.
                        String displayType = appointmentType;
                        if (applicationType.isNotEmpty && !isWalkIn) {
                          final appTypeUpper = applicationType.toUpperCase();
                          displayType = '$appTypeUpper $appointmentType';
                        }
                        
                        final location = isWalkIn
                            ? (itemData['location'] ?? 'DENR Office')
                            : (itemData['location'] ?? 'No location');
                        final status = isWalkIn
                            ? 'Walk-In'
                            : (itemData['status'] ?? 'Pending');
                        final completedAt = itemData['completedAt'];

                        return Card(
                          elevation: 2,
                          margin: const EdgeInsets.symmetric(vertical: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: status == 'Completed'
                                  ? Colors.green
                                  : isWalkIn
                                      ? Colors.blue
                                      : Colors.orange,
                              child: Icon(
                                status == 'Completed'
                                    ? Icons.check_circle
                                    : isWalkIn
                                        ? Icons.person_pin_circle
                                        : Icons.hourglass_bottom,
                                color: Colors.white,
                              ),
                            ),
                            title: Text(
                              isWalkIn ? appointmentType : "$displayType - $status",
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.black,
                              ),
                            ),
                            subtitle: Text(
                              isWalkIn
                                  ? "📍 $location | Purpose: ${itemData['purpose'] ?? 'N/A'}"
                                  : "📍 $location",
                              style: const TextStyle(color: Colors.black54),
                            ),
                            trailing: const Icon(Icons.info, color: Colors.green),
                            onTap: () => _showAppointmentDetails(
                              context,
                              itemData,
                              completedAt,
                            ),
                          ),
                        );
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

  /// ✅ Build filter button
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

  /// ✅ Show certificate notification details
  void _showCertificateNotificationDetails(
    BuildContext context,
    Map<String, dynamic> notification,
    String notificationId,
  ) {
    // Mark notification as read
    _firestore.collection('notifications').doc(notificationId).update({
      'status': 'read',
    });

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.file_present, color: Colors.green, size: 28),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                notification['title'] ?? 'Certificate Ready',
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
              _buildDetail("Certificate Type", notification['certificateType'] ?? 'N/A'),
              _buildDetail("Application Type", notification['applicationType'] ?? 'N/A'),
              const SizedBox(height: 12),
              Text(
                notification['message'] ?? '',
                style: const TextStyle(fontSize: 14, color: Colors.black87),
              ),
              if (notification['remarks'] != null && notification['remarks'] != '')
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: _buildDetail("Remarks", notification['remarks']),
                ),
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

  /// ✅ Show appointment details
  void _showAppointmentDetails(
    BuildContext context,
    Map<String, dynamic> appointment,
    dynamic completedAt,
  ) {
    final appointmentType = appointment['appointmentType'] ?? '';
    final isWalkIn = appointmentType == 'Walk-in Appointment';

    // Format scheduled date and time for walk-in appointments
    String? formattedSchedule;
    if (isWalkIn) {
      final scheduledDate = appointment['scheduledDate'];
      final scheduledTime = appointment['scheduledTime'];
      if (scheduledDate != null && scheduledTime != null) {
        formattedSchedule = "$scheduledDate at $scheduledTime";
      }
    }

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text("📋 Appointment Details"),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDetail(
                "Appointment Type",
                appointment['appointmentType'] ?? 'N/A',
              ),
              if (appointment['applicationType'] != null && appointment['applicationType'] != '')
                _buildDetail(
                  "Application Type",
                  appointment['applicationType']?.toString().toUpperCase() ?? 'N/A',
                ),
              _buildDetail("Location", appointment['location'] ?? 'N/A'),
              if (isWalkIn) ...[
                _buildDetail("Purpose", appointment['purpose'] ?? 'N/A'),
                if (formattedSchedule != null)
                  _buildDetail("Scheduled", formattedSchedule),
              ],
              if (!isWalkIn)
                _buildDetail("Status", appointment['status'] ?? 'N/A'),
              _buildDetail(
                "Remarks",
                appointment['remarks'] ?? 'None',
              ),
              if (completedAt != null)
                _buildDetail(
                  "Completed At",
                  completedAt.toDate()?.toString() ?? 'N/A',
                ),
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

  Widget _buildDetail(String label, String? value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(
        "$label: ${value ?? 'N/A'}",
        style: const TextStyle(fontSize: 14),
      ),
    );
  }
}
