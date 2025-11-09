import 'package:flutter/material.dart';
import 'package:treesure_app/features/forester/forester_tree_mapping.dart';
import 'package:treesure_app/features/forester/testQr_screen.dart';

class ForesterHomepage extends StatefulWidget {
  final String foresterId; // comes from login
  final String foresterName; // comes from login
  const ForesterHomepage({
    super.key,
    required this.foresterId,
    required this.foresterName,
  });

  @override
  State<ForesterHomepage> createState() => _ForesterHomepageState();
}

class _ForesterHomepageState extends State<ForesterHomepage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 20),

            // Profile Header with QR icon
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
                      Text(
                        widget.foresterName,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const Text(
                        "Forester",
                        style: TextStyle(fontSize: 14, color: Colors.white70),
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
                    child: GestureDetector(
                      onTap: () {
                        // Open QR Scanner immediately when the QR icon is tapped
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
                        padding: const EdgeInsets.all(4.0),
                        child: const CircleAvatar(
                          radius: 25,
                          backgroundColor: Colors.white,
                          child: Icon(Icons.qr_code, size: 30, color: Colors.green),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 40),

            // Features section (only Tree Mapping remains)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Features",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.green.shade800,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildFeatureButton(
                    "Tree Mapping",
                    Icons.forest,
                    () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const ForesterTreeMapping()),
                      );
                    },
                  ),
                  const SizedBox(height: 30),
                ],
              ),
            ),

            // Horizontal Tree Images
            SizedBox(
              height: 110,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                children: [
                  _buildImageBox("assets/tree1.jpg"),
                  _buildImageBox("assets/tree2.jpg"),
                  _buildImageBox("assets/tree3.jpg"),
                ],
              ),
            ),

            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  // Feature Button (like ApplicantHomepage)
  Widget _buildFeatureButton(String title, IconData icon, VoidCallback onPressed) {
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

  // Tree image box
  Widget _buildImageBox(String imagePath) {
    return Container(
      width: 100,
      height: 100,
      margin: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.green, width: 2),
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.25),
            blurRadius: 6,
            offset: const Offset(3, 4),
          ),
        ],
        image: DecorationImage(
          image: AssetImage(imagePath),
          fit: BoxFit.cover,
        ),
      ),
    );
  }
}
