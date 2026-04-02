import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:treesure_app/features/navbars/applicant_navbar.dart';
import 'package:treesure_app/features/navbars/forester_navbar.dart';
import 'package:treesure_app/features/signup/signup_page.dart';
import '../roles/roles_page.dart';

class LoginPage extends StatefulWidget {
  final String role;

  const LoginPage({super.key, required this.role});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;

  static const _primaryGreen = Color(0xFF2E7D32);
  static const _darkGreen = Color(0xFF1B5E20);

  Future<void> _login(BuildContext context) async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      _showSnackBar("Please enter both email and password.", Colors.red);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final query = await FirebaseFirestore.instance
          .collection('users')
          .where('username', isEqualTo: email)
          .where('password', isEqualTo: password)
          .limit(1)
          .get();

      if (query.docs.isNotEmpty) {
        final doc = query.docs.first;
        final userData = doc.data();
        final String dbRole = userData['role'] ?? "Unknown";

        if (dbRole.toLowerCase() == widget.role.toLowerCase()) {
          if (dbRole == "Forester") {
            final String foresterId = doc.id;
            final String foresterName = userData['name'] ?? "Unknown Forester";

            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (_) => ForesterNavbar(
                  foresterId: foresterId,
                  foresterName: foresterName,
                ),
              ),
            );
          } else if (dbRole == "Applicant") {
            final String applicantId = doc.id;
            final String applicantName =
                userData['name'] ?? "Unknown Applicant";

            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (_) => ApplicantNavbar(
                  applicantId: applicantId,
                  applicantName: applicantName,
                ),
              ),
            );
          }
        } else {
          _showSnackBar(
              "You are registered as $dbRole, not ${widget.role}.", Colors.red);
        }
      } else {
        _showSnackBar("Invalid username or password.", Colors.red);
      }
    } catch (e) {
      _showSnackBar("Error: $e", Colors.red);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isForester = widget.role.toLowerCase() == 'forester';

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [_darkGreen, _primaryGreen, Color(0xFFE8F5E9)],
            stops: [0.0, 0.35, 1.0],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            child: Column(
              children: [
                // Top section with back button
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withAlpha(30),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.arrow_back_rounded,
                            color: Colors.white),
                        onPressed: () => Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const RolePage()),
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 8),

                // Role icon
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(30),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                        color: Colors.white.withAlpha(50), width: 2),
                  ),
                  child: Icon(
                    isForester ? Icons.forest_rounded : Icons.person_rounded,
                    color: Colors.white,
                    size: 40,
                  ),
                ),

                const SizedBox(height: 16),

                Text(
                  widget.role,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    fontFamily: 'Poppins',
                    letterSpacing: -0.5,
                  ),
                ),

                const SizedBox(height: 4),

                Text(
                  'Sign in to continue',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white.withAlpha(200),
                    fontFamily: 'Poppins',
                  ),
                ),

                const SizedBox(height: 32),

                // White card form area
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.symmetric(horizontal: 20),
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withAlpha(15),
                        blurRadius: 24,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Welcome back',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: _darkGreen,
                          fontFamily: 'Poppins',
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Enter your credentials to log in',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[500],
                          fontFamily: 'Poppins',
                        ),
                      ),

                      const SizedBox(height: 28),

                      // Username field
                      _buildTextField(
                        controller: _emailController,
                        hint: 'Username',
                        icon: Icons.person_outline_rounded,
                      ),

                      const SizedBox(height: 16),

                      // Password field
                      _buildTextField(
                        controller: _passwordController,
                        hint: 'Password',
                        icon: Icons.lock_outline_rounded,
                        obscure: _obscurePassword,
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            color: Colors.grey[400],
                            size: 20,
                          ),
                          onPressed: () => setState(
                              () => _obscurePassword = !_obscurePassword),
                        ),
                      ),

                      const SizedBox(height: 28),

                      // Login button
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: _isLoading ? null : () => _login(context),
                            borderRadius: BorderRadius.circular(16),
                            child: Ink(
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [_darkGreen, _primaryGreen],
                                ),
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: _primaryGreen.withAlpha(60),
                                    blurRadius: 14,
                                    offset: const Offset(0, 6),
                                  ),
                                ],
                              ),
                              child: Center(
                                child: _isLoading
                                    ? const SizedBox(
                                        width: 24,
                                        height: 24,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2.5,
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                                  Colors.white),
                                        ),
                                      )
                                    : const Text(
                                        'Log In',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 17,
                                          fontWeight: FontWeight.w700,
                                          fontFamily: 'Poppins',
                                        ),
                                      ),
                              ),
                            ),
                          ),
                        ),
                      ),

                      // Sign up link (only for applicants)
                      if (!isForester) ...[
                        const SizedBox(height: 20),
                        Center(
                          child: GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      SignupPage(role: widget.role),
                                ),
                              );
                            },
                            child: RichText(
                              text: TextSpan(
                                text: "Don't have an account? ",
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[500],
                                  fontFamily: 'Poppins',
                                ),
                                children: const [
                                  TextSpan(
                                    text: 'Sign Up',
                                    style: TextStyle(
                                      color: _primaryGreen,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool obscure = false,
    Widget? suffixIcon,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF5F7F5),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE8E8E8)),
      ),
      child: TextFormField(
        controller: controller,
        obscureText: obscure,
        style: const TextStyle(
          fontSize: 15,
          fontFamily: 'Poppins',
          color: Color(0xFF2D2D2D),
        ),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(
            color: Colors.grey[400],
            fontSize: 14,
            fontFamily: 'Poppins',
          ),
          prefixIcon: Container(
            margin: const EdgeInsets.all(10),
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: const Color(0xFFE8F5E9),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: _primaryGreen, size: 18),
          ),
          suffixIcon: suffixIcon,
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
      ),
    );
  }
}
