import 'package:flutter/material.dart';

// ✅ Correct applicant page imports
import 'package:treesure_app/features/applicant list navbars/history_page.dart';
import 'package:treesure_app/features/applicant list navbars/notif_page.dart';
import 'package:treesure_app/features/applicant list navbars/profile_page.dart';
import 'package:treesure_app/features/home/applicant_homepage.dart';

class ApplicantNavbar extends StatefulWidget {
  final String applicantId; // comes from login
  final String applicantName; // comes from login

  const ApplicantNavbar({
    super.key,
    required this.applicantId,
    required this.applicantName,
  });

  @override
  State<ApplicantNavbar> createState() => _ApplicantNavbarState();
}

class _ApplicantNavbarState extends State<ApplicantNavbar> {
  int _currentIndex = 0;
  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();

   _pages = [
  ApplicantHomepage(
    applicantId: widget.applicantId,
    applicantName: widget.applicantName,
  ),
  HistoryPage(
    applicantId: widget.applicantId,
  ),
  const NotifPage(), // ✅ No parameters needed
 
  ProfilePage(
    userId: widget.applicantId, // ✅ Matches your ProfilePage parameter
  ),
];

  }

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
        elevation: 8,
        color: const Color(0xFFF5F5F5),
        child: BottomNavigationBar(
          type: BottomNavigationBarType.fixed,
          backgroundColor: const Color(0xFFF5F5F5),
          selectedItemColor: Colors.green,
          unselectedItemColor: Colors.green,
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
