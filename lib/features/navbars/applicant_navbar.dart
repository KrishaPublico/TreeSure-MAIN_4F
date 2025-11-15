import 'package:flutter/material.dart';
import 'package:treesure_app/features/home/applicant_homepage.dart';
import 'package:treesure_app/features/applicant%20list%20navbars/notif_page.dart';
import 'package:treesure_app/features/applicant%20list%20navbars/profile_page.dart';

import '../applicant list navbars/applicant_summary_reports.dart';

class ApplicantNavbar extends StatefulWidget {
  final String applicantId; // comes from login
  final String applicantName; // comes from login

  const ApplicantNavbar({
    super.key,
    required this.applicantId,
    required this.applicantName,
  });

  @override
  ApplicantNavbarState createState() => ApplicantNavbarState();
}

class ApplicantNavbarState extends State<ApplicantNavbar> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final List<Widget> pages = [
      ApplicantHomepage(
        applicantId: widget.applicantId,
        applicantName: widget.applicantName,
      ),
      ApplicantSummaryPage(
        applicantName: widget.applicantName,
        applicantId: widget.applicantId,
      ),
      NotifPage(
        applicantName: widget.applicantName,
        applicantId: widget.applicantId,
      ),
      ProfilePage(
       userId: widget.applicantId,
      ),
    ];

    return Scaffold(
      body: SafeArea(
        child: IndexedStack(
          index: _currentIndex,
          children: pages,
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
          onTap: (index) {
            setState(() {
              _currentIndex = index;
            });
          },
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home),
              label: "Home",
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.pages),
              label: "Reports",
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