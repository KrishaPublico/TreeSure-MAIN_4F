import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:treesure_app/features/navbars/applicant_navbar.dart';
import 'package:treesure_app/features/navbars/forester_navbar.dart';

class LoginPage extends StatefulWidget {
  final String role; // Role passed from RolePage

  const LoginPage({super.key, required this.role});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _obscurePassword = true;

  Future<void> _login(BuildContext context) async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please enter both email and password."),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      // Query Firestore for this username
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
          // ✅ Role matches → Navigate to correct navbar
          if (dbRole == "Forester") {
            final String foresterId = doc.id; // Document ID
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
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const ApplicantNavbar()),
            );
          }
        } else {
          // ❌ Wrong role
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content:
                  Text("You are registered as $dbRole, not ${widget.role}."),
              backgroundColor: Colors.red,
            ),
          );
        }
      } else {
        // ❌ Invalid credentials
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Invalid username or password."),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error: $e"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 30),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                "TreeSure - ${widget.role} Login",
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.green[900],
                ),
              ),
              const SizedBox(height: 30),

              // Email
              TextFormField(
                controller: _emailController,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.email, color: Colors.white),
                  hintText: "Email / Username",
                  filled: true,
                  fillColor: Colors.green,
                  hintStyle: const TextStyle(color: Colors.white),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                ),
                style: const TextStyle(color: Colors.white),
              ),
              const SizedBox(height: 15),

              // Password
              TextFormField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.vpn_key, color: Colors.white),
                  hintText: "Password",
                  filled: true,
                  fillColor: Colors.green,
                  hintStyle: const TextStyle(color: Colors.white),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_off
                          : Icons.visibility,
                      color: Colors.white,
                    ),
                    onPressed: () {
                      setState(() {
                        _obscurePassword = !_obscurePassword;
                      });
                    },
                  ),
                ),
                style: const TextStyle(color: Colors.white),
              ),
              const SizedBox(height: 20),

              // Login Button
              ElevatedButton(
                onPressed: () => _login(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green.shade800,
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text(
                  "Log In",
                  style: TextStyle(fontSize: 18, color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
