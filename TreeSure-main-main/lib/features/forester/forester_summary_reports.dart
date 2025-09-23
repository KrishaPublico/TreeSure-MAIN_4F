import 'package:flutter/material.dart';

class ForesterSummaryReports extends StatelessWidget {
  const ForesterSummaryReports({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor:Colors.green[800],
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
