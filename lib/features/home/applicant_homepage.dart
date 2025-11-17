import 'package:flutter/material.dart';
import 'package:treesure_app/features/applicant/ctpo.dart';
import 'package:treesure_app/features/applicant/CuttingPermit.dart';
import 'package:treesure_app/features/applicant/testQR.dart'; // ✅ Correct import
import 'package:treesure_app/features/applicant/cov.dart';
import 'package:treesure_app/features/applicant/chainsawreg.dart';

class ApplicantHomepage extends StatelessWidget {
  final String applicantId; // comes from login
  final String applicantName; // comes from login

  const ApplicantHomepage({
    super.key,
    required this.applicantId,
    required this.applicantName,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 20),

            // ✅ HEADER (same as ForesterHomepage)
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 350,
                  decoration: BoxDecoration(
                    color: Colors.green,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      children: [
                        Image.asset("assets/treesure_leaf.png", height: 50),
                        const SizedBox(height: 10),
                        const CircleAvatar(
                          radius: 30,
                          backgroundColor: Colors.white,
                          child:
                              Icon(Icons.person, size: 40, color: Colors.green),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          applicantName,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          applicantId,
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.white70,
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),

                // ✅ Clickable QR icon → Navigates to ApplicantTreeMapping
                Positioned(
                  bottom: -25,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: GestureDetector(
                      onTap: () {
                        // Navigate to QR scanner screen when tapped
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const QrUploadScanner(),
                          ),
                        );
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.green,
                          borderRadius: BorderRadius.circular(50),
                        ),
                        child: const Padding(
                          padding: EdgeInsets.all(4.0),
                          child: CircleAvatar(
                            radius: 25,
                            backgroundColor: Colors.white,
                            child: Icon(Icons.qr_code,
                                size: 30, color: Colors.green),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 60),

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
                    "Permits",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.green.shade800,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // ✅ CTPO Button
                  _buildApplicantPermitButton(
                    context,
                    "CTPO (Certificate of Tree Plantation Ownership)",
                    Icons.description,
                    () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => CTPOUploadPage(
                            applicantId: applicantId,
                            applicantName: applicantName,
                          ),
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 8),

                  // ✅ Cutting Permit
                  _buildApplicantPermitButton(
                    context,
                    "Cutting Permits",
                    Icons.description,
                    () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => CuttingPermitPage(
                            applicantId: applicantId,
                            applicantName: applicantName,
                          ),
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 8),

                  _buildApplicantPermitButton(
                    context,
                    "Transport Permit",
                    Icons.description,
                    () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => CovFormPage(
                            applicantName: applicantName,
                            applicantId: applicantId,
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 8),

                  _buildApplicantPermitButton(
                    context,
                    "Chainsaw Registration",
                    Icons.description,
                    () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ChainsawRegistrationPage(
                            applicantName: applicantName,
                            applicantId:
                                applicantId, // Pass the applicantId here
                          ),
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
  Widget _buildApplicantPermitButton(BuildContext context, String title,
      IconData icon, VoidCallback onPressed) {
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
