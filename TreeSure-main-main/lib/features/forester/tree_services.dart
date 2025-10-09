import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';

class TreeService {
  final ImagePicker _picker = ImagePicker();

  /// Pick image from gallery
  Future<XFile?> pickImage() async {
    try {
      return await _picker.pickImage(source: ImageSource.gallery);
    } catch (e) {
      throw Exception("Image pick failed: $e");
    }
  }

  /// Upload image to Firebase Storage with metadata
  Future<String?> uploadImageToStorage(
    XFile image, {
    required String foresterId,
    required String treeId,
  }) async {
    try {
      // Create a timestamp
      String timestamp = DateTime.now().millisecondsSinceEpoch.toString();

      // File name will be based on treeId + timestamp
      String fileName = "${treeId}_$timestamp.jpg";

      // Storage reference
      final ref = FirebaseStorage.instance.ref().child("tree_photos/$fileName");

      // Define metadata
      final metadata = SettableMetadata(
        customMetadata: {
          "foresterId": foresterId,
          "treeId": treeId,
          "timestamp": timestamp,
        },
      );

      UploadTask task;
      if (kIsWeb) {
        task = ref.putData(await image.readAsBytes(), metadata);
      } else {
        task = ref.putFile(File(image.path), metadata);
      }

      TaskSnapshot snapshot = await task;
      return await snapshot.ref.getDownloadURL();
    } catch (e) {
      print("Image upload error: $e");
      return null;
    }
  }

  /// Save tree data in Firestore under a specific forester
  Future<String> sendTreeInfo({
    required String foresterId,
    required String forester,
    required String treeNo,
    required String specie,
    required double diameter,
    required double height,
    required double volume,
    XFile? imageFile, required double lat, required double lng,
  }) async {
    // Get device location
    final position = await _getCurrentPosition();
    double lat = position.latitude;
    double lng = position.longitude;

    final collectionRef = FirebaseFirestore.instance
        .collection('users')
        .doc(foresterId)
        .collection('tree_inventory');

    final snapshot = await collectionRef.get();
    final count = snapshot.docs.length;
    final newId = "T${count + 1}";

    String? photoUrl;
    if (imageFile != null) {
      photoUrl = await uploadImageToStorage(
        imageFile,
        foresterId: foresterId,
        treeId: newId,
      );
    }

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
      'photo_url': photoUrl ?? '',
    });

    return newId;
  }

  /// Calculate tree volume
  double calculateVolume(double diameter, double height) {
    return 3.141592653589793 * (diameter / 2) * (diameter / 2) * height;
  }

  Future<Position> _getCurrentPosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    // Check if location services are enabled
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception("Location services are disabled.");
    }

    // Check permission
    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw Exception("Location permissions are denied.");
      }
    }

    if (permission == LocationPermission.deniedForever) {
      throw Exception("Location permissions are permanently denied.");
    }

    // Get the current position
    return await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
  }
}
