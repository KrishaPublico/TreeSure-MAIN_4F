import 'package:flutter/material.dart';

class PermitToCutPage extends StatefulWidget {
  const PermitToCutPage({Key? key}) : super(key: key);

  @override
  _PermitToCutPageState createState() => _PermitToCutPageState();
}

class _PermitToCutPageState extends State<PermitToCutPage> {
  final List<String> requirements = [
    "1. Letter request to be addressed to:\n   FORESTER JOSELITO D. RAZON\n   CENR Officer\n   DENR-CENRO APARRI\n   Punta, Aparri, Cagayan",
    "2. Barangay Certification interposing no objection on the cutting of trees.",
    "3. Certified copy of Title/Electronic Copy of Title.",
    "4. Special Power of Attorney (SPA) / Deed of Sale from the owner of the Land Title (If the applicant is not the owner of the Titled lot)",
  ];

  Widget buildUploadField(String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(fontSize: 16),
                ),
              ),
              ElevatedButton(
                onPressed: () {
                  // Non-functional button (no upload yet)
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green[700],
                  foregroundColor: Colors.white,
                ),
                child: const Text("Upload File"),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void handleSubmit() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Submit button pressed (file upload disabled).'),
        backgroundColor: Colors.green[700],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Issuance of Tree Cutting Permit'),
        backgroundColor: Colors.green[700],
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'ISSUANCE OF TREE CUTTING PERMIT WITHIN TITLED LOT/PRIVATE LOT',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            const Text(
              'REQUIREMENTS:',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),

            // Requirement Upload Buttons (non-functional)
            for (String label in requirements) buildUploadField(label),

            const SizedBox(height: 24),

            const Text(
              'Seedling Replacement as per DENR Memorandum No. 2012-02 '
              '(one (1) Tree = 50 indigenous seedlings)',
              style: TextStyle(
                fontSize: 16,
                fontStyle: FontStyle.italic,
              ),
            ),

            const SizedBox(height: 32),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: handleSubmit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green[700],
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Submit',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}
