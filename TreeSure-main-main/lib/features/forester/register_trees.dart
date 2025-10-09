import 'dart:io';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

import 'tree_services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class RegisterTreesPage extends StatefulWidget {
  final String foresterId;
  final String foresterName;

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

  LatLng? _currentPosition; // for displaying on map
  final MapController _mapController = MapController();




  final FocusNode treeNoFocus = FocusNode();
  final FocusNode specieFocus = FocusNode();
  final FocusNode diameterFocus = FocusNode();
  final FocusNode heightFocus = FocusNode();

  final TreeService _treeService = TreeService(); // ✅ use the service here

  XFile? imageFile;
  String? lastSubmittedTreeId;

  @override
  void initState() {
    super.initState();
    diameterController.addListener(_updateVolume);
    heightController.addListener(_updateVolume);
  }
Future<void> _getLocation() async {
  var permission = await Permission.location.status;
  if (!permission.isGranted) {
    permission = await Permission.location.request();
    if (!permission.isGranted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Location permission denied.")),
      );
      return;
    }
  }

  try {
    final position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );

    setState(() {
      latController.text = position.latitude.toStringAsFixed(6);
      longController.text = position.longitude.toStringAsFixed(6);
      _currentPosition = LatLng(position.latitude, position.longitude);
    });

    _mapController.move(_currentPosition!, 17); // zoom in

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Location fetched successfully!")),
    );
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Failed to get location: $e")),
    );
  }
}

  void _updateVolume() {
    double diameter = double.tryParse(diameterController.text) ?? 0;
    double height = double.tryParse(heightController.text) ?? 0;
    double volume = _treeService.calculateVolume(diameter, height); // ✅ service
    volumeController.text = volume > 0 ? volume.toStringAsFixed(2) : '';
  }

  Future<void> handleSubmit() async {
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
      final newDocId = await _treeService.sendTreeInfo(
        // ✅ service
        lat: latitude,
        lng: longitude,
        treeNo: treeNo,
        specie: specie,
        diameter: diameter,
        height: height,
        volume: volume,
        foresterId: widget.foresterId,
        forester: widget.foresterName,
        imageFile: imageFile,
      );

      setState(() {
        lastSubmittedTreeId = newDocId;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Submission successful!")),
      );

      _clearFields();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("All fields are required!")),
      );
    }
  }

  void _clearFields() {
    treeNoController.clear();
    specieController.clear();
    diameterController.clear();
    heightController.clear();
    volumeController.clear();
    latController.clear();
    longController.clear();
    setState(() => imageFile = null);
  }

  Future<void> pickImage() async {
    try {
      final picked = await _treeService.pickImage(); // ✅ service
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

  Future<void> viewSummaryDialog() async {
    Map<String, dynamic> submittedData = {
      "Forester Name": widget.foresterName,
      "Tree No.": treeNoController.text,
      "Specie": specieController.text,
      "Diameter (cm)": diameterController.text,
      "Height (m)": heightController.text,
      "Volume (CU m)": volumeController.text,
      "Latitude": latController.text,
      "Longitude": longController.text,
    };

    String? photoUrl;

    // ✅ Fetch from Firestore (UI side only)
    if (lastSubmittedTreeId != null) {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.foresterId)
          .collection('tree_inventory')
          .doc(lastSubmittedTreeId)
          .get();

      if (doc.exists && doc.data()?['photo_url'] != null) {
        photoUrl = doc['photo_url'];
      }
    }

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
          child: Column(
            children: [
              DataTable(
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
                                FocusScope.of(context)
                                    .requestFocus(focusMap[key]);
                              },
                            )
                          : const SizedBox.shrink(),
                    ),
                  ]);
                }).toList(),
              ),
              const SizedBox(height: 20),
              const Text("Photo Evidence",
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              if (photoUrl != null && photoUrl.isNotEmpty)
                Image.network(photoUrl, height: 200, fit: BoxFit.cover)
              else if (imageFile != null)
                kIsWeb
                    ? Image.network(imageFile!.path,
                        height: 200, fit: BoxFit.cover)
                    : Image.file(File(imageFile!.path),
                        height: 200, fit: BoxFit.cover)
              else
                const Text("No image available"),
            ],
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
            // ✅ Auto-location fields
            Row(
              children: [
                Expanded(
                  child:
                      buildTextField("Latitude", latController, enabled: false),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: buildTextField("Longitude", longController,
                      enabled: false),
                ),
              ],
            ),
            TextButton.icon(
              icon: const Icon(Icons.my_location, color: Colors.green),
              label: const Text("Get Current Location"),
              onPressed: _getLocation,
            ),
            const SizedBox(height: 20),
            const Text("Photo Evidence",
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            if (imageFile != null)
              kIsWeb
                  ? Image.network(imageFile!.path, height: 200)
                  : Image.file(File(imageFile!.path), height: 200)
            else
              const Text("No image selected."),
            TextButton.icon(
              icon: const Icon(Icons.upload),
              label: const Text("Pick Photo"),
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
