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

  // Theme colors
  static const _primaryGreen = Color(0xFF2E7D32);
  static const _darkGreen = Color(0xFF1B5E20);
  static const _lightGreen = Color(0xFFE8F5E9);
  static const _surfaceColor = Color(0xFFF5F9F5);

  /// Fetch forester data from Firestore
  Future<Map<String, dynamic>?> _getForesterData() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection("users")
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
      backgroundColor: _surfaceColor,
      body: FutureBuilder<Map<String, dynamic>?>(
        future: _getForesterData(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(
                color: _primaryGreen,
                strokeWidth: 3,
              ),
            );
          }

          if (!snapshot.hasData || snapshot.data == null) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: const BoxDecoration(
                      color: _lightGreen,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.person_off_rounded,
                        size: 48, color: _primaryGreen),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    "No profile data found.",
                    style: TextStyle(
                      fontSize: 16,
                      color: Color(0xFF37474F),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            );
          }

          final foresterData = snapshot.data!;
          final address = foresterData['address'] ?? "No Address";
          final contact = foresterData['contact'] ?? "No Contact";
          final username = foresterData['username'] ?? "No Username";

          return SafeArea(
            child: Column(
              children: [
                // Modern gradient header
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(20, 30, 20, 30),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.green[800]!, Colors.green[600]!],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(36),
                      bottomRight: Radius.circular(36),
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
                    children: [
                      // Avatar
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withOpacity(0.4),
                            width: 3,
                          ),
                        ),
                        child: Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withOpacity(0.2),
                          ),
                          child: const Icon(
                            Icons.person_rounded,
                            size: 44,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        foresterName,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          "Forester",
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.white70,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Info section
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Personal Information",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF37474F),
                          ),
                        ),
                        const SizedBox(height: 14),
                        _buildInfoCard(
                          icon: Icons.home_rounded,
                          label: "Address",
                          value: address,
                        ),
                        _buildInfoCard(
                          icon: Icons.phone_rounded,
                          label: "Contact",
                          value: contact,
                        ),
                        _buildInfoCard(
                          icon: Icons.person_rounded,
                          label: "Username",
                          value: username,
                        ),
                        const SizedBox(height: 32),
                        // Logout Button
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () => _handleLogout(context),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red[50],
                              foregroundColor: Colors.red[700],
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              elevation: 0,
                            ),
                            icon: const Icon(Icons.logout_rounded, size: 20),
                            label: const Text(
                              "Logout",
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
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
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
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: _lightGreen,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 22, color: _primaryGreen),
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
                    color: Colors.grey[500],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
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

  void _handleLogout(BuildContext context) async {
    final confirmLogout = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.red[50],
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.logout_rounded, size: 32, color: Colors.red[700]),
            ),
            const SizedBox(height: 16),
            const Text(
              "Logout",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF263238),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "Are you sure you want to log out?",
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context, false),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      side: BorderSide(color: Colors.grey[300]!),
                    ),
                    child: const Text(
                      "Cancel",
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF37474F),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context, true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red[700],
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 0,
                    ),
                    child: const Text(
                      "Logout",
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );

    if (confirmLogout == true && context.mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const RolePage()),
      );
    }
  }
}
