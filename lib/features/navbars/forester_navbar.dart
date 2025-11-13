import 'package:flutter/material.dart';

import 'package:treesure_app/features/forester/forester_summary_reports.dart';
import 'package:treesure_app/features/forester%20list%20of%20navbars/notif_page.dart';
import 'package:treesure_app/features/forester%20list%20of%20navbars/profile_page.dart';
import 'package:treesure_app/features/home/forester_homepage.dart';

class ForesterNavbar extends StatefulWidget {
  final String foresterId; // comes from login
  final String foresterName; // comes from login
  const ForesterNavbar(
      {super.key, required this.foresterId, required this.foresterName});

  @override
  ForesterNavbarState createState() => ForesterNavbarState();
}

class ForesterNavbarState extends State<ForesterNavbar> {
  int _currentIndex = 0;
  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _pages = [
      ForesterHomepage(
        foresterId: widget.foresterId,
        foresterName: widget.foresterName,
      ),
      ForesterSummaryReports(foresterId: widget.foresterId),
      NotifPage_Forester(
        applicantName: widget.foresterName,
        foresterId: widget.foresterId,
        foresterName: widget.foresterName,
      ),
      ProfilePage_Forester(
        foresterName: widget.foresterName,
        foresterId: widget.foresterId,
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
        elevation: 8, // Adds shadow effect
        color: const Color(0xFFF5F5F5), // Dirty white background
        child: BottomNavigationBar(
          type: BottomNavigationBarType.fixed,
          backgroundColor: const Color(0xFFF5F5F5), // Matches dirty white
          selectedItemColor: Colors.green, // Green selected icon
          unselectedItemColor: Colors.green, // Green unselected icon
          currentIndex: _currentIndex,
          onTap: _onItemTapped,
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
