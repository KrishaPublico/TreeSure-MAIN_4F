import 'package:flutter/material.dart';

import 'package:treesure_app/features/forester%20list%20of%20navbars/history_page.dart';
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
      const HistoryPage_Forester(),
      NotifPage_Forester(
  foresterId: widget.foresterId,
  foresterName: widget.foresterName,
  applicantName: '', // ✅ Required by your NotifPage_Forester constructor
),
     ProfilePage_Forester(
  foresterId: widget.foresterId,
  foresterName: widget.foresterName,
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
