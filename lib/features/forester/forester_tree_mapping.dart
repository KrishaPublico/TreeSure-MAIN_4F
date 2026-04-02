import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:location/location.dart';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';

class ForesterTreeMapping extends StatefulWidget {
  final String? appointmentId;
  final String? initialTreeId;
  final String foresterId;

  const ForesterTreeMapping(
      {super.key,
      required this.foresterId,
      this.appointmentId,
      this.initialTreeId});

  @override
  _ForesterTreeMappingState createState() => _ForesterTreeMappingState();
}

class _ForesterTreeMappingState extends State<ForesterTreeMapping> {
  final MapController _controller = MapController();
  Location location = Location();
  LocationData? currentLocation;

  List<Marker> markers = [];
  List<Polyline> polylines = [];
  List<Map<String, dynamic>> taggedTrees = [];
  List<Map<String, dynamic>> appointments = [];
  String? selectedAppointmentId;
  String? selectedTreeId;
  int appointmentCount = 0;
  bool isLoading = true;
  bool _hasTriggeredInitialAppointmentFetch = false;
  bool _hasAppliedInitialTreeFocus = false;

  // Distance and elevation data
  Map<String, Map<String, dynamic>> treeDistanceData = {};
  Map<String, double?> treeElevationData = {};
  bool isLoadingDistanceElevation = false;

  // Map type selection
  String _mapType = 'street'; // 'street', 'satellite', 'terrain'

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
      _attemptInitialAppointmentSelection();
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

      debugPrint(
          '✅ Fetched ${trees.length} trees for appointment $appointmentId');

      setState(() {
        taggedTrees = trees;
        isLoading = false;
      });

      // Add markers for trees
      _setMarkers();
      _attemptInitialTreeFocus();

      // Fetch distance matrix and elevations if we have current location
      setState(() {
        isLoadingDistanceElevation = true;
      });

      if (currentLocation != null && trees.isNotEmpty) {
        final origin =
            LatLng(currentLocation!.latitude!, currentLocation!.longitude!);
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

  void _attemptInitialAppointmentSelection() {
    if (_hasTriggeredInitialAppointmentFetch) return;
    final targetAppointmentId = widget.appointmentId;
    if (targetAppointmentId == null) return;

    final hasAppointment = appointments
        .any((appointment) => appointment['id'] == targetAppointmentId);
    if (!hasAppointment) return;

    _hasTriggeredInitialAppointmentFetch = true;
    _fetchTreesForAppointment(targetAppointmentId);
  }

  void _attemptInitialTreeFocus() {
    if (_hasAppliedInitialTreeFocus) return;
    final targetTreeId = widget.initialTreeId;
    if (targetTreeId == null) return;
    if (widget.appointmentId != null &&
        widget.appointmentId != selectedAppointmentId) {
      return;
    }

    Map<String, dynamic>? matchedTree;
    for (final tree in taggedTrees) {
      final inventoryId = tree['tree_id']?.toString();
      if (inventoryId == targetTreeId) {
        matchedTree = tree;
        break;
      }
    }

    if (matchedTree == null) return;
    final lat = (matchedTree['latitude'] as num?)?.toDouble();
    final lng = (matchedTree['longitude'] as num?)?.toDouble();
    if (lat == null || lng == null) return;

    _hasAppliedInitialTreeFocus = true;
    _onTreeMarkerTapped(targetTreeId, lat, lng);
  }

  void _setMarkers() {
    final newMarkers = <Marker>[];
    final newPolylines = <Polyline>[];

    // Add current location marker
    if (currentLocation != null) {
      newMarkers.add(
        Marker(
          point:
              LatLng(currentLocation!.latitude!, currentLocation!.longitude!),
          width: 48,
          height: 48,
          alignment: Alignment.bottomCenter,
          child: const Tooltip(
            message: 'Current Location',
            child: Icon(Icons.my_location, color: Colors.blueAccent, size: 30),
          ),
        ),
      );
    }

    // Add markers for each tagged tree
    for (int i = 0; i < taggedTrees.length; i++) {
      final tree = taggedTrees[i];
      final lat = (tree['latitude'] as num?)?.toDouble();
      final lng = (tree['longitude'] as num?)?.toDouble();
      final specie = tree['specie'] ?? 'Unknown';
      final treeId = tree['tree_id'] ?? tree['tree_no'] ?? 'N/A';

      if (lat != null && lng != null) {
        // Build tooltip text with distance and elevation
        String tooltipText = 'Tree: $specie\nID: ${tree['tree_no'] ?? "N/A"}';

        final distanceInfo = treeDistanceData[treeId];
        if (distanceInfo != null) {
          tooltipText +=
              '\n🚗 ${distanceInfo['distance']} • ${distanceInfo['duration']}';
        }

        final elevation = treeElevationData[treeId];
        if (elevation != null) {
          tooltipText +=
              '\n⛰️ ${elevation.toStringAsFixed(1)}m above sea level';
        }

        newMarkers.add(
          Marker(
            point: LatLng(lat, lng),
            width: 48,
            height: 48,
            alignment: Alignment.bottomCenter,
            child: GestureDetector(
              onTap: () => _onTreeMarkerTapped(treeId, lat, lng),
              child: Tooltip(
                message: tooltipText,
                child: Icon(Icons.park, color: Colors.green.shade700, size: 32),
              ),
            ),
          ),
        );
      }
    }

    setState(() {
      markers = newMarkers;
      polylines = newPolylines;
    });

    // After adding markers, fit camera to show all points
    _fitMapToAllMarkers();
  }

  void _onTreeMarkerTapped(String treeId, double lat, double lng) {
    debugPrint('🎯 Tree marker tapped: $treeId at ($lat, $lng)');
    debugPrint(
        '📍 Current location: ${currentLocation?.latitude}, ${currentLocation?.longitude}');

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
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _controller.move(LatLng(lat, lng), 17);
      });
    }
  }

  Future<void> _drawRoute(LatLng origin, LatLng destination) async {
    try {
      if (_locationsMatch(origin, destination)) {
        setState(() {
          polylines.clear();
        });
        _controller.move(destination, 17);
        return;
      }

      debugPrint(
          '🗺️ Drawing route from ${origin.latitude},${origin.longitude} to ${destination.latitude},${destination.longitude}');

      final result = await _fetchDirections(origin, destination);

      debugPrint('📍 Route points fetched: ${result.length} points');

      if (result.isNotEmpty) {
        setState(() {
          polylines = [
            Polyline(
              points: result,
              color: Colors.blueAccent,
              strokeWidth: 5,
            ),
          ];
        });
        debugPrint('✅ Route polyline added successfully');
        _fitCameraToRoute(result);
      } else {
        debugPrint('❌ No route points returned');
      }
    } catch (e) {
      debugPrint('❌ Error drawing route: $e');
    }
  }

  Future<List<LatLng>> _fetchDirections(LatLng origin, LatLng dest) async {
    final url = Uri.parse(
      'https://router.project-osrm.org/route/v1/driving/'
      '${origin.longitude},${origin.latitude};'
      '${dest.longitude},${dest.latitude}'
      '?overview=full&geometries=polyline',
    );

    try {
      debugPrint('🌐 Fetching directions from OSRM...');
      final response = await http.get(url);
      debugPrint('📡 API Response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final routes = data['routes'] as List<dynamic>?;

        if (routes == null || routes.isEmpty) {
          debugPrint('❌ No routes found in response');
          return [];
        }

        final route = routes.first as Map<String, dynamic>;
        final geometry = route['geometry'] as String?;

        if (geometry == null) {
          debugPrint('❌ No geometry in route');
          return [];
        }

        final points = _decodePolyline(geometry);
        debugPrint('✅ Decoded ${points.length} polyline points');

        return points;
      } else {
        debugPrint('❌ HTTP Error: ${response.statusCode}');
        throw Exception('Failed to get directions');
      }
    } catch (e) {
      debugPrint('❌ Error fetching directions: $e');
      return [];
    }
  }

  List<LatLng> _decodePolyline(String encoded) {
    List<LatLng> points = [];
    int index = 0;
    int lat = 0;
    int lng = 0;

    while (index < encoded.length) {
      int b;
      int shift = 0;
      int result = 0;

      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      final int deltaLat = (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
      lat += deltaLat;

      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      final int deltaLng = (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
      lng += deltaLng;

      points.add(LatLng(lat / 1E5, lng / 1E5));
    }

    return points;
  }

  void _fitCameraToRoute(List<LatLng> routePoints) {
    if (routePoints.isEmpty) return;

    try {
      if (_allPointsCoincident(routePoints)) {
        _controller.move(routePoints.first, 17);
        return;
      }

      final bounds = LatLngBounds.fromPoints(routePoints);
      _controller.fitCamera(
        CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(60)),
      );
    } catch (e) {
      debugPrint('⚠️ Failed to fit camera to route: $e');
    }
  }

  /// 🚗 Calculate straight-line distances from current location to trees
  Future<void> _fetchDistanceMatrix(
      LatLng origin, List<Map<String, dynamic>> trees) async {
    if (trees.isEmpty) return;

    try {
      for (var tree in trees) {
        final lat = (tree['latitude'] as num?)?.toDouble();
        final lng = (tree['longitude'] as num?)?.toDouble();

        if (lat != null && lng != null) {
          final treeId = tree['tree_id'] ?? tree['tree_no'] ?? 'unknown';

          // Calculate straight-line distance using Haversine formula
          final distance = _calculateDistance(
            origin.latitude,
            origin.longitude,
            lat,
            lng,
          );

          // Estimate driving time (assuming ~40 km/h average speed in forest terrain)
          final durationMinutes = (distance / 40 * 60).round();

          treeDistanceData[treeId] = {
            'distance': '${distance.toStringAsFixed(2)} km',
            'distance_value': (distance * 1000).round(),
            'duration': '$durationMinutes mins',
            'duration_value': durationMinutes * 60,
          };
        }
      }

      setState(() {});
    } catch (e) {
      debugPrint('❌ Error calculating distances: $e');
    }
  }

  /// Calculate distance between two points using Haversine formula (in km)
  double _calculateDistance(
      double lat1, double lon1, double lat2, double lon2) {
    const double earthRadius = 6371; // Earth's radius in km

    final dLat = _degreesToRadians(lat2 - lat1);
    final dLon = _degreesToRadians(lon2 - lon1);

    final a = (math.sin(dLat / 2) * math.sin(dLat / 2)) +
        (math.cos(_degreesToRadians(lat1)) *
            math.cos(_degreesToRadians(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2));

    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));

    return earthRadius * c;
  }

  double _degreesToRadians(double degrees) {
    return degrees * math.pi / 180;
  }

  /// ⛰️ Note: Elevation data removed (was using Google Elevation API)
  /// For elevation data, consider using open-source alternatives like:
  /// - OpenTopoData API
  /// - Mapbox Elevation API
  /// - GeoNames API
  Future<void> _fetchElevations(List<Map<String, dynamic>> trees) async {
    // Elevation fetching disabled - requires API key from elevation service
    debugPrint('ℹ️ Elevation data fetching is disabled (no API configured)');
    return;
  }

  Future<void> _fitMapToAllMarkers() async {
    if (markers.isEmpty) return;
    try {
      final points = markers.map((marker) => marker.point).toList();
      if (_allPointsCoincident(points)) {
        _controller.move(points.first, 17);
        return;
      }

      final bounds = LatLngBounds.fromPoints(points);
      _controller.fitCamera(
        CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(60)),
      );
    } catch (e) {
      // Some platforms can throw if bounds are invalid or map not ready
      debugPrint('Could not fit map to markers: $e');
    }
  }

  bool _locationsMatch(LatLng? a, LatLng? b, {double tolerance = 1e-5}) {
    if (a == null || b == null) return false;
    return (a.latitude - b.latitude).abs() <= tolerance &&
        (a.longitude - b.longitude).abs() <= tolerance;
  }

  bool _allPointsCoincident(List<LatLng> points, {double tolerance = 1e-6}) {
    if (points.isEmpty) return true;
    final first = points.first;
    for (final point in points.skip(1)) {
      if ((point.latitude - first.latitude).abs() > tolerance ||
          (point.longitude - first.longitude).abs() > tolerance) {
        return false;
      }
    }
    return true;
  }

  /// 🗺️ Get tile layer configuration based on map type
  TileLayer _getTileLayer() {
    switch (_mapType) {
      case 'satellite':
        // Using ESRI World Imagery (satellite)
        return TileLayer(
          urlTemplate:
              'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}',
          userAgentPackageName: 'com.treesure.app',
          maxZoom: 19,
        );
      case 'terrain':
        // Using OpenTopoMap (topographic/terrain)
        return TileLayer(
          urlTemplate: 'https://tile.opentopomap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.treesure.app',
          maxZoom: 17,
        );
      case 'street':
      default:
        // Using OpenStreetMap (street map)
        return TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.treesure.app',
          maxZoom: 19,
        );
    }
  }

  static const _primaryGreen = Color(0xFF2E7D32);
  static const _darkGreen = Color(0xFF1B5E20);
  static const _lightGreen = Color(0xFFE8F5E9);

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: Column(
        children: [
          // Gradient header
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF1B5E20), Color(0xFF388E3C)],
              ),
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
            ),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(4, 8, 8, 20),
                child: Row(
                  children: [
                    if (selectedAppointmentId != null)
                      IconButton(
                        icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
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
                    else
                      const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            selectedAppointmentId == null
                                ? 'My Appointments'
                                : 'Tree Locations',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            selectedAppointmentId == null
                                ? '${appointments.length} appointment${appointments.length != 1 ? 's' : ''} found'
                                : '${taggedTrees.length} tree${taggedTrees.length != 1 ? 's' : ''} tagged',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.8),
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.refresh_rounded, color: Colors.white),
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
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Content
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator(color: _primaryGreen))
                : selectedAppointmentId == null
                    ? _buildAppointmentsList()
                    : _buildMapView(),
          ),
        ],
      ),
    );
  }

  Widget _buildAppointmentsList() {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    if (appointments.isEmpty) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(screenWidth * 0.05),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: _lightGreen,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(Icons.assignment_outlined, size: 40, color: _primaryGreen),
              ),
              SizedBox(height: screenHeight * 0.025),
              const Text(
                'No Appointments Found',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1A1A1A),
                ),
              ),
              SizedBox(height: screenHeight * 0.01),
              Text(
                'No appointments are assigned to you yet',
                style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.fromLTRB(screenWidth * 0.04, 12, screenWidth * 0.04, 16),
      itemCount: appointments.length,
      itemBuilder: (context, index) {
        final appointment = appointments[index];
        final appointmentId = appointment['id'] ?? 'N/A';
        final appointmentType = appointment['appointmentType'] ?? 'Unknown';
        final location = appointment['location'] ?? 'N/A';
        final status = appointment['status'] ?? 'Unknown';
        final actualTreeCount = appointment['actual_tree_count'] as int? ?? 0;

        Color statusColor;
        IconData statusIcon;
        switch (status.toLowerCase()) {
          case 'completed':
            statusColor = const Color(0xFF4CAF50);
            statusIcon = Icons.check_circle_rounded;
            break;
          case 'in progress':
            statusColor = const Color(0xFFFF9800);
            statusIcon = Icons.timelapse_rounded;
            break;
          case 'pending':
            statusColor = const Color(0xFF2196F3);
            statusIcon = Icons.schedule_rounded;
            break;
          default:
            statusColor = Colors.grey;
            statusIcon = Icons.info_rounded;
        }

        return Container(
          margin: EdgeInsets.only(bottom: screenHeight * 0.015),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => _fetchTreesForAppointment(appointmentId),
              borderRadius: BorderRadius.circular(16),
              child: Padding(
                padding: EdgeInsets.all(screenWidth * 0.04),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: _lightGreen,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.calendar_today_rounded, size: 22, color: _primaryGreen),
                        ),
                        SizedBox(width: screenWidth * 0.035),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                appointmentType,
                                style: TextStyle(
                                  fontSize: screenWidth * 0.04,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF1A1A1A),
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 3),
                              Row(
                                children: [
                                  Icon(Icons.location_on_rounded, size: 14, color: Colors.grey[400]),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      location,
                                      style: TextStyle(
                                        fontSize: screenWidth * 0.033,
                                        color: Colors.grey[500],
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        SizedBox(width: screenWidth * 0.02),
                        Container(
                          padding: EdgeInsets.symmetric(
                              horizontal: screenWidth * 0.025,
                              vertical: screenHeight * 0.006),
                          decoration: BoxDecoration(
                            color: statusColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(statusIcon, size: 12, color: statusColor),
                              SizedBox(width: screenWidth * 0.01),
                              Text(
                                status,
                                style: TextStyle(
                                  fontSize: screenWidth * 0.028,
                                  fontWeight: FontWeight.w600,
                                  color: statusColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: screenHeight * 0.015),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: screenWidth * 0.035,
                        vertical: screenHeight * 0.012,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF5F5F5),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.park_rounded, size: 18, color: _primaryGreen),
                          SizedBox(width: screenWidth * 0.02),
                          Text(
                            '$actualTreeCount tree${actualTreeCount != 1 ? 's' : ''} tagged',
                            style: TextStyle(
                              fontSize: screenWidth * 0.033,
                              fontWeight: FontWeight.w600,
                              color: _primaryGreen,
                            ),
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: _primaryGreen.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Icon(Icons.chevron_right_rounded, size: screenWidth * 0.045, color: _primaryGreen),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildMapView() {
    LatLng? initialCenter;
    if (currentLocation != null) {
      initialCenter =
          LatLng(currentLocation!.latitude!, currentLocation!.longitude!);
    } else {
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
      final screenWidth = MediaQuery.of(context).size.width;
      final screenHeight = MediaQuery.of(context).size.height;

      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: _lightGreen,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(Icons.map_outlined, size: 40, color: _primaryGreen),
            ),
            SizedBox(height: screenHeight * 0.025),
            const Text(
              'No Tree Locations',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1A1A1A),
              ),
            ),
            SizedBox(height: screenHeight * 0.01),
            Text(
              'No trees have been tagged for this appointment',
              style: TextStyle(fontSize: 14, color: Colors.grey[500]),
            ),
          ],
        ),
      );
    }

    return Stack(
      children: [
        ClipRRect(
          child: FlutterMap(
            mapController: _controller,
            options: MapOptions(
              initialCenter: initialCenter,
              initialZoom: 14.5,
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.pinchZoom |
                    InteractiveFlag.drag |
                    InteractiveFlag.flingAnimation |
                    InteractiveFlag.doubleTapZoom,
              ),
            ),
            children: [
              _getTileLayer(),
              if (polylines.isNotEmpty) PolylineLayer(polylines: polylines),
              if (markers.isNotEmpty) MarkerLayer(markers: markers),
            ],
          ),
        ),
        // Map type selector
        Positioned(
          top: MediaQuery.of(context).size.height * 0.02,
          right: MediaQuery.of(context).size.width * 0.04,
          child: _buildMapTypeSelector(),
        ),
        // Bottom info panel
        Positioned(
          bottom: MediaQuery.of(context).size.height * 0.025,
          left: MediaQuery.of(context).size.width * 0.04,
          right: MediaQuery.of(context).size.width * 0.04,
          child: _buildInfoPanel(),
        ),
      ],
    );
  }

  Widget _buildInfoPanel() {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    return Container(
      constraints: BoxConstraints(
        maxHeight: screenHeight * 0.35,
      ),
      padding: EdgeInsets.all(screenWidth * 0.04),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: screenWidth * 0.025,
                    vertical: screenHeight * 0.006,
                  ),
                  decoration: BoxDecoration(
                    color: _lightGreen,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.park_rounded, size: 16, color: _primaryGreen),
                      SizedBox(width: screenWidth * 0.012),
                      Text(
                        '${taggedTrees.length} Trees',
                        style: TextStyle(
                          fontSize: screenWidth * 0.035,
                          fontWeight: FontWeight.w700,
                          color: _primaryGreen,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                if (selectedTreeId != null) ...[
                  Flexible(
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: screenWidth * 0.025,
                        vertical: screenHeight * 0.006,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE3F2FD),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.route_rounded,
                              size: screenWidth * 0.035,
                              color: const Color(0xFF1565C0)),
                          SizedBox(width: screenWidth * 0.01),
                          Flexible(
                            child: Text(
                              'Route Active',
                              style: TextStyle(
                                fontSize: screenWidth * 0.028,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF1565C0),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(width: screenWidth * 0.015),
                  InkWell(
                    onTap: () {
                      setState(() {
                        selectedTreeId = null;
                        polylines.clear();
                      });
                    },
                    child: Container(
                      padding: EdgeInsets.all(screenWidth * 0.012),
                      decoration: BoxDecoration(
                        color: Colors.red[50],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.close_rounded,
                        size: screenWidth * 0.04,
                        color: Colors.red[400],
                      ),
                    ),
                  ),
                ],
              ],
            ),
            SizedBox(height: screenHeight * 0.01),
            Text(
              selectedTreeId == null
                  ? 'Tap a tree card or marker to display route'
                  : 'Showing route to selected tree',
              style: TextStyle(
                fontSize: screenWidth * 0.03,
                color: Colors.grey[500],
                fontStyle: FontStyle.italic,
              ),
              textAlign: TextAlign.center,
            ),
            if (isLoadingDistanceElevation) ...[
              SizedBox(height: screenHeight * 0.01),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: screenWidth * 0.03,
                    height: screenWidth * 0.03,
                    child:
                        const CircularProgressIndicator(strokeWidth: 2, color: _primaryGreen),
                  ),
                  SizedBox(width: screenWidth * 0.02),
                  Flexible(
                    child: Text(
                      'Loading distance data...',
                      style: TextStyle(
                        fontSize: screenWidth * 0.028,
                        color: Colors.grey[500],
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
            SizedBox(height: screenHeight * 0.012),
            if (currentLocation == null)
              Padding(
                padding: EdgeInsets.only(bottom: screenHeight * 0.01),
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: screenWidth * 0.025,
                    vertical: screenHeight * 0.007,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.orange[50],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.info_outline_rounded,
                          size: screenWidth * 0.035,
                          color: Colors.orange[700]),
                      SizedBox(width: screenWidth * 0.015),
                      Flexible(
                        child: Text(
                          'Device location unavailable',
                          style: TextStyle(
                              fontSize: screenWidth * 0.028,
                              color: Colors.orange[700]),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            if (taggedTrees.isNotEmpty)
              SizedBox(
                height: screenHeight * 0.13,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: taggedTrees.length,
                  itemBuilder: (context, index) => _buildTreeCard(taggedTrees[index]),
                ),
              )
            else
              Text(
                'No tagged trees yet',
                style: TextStyle(
                    color: Colors.grey[400],
                    fontSize: screenWidth * 0.035),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTreeCard(Map<String, dynamic> tree) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final treeId = tree['tree_id'] ?? tree['tree_no'] ?? 'N/A';
    final isSelected = selectedTreeId == treeId;
    final distanceInfo = treeDistanceData[treeId];
    final elevation = treeElevationData[treeId];
    final accentColor = isSelected ? const Color(0xFF1565C0) : _primaryGreen;

    return GestureDetector(
      onTap: () {
        final lat = (tree['latitude'] as num?)?.toDouble();
        final lng = (tree['longitude'] as num?)?.toDouble();
        if (lat != null && lng != null) {
          _onTreeMarkerTapped(treeId, lat, lng);
        }
      },
      child: Container(
        width: screenWidth * 0.3,
        margin: EdgeInsets.only(right: screenWidth * 0.025),
        padding: EdgeInsets.all(screenWidth * 0.025),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFE3F2FD) : _lightGreen,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? const Color(0xFF1565C0) : _primaryGreen.withOpacity(0.3),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (isSelected)
                Icon(Icons.near_me_rounded,
                    size: screenWidth * 0.035,
                    color: accentColor),
              Text(
                tree['specie'] ?? 'Unknown',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: screenWidth * 0.03,
                  fontWeight: FontWeight.w700,
                  color: accentColor,
                ),
              ),
              Text(
                'ID: ${tree['tree_no'] ?? "N/A"}',
                style: TextStyle(
                  fontSize: screenWidth * 0.025,
                  color: Colors.grey[500],
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (distanceInfo != null) ...[
                SizedBox(height: screenHeight * 0.003),
                Text(
                  distanceInfo['distance'],
                  style: TextStyle(
                    fontSize: screenWidth * 0.025,
                    color: Colors.grey[700],
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  distanceInfo['duration'],
                  style: TextStyle(
                    fontSize: screenWidth * 0.022,
                    color: Colors.grey[500],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              if (elevation != null) ...[
                SizedBox(height: screenHeight * 0.003),
                Text(
                  '${elevation.toStringAsFixed(0)}m elev',
                  style: TextStyle(
                    fontSize: screenWidth * 0.022,
                    color: Colors.grey[500],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              if (currentLocation != null) ...[
                SizedBox(height: screenHeight * 0.005),
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: screenWidth * 0.02,
                    vertical: screenHeight * 0.003,
                  ),
                  decoration: BoxDecoration(
                    color: accentColor,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    isSelected ? 'Selected' : 'Route',
                    style: TextStyle(
                      fontSize: screenWidth * 0.022,
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMapTypeSelector() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildMapTypeButton('street', Icons.map_rounded, 'Street'),
          Container(height: 1, color: Colors.grey[200]),
          _buildMapTypeButton('satellite', Icons.satellite_alt_rounded, 'Satellite'),
          Container(height: 1, color: Colors.grey[200]),
          _buildMapTypeButton('terrain', Icons.terrain_rounded, 'Terrain'),
        ],
      ),
    );
  }

  Widget _buildMapTypeButton(String type, IconData icon, String label) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSelected = _mapType == type;

    return InkWell(
      onTap: () {
        setState(() {
          _mapType = type;
        });
      },
      child: Container(
        padding: EdgeInsets.symmetric(
            horizontal: screenWidth * 0.03, vertical: screenWidth * 0.025),
        decoration: BoxDecoration(
          color: isSelected ? _darkGreen : Colors.transparent,
          borderRadius: type == 'street'
              ? const BorderRadius.only(
                  topLeft: Radius.circular(14),
                  topRight: Radius.circular(14),
                )
              : type == 'terrain'
                  ? const BorderRadius.only(
                      bottomLeft: Radius.circular(14),
                      bottomRight: Radius.circular(14),
                    )
                  : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: screenWidth * 0.045,
              color: isSelected ? Colors.white : Colors.grey[600],
            ),
            SizedBox(width: screenWidth * 0.02),
            Text(
              label,
              style: TextStyle(
                fontSize: screenWidth * 0.03,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? Colors.white : Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
