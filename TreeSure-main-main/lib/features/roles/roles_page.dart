import 'package:flutter/material.dart';
import 'package:treesure_app/features/login/login_page.dart';
import '../intro/intro_page.dart'; // 👈 import IntroPage so we can go back

class RolePage extends StatelessWidget {
  const RolePage({super.key});

  @override
  Widget build(BuildContext context) {
    final double buttonWidth = 200; // ✅ consistent width for all buttons

    final ButtonStyle commonButtonStyle = ElevatedButton.styleFrom(
      backgroundColor: const Color(0xFF175B19), // ✅ unified green color
      foregroundColor: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 15),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(25),
      ),
      textStyle: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
      ),
    );

    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // ✅ Logo
            Image.asset(
              "assets/treesurelogo.png",
              height: MediaQuery.of(context).size.width * 0.45,
            ),

            const SizedBox(height: 15),

            // ✅ Title
            const Text(
              "TreeSure",
              style: TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.bold,
                color: Color(0xFF175B19),
              ),
            ),

            const SizedBox(height: 20),

            // ✅ Instruction
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                "Choose your role to continue:",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ),

            const SizedBox(height: 30),

            // ✅ Forester Button
            SizedBox(
              width: buttonWidth,
              child: ElevatedButton(
                style: commonButtonStyle,
                onPressed: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          const LoginPage(role: "Forester"),
                    ),
                  );
                },
                child: const Text("Forester"),
              ),
            ),

            const SizedBox(height: 15),

            // ✅ Applicant Button
            SizedBox(
              width: buttonWidth,
              child: ElevatedButton(
                style: commonButtonStyle,
                onPressed: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          const LoginPage(role: "Applicant"),
                    ),
                  );
                },
                child: const Text("Applicant"),
              ),
            ),

            const SizedBox(height: 15),

            // ✅ Logout Button (same style, same color now)
            SizedBox(
              width: buttonWidth,
              child: ElevatedButton(
                style: commonButtonStyle,
                onPressed: () {
                  // Later: FirebaseAuth.instance.signOut();
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const IntroPage(),
                    ),
                  );
                },
                child: const Text("Logout"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
