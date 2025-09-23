import 'package:flutter/material.dart';
import 'package:treesure_app/features/applicant/ctpo.dart';
import 'package:treesure_app/features/applicant/CuttingPermit.dart';
import 'package:treesure_app/features/applicant/summary_Reports.dart';

class ApplicantHomepage extends StatelessWidget {
  const ApplicantHomepage({super.key});

  final int totalRestrictedTrees = 30;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 20),

            // Profile Header with QR code
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: MediaQuery.of(context).size.width * 0.9,
                  decoration: BoxDecoration(
                    color: Colors.green,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: [
                      Image.asset("assets/treesure_leaf.png", height: 50),
                      const SizedBox(height: 10),
                      const CircleAvatar(
                        radius: 30,
                        backgroundColor: Colors.white,
                        child: Icon(Icons.person, size: 40, color: Colors.green),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        "Krisha Arellano Publico",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const Text(
                        "Applicant",
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white70,
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
                Positioned(
                  bottom: -25,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.green,
                        borderRadius: BorderRadius.circular(50),
                      ),
                      padding: const EdgeInsets.all(4.0),
                      child: const CircleAvatar(
                        radius: 25,
                        backgroundColor: Colors.white,
                        child: Icon(Icons.qr_code, size: 30, color: Colors.green),
                      ),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 40),

            // Total Trees Button
            SizedBox(
              width: 250,
              height: 60,
              child: ElevatedButton.icon(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content:
                          Text('Total Restricted Trees: $totalRestrictedTrees'),
                    ),
                  );
                },
                icon: const Icon(
                  Icons.park_rounded,
                  size: 36,
                  color: Colors.white,
                ),
                label: Text(
                  'Total Trees: $totalRestrictedTrees',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color.fromARGB(255, 52, 123, 57),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Tree Restrictions Section
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  "What trees are not allowed to cut?",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.green.shade800,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),

            buildTreeRestrictionCard(
              "Trees marked by the DENR as Significant or Important",
              "assets/pic1.jpg",
            ),
            buildTreeRestrictionCard(
              "Century-old trees, even if not officially tagged",
              "assets/pic2.jpg",
            ),
            buildTreeRestrictionCard(
              "Trees that add beauty to public areas",
              "assets/pic3.JPG",
            ),

            const SizedBox(height: 20),

            // Permit & Certificate Buttons
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Permits & Certificates",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.green.shade800,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // ✅ CTPO Button -> Opens Upload Page
                  _buildApplicantPermitButton(
                    context,
                    "CTPO (Certificate of Tree Plantation Ownership)",
                    Icons.description,
                    () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const CTPOUploadPage(),
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 8),
                  _buildApplicantPermitButton(
                    context,
                    "Cutting Permit",
                    Icons.description,
                    () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const CuttingPermitPage(),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 8),
                  _buildApplicantPermitButton(
                    context,
                    "Certificate to Travel (COV)",
              Icons.build,
                    () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text("Access Certificate to Travel information")),
                      );
                    },
                  ),
                  const SizedBox(height: 8),
                  _buildApplicantPermitButton(
                    context,
                    "Chainsaw Permit",
                    Icons.build,
                    () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text("Access Chainsaw Permit information.")),
                      );
                    },
                  ),
                  const SizedBox(height: 8),
                  _buildApplicantPermitButton(
                    context,
                    "Reports",
                      Icons.description,
                    () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const SummaryReportsPage(),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 30),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Restriction Card Widget
  Widget buildTreeRestrictionCard(String text, String imagePath) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 20),
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 10,
                    offset: const Offset(3, 3),
                  ),
                ],
              ),
              clipBehavior: Clip.hardEdge,
              child: Image.asset(
                imagePath,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                text,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.black87,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Permit Button Widget
  Widget _buildApplicantPermitButton(
      BuildContext context, String title, IconData icon, VoidCallback onPressed) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.green.shade800,
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.white),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(fontSize: 14, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
