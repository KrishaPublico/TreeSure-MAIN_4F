import 'package:flutter/material.dart';
import 'pltp.dart'; // Ensure this path is correct
import 'splt.dart';

class CuttingPermitPage extends StatefulWidget {
  final String applicantId;
  final String applicantName;

  const CuttingPermitPage({
    super.key,
    required this.applicantId,
    required this.applicantName,
  });

  @override
  State<CuttingPermitPage> createState() => _CuttingPermitPageState();
}

class _CuttingPermitPageState extends State<CuttingPermitPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Cutting Permit Options',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.green[700],
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildCardButton(
            context,
            "Private Land Timber Permit (PLTP)",
            () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => PLTPFormPage(
                    applicantId: widget.applicantId,
                    applicantName: widget.applicantName,
                  ),
                ),
              );
            },
          ),
          _buildCardButton(
            context,
            "Special Land Timber Permit (SPLT)",
            () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => SPLTFormPage(
                    applicantName: widget.applicantName,
                    applicantId: widget.applicantId,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildCardButton(
      BuildContext context, String title, VoidCallback onPressed) {
    return Card(
      color: Colors.green[700],
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(12),
        splashColor: Colors.green[200],
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}
