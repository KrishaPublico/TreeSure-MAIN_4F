import 'package:flutter/material.dart';
import 'package:treesure_app/features/forester/register_trees.dart';
import 'package:treesure_app/features/forester/forester_summary_reports.dart';

class ForesterHomepage extends StatelessWidget {
  const ForesterHomepage({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        children: [
          const SizedBox(height: 20),

          // Header Stack with QR
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
                        child: Icon(Icons.person, size: 40, color: Colors.green),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        "Teresa Ubasa Bayuga",
                        style: TextStyle(
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
                    child: const Padding(
                      padding: EdgeInsets.all(4.0),
                      child: CircleAvatar(
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

          const SizedBox(height: 60),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 30.0),
            child: Column(
              children: [
                _buildMenuButton(
                  context,
                  "50 Registered Trees",
                  Icons.check_circle,
                  Colors.green[800]!,
                  () {
                    // TODO: Add navigation to registered trees
                  },
                  textStyle: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 15), // keep spacing above Tree Inventory
                _buildMenuButton(
                  context,
                  "Tree Inventory",
                  Icons.forest,
                  Colors.green[800]!,
                  () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const RegisterTreesPage()),
                    );
                  },
                ),
                const SizedBox(height: 8), // reduced spacing
                _buildMenuButton(
                  context,
                  "Tree Mapping",
                  Icons.map,
                  Colors.green[800]!,
                  () {
                    // TODO: Add Tree Mapping Page navigation
                  },
                ),
                const SizedBox(height: 8), // reduced spacing
                _buildMenuButton(
                  context,
                  "Reports",
                  Icons.insert_chart_outlined,
                  Colors.green[800]!,
                  () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const ForesterSummaryReports()),
                    );
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 30),

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
    );
  }

  Widget _buildMenuButton(
    BuildContext context,
    String title,
    IconData icon,
    Color color,
    VoidCallback onPressed, {
    TextStyle? textStyle,
  }) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.white),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: textStyle ?? const TextStyle(fontSize: 16, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

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
