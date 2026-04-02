import 'package:flutter/material.dart';
import 'package:treesure_app/features/forester/forester_tree_mapping.dart';
import 'package:treesure_app/features/forester/forester_qr_scanner.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ForesterHomepage extends StatefulWidget {
  final String foresterId;
  final String foresterName;
  const ForesterHomepage({
    super.key,
    required this.foresterId,
    required this.foresterName,
  });

  @override
  State<ForesterHomepage> createState() => _ForesterHomepageState();
}

class _ForesterHomepageState extends State<ForesterHomepage> {
  int _refreshKey = 0;

  Future<void> _onRefresh() async {
    setState(() {
      _refreshKey++;
    });
    await Future.delayed(const Duration(milliseconds: 500));
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _onRefresh,
      color: Colors.green[800],
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics()),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 24),

            // Profile header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.green[800]!, Colors.green[600]!],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.25),
                      shape: BoxShape.circle,
                    ),
                    child: const CircleAvatar(
                      radius: 28,
                      backgroundColor: Colors.white,
                      child: Icon(Icons.person_rounded,
                          size: 32, color: Color(0xFF2E7D32)),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.foresterName,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            letterSpacing: 0.2,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text(
                            "Forester",
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: Colors.white,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Image.asset("assets/treesure_leaf.png", height: 40),
                ],
              ),
            ),

            const SizedBox(height: 28),

            // Greeting
            Text(
              'Welcome back!',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                color: Colors.green[900],
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Manage appointments and track tree data.',
              style: TextStyle(
                fontSize: 15,
                color: Colors.grey[500],
                height: 1.4,
              ),
            ),

            const SizedBox(height: 28),

            // Quick actions
            Row(
              children: [
                Expanded(
                  child: _buildActionCard(
                    icon: Icons.qr_code_scanner_rounded,
                    label: "Scan QR",
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const ForesterQrScanner(),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: _buildActionCard(
                    icon: Icons.forest_rounded,
                    label: "Tree Mapping",
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ForesterTreeMapping(
                            foresterId: widget.foresterId,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),

            const SizedBox(height: 28),

            // Stats section
            StreamBuilder<QuerySnapshot>(
              key: ValueKey(_refreshKey),
              stream: FirebaseFirestore.instance
                  .collection('appointments')
                  .where('foresterIds', arrayContains: widget.foresterId)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(40.0),
                      child: CircularProgressIndicator(
                        color: Color(0xFF2E7D32),
                        strokeWidth: 2.5,
                      ),
                    ),
                  );
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return _buildEmptyStats();
                }

                final docs = snapshot.data!.docs;
                int total = docs.length;
                int pending = 0;
                int inProgress = 0;
                int completed = 0;

                for (var doc in docs) {
                  final status = doc['status'] ?? 'Pending';
                  if (status == 'Pending')
                    pending++;
                  else if (status == 'In Progress')
                    inProgress++;
                  else if (status == 'Completed') completed++;
                }

                return _buildStatsSection(
                    total, pending, inProgress, completed);
              },
            ),

            const SizedBox(height: 30),
          ],
        ),
      ),
    ),
    );
  }

  Widget _buildActionCard({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.green[50],
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.green[100]!, width: 1),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.green[800],
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: Colors.white, size: 28),
            ),
            const SizedBox(height: 14),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.green[900],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyStats() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.green[50],
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.green[100]!, width: 1),
      ),
      child: Column(
        children: [
          Icon(Icons.bar_chart_rounded, size: 40, color: Colors.green[300]),
          const SizedBox(height: 12),
          Text(
            'No appointments yet',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.green[800],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Your stats will appear here.',
            style: TextStyle(fontSize: 13, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsSection(
      int total, int pending, int inProgress, int completed) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Overview',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Colors.green[900],
          ),
        ),
        const SizedBox(height: 16),

        // Total appointments highlight
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.green[800]!, Colors.green[600]!],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.calendar_today_rounded,
                    color: Colors.white, size: 22),
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Total Appointments',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.white70,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    total.toString(),
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 12),

        // Status breakdown
        Row(
          children: [
            Expanded(
              child: _buildStatTile(
                label: 'Pending',
                value: pending.toString(),
                icon: Icons.schedule_rounded,
                color: Colors.green[700]!,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildStatTile(
                label: 'In Progress',
                value: inProgress.toString(),
                icon: Icons.trending_up_rounded,
                color: Colors.green[800]!,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildStatTile(
                label: 'Done',
                value: completed.toString(),
                icon: Icons.check_circle_outline_rounded,
                color: Colors.green[900]!,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatTile({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.15), width: 1),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 10),
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: color.withOpacity(0.7),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
