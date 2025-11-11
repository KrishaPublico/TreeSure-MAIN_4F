import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:path_provider/path_provider.dart';

class TreeService {
  final ImagePicker _picker = ImagePicker();

  Future<XFile?> pickImage() async {
    try {
      return await _picker.pickImage(source: ImageSource.gallery);
    } catch (e) {
      throw Exception("Image pick failed: $e");
    }
  }

  Future<String?> uploadImageToStorage(
    XFile image, {
    required String foresterId,
    required String treeId,
  }) async {
    try {
      String timestamp = DateTime.now().millisecondsSinceEpoch.toString();
      String fileName = "${treeId}_$timestamp.jpg";
      final ref = FirebaseStorage.instance.ref().child("tree_photos/$fileName");

      final metadata = SettableMetadata(customMetadata: {
        "foresterId": foresterId,
        "treeId": treeId,
        "timestamp": timestamp,
      });

      UploadTask task = kIsWeb
          ? ref.putData(await image.readAsBytes(), metadata)
          : ref.putFile(File(image.path), metadata);

      // ✅ Handle the upload task on the main thread
      TaskSnapshot snapshot = await task.then((snapshot) {
        return snapshot;
      }, onError: (error, stackTrace) {
        print("Image upload error: $error");
        throw error;
      });

      return await snapshot.ref.getDownloadURL();
    } catch (e) {
      print("Image upload error: $e");
      return null;
    }
  }

  /// ✅ Generate and upload QR code to Firebase Storage
  Future<String?> generateAndUploadQr({
    required String treeId,
    required Map<String, dynamic> treeData,
  }) async {
    try {
      final qrData = {
        "tree_id": treeId,
        "tree_no": treeData["tree_no"],
        "specie": treeData["specie"],
        "latitude": treeData["latitude"],
        "longitude": treeData["longitude"],
        "volume": treeData["volume"],
      };

      // Generate QR as image data
      final qrPainter = QrPainter(
        data: qrData.toString(),
        version: QrVersions.auto,
        color: const Color(0xFF000000),
        emptyColor: const Color(0xFFFFFFFF),
      );

      final picData =
          await qrPainter.toImageData(300, format: ImageByteFormat.png);
      final Uint8List qrBytes = picData!.buffer.asUint8List();

      // Save temporarily
      final tempDir = await getTemporaryDirectory();
      final qrFile = File('${tempDir.path}/$treeId.png');
      await qrFile.writeAsBytes(qrBytes);

      // Upload to Firebase Storage
      final ref = FirebaseStorage.instance.ref().child("tree_qr/$treeId.png");
      final uploadTask = ref.putFile(qrFile);
      
      // ✅ Handle the upload task on the main thread
      final snapshot = await uploadTask.then((snapshot) {
        return snapshot;
      }, onError: (error, stackTrace) {
        print("QR upload error: $error");
        throw error;
      });
      
      final qrUrl = await snapshot.ref.getDownloadURL();

      return qrUrl;
    } catch (e) {
      print("QR generation/upload failed: $e");
      return null;
    }
  }

  /// ✅ Save tree info (including photo + QR)
  Future<String> sendTreeInfo({
    required String foresterId,
    required String forester,
    required String treeId,
    required String treeNo,
    required String specie,
    required double diameter,
    required double height,
    required double volume,
    XFile? imageFile,
    required double lat,
    required double lng,
    required String appointmentId, // ✅ cutting appointment document ID
    String? treeTaggingAppointmentId, // ✅ tree_tagging_appointment doc ID to store as field
    String? treeStatus, // ✅ tree cutting status (Ready for Cutting / Not Yet Ready)
  }) async {
    final collectionRef = FirebaseFirestore.instance
        .collection('appointments')
        .doc(appointmentId)
        .collection('tree_inventory');

    String? photoUrl;
    if (imageFile != null) {
      photoUrl = await uploadImageToStorage(
        imageFile,
        foresterId: foresterId,
        treeId: treeId,
      );
    }

    // Prepare tree data
    final treeData = {
      'latitude': lat,
      'longitude': lng,
      'tree_no': treeNo,
      'tree_id': treeId,
      'specie': specie,
      'diameter': diameter,
      'height': height,
      'volume': volume,
      'timestamp': Timestamp.now(),
      'forester_name': forester,
      'forester_id': foresterId,
      'appointment_id': appointmentId,
      'tree_tagging_appointment_id': treeTaggingAppointmentId, // ✅ Store the tree_tagging_appointment doc ID
      'tree_status': treeStatus ?? 'Not Yet Ready', // ✅ Store the tree cutting status
      'photo_url': photoUrl ?? '',
    };

    // ✅ Generate and upload QR
    final qrUrl = await generateAndUploadQr(treeId: treeId, treeData: treeData);
    treeData['qr_url'] = qrUrl ?? '';

    // ✅ Save to Firestore
    await collectionRef.doc(treeId).set(treeData);

    return treeId;
  }

  double calculateVolume(double diameter, double height) {
    return 3.141592653589793 * (diameter / 2) * (diameter / 2) * height;
  }
}
