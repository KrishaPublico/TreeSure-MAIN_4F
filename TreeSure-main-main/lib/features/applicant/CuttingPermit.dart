import 'package:flutter/material.dart';
import 'pltp.dart'; // Ensure this path is correct based on your project structure
import 'splt.dart';
import 'PermitToCut.dart';

class CuttingPermitPage extends StatelessWidget {
  const CuttingPermitPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cutting Permit Options', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.green[700],
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildCardButton(context, "Private Land Timber Permit (PLTP)", () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const PLTPFormPage()),
            );
          }),
          _buildCardButton(context, "Special Land Timber Permit (SPLT)", () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const SPLTFormPage()),
            );
          }),
          _buildCardButton(context, "Wood Delivery Permit", () {
            // Add navigation or functionality later
          }),
          _buildCardButton(context, "Permit to Cut", () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const PermitToCutPage()),
            );
          }),
          _buildCardButton(context, "Wood Charcoal Production Permit", () {
            // Add navigation or functionality later
          }),

          // Non Timber Dropdown
          _buildDropdownCard(
            context,
            title: "Non Timber",
            options: ["Forest Product", "Rattan", "Bamboo"],
          ),

          // Tenurial Instrument Dropdown
          _buildDropdownCard(
            context,
            title: "Tenurial Instrument",
            options: ["CPSF"],
          ),
        ],
      ),
    );
  }

  Widget _buildCardButton(BuildContext context, String title, VoidCallback onPressed) {
    return Card(
      color: Colors.green[700],
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.symmetric(vertical: 5), // Reduced spacing
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(12),
        splashColor: Colors.green[200],
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
          child: Text(
            title,
            style: const TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.w600),
          ),
        ),
      ),
    );
  }

  Widget _buildDropdownCard(BuildContext context,
      {required String title, required List<String> options}) {
    return Card(
      color: Colors.green[700],
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.symmetric(vertical: 5), // Reduced spacing
      child: Theme(
        data: Theme.of(context).copyWith(
          dividerColor: Colors.transparent,
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 20),
          childrenPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          collapsedIconColor: Colors.white,
          iconColor: Colors.white,
          title: Text(
            title,
            style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
          ),
          children: options
              .map(
                (option) => ListTile(
                  title: Text(
                    option,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                  onTap: () {
                    // Add your logic or navigation here
                  },
                ),
              )
              .toList(),
        ),
      ),
    );
  }
}
