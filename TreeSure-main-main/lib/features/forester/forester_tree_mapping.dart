import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:location/location.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';

// 🗝️ Replace this with your own API key
const String googleAPIKey = 'AIzaSyC8E4EJ8h5H1Csre_oHjrMP9_XbVi7-Xz0';

class ForesterTreeMapping extends StatefulWidget {
  final String? appointmentId;
  final String foresterId;

  const ForesterTreeMapping(
      {super.key, required this.foresterId, this.appointmentId});

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
  List<Map<String, dynamic>> appointments = [];
  String? selectedAppointmentId;
  String? selectedTreeId;
  int appointmentCount = 0;
  bool isLoading = true;
  
  // Distance and elevation data
  Map<String, Map<String, dynamic>> treeDistanceData = {};
  Map<String, double?> treeElevationData = {};
  bool isLoadingDistanceElevation = false;

  @override
  void initState() {
    super.initState();
    _initLocation();
  }

  Future<void> _initLocation() async {
    bool serviceEnabled;
    PermissionStatus permissionGranted;

    try {
      // On web, location plugin has different behavior
      if (kIsWeb) {
        // Browser geolocation - simplified flow
        try {
          currentLocation = await location.getLocation();
        } catch (e) {
          debugPrint('Web location unavailable: $e');
          currentLocation = null;
        }
      } else {
        // Mobile/desktop flow with full permission checks
        // Check service
        serviceEnabled = await location.serviceEnabled();
        if (!serviceEnabled) {
          serviceEnabled = await location.requestService();
          // If still not enabled, continue without location
          if (!serviceEnabled) {
            currentLocation = null;
          }
        }

        // Check permission
        permissionGranted = await location.hasPermission();
        if (permissionGranted == PermissionStatus.denied) {
          permissionGranted = await location.requestPermission();
        }

        if (permissionGranted == PermissionStatus.granted &&
            serviceEnabled == true) {
          // Get location
          currentLocation = await location.getLocation();
        } else {
          currentLocation = null; // proceed without device location
        }
      }
    } catch (e) {
      // MissingPluginException or other platform issues — proceed without device location
      debugPrint(
          'Location unavailable, continuing without current location: $e');
      currentLocation = null;
    }

    // Fetch tagged trees from Firestore
    await _fetchTaggedTrees();

    setState(() {});
  }

  Future<void> _fetchTaggedTrees() async {
    setState(() {
      isLoading = true;
    });

    try {
      // Query appointments where foresterId is in the foresterIds array
      final appointmentsSnapshot = await FirebaseFirestore.instance
          .collection('appointments')
          .where('foresterIds', arrayContains: widget.foresterId)
          .get();

      if (appointmentsSnapshot.docs.isEmpty) {
        debugPrint('No appointments found for forester: ${widget.foresterId}');
        setState(() {
          appointments = [];
          taggedTrees = [];
          appointmentCount = 0;
          isLoading = false;
        });
        return;
      }

      // Store appointment data and fetch tree counts
      List<Map<String, dynamic>> appointmentsList = [];
      for (var doc in appointmentsSnapshot.docs) {
        final data = doc.data();
        data['id'] = doc.id;
        
        // Get actual tree count from tree_inventory subcollection
        final treeCount = await FirebaseFirestore.instance
            .collection('appointments')
            .doc(doc.id)
            .collection('tree_inventory')
            .count()
            .get();
        
        data['actual_tree_count'] = treeCount.count ?? 0;
        appointmentsList.add(data);
      }

      debugPrint('✅ Fetched ${appointmentsList.length} appointments');

      setState(() {
        appointments = appointmentsList;
        appointmentCount = appointmentsList.length;
        isLoading = false;
        // Clear trees until an appointment is selected
        taggedTrees = [];
        selectedAppointmentId = null;
        selectedTreeId = null;
      });
    } catch (e) {
      debugPrint('❌ Error fetching appointments: $e');
      setState(() {
        appointments = [];
        taggedTrees = [];
        appointmentCount = 0;
        isLoading = false;
      });
    }
  }

  Future<void> _fetchTreesForAppointment(String appointmentId) async {
    setState(() {
      isLoading = true;
      selectedAppointmentId = appointmentId;
      selectedTreeId = null;
    });

    try {
      final treeInventorySnapshot = await FirebaseFirestore.instance
          .collection('appointments')
          .doc(appointmentId)
          .collection('tree_inventory')
          .get();

      List<Map<String, dynamic>> trees = [];
      for (var treeDoc in treeInventorySnapshot.docs) {
        final treeData = treeDoc.data();
        treeData['tree_id'] = treeDoc.id;
        treeData['appointment_id'] = appointmentId;
        trees.add(treeData);
      }

      debugPrint('✅ Fetched ${trees.length} trees for appointment $appointmentId');

      setState(() {
        taggedTrees = trees;
        isLoading = false;
      });

      // Add markers for trees
      _setMarkers();
      
      // Fetch distance matrix and elevations if we have current location
      setState(() {
        isLoadingDistanceElevation = true;
      });
      
      if (currentLocation != null && trees.isNotEmpty) {
        final origin = LatLng(currentLocation!.latitude!, currentLocation!.longitude!);
        await _fetchDistanceMatrix(origin, trees);
      }
      
      // Fetch elevations for all trees
      if (trees.isNotEmpty) {
        await _fetchElevations(trees);
      }
      
      setState(() {
        isLoadingDistanceElevation = false;
      });
    } catch (e) {
      debugPrint('❌ Error fetching trees: $e');
      setState(() {
        taggedTrees = [];
        isLoading = false;
      });
    }
  }

  void _setMarkers() {
    // Reset to avoid duplicate markers/polylines on refreshes
    markers.clear();
    polylines.clear();

    // Add current location marker
    if (currentLocation != null) {
      markers.add(Marker(
        markerId: const MarkerId('current'),
        position:
            LatLng(currentLocation!.latitude!, currentLocation!.longitude!),
        infoWindow: const InfoWindow(title: 'Current Location'),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
      ));
    }

    // Add markers for each tagged tree
    for (int i = 0; i < taggedTrees.length; i++) {
      final tree = taggedTrees[i];
      final lat = (tree['latitude'] as num?)?.toDouble();
      final lng = (tree['longitude'] as num?)?.toDouble();
      final specie = tree['specie'] ?? 'Unknown';
      final treeId = tree['tree_id'] ?? tree['tree_no'] ?? 'N/A';

      if (lat != null && lng != null) {
        // Build info window snippet with distance and elevation
        String snippet = 'ID: ${tree['tree_no'] ?? "N/A"}';
        
        final distanceInfo = treeDistanceData[treeId];
        if (distanceInfo != null) {
          snippet += '\n🚗 ${distanceInfo['distance']} • ${distanceInfo['duration']}';
        }
        
        final elevation = treeElevationData[treeId];
        if (elevation != null) {
          snippet += '\n⛰️ ${elevation.toStringAsFixed(1)}m above sea level';
        }
        
        markers.add(Marker(
          markerId: MarkerId('tree_$i'),
          position: LatLng(lat, lng),
          infoWindow: InfoWindow(
            title: 'Tree: $specie',
            snippet: snippet,
          ),
          icon:
              BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
          onTap: () => _onTreeMarkerTapped(treeId, lat, lng),
        ));
      }
    }
    
    // After adding markers, fit camera to show all points
    _fitMapToAllMarkers();

    setState(() {});
  }

  void _onTreeMarkerTapped(String treeId, double lat, double lng) {
    debugPrint('🎯 Tree marker tapped: $treeId at ($lat, $lng)');
    debugPrint('📍 Current location: ${currentLocation?.latitude}, ${currentLocation?.longitude}');
    
    setState(() {
      selectedTreeId = treeId;
      polylines.clear();
    });

    // Draw route from current location to selected tree
    if (currentLocation != null) {
      debugPrint('🚀 Starting route drawing...');
      _drawRoute(
        LatLng(currentLocation!.latitude!, currentLocation!.longitude!),
        LatLng(lat, lng),
      );
    } else {
      debugPrint('⚠️ Cannot draw route: current location is null');
    }
  }

  Future<void> _drawRoute(LatLng origin, LatLng destination) async {
    try {
      debugPrint('🗺️ Drawing route from ${origin.latitude},${origin.longitude} to ${destination.latitude},${destination.longitude}');
      
      final result = await _fetchDirections(origin, destination);

      debugPrint('📍 Route points fetched: ${result.length} points');

      if (result.isNotEmpty) {
        setState(() {
          polylines.add(
            Polyline(
              polylineId: const PolylineId('route_to_tree'),
              color: Colors.blue,
              width: 6,
              points: result,
              startCap: Cap.roundCap,
              endCap: Cap.roundCap,
              geodesic: true,
            ),
          );
        });
        debugPrint('✅ Route polyline added successfully');
      } else {
        debugPrint('❌ No route points returned');
      }
    } catch (e) {
      debugPrint('❌ Error drawing route: $e');
    }
  }

  Future<List<LatLng>> _fetchDirections(LatLng origin, LatLng dest) async {
    final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/directions/json?origin=${origin.latitude},${origin.longitude}&destination=${dest.latitude},${dest.longitude}&key=$googleAPIKey');

    try {
      debugPrint('🌐 Fetching directions from API...');
      final response = await http.get(url);
      debugPrint('📡 API Response status: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        debugPrint('📊 API Response status: ${data['status']}');
        
        if (data['status'] == 'REQUEST_DENIED') {
          debugPrint('❌ API Error: ${data['error_message']}');
          return [];
        }
        
        if ((data['routes'] as List).isEmpty) {
          debugPrint('❌ No routes found in response');
          return [];
        }
        
        final points = data['routes'][0]['overview_polyline']['points'];
        debugPrint('🔢 Encoded polyline length: ${points.length} characters');
        
        // Decode polyline using an instance (decodePolyline is an instance method in this package version)
        final polylinePoints = PolylinePoints();
        final result = polylinePoints.decodePolyline(points);
        debugPrint('✅ Decoded ${result.length} polyline points');

        List<LatLng> polylineCoordinates = [];
        for (var point in result) {
          polylineCoordinates.add(LatLng(point.latitude, point.longitude));
        }
        return polylineCoordinates;
      } else {
        debugPrint('❌ HTTP Error: ${response.statusCode}');
        throw Exception('Failed to get directions');
      }
    } catch (e) {
      debugPrint('❌ Error fetching directions: $e');
      return [];
    }
  }

  /// 🚗 Distance Matrix API - Get travel time and distance
  Future<void> _fetchDistanceMatrix(LatLng origin, List<Map<String, dynamic>> trees) async {
    if (trees.isEmpty) return;

    try {
      // Build destinations string (max 25 at a time per API limit)
      List<String> destinations = [];
      for (var tree in trees) {
        final lat = (tree['latitude'] as num?)?.toDouble();
        final lng = (tree['longitude'] as num?)?.toDouble();
        if (lat != null && lng != null) {
          destinations.add('$lat,$lng');
        }
      }

      if (destinations.isEmpty) return;

      // Split into batches of 25 (API limit)
      for (int i = 0; i < destinations.length; i += 25) {
        final batch = destinations.skip(i).take(25).toList();
        final destinationsStr = batch.join('|');
        
        final url = Uri.parse(
          'https://maps.googleapis.com/maps/api/distancematrix/json?origins=${origin.latitude},${origin.longitude}&destinations=$destinationsStr&key=$googleAPIKey&units=metric',
        );

        final response = await http.get(url);
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          
          if (data['status'] == 'OK' && data['rows'] != null) {
            final elements = data['rows'][0]['elements'] as List;
            
            for (int j = 0; j < elements.length && (i + j) < trees.length; j++) {
              final element = elements[j];
              final tree = trees[i + j];
              final treeId = tree['tree_id'] ?? tree['tree_no'] ?? 'unknown_$i';
              
              if (element['status'] == 'OK') {
                treeDistanceData[treeId] = {
                  'distance': element['distance']['text'], // e.g., "5.2 km"
                  'distance_value': element['distance']['value'], // in meters
                  'duration': element['duration']['text'], // e.g., "12 mins"
                  'duration_value': element['duration']['value'], // in seconds
                };
              }
            }
          }
        }
      }

      setState(() {});
    } catch (e) {
      debugPrint('❌ Error fetching distance matrix: $e');
    }
  }

  /// ⛰️ Elevation API - Get elevation for each tree
  Future<void> _fetchElevations(List<Map<String, dynamic>> trees) async {
    if (trees.isEmpty) return;

    try {
      // Build locations string (max 512 locations per request)
      List<String> locations = [];
      List<String> treeIds = [];
      
      for (var tree in trees) {
        final lat = (tree['latitude'] as num?)?.toDouble();
        final lng = (tree['longitude'] as num?)?.toDouble();
        final treeId = tree['tree_id'] ?? tree['tree_no'] ?? 'unknown';
        
        if (lat != null && lng != null) {
          locations.add('$lat,$lng');
          treeIds.add(treeId);
        }
      }

      if (locations.isEmpty) return;

      // Process in batches of 512
      for (int i = 0; i < locations.length; i += 512) {
        final batch = locations.skip(i).take(512).toList();
        final locationsStr = batch.join('|');
        
        final url = Uri.parse(
          'https://maps.googleapis.com/maps/api/elevation/json?locations=$locationsStr&key=$googleAPIKey',
        );

        final response = await http.get(url);
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          
          if (data['status'] == 'OK' && data['results'] != null) {
            final results = data['results'] as List;
            
            for (int j = 0; j < results.length && (i + j) < treeIds.length; j++) {
              final result = results[j];
              final treeId = treeIds[i + j];
              
              treeElevationData[treeId] = result['elevation']?.toDouble();
            }
          }
        }
      }

      setState(() {});
    } catch (e) {
      debugPrint('❌ Error fetching elevations: $e');
    }
  }

  Future<void> _fitMapToAllMarkers() async {
    if (markers.isEmpty) return;
    try {
      final controller = await _controller.future;
      double? minLat, maxLat, minLng, maxLng;
      for (final m in markers) {
        final lat = m.position.latitude;
        final lng = m.position.longitude;
        minLat = (minLat == null) ? lat : (lat < minLat ? lat : minLat);
        maxLat = (maxLat == null) ? lat : (lat > maxLat ? lat : maxLat);
        minLng = (minLng == null) ? lng : (lng < minLng ? lng : minLng);
        maxLng = (maxLng == null) ? lng : (lng > maxLng ? lng : maxLng);
      }
      if (minLat == null || maxLat == null || minLng == null || maxLng == null)
        return;

      // If only one marker, just move camera to it
      if (minLat == maxLat && minLng == maxLng) {
        await controller.animateCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(target: LatLng(minLat, minLng), zoom: 16),
          ),
        );
        return;
      }

      final bounds = LatLngBounds(
        southwest: LatLng(minLat, minLng),
        northeast: LatLng(maxLat, maxLng),
      );
      await controller.animateCamera(
        CameraUpdate.newLatLngBounds(bounds, 60),
      );
    } catch (e) {
      // Some platforms can throw if bounds are invalid or map not ready
      debugPrint('Could not fit map to markers: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(selectedAppointmentId == null
            ? 'My Appointments'
            : 'Tree Locations'),
        backgroundColor: Colors.green.shade700,
        elevation: 0,
        leading: selectedAppointmentId != null
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () {
                  setState(() {
                    selectedAppointmentId = null;
                    selectedTreeId = null;
                    taggedTrees = [];
                    markers.clear();
                    polylines.clear();
                  });
                },
              )
            : null,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: isLoading
                ? null
                : () {
                    if (selectedAppointmentId != null) {
                      _fetchTreesForAppointment(selectedAppointmentId!);
                    } else {
                      _fetchTaggedTrees();
                    }
                  },
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : selectedAppointmentId == null
              ? _buildAppointmentsList()
              : _buildMapView(),
    );
  }

  Widget _buildAppointmentsList() {
    if (appointments.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.assignment_outlined, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              'No appointments found',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Forester ID: ${widget.foresterId}',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: appointments.length,
      itemBuilder: (context, index) {
        final appointment = appointments[index];
        final appointmentId = appointment['id'] ?? 'N/A';
        final appointmentType = appointment['appointmentType'] ?? 'Unknown';
        final location = appointment['location'] ?? 'N/A';
        final status = appointment['status'] ?? 'Unknown';
        final actualTreeCount = appointment['actual_tree_count'] as int? ?? 0;

        Color statusColor;
        switch (status.toLowerCase()) {
          case 'completed':
            statusColor = Colors.green;
            break;
          case 'in progress':
            statusColor = Colors.orange;
            break;
          case 'pending':
            statusColor = Colors.blue;
            break;
          default:
            statusColor = Colors.grey;
        }

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: InkWell(
            onTap: () => _fetchTreesForAppointment(appointmentId),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          appointmentType,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          status,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: statusColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.location_on,
                          size: 16, color: Colors.grey),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          location,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[700],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.park, size: 16, color: Colors.grey),
                      const SizedBox(width: 4),
                      Text(
                        '$actualTreeCount trees',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[700],
                        ),
                      ),
                      const Spacer(),
                      const Icon(Icons.chevron_right, color: Colors.green),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildMapView() {
    // Determine initial camera center: prefer current location, else first tree, else null
    LatLng? initialCenter;
    if (currentLocation != null) {
      initialCenter =
          LatLng(currentLocation!.latitude!, currentLocation!.longitude!);
    } else {
      // Try first valid tree coordinate
      for (final tree in taggedTrees) {
        final lat = (tree['latitude'] as num?)?.toDouble();
        final lng = (tree['longitude'] as num?)?.toDouble();
        if (lat != null && lng != null) {
          initialCenter = LatLng(lat, lng);
          break;
        }
      }
    }

    if (initialCenter == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.map_outlined, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              'No tree locations found',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    return Stack(
      children: [
        GoogleMap(
          mapType: MapType.normal,
          myLocationEnabled: currentLocation != null,
          initialCameraPosition: CameraPosition(
            target: initialCenter,
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
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Trees: ${taggedTrees.length}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                    if (selectedTreeId != null)
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.blue[100],
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: const [
                                Icon(Icons.route, size: 12, color: Colors.blue),
                                SizedBox(width: 4),
                                Text(
                                  'Route Active',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.blue,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          InkWell(
                            onTap: () {
                              setState(() {
                                selectedTreeId = null;
                                polylines.clear();
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: Colors.red[100],
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(
                                Icons.close,
                                size: 16,
                                color: Colors.red,
                              ),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  selectedTreeId == null
                      ? 'Tap a tree card or marker to display route on map'
                      : 'Showing route from your location to selected tree',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey[600],
                    fontStyle: FontStyle.italic,
                  ),
                  textAlign: TextAlign.center,
                ),
                if (isLoadingDistanceElevation) ...[
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Loading distance & elevation data...',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.grey[600],
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 12),
                if (currentLocation == null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(Icons.info_outline,
                            size: 16, color: Colors.orange),
                        SizedBox(width: 4),
                        Text(
                          'Device location unavailable',
                          style: TextStyle(fontSize: 11, color: Colors.orange),
                        ),
                      ],
                    ),
                  ),
                if (taggedTrees.isNotEmpty)
                  SizedBox(
                    height: 100,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: taggedTrees.length,
                      itemBuilder: (context, index) {
                        final tree = taggedTrees[index];
                        final treeId =
                            tree['tree_id'] ?? tree['tree_no'] ?? 'N/A';
                        final isSelected = selectedTreeId == treeId;
                        final distanceInfo = treeDistanceData[treeId];
                        final elevation = treeElevationData[treeId];

                        return GestureDetector(
                          onTap: () {
                            final lat = (tree['latitude'] as num?)?.toDouble();
                            final lng = (tree['longitude'] as num?)?.toDouble();
                            if (lat != null && lng != null) {
                              _onTreeMarkerTapped(treeId, lat, lng);
                            }
                          },
                          child: Container(
                            width: 120,
                            margin: const EdgeInsets.only(right: 8),
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? Colors.blue[100]
                                  : Colors.green[50],
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color:
                                    isSelected ? Colors.blue : Colors.green,
                                width: isSelected ? 2 : 1.5,
                              ),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                if (isSelected)
                                  const Icon(Icons.near_me,
                                      size: 14, color: Colors.blue),
                                Text(
                                  tree['specie'] ?? 'Unknown',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: isSelected
                                        ? Colors.blue
                                        : Colors.green,
                                  ),
                                ),
                                Text(
                                  'ID: ${tree['tree_no'] ?? "N/A"}',
                                  style: const TextStyle(
                                    fontSize: 9,
                                    color: Colors.grey,
                                  ),
                                ),
                                if (distanceInfo != null) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    '🚗 ${distanceInfo['distance']}',
                                    style: const TextStyle(
                                      fontSize: 9,
                                      color: Colors.black87,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  Text(
                                    '⏱️ ${distanceInfo['duration']}',
                                    style: const TextStyle(
                                      fontSize: 8,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ],
                                if (elevation != null) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    '⛰️ ${elevation.toStringAsFixed(0)}m',
                                    style: const TextStyle(
                                      fontSize: 8,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ],
                                if (currentLocation != null) ...[
                                  const SizedBox(height: 4),
                                  GestureDetector(
                                    onTap: () {
                                      final lat = (tree['latitude'] as num?)?.toDouble();
                                      final lng = (tree['longitude'] as num?)?.toDouble();
                                      if (lat != null && lng != null) {
                                        // Show visual route on map
                                        _onTreeMarkerTapped(treeId, lat, lng);
                                      }
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: isSelected ? Colors.blue : Colors.green,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            isSelected ? Icons.near_me : Icons.route,
                                            size: 10,
                                            color: Colors.white,
                                          ),
                                          const SizedBox(width: 2),
                                          Text(
                                            isSelected ? 'Selected' : 'Show Route',
                                            style: const TextStyle(
                                              fontSize: 8,
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
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
    );
  }
}
