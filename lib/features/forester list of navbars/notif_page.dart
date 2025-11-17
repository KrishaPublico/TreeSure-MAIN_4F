import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:treesure_app/features/forester/applicant_detail_page.dart';
import 'package:cloud_firestore/cloud_firestore.dart' show Timestamp;

class NotifPage_Forester extends StatefulWidget {
  final String foresterId; // comes from login
  final String foresterName; // comes from login
  final String applicantName; // comes from login
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

  /// ✅ Fetch applicant name from users collection
  Future<String> _getApplicantName(String applicantId) async {
    try {
      final doc = await _firestore.collection('users').doc(applicantId).get();
      return doc.data()?['name'] as String? ?? 'Unknown';
    } catch (e) {
      return 'Unknown';
    }
  }

  /// ✅ Filter appointments by status
  List<QueryDocumentSnapshot> _filterAppointments(
      List<QueryDocumentSnapshot> appointments) {
    if (_selectedStatus == 'All') {
      return appointments;
    }
    // Handle case where status might be missing (default to 'Pending')
    return appointments.where((doc) {
      final status =
          (doc.data() as Map<String, dynamic>)['status'] ?? 'Pending';
      return status == _selectedStatus;
    }).toList();
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
      body: Column(
        children: [
          // ✅ Status Filter Tabs + Sort Toggle
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
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
          ),
          // ✅ Real-time Stream of Appointments
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _firestore
                  .collection('appointments')
                  .where('foresterIds', arrayContains: widget.foresterId)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                      child: CircularProgressIndicator(color: Colors.green));
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(
                    child: Text(
                      "No appointments assigned to you.",
                      style: TextStyle(color: Colors.grey),
                    ),
                  );
                }

                final allAppointments = snapshot.data!.docs;
                final filteredAppointments =
                    _filterAppointments(allAppointments);
                final sortedAppointments =
                    _sortAppointments(filteredAppointments);

                if (sortedAppointments.isEmpty) {
                  return Center(
                    child: Text(
                      _selectedStatus == 'All'
                          ? "No appointments assigned to you."
                          : "No $_selectedStatus appointments.",
                      style: const TextStyle(color: Colors.grey),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  itemCount: sortedAppointments.length,
                  itemBuilder: (context, index) {
                    final apptDoc = sortedAppointments[index];
                    final appt = apptDoc.data() as Map<String, dynamic>;
                    final applicantId = appt['applicantId'] as String?;
                    final appointmentType =
                        appt['appointmentType'] ?? 'Tree Tagging';
                    final applicationType = appt['applicationType'] ?? '';

                    // Build display type: "CTPO Tree Tagging", "PLTP Revisit", etc.
                    String displayType = appointmentType;
                    if (applicationType.isNotEmpty) {
                      final appTypeUpper = applicationType.toUpperCase();
                      displayType = '$appTypeUpper $appointmentType';
                    }

                    final location = appt['location'] ?? 'No location';
                    final status = appt['status'] ?? 'Pending';

                    return FutureBuilder<String>(
                      future: _getApplicantName(applicantId ?? ''),
                      builder: (context, nameSnapshot) {
                        final applicantName = nameSnapshot.data ?? 'Unknown';

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
                                  : Colors.orange,
                              child: Icon(
                                status == 'Completed'
                                    ? Icons.check_circle
                                    : Icons.hourglass_bottom,
                                color: Colors.white,
                              ),
                            ),
                            title: Text(
                              "$displayType - $status",
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black),
                            ),
                            subtitle: Text(
                              "$applicantName\n📍 $location",
                              style: const TextStyle(color: Colors.black54),
                            ),
                            isThreeLine: true,
                            trailing: const Icon(Icons.arrow_forward_ios,
                                color: Colors.green),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => ApplicantDetailPage(
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
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
          )
        ],
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
}
