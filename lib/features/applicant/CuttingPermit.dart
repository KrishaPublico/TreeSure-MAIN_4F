import 'package:flutter/material.dart';
import 'pltp.dart';
import 'splt.dart';

class CuttingPermitPage extends StatefulWidget {
  final String applicantId;
  final String applicantName;

  const CuttingPermitPage({
    super.key,
    required this.applicantId,
    required this.applicantName,
  });

  @override
  State<CuttingPermitPage> createState() => _CuttingPermitPageState();
}

class _CuttingPermitPageState extends State<CuttingPermitPage> {
  static const Color _primaryGreen = Color(0xFF2E7D32);
  static const Color _darkGreen = Color(0xFF1B5E20);
  static const Color _lightGreen = Color(0xFFE8F5E9);
  static const Color _surfaceColor = Color(0xFFF1F8E9);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _surfaceColor,
      body: CustomScrollView(
        slivers: [
          // Gradient Header
          SliverToBoxAdapter(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [_darkGreen, _primaryGreen, Color(0xFF43A047)],
                ),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(28),
                  bottomRight: Radius.circular(28),
                ),
              ),
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          InkWell(
                            onTap: () => Navigator.pop(context),
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 22),
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Cutting Permit',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  'Select permit type to proceed',
                                  style: TextStyle(fontSize: 13, color: Colors.white70),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.info_outline_rounded, color: Colors.white70, size: 20),
                            SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Choose the type of cutting permit based on your land classification.',
                                style: TextStyle(fontSize: 12, color: Colors.white70),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          // Cards
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                const SizedBox(height: 8),
                _buildPermitCard(
                  context,
                  title: "Private Land Timber Permit",
                  subtitle: "PLTP",
                  description: "For cutting trees within private/titled lands",
                  icon: Icons.landscape_rounded,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => PLTPFormPage(
                          applicantId: widget.applicantId,
                          applicantName: widget.applicantName,
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 12),
                _buildPermitCard(
                  context,
                  title: "Special Land Timber Permit",
                  subtitle: "SPLT",
                  description: "For premium/naturally grown trees within private lands",
                  icon: Icons.park_rounded,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => SPLTFormPage(
                          applicantName: widget.applicantName,
                          applicantId: widget.applicantId,
                        ),
                      ),
                    );
                  },
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPermitCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required String description,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [_primaryGreen, Color(0xFF43A047)],
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(icon, color: Colors.white, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: _lightGreen,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          subtitle,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: _primaryGreen,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1A1A1A),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        description,
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: _lightGreen,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.arrow_forward_rounded, color: _primaryGreen, size: 20),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
