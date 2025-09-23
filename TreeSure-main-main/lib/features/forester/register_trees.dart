import 'package:flutter/material.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as path;

class RegisterTreesPage extends StatefulWidget {
  const RegisterTreesPage({super.key});

  @override
  State<RegisterTreesPage> createState() => _RegisterTreesPageState();
}

class _RegisterTreesPageState extends State<RegisterTreesPage> {
  final TextEditingController treeNoController = TextEditingController();
  final TextEditingController specieController = TextEditingController();
  final TextEditingController diameterController = TextEditingController();
  final TextEditingController heightController = TextEditingController();
  final TextEditingController northingController = TextEditingController();
  final TextEditingController eastingController = TextEditingController();
  final TextEditingController volumeController = TextEditingController();

  final FocusNode treeNoFocus = FocusNode();
  final FocusNode specieFocus = FocusNode();
  final FocusNode diameterFocus = FocusNode();
  final FocusNode heightFocus = FocusNode();
  final FocusNode northingFocus = FocusNode();
  final FocusNode eastingFocus = FocusNode();

  File? imageFile;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    diameterController.addListener(_updateVolume);
    heightController.addListener(_updateVolume);
  }

  void _updateVolume() {
    double diameter = double.tryParse(diameterController.text) ?? 0;
    double height = double.tryParse(heightController.text) ?? 0;
    double volume = 3.141592653589793 * (diameter / 2) * (diameter / 2) * height;
    volumeController.text = volume > 0 ? volume.toStringAsFixed(2) : '';
  }

  @override
  void dispose() {
    treeNoController.dispose();
    specieController.dispose();
    diameterController.dispose();
    heightController.dispose();
    northingController.dispose();
    eastingController.dispose();
    volumeController.dispose();

    treeNoFocus.dispose();
    specieFocus.dispose();
    diameterFocus.dispose();
    heightFocus.dispose();
    northingFocus.dispose();
    eastingFocus.dispose();

    super.dispose();
  }

  Future<void> pickImage() async {
    try {
      final XFile? picked = await _picker.pickImage(source: ImageSource.gallery);
      if (picked != null) {
        setState(() {
          imageFile = File(picked.path);
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to pick image: $e")),
      );
    }
  }

  void generateQrTag() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("QR Code generated based on tree details")),
    );
  }

  void viewSummaryDialog() {
    Map<String, dynamic> submittedData = {
      "Tree No.": treeNoController.text,
      "Specie": specieController.text,
      "Diameter (cm)": diameterController.text,
      "Height (m)": heightController.text,
      "Volume (CU m)": volumeController.text,
      "GPS Location - Northing": northingController.text,
      "GPS Location - Easting": eastingController.text,
      "Photo Evidence": imageFile != null ? path.basename(imageFile!.path) : "No image selected",
    };

    final Map<String, FocusNode> focusMap = {
      "Tree No.": treeNoFocus,
      "Specie": specieFocus,
      "Diameter (cm)": diameterFocus,
      "Height (m)": heightFocus,
      "GPS Location - Northing": northingFocus,
      "GPS Location - Easting": eastingFocus,
    };

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Tree Data Summary"),
        content: SingleChildScrollView(
          child: DataTable(
            columnSpacing: 10,
            columns: const [
              DataColumn(label: Text("Field", style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text("Value", style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text("Edit", style: TextStyle(fontWeight: FontWeight.bold))),
            ],
            rows: submittedData.entries.map((entry) {
              final key = entry.key;
              final value = entry.value.toString();
              final canEdit = focusMap.containsKey(key);

              return DataRow(cells: [
                DataCell(Text(key)),
                DataCell(Text(value)),
                DataCell(
                  canEdit
                      ? IconButton(
                          icon: Icon(Icons.edit, color: Colors.green[700]),
                          onPressed: () {
                            Navigator.of(context).pop();
                            FocusScope.of(context).requestFocus(focusMap[key]);
                          },
                        )
                      : const SizedBox.shrink(),
                ),
              ]);
            }).toList(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              "Close",
              style: TextStyle(color: Colors.green[700]),
            ),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Tree Inventory"),
        backgroundColor: Colors.green[800],
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code),
            tooltip: 'Generate QR Tag',
            onPressed: generateQrTag,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: [
            buildTextField("Tree No.", treeNoController, focusNode: treeNoFocus),
            buildTextField("Specie", specieController, focusNode: specieFocus),
            Row(
              children: [
                Expanded(child: buildTextField("Diameter (cm)", diameterController, focusNode: diameterFocus, keyboardType: TextInputType.number)),
                const SizedBox(width: 12),
                Expanded(child: buildTextField("Height (m)", heightController, focusNode: heightFocus, keyboardType: TextInputType.number)),
              ],
            ),
            buildTextField("Volume (CU m)", volumeController, enabled: false),
            const SizedBox(height: 12),
            const Text("GPS Location", style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(child: buildTextField("Northing", northingController, focusNode: northingFocus)),
                const SizedBox(width: 12),
                Expanded(child: buildTextField("Easting", eastingController, focusNode: eastingFocus)),
              ],
            ),
            const SizedBox(height: 20),
            const Text("Photo Evidence", style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            imageFile != null
                ? Image.file(imageFile!, height: 200)
                : const Text("No image selected."),
            TextButton.icon(
              icon: const Icon(Icons.upload),
              label: const Text("Upload Photo"),
              onPressed: pickImage,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Submitted")),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green[800],
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: const Text("Submit", style: TextStyle(fontSize: 16, color: Colors.white)),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: viewSummaryDialog,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green[800],
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: const Text("View Summary", style: TextStyle(fontSize: 16, color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildTextField(String label, TextEditingController controller,
      {FocusNode? focusNode, bool enabled = true, TextInputType? keyboardType}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        enabled: enabled,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
    );
  }
}
