import 'package:flutter/material.dart';
import 'package:treesure_app/features/login/login_page.dart';

class RolePage extends StatelessWidget {
  const RolePage({super.key});

  static const _primaryGreen = Color(0xFF2E7D32);
  static const _darkGreen = Color(0xFF1B5E20);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFE8F5E9),
              Colors.white,
              Colors.white,
            ],
            stops: [0.0, 0.4, 1.0],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 16),

              // Back button row
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withAlpha(15),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back_rounded,
                          color: _darkGreen),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Logo
              Image.asset(
                "assets/treesurelogo.png",
                height: MediaQuery.of(context).size.width * 0.32,
              ),

              const SizedBox(height: 16),

              const Text(
                "TreeSure",
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: _darkGreen,
                  fontFamily: 'Poppins',
                  letterSpacing: -0.5,
                ),
              ),

              const SizedBox(height: 32),

              // Section title
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F5E9),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  "Select your role",
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: _primaryGreen,
                    fontFamily: 'Poppins',
                  ),
                ),
              ),

              const SizedBox(height: 32),

              // Role cards
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  children: [
                    _buildRoleCard(
                      context: context,
                      icon: Icons.forest_rounded,
                      title: 'Forester',
                      subtitle: 'Manage and monitor tree inventory',
                      onTap: () {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                const LoginPage(role: "Forester"),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                    _buildRoleCard(
                      context: context,
                      icon: Icons.person_rounded,
                      title: 'Applicant',
                      subtitle: 'Apply for tree planting permits',
                      onTap: () {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                const LoginPage(role: "Applicant"),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),

              const Spacer(),

              // Footer
              Padding(
                padding: const EdgeInsets.only(bottom: 24),
                child: Text(
                  'Choose a role to continue',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[400],
                    fontFamily: 'Poppins',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRoleCard({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Ink(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: _primaryGreen.withAlpha(20),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
              BoxShadow(
                color: Colors.black.withAlpha(8),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
            border: Border.all(
              color: const Color(0xFFE8F5E9),
              width: 1.5,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                // Icon container
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [_darkGreen, _primaryGreen],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: _primaryGreen.withAlpha(50),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Icon(icon, color: Colors.white, size: 28),
                ),
                const SizedBox(width: 18),
                // Text
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: _darkGreen,
                          fontFamily: 'Poppins',
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[600],
                          fontFamily: 'Poppins',
                        ),
                      ),
                    ],
                  ),
                ),
                // Arrow
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F5E9),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.arrow_forward_rounded,
                    color: _primaryGreen,
                    size: 20,
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
