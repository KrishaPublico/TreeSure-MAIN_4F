import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:location/location.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// 🗝️ Replace this with your own API key
const String googleAPIKey = 'AIzaSyBqlgPkoI7MkbAFwl07WLs-_jHvbSOXPvo';

class ForesterTreeMapping extends StatefulWidget {
  final String? appointmentId;

  const ForesterTreeMapping({Key? key, this.appointmentId}) : super(key: key);

  @override
  _ForesterTreeMappingState createState() => _ForesterTreeMappingState();
}

class _ForesterTreeMappingState extends State<ForesterTreeMapping> {
  final Completer<GoogleMapController> _controller = Completer();
  Location location = Location();
  LocationData? currentLocation;

  Set<Marker> markers = {};
  Set<Polyline> polylines = {};
  List<Map<String, dynamic>> taggedTrees = [];

  @override
  void initState() {
    super.initState();
    _initLocation();
  }

  Future<void> _initLocation() async {
    bool serviceEnabled;
    PermissionStatus permissionGranted;

    // Check service
    serviceEnabled = await location.serviceEnabled();
    if (!serviceEnabled) {
      serviceEnabled = await location.requestService();
      if (!serviceEnabled) return;
    }

    // Check permission
    permissionGranted = await location.hasPermission();
    if (permissionGranted == PermissionStatus.denied) {
      permissionGranted = await location.requestPermission();
      if (permissionGranted != PermissionStatus.granted) return;
    }

    // Get location
    currentLocation = await location.getLocation();

    // Fetch tagged trees from Firestore
    await _fetchTaggedTrees();

    setState(() {});
  }

  Future<void> _fetchTaggedTrees() async {
    if (widget.appointmentId == null) return;

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('appointments')
          .doc(widget.appointmentId)
          .collection('tree_inventory')
          .get();

      setState(() {
        taggedTrees = snapshot.docs.map((doc) => doc.data()).toList();
      });

      // Add markers and routes for tagged trees
      _setMarkers();
    } catch (e) {
      print('❌ Error fetching tagged trees: $e');
    }
  }

  void _setMarkers() {
    if (currentLocation == null) return;

    // Add current location marker
    markers.add(Marker(
      markerId: const MarkerId('current'),
      position: LatLng(currentLocation!.latitude!, currentLocation!.longitude!),
      infoWindow: const InfoWindow(title: 'Current Location'),
      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
    ));

    // Add markers for each tagged tree
    for (int i = 0; i < taggedTrees.length; i++) {
      final tree = taggedTrees[i];
      final lat = tree['latitude'] as double?;
      final lng = tree['longitude'] as double?;
      final specie = tree['specie'] ?? 'Unknown';

      if (lat != null && lng != null) {
        markers.add(Marker(
          markerId: MarkerId('tree_$i'),
          position: LatLng(lat, lng),
          infoWindow: InfoWindow(
            title: 'Tree: $specie',
            snippet: 'ID: ${tree['tree_no'] ?? "N/A"}',
          ),
          icon:
              BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
        ));

        // Draw route from current location to each tree
        if (i < 3) {
          // Limit to first 3 trees for performance
          _drawRoute(
            LatLng(currentLocation!.latitude!, currentLocation!.longitude!),
            LatLng(lat, lng),
          );
        }
      }
    }

    setState(() {});
  }

  Future<void> _drawRoute(LatLng origin, LatLng destination) async {
    try {
      final result = await _fetchDirections(origin, destination);

      if (result.isNotEmpty) {
        setState(() {
          polylines.add(
            Polyline(
              polylineId: PolylineId('route_${polylines.length}'),
              color: Colors.green,
              width: 5,
              points: result,
            ),
          );
        });
      }
    } catch (e) {
      print('Error drawing route: $e');
    }
  }

  Future<List<LatLng>> _fetchDirections(LatLng origin, LatLng dest) async {
    final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/directions/json?origin=${origin.latitude},${origin.longitude}&destination=${dest.latitude},${dest.longitude}&key=$googleAPIKey');

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if ((data['routes'] as List).isEmpty) return [];
        final points = data['routes'][0]['overview_polyline']['points'];
        final polylinePoints = PolylinePoints();
        final result = polylinePoints.decodePolyline(points);

        List<LatLng> polylineCoordinates = [];
        for (var point in result) {
          polylineCoordinates.add(LatLng(point.latitude, point.longitude));
        }
        return polylineCoordinates;
      } else {
        throw Exception('Failed to get directions');
      }
    } catch (e) {
      print('Error fetching directions: $e');
      return [];
    }
  }

  Future<void> _openInGoogleMaps(double lat, double lng) async {
    final url = Uri.parse(
        'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      throw 'Could not launch Google Maps';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tree Mapping & Navigation'),
        backgroundColor: Colors.green.shade700,
        elevation: 0,
      ),
      body: currentLocation == null
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                GoogleMap(
                  mapType: MapType.normal,
                  myLocationEnabled: true,
                  initialCameraPosition: CameraPosition(
                    target: LatLng(currentLocation!.latitude!,
                        currentLocation!.longitude!),
                    zoom: 14.5,
                  ),
                  onMapCreated: (GoogleMapController controller) {
                    _controller.complete(controller);
                  },
                  markers: markers,
                  polylines: polylines,
                ),
                // Info panel at bottom
                Positioned(
                  bottom: 20,
                  left: 20,
                  right: 20,
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Tagged Trees: ${taggedTrees.length}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                        ),
                        const SizedBox(height: 12),
                        if (taggedTrees.isNotEmpty)
                          SizedBox(
                            height: 100,
                            child: ListView.builder(
                              scrollDirection: Axis.horizontal,
                              itemCount: taggedTrees.length,
                              itemBuilder: (context, index) {
                                final tree = taggedTrees[index];
                                return GestureDetector(
                                  onTap: () {
                                    final lat = tree['latitude'] as double?;
                                    final lng = tree['longitude'] as double?;
                                    if (lat != null && lng != null) {
                                      _openInGoogleMaps(lat, lng);
                                    }
                                  },
                                  child: Container(
                                    width: 90,
                                    margin: const EdgeInsets.only(right: 8),
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Colors.green[50],
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: Colors.green,
                                        width: 1.5,
                                      ),
                                    ),
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          tree['specie'] ?? 'Unknown',
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          textAlign: TextAlign.center,
                                          style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.green,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'ID: ${tree['tree_no'] ?? "N/A"}',
                                          style: const TextStyle(
                                            fontSize: 10,
                                            color: Colors.grey,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          )
                        else
                          const Text(
                            'No tagged trees yet',
                            style: TextStyle(color: Colors.grey),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
