import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:treesure_app/features/navbars/forester_navbar.dart';

class ForesterTreeMapping extends StatefulWidget {
  final String foresterId; // comes from login
  final String foresterName; // comes from login

  const ForesterTreeMapping({
    super.key,
    required this.foresterId,
    required this.foresterName,
  });

  @override
  State<ForesterTreeMapping> createState() => _ForesterTreeMappingState();
}

class _ForesterTreeMappingState extends State<ForesterTreeMapping> {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: MapPage(
        foresterId: widget.foresterId,
        foresterName: widget.foresterName,
      ),
    );
  }
}

class MapPage extends StatelessWidget {
  final String foresterId;
  final String foresterName;

  const MapPage({
    super.key,
    required this.foresterId,
    required this.foresterName,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Live Map Viewer"),
        leading: BackButton(
          onPressed: () {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (_) => ForesterNavbar(
                  foresterId: foresterId,
                  foresterName: foresterName,
                ),
              ),
            );
          },
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection(
                'tree_inventory')
            .orderBy('timestamp')
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final markers = snapshot.data!.docs.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final lat = data['latitude'];
            final lng = data['longitude'];
            return Marker(
              point: LatLng(lat, lng),
              width: 60,
              height: 60,
              child: const Icon(Icons.location_on, color: Colors.red),
            );
          }).toList();

          final points = snapshot.data!.docs.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return LatLng(data['latitude'], data['longitude']);
          }).toList();

          return FlutterMap(
            options: MapOptions(
              initialCenter: points.isNotEmpty
                  ? points.last
                  : const LatLng(18.3578, 121.6414), // fallback: Aparri
              initialZoom: 13,
            ),
            children: [
              TileLayer(
                urlTemplate: "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
                subdomains: const ['a', 'b', 'c'],
              ),
              PolylineLayer(
                polylines: [
                  Polyline(
                    points: points,
                    strokeWidth: 4.0,
                    color: Colors.blue,
                  ),
                ],
              ),
              MarkerLayer(markers: markers),
            ],
          );
        },
      ),
    );
  }
}
