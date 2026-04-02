import 'package:flutter/material.dart';
import 'package:treesure_app/features/applicant/ctpo.dart';
import 'package:treesure_app/features/applicant/CuttingPermit.dart';
import 'package:treesure_app/features/applicant/applicant_qr_scanner.dart';
import 'package:treesure_app/features/applicant/cov.dart  ';
import 'package:treesure_app/features/applicant/chainsawreg.dart';

class ApplicantHomepage extends StatelessWidget {
  final String applicantId;
  final String applicantName;

  static const _primaryGreen = Color(0xFF2E7D32);
  static const _darkGreen = Color(0xFF1B5E20);
  static const _lightGreen = Color(0xFFE8F5E9);
  static const _surfaceColor = Color(0xFFF5F8F5);

  const ApplicantHomepage({
    super.key,
    required this.applicantId,
    required this.applicantName,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _surfaceColor,
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Modern gradient header
            _buildHeader(context),

            const SizedBox(height: 36),

            // Quick Actions row
            _buildQuickActions(context),

            const SizedBox(height: 28),

            // Tree Restrictions Section
            _buildSectionHeader(
              icon: Icons.info_outline_rounded,
              title: 'Protected Trees',
              subtitle: 'Trees not allowed to cut',
            ),
            const SizedBox(height: 12),

            _buildTreeRestrictionCard(
              'Trees marked by the DENR as Significant or Important',
              'assets/pic1.jpg',
              Icons.verified_rounded,
            ),
            _buildTreeRestrictionCard(
              'Century-old trees, even if not officially tagged',
              'assets/pic2.jpg',
              Icons.park_rounded,
            ),
            _buildTreeRestrictionCard(
              'Trees that add beauty to public areas',
              'assets/pic3.JPG',
              Icons.nature_rounded,
            ),

            const SizedBox(height: 28),

            // Permits Section
            _buildSectionHeader(
              icon: Icons.description_rounded,
              title: 'Permits & Certificates',
              subtitle: 'Apply for permits',
            ),
            const SizedBox(height: 12),

            _buildPermitCard(
              context,
              title: 'CTPO',
              subtitle: 'Certificate of Tree Plantation Ownership',
              icon: Icons.eco_rounded,
              color: const Color(0xFF2E7D32),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => CTPOUploadPage(
                    applicantId: applicantId,
                    applicantName: applicantName,
                  ),
                ),
              ),
            ),
            _buildPermitCard(
              context,
              title: 'Cutting Permit',
              subtitle: 'Request permission to cut trees',
              icon: Icons.content_cut_rounded,
              color: const Color(0xFF388E3C),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => CuttingPermitPage(
                    applicantId: applicantId,
                    applicantName: applicantName,
                  ),
                ),
              ),
            ),
            _buildPermitCard(
              context,
              title: 'Transport Permit',
              subtitle: 'Certificate of verification for transport',
              icon: Icons.local_shipping_rounded,
              color: const Color(0xFF43A047),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => CovFormPage(
                    applicantName: applicantName,
                    applicantId: applicantId,
                  ),
                ),
              ),
            ),
            _buildPermitCard(
              context,
              title: 'Chainsaw Registration',
              subtitle: 'Register your chainsaw equipment',
              icon: Icons.carpenter_rounded,
              color: const Color(0xFF4CAF50),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ChainsawRegistrationPage(
                    applicantName: applicantName,
                    applicantId: applicantId,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_darkGreen, _primaryGreen, Color(0xFF43A047)],
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(32),
          bottomRight: Radius.circular(32),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
          child: Column(
            children: [
              // Top row with logo
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Image.asset('assets/treesure_leaf.png', height: 28),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'TreeSure',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 1,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Avatar with ring
              Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withOpacity(0.4),
                    width: 2,
                  ),
                ),
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                  ),
                  child: const CircleAvatar(
                    radius: 32,
                    backgroundColor: _lightGreen,
                    child: Icon(Icons.person_rounded, size: 36, color: _primaryGreen),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Welcome text
              Text(
                'Welcome back,',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.white.withOpacity(0.8),
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                applicantName,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'ID: $applicantId',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withOpacity(0.9),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Expanded(
            child: _buildQuickActionCard(
              context,
              icon: Icons.qr_code_scanner_rounded,
              label: 'Scan QR',
              color: _primaryGreen,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ApplicantQrScanner(),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildQuickActionCard(
              context,
              icon: Icons.eco_rounded,
              label: 'My Trees',
              color: const Color(0xFF388E3C),
              onTap: () {},
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildQuickActionCard(
              context,
              icon: Icons.assignment_rounded,
              label: 'Status',
              color: const Color(0xFF43A047),
              onTap: () {},
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionCard(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.08),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: color, size: 26),
              ),
              const SizedBox(height: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _primaryGreen.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: _primaryGreen, size: 20),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: _darkGreen,
                ),
              ),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTreeRestrictionCard(String text, String imagePath, IconData badge) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            // Image thumbnail
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: _primaryGreen.withOpacity(0.15),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Image.asset(imagePath, fit: BoxFit.cover),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(badge, size: 16, color: _primaryGreen),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF3E0),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'Protected',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFFE65100),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    text,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey.shade800,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPermitCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.06),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [color, color.withOpacity(0.7)],
                    ),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, color: Colors.white, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: _darkGreen,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                          height: 1.2,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _lightGreen,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 14,
                    color: _primaryGreen,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
