import 'package:flutter/material.dart';
import '../roles/roles_page.dart';

class IntroPage extends StatelessWidget {
  const IntroPage({super.key});

  static const _primaryGreen = Color(0xFF2E7D32);
  static const _darkGreen = Color(0xFF1B5E20);

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

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
              Color(0xFFE8F5E9),
            ],
            stops: [0.0, 0.3, 0.7, 1.0],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              const Spacer(flex: 2),

              // Decorative circle behind logo
              Container(
                width: size.width * 0.52,
                height: size.width * 0.52,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      const Color(0xFFE8F5E9),
                      const Color(0xFFC8E6C9).withAlpha(80),
                      Colors.transparent,
                    ],
                    stops: const [0.3, 0.7, 1.0],
                  ),
                ),
                child: Center(
                  child: Image.asset(
                    'assets/treesurelogo.png',
                    width: size.width * 0.38,
                    fit: BoxFit.contain,
                  ),
                ),
              ),

              const SizedBox(height: 32),

              // Title with leaf
              SizedBox(
                height: 64,
                child: Stack(
                  alignment: Alignment.center,
                  clipBehavior: Clip.none,
                  children: [
                    const Text(
                      'TreeSure',
                      style: TextStyle(
                        fontSize: 44,
                        fontWeight: FontWeight.w800,
                        color: _darkGreen,
                        fontFamily: 'Poppins',
                        letterSpacing: -0.5,
                      ),
                    ),
                    Positioned(
                      top: -14,
                      right: 58,
                      child: Image.asset(
                        'assets/treesure_leaf.png',
                        height: 30,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // Tagline
              Text(
                'Protect. Track. Grow.',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: _primaryGreen.withAlpha(180),
                  fontFamily: 'Poppins',
                  letterSpacing: 2.0,
                ),
              ),

              const Spacer(flex: 3),

              // Get Started button
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const RolePage(),
                      ),
                    ),
                    borderRadius: BorderRadius.circular(16),
                    child: Ink(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [_darkGreen, _primaryGreen],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: _primaryGreen.withAlpha(80),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'Get Started',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 20,
                                fontFamily: 'Poppins',
                              ),
                            ),
                            SizedBox(width: 10),
                            Icon(
                              Icons.arrow_forward_rounded,
                              color: Colors.white,
                              size: 22,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Version text
              Text(
                'v1.0.0',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[400],
                  fontFamily: 'Poppins',
                ),
              ),

              const Spacer(flex: 1),
            ],
          ),
        ),
      ),
    );
  }
}
