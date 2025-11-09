import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:treesure_app/features/roles/roles_page.dart';

class ProfilePage_Forester extends StatelessWidget {
  final String foresterId; // Firestore document ID
  final String foresterName;

  const ProfilePage_Forester({
    super.key,
    required this.foresterId,
    required this.foresterName,
  });

  /// Fetch forester data from Firestore
  Future<Map<String, dynamic>?> _getForesterData() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection("users") // Change to your collection if needed
          .doc(foresterId)
          .get();

      if (!doc.exists) return null;

      return doc.data();
    } catch (e) {
      debugPrint("Error fetching forester data: $e");
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: FutureBuilder<Map<String, dynamic>?>(
        future: _getForesterData(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data == null) {
            return const Center(
              child: Text(
                "No profile data found.",
                style: TextStyle(color: Colors.red),
              ),
            );
          }

          final foresterData = snapshot.data!;
          final address = foresterData['address'] ?? "No Address";
          final contact = foresterData['contact'] ?? "No Contact";
          final username = foresterData['username'] ?? "No Username";

          return Center(
            child: SingleChildScrollView(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(height: 40),

                  // Profile Picture
                  const CircleAvatar(
                    radius: 50,
                    backgroundColor: Colors.green,
                    child: Icon(
                      Icons.person,
                      size: 50,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Forester Name
                  Text(
                    foresterName,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                  const SizedBox(height: 30),

                  // Info Card (same style as applicant page)
                  Container(
                    width: MediaQuery.of(context).size.width * 0.8,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.green[100],
                      borderRadius: BorderRadius.circular(15),
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black26,
                          blurRadius: 5,
                          offset: Offset(2, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildInfoRow(Icons.home, "Address", address),
                        const Divider(color: Colors.green),
                        _buildInfoRow(Icons.phone, "Contact", contact),
                        const Divider(color: Colors.green),
                        _buildInfoRow(Icons.person, "Username", username),
                      ],
                    ),
                  ),

                  const SizedBox(height: 30),

                  // Logout Button
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green[800],
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(25),
                      ),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 50, vertical: 15),
                    ),
                    onPressed: () async {
                      final confirmLogout = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text("Logout"),
                          content: const Text(
                              "Are you sure you want to log out?"),
                          actions: [
                            TextButton(
                              onPressed: () =>
                                  Navigator.pop(context, false),
                              child: const Text("Cancel"),
                            ),
                            TextButton(
                              onPressed: () =>
                                  Navigator.pop(context, true),
                              child: const Text(
                                "Logout",
                                style: TextStyle(color: Colors.red),
                              ),
                            ),
                          ],
                        ),
                      );

                      if (confirmLogout == true && context.mounted) {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                              builder: (context) => const RolePage()),
                        );
                      }
                    },
                    child: const Text("Logout"),
                  ),
                  const SizedBox(height: 30),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  /// Helper for displaying info rows
  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: Colors.green[800]),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            "$label: $value",
            style: const TextStyle(fontSize: 16, color: Colors.black87),
          ),
        ),
      ],
    );
  }
}
