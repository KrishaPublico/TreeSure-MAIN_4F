import 'package:flutter/material.dart';

class SummaryReportsPage extends StatelessWidget {
  final String applicantId;
  final String applicantName;
  const SummaryReportsPage(
      {super.key, required this.applicantId, required this.applicantName});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.green[700],
        title: const Text(
          "Summary Reports",
          style: TextStyle(
            color: Colors.white, // White color
            fontWeight: FontWeight.normal, // No bold
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white), // White back icon
      ),
      body: const Center(
        child: Text(
          "This is the Summary Reports Page",
          style: TextStyle(fontSize: 15),
        ),
      ),
    );
  }
}
