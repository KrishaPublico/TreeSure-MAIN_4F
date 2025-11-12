import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_firestore/cloud_firestore.dart' show Timestamp;

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
                      _buildFilterButton('Walk-In'),
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

            // 🔹 Real-time Stream of Notifications
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: _firestore
                    .collection('appointments')
                    .where('applicantId', isEqualTo: widget.applicantId)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return Center(
                      child: Text("Error: ${snapshot.error}"),
                    );
                  }
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return const Center(child: Text("No appointments yet."));
                  }

                  final allAppointments = snapshot.data!.docs;

                  // ✅ Filter appointments by status or type
                  final filteredAppointments = _selectedStatus == 'All'
                      ? allAppointments
                      : _selectedStatus == 'Walk-In'
                          ? allAppointments.where((doc) {
                              final appointmentType =
                                  (doc.data() as Map<String, dynamic>)['appointmentType'] ?? '';
                              return appointmentType == 'Walk-In';
                            }).toList()
                          : allAppointments.where((doc) {
                              final status =
                                  (doc.data() as Map<String, dynamic>)['status'] ??
                                      'Pending';
                              return status == _selectedStatus;
                            }).toList();

                  // ✅ Sort appointments by createdAt
                  final sortedAppointments =
                      _sortAppointments(filteredAppointments);

                  if (sortedAppointments.isEmpty) {
                    return Center(
                      child: Text(
                        _selectedStatus == 'All'
                            ? "No appointments found."
                            : "No $_selectedStatus appointments.",
                        style: const TextStyle(color: Colors.grey),
                      ),
                    );
                  }

                  return ListView.builder(
                    itemCount: sortedAppointments.length,
                    itemBuilder: (context, index) {
                      final apptDoc = sortedAppointments[index];
                      final apptData = apptDoc.data() as Map<String, dynamic>;
                      final appointmentType =
                          apptData['appointmentType'] ?? 'Tree Tagging';
                      final type = appointmentType == 'Cutting Assignment'
                          ? apptData['permitType'] ?? 'Cutting Assignment'
                          : appointmentType;
                      final location = apptData['location'] ?? 'No location';
                      final status = apptData['status'] ?? 'Pending';
                      final completedAt = apptData['completedAt'];

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
                            "$type - $status",
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                            ),
                          ),
                          subtitle: Text(
                            "📍 $location",
                            style: const TextStyle(color: Colors.black54),
                          ),
                          trailing: const Icon(Icons.info, color: Colors.green),
                          onTap: () => _showAppointmentDetails(
                            context,
                            apptData,
                            completedAt,
                          ),
                        ),
                      );
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

  /// ✅ Show appointment details
  void _showAppointmentDetails(
    BuildContext context,
    Map<String, dynamic> appointment,
    dynamic completedAt,
  ) {
    final appointmentType = appointment['appointmentType'] ?? '';
    final isWalkIn = appointmentType == 'Walk-In';
    
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
                "Type",
                appointment['appointmentType'] == 'Cutting Assignment'
                    ? appointment['permitType'] ?? 'N/A'
                    : appointment['appointmentType'] ?? 'N/A',
              ),
              if (isWalkIn)
                _buildDetail("Purpose", appointment['purpose'] ?? 'N/A'),
              if (!isWalkIn)
                _buildDetail("Location", appointment['location'] ?? 'N/A'),
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
