import 'package:flutter/material.dart';
import 'package:treesure_app/features/applicant%20list%20navbars/history_page.dart';
import 'package:treesure_app/features/home/applicant_homepage.dart';
import 'package:treesure_app/features/applicant%20list%20navbars/notif_page.dart';
import 'package:treesure_app/features/applicant%20list%20navbars/profile_page.dart';

class ApplicantNavbar extends StatefulWidget {
  const ApplicantNavbar({super.key});

  @override
  ApplicantNavbarState createState() => ApplicantNavbarState();
}

class ApplicantNavbarState extends State<ApplicantNavbar> {
  int _currentIndex = 0;

  final List<Widget> _pages = const [
    ApplicantHomepage(),
    HistoryPage(),
    NotifPage(),
    ProfilePage(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

   @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: IndexedStack(
          index: _currentIndex,
          children: _pages,
        ),
      ),
      bottomNavigationBar: Material(
        elevation: 8, // Adds shadow effect
        color: const Color(0xFFF5F5F5), // Dirty white background
        child: BottomNavigationBar(
          type: BottomNavigationBarType.fixed,
          backgroundColor: const Color(0xFFF5F5F5), // Matches dirty white
          selectedItemColor: Colors.green,      // Green selected icon
          unselectedItemColor: Colors.green,    // Green unselected icon
          currentIndex: _currentIndex,
          onTap: _onItemTapped,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home),
              label: "Home",
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.history),
              label: "History",
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.notifications),
              label: "Notifications",
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person),
              label: "Profile",
            ),
          ],
        ),
      ),
    );
  }
}
