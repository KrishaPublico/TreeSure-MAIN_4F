import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class RegisterTreesPage extends StatefulWidget {
  final String foresterId; // comes from login
  final String foresterName; // comes from login

  const RegisterTreesPage({
    super.key,
    required this.foresterId,
    required this.foresterName,
  });

  @override
  State<RegisterTreesPage> createState() => _RegisterTreesPageState();
}

class _RegisterTreesPageState extends State<RegisterTreesPage> {
  final TextEditingController treeNoController = TextEditingController();
  final TextEditingController specieController = TextEditingController();
  final TextEditingController diameterController = TextEditingController();
  final TextEditingController heightController = TextEditingController();
  final TextEditingController volumeController = TextEditingController();
  final TextEditingController latController = TextEditingController();
  final TextEditingController longController = TextEditingController();

  final FocusNode treeNoFocus = FocusNode();
  final FocusNode specieFocus = FocusNode();
  final FocusNode diameterFocus = FocusNode();
  final FocusNode heightFocus = FocusNode();

  XFile? imageFile;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    diameterController.addListener(_updateVolume);
    heightController.addListener(_updateVolume);
  }

  /// save into sub-collection under forester document
  Future<void> sendTreeInfo({
    required String foresterId,
    required String forester,
    required double lat,
    required double lng,
    required String treeNo,
    required String specie,
    required double diameter,
    required double height,
    required double volume,
  }) async {
    final collectionRef = FirebaseFirestore.instance
        .collection('users')
        .doc(foresterId)
        .collection('tree_inventory'); // sub-collection

    // 🔹 Get the current number of documents to create new ID
    final snapshot = await collectionRef.get();
    final count = snapshot.docs.length; // total documents
    final newId = "T${count + 1}"; // e.g., T1, T2, T3...

    await collectionRef.doc(newId).set({
      'latitude': lat,
      'longitude': lng,
      'tree_no': treeNo,
      'specie': specie,
      'diameter': diameter,
      'height': height,
      'volume': volume,
      'timestamp': Timestamp.now(),
      'forester_name': forester,
    });
  }

  void handleSubmit() {
    final latitude = double.tryParse(latController.text);
    final longitude = double.tryParse(longController.text);
    final treeNo = treeNoController.text.trim();
    final specie = specieController.text.trim();
    final diameter = double.tryParse(diameterController.text);
    final height = double.tryParse(heightController.text);
    final volume = double.tryParse(volumeController.text);

    if (latitude != null &&
        longitude != null &&
        treeNo.isNotEmpty &&
        specie.isNotEmpty &&
        diameter != null &&
        height != null &&
        volume != null) {
      sendTreeInfo(
          lat: latitude,
          lng: longitude,
          treeNo: treeNo,
          specie: specie,
          diameter: diameter,
          height: height,
          volume: volume,
          foresterId: widget.foresterId,
          forester: widget.foresterName);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Submission successful!")),
      );

      /// clear fields after save
      treeNoController.clear();
      specieController.clear();
      diameterController.clear();
      heightController.clear();
      volumeController.clear();
      latController.clear();
      longController.clear();
      setState(() => imageFile = null);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("All fields are required!")),
      );
    }
  }

  void _updateVolume() {
    double diameter = double.tryParse(diameterController.text) ?? 0;
    double height = double.tryParse(heightController.text) ?? 0;
    double volume =
        3.141592653589793 * (diameter / 2) * (diameter / 2) * height;
    volumeController.text = volume > 0 ? volume.toStringAsFixed(2) : '';
  }

  @override
  void dispose() {
    treeNoController.dispose();
    specieController.dispose();
    diameterController.dispose();
    heightController.dispose();
    volumeController.dispose();
    latController.dispose();
    longController.dispose();

    treeNoFocus.dispose();
    specieFocus.dispose();
    diameterFocus.dispose();
    heightFocus.dispose();

    super.dispose();
  }

  Future<void> pickImage() async {
    try {
      final XFile? picked =
          await _picker.pickImage(source: ImageSource.gallery);
      if (picked != null) {
        setState(() {
          imageFile = picked;
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
      "Forester Name": widget.foresterName,
      "Tree No.": treeNoController.text,
      "Specie": specieController.text,
      "Diameter (cm)": diameterController.text,
      "Height (m)": heightController.text,
      "Volume (CU m)": volumeController.text,
      "Latitude": latController.text,
      "Longitude": longController.text,
      "Photo Evidence": imageFile != null ? imageFile!.name : "No image",
    };

    final Map<String, FocusNode> focusMap = {
      "Tree No.": treeNoFocus,
      "Specie": specieFocus,
      "Diameter (cm)": diameterFocus,
      "Height (m)": heightFocus,
    };

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Tree Data Summary"),
        content: SingleChildScrollView(
          child: DataTable(
            columnSpacing: 10,
            columns: const [
              DataColumn(
                  label: Text("Field",
                      style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(
                  label: Text("Value",
                      style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(
                  label: Text("Edit",
                      style: TextStyle(fontWeight: FontWeight.bold))),
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
            child: Text("Close", style: TextStyle(color: Colors.green[700])),
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
            Text("Forester: ${widget.foresterName}",
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 20),
            buildTextField("Tree No.", treeNoController,
                focusNode: treeNoFocus),
            buildTextField("Specie", specieController, focusNode: specieFocus),
            Row(
              children: [
                Expanded(
                  child: buildTextField("Diameter (cm)", diameterController,
                      focusNode: diameterFocus,
                      keyboardType: TextInputType.number),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: buildTextField("Height (m)", heightController,
                      focusNode: heightFocus,
                      keyboardType: TextInputType.number),
                ),
              ],
            ),
            buildTextField("Volume (CU m)", volumeController, enabled: false),
            const SizedBox(height: 12),
            const Text("GPS Location",
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(child: buildTextField("Latitude", latController)),
                const SizedBox(width: 12),
                Expanded(child: buildTextField("Longitude", longController)),
              ],
            ),
            const SizedBox(height: 20),
            const Text("Photo Evidence",
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            imageFile != null
                ? Image.network(imageFile!.path, height: 200)
                : const Text("No image selected."),
            TextButton.icon(
              icon: const Icon(Icons.upload),
              label: const Text("Upload Photo"),
              onPressed: pickImage,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: handleSubmit,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green[800],
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: const Text("Submit",
                  style: TextStyle(fontSize: 16, color: Colors.white)),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: viewSummaryDialog,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green[800],
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: const Text("View Summary",
                  style: TextStyle(fontSize: 16, color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildTextField(
    String label,
    TextEditingController controller, {
    FocusNode? focusNode,
    bool enabled = true,
    TextInputType? keyboardType,
  }) {
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
