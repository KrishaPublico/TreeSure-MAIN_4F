import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class SignupPage extends StatefulWidget {
  final String role;

  const SignupPage({super.key, required this.role});

  @override
  State<SignupPage> createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _contactController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();

  bool _obscurePassword = true;
  bool _isLoading = false;

  static const _primaryGreen = Color(0xFF2E7D32);
  static const _darkGreen = Color(0xFF1B5E20);

  Future<void> _signup() async {
    final name = _nameController.text.trim();
    final username = _usernameController.text.trim();
    final password = _passwordController.text.trim();
    final contact = _contactController.text.trim();
    final address = _addressController.text.trim();

    if (name.isEmpty ||
        username.isEmpty ||
        password.isEmpty ||
        contact.isEmpty ||
        address.isEmpty) {
      _showSnackBar("Please fill in all fields.", Colors.red);
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final usersCollection = FirebaseFirestore.instance.collection('users');

      // Check if username already exists
      final existingUser = await usersCollection
          .where('username', isEqualTo: username)
          .limit(1)
          .get();

      if (existingUser.docs.isNotEmpty) {
        _showSnackBar("Username already exists. Try another.", Colors.red);
        setState(() {
          _isLoading = false;
        });
        return;
      }

      // Generate new sequential ID
      final querySnapshot = await usersCollection.get();
      List<int> existingIds = [];
      for (var doc in querySnapshot.docs) {
        final id = doc.id;
        if (int.tryParse(id) != null) {
          existingIds.add(int.parse(id));
        }
      }
      existingIds.sort();
      final newId = existingIds.isEmpty
          ? '001'
          : (existingIds.last + 1).toString().padLeft(3, '0');

      // Add user with numeric ID
      await usersCollection.doc(newId).set({
        'name': name,
        'username': username,
        'password': password,
        'contact': contact,
        'address': address,
        'role': widget.role,
        'createdAt': FieldValue.serverTimestamp(),
      });

      _showSnackBar(
          "Signed up successfully as ${widget.role.toUpperCase()}!",
          _primaryGreen);

      // Clear fields
      _nameController.clear();
      _usernameController.clear();
      _passwordController.clear();
      _contactController.clear();
      _addressController.clear();
    } catch (e) {
      _showSnackBar("Error: $e", Colors.red);
    } finally {
      setState(() {
        _isLoading = false;
      });
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
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [_darkGreen, _primaryGreen, Color(0xFFE8F5E9)],
            stops: [0.0, 0.3, 1.0],
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
                  child: Row(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withAlpha(30),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.arrow_back_rounded,
                              color: Colors.white),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ),
                      const SizedBox(width: 16),
                      const Text(
                        'Create Account',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          fontFamily: 'Poppins',
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 8),

                // Icon
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(30),
                    borderRadius: BorderRadius.circular(22),
                    border:
                        Border.all(color: Colors.white.withAlpha(50), width: 2),
                  ),
                  child: const Icon(
                    Icons.person_add_rounded,
                    color: Colors.white,
                    size: 36,
                  ),
                ),

                const SizedBox(height: 12),

                Text(
                  'Join as ${widget.role}',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    fontFamily: 'Poppins',
                  ),
                ),

                const SizedBox(height: 4),

                Text(
                  'Fill in your details to get started',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.white.withAlpha(200),
                    fontFamily: 'Poppins',
                  ),
                ),

                const SizedBox(height: 24),

                // White card form
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.symmetric(horizontal: 20),
                  padding: const EdgeInsets.all(24),
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
                      // Section header
                      Row(
                        children: [
                          Container(
                            width: 4,
                            height: 20,
                            decoration: BoxDecoration(
                              color: _primaryGreen,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          const SizedBox(width: 10),
                          const Text(
                            'Personal Information',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: _darkGreen,
                              fontFamily: 'Poppins',
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 20),

                      _buildTextField(
                        controller: _nameController,
                        hint: 'Full Name',
                        icon: Icons.person_outline_rounded,
                      ),
                      const SizedBox(height: 14),

                      _buildTextField(
                        controller: _usernameController,
                        hint: 'Username',
                        icon: Icons.alternate_email_rounded,
                      ),
                      const SizedBox(height: 14),

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

                      const SizedBox(height: 24),

                      // Contact section
                      Row(
                        children: [
                          Container(
                            width: 4,
                            height: 20,
                            decoration: BoxDecoration(
                              color: _primaryGreen,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          const SizedBox(width: 10),
                          const Text(
                            'Contact Details',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: _darkGreen,
                              fontFamily: 'Poppins',
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 20),

                      _buildTextField(
                        controller: _contactController,
                        hint: 'Contact Number',
                        icon: Icons.phone_outlined,
                      ),
                      const SizedBox(height: 14),

                      _buildTextField(
                        controller: _addressController,
                        hint: 'Address',
                        icon: Icons.location_on_outlined,
                      ),

                      const SizedBox(height: 28),

                      // Sign Up button
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: _isLoading
                            ? const Center(
                                child: SizedBox(
                                  width: 28,
                                  height: 28,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                        _primaryGreen),
                                  ),
                                ),
                              )
                            : Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: _signup,
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
                                    child: const Center(
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(Icons.how_to_reg_rounded,
                                              color: Colors.white, size: 20),
                                          SizedBox(width: 10),
                                          Text(
                                            'Sign Up',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 17,
                                              fontWeight: FontWeight.w700,
                                              fontFamily: 'Poppins',
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                      ),

                      const SizedBox(height: 16),

                      // Already have account
                      Center(
                        child: GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: RichText(
                            text: TextSpan(
                              text: 'Already have an account? ',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[500],
                                fontFamily: 'Poppins',
                              ),
                              children: const [
                                TextSpan(
                                  text: 'Log In',
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
                  ),
                ),

                const SizedBox(height: 32),
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

