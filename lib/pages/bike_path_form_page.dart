import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:uuid/uuid.dart';
import '../models/bike_path.dart';
import '../models/street_segment.dart';
import '../models/route_candidate.dart';
import '../models/path_quality_report.dart'; // For PathRateStatus
import '../services/providers.dart';
import '../services/geocoding_service.dart';

import 'package:geolocator/geolocator.dart';

class BikePathFormPage extends ConsumerStatefulWidget {
  const BikePathFormPage({super.key});

  @override
  ConsumerState<BikePathFormPage> createState() => _BikePathFormPageState();
}

class _BikePathFormPageState extends ConsumerState<BikePathFormPage> {
  final _formKey = GlobalKey<FormState>();

  // Path Data
  final List<StreetSegment> _segments = [];
  PathRateStatus _status = PathRateStatus.optimal;
  bool _publishable = true;
  double _totalPathDistance = 0.0;

  // Search State
  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;

  // Map State
  GoogleMapController? _mapController;
  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};

  void _addSegment(GeocodingResult result) {
    // Convert GeocodingResult to StreetSegment
    final newSegment = StreetSegment(
      id: const Uuid().v4(), // Generate ID since PlaceId missing
      streetName: result.formattedAddress.split(',')[0], // Approximation
      formattedAddress: result.formattedAddress,
      lat: result.location.latitude,
      lng: result.location.longitude,
      polyline: result.viewport != null
          ? [result.viewport!.southwest, result.viewport!.northeast]
          : null, // Just a line for now if viewport available
    );

    setState(() {
      _segments.add(newSegment);
    });

    _recalculateFullRoute(); // Fetch actual path logic

    _searchController.clear();
    // Navigator.pop(context); // REMOVED: This was accidentally closing the whole page!
  }

  // New method to fetch real street paths between segments
  Future<void> _recalculateFullRoute() async {
    // 1. Set markers immediately (optimistic UI)
    _markers = {};
    for (int i = 0; i < _segments.length; i++) {
      final seg = _segments[i];
      _markers.add(Marker(
        markerId: MarkerId('seg_$i'),
        position: LatLng(seg.lat, seg.lng),
        infoWindow: InfoWindow(title: '${i + 1}. ${seg.streetName}'),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
      ));
    }
    setState(() {}); // Refresh markers

    if (_segments.length < 2) {
      _polylines = {};
      // Just zoom to specific point
      if (_segments.isNotEmpty && _mapController != null) {
        _mapController!.animateCamera(CameraUpdate.newLatLngZoom(
            LatLng(_segments.first.lat, _segments.first.lng), 14));
      }
      setState(() {});
      return;
    }

    // 2. Fetch directions between sequential segments
    List<LatLng> fullRoutePoints = [];
    double calculatedDistance = 0.0;
    final directionsService = ref.read(directionsServiceProvider);

    for (int i = 0; i < _segments.length - 1; i++) {
      final start = _segments[i];
      final end = _segments[i + 1];

      try {
        // Try bicycling first (preferred)
        var directions = await directionsService.getDirections(
          origin: LatLng(start.lat, start.lng),
          destination: LatLng(end.lat, end.lng),
          mode: 'bicycling',
        );

        // Fallback to Driving
        if (directions == null) {
          print('DEBUG: Bicycling route not found, trying driving fallback...');
          directions = await directionsService.getDirections(
            origin: LatLng(start.lat, start.lng),
            destination: LatLng(end.lat, end.lng),
            mode: 'driving',
          );
        }

        if (directions != null) {
          fullRoutePoints.addAll(directions.polylinePoints);
          calculatedDistance += directions.distanceValue;
        } else {
          // Fallback to straight line
          print('DEBUG: Both modes failed, using straight line fallback.');
          fullRoutePoints.add(LatLng(start.lat, start.lng));
          fullRoutePoints.add(LatLng(end.lat, end.lng));

          // Calculate straight line distance
          calculatedDistance += Geolocator.distanceBetween(
              start.lat, start.lng, end.lat, end.lng);
        }
      } catch (e) {
        print('Error fetching route segment: $e');
        fullRoutePoints.add(LatLng(start.lat, start.lng));
        fullRoutePoints.add(LatLng(end.lat, end.lng));
        calculatedDistance +=
            Geolocator.distanceBetween(start.lat, start.lng, end.lat, end.lng);
      }
    }

    // 3. Update Polyline and Distance
    if (mounted) {
      setState(() {
        _totalPathDistance = calculatedDistance;
        _polylines = {
          Polyline(
            polylineId: const PolylineId('full_bike_path'),
            points: fullRoutePoints,
            color: Colors.blueAccent,
            width: 5,
            jointType: JointType.round,
            startCap: Cap.roundCap,
            endCap: Cap.roundCap,
          )
        };
      });

      // Zoom to fit whole path
      if (_mapController != null && fullRoutePoints.isNotEmpty) {
        // Compute bounds
        double minLat = 90, maxLat = -90, minLng = 180, maxLng = -180;
        for (var p in fullRoutePoints) {
          if (p.latitude < minLat) minLat = p.latitude;
          if (p.latitude > maxLat) maxLat = p.latitude;
          if (p.longitude < minLng) minLng = p.longitude;
          if (p.longitude > maxLng) maxLng = p.longitude;
        }
        _mapController!.animateCamera(CameraUpdate.newLatLngBounds(
            LatLngBounds(
                southwest: LatLng(minLat, minLng),
                northeast: LatLng(maxLat, maxLng)),
            100 // Padding
            ));
      }
    }
  }

  // Helper alias to keep old call working if needed, but we essentially replaced logic
  void _updateMapVisualization() {
    _recalculateFullRoute();
  }

  Future<void> _handleSearch(String query) async {
    if (query.isEmpty) return;
    setState(() => _isSearching = true);
    final result =
        await ref.read(geocodingServiceProvider).searchAddress(query);
    setState(() => _isSearching = false);

    if (result != null) {
      // Prompt confirm
      if (!mounted) return;
      showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
                title: Text(result.formattedAddress),
                content: const Text('Add this street to the path?'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Cancel')),
                  ElevatedButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _addSegment(result);
                      },
                      child: const Text('Add')),
                ],
              ));
    } else {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Address not found')));
    }
  }

  void _submit() async {
    if (_segments.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Add at least one street segment.')));
      return;
    }

    final user = ref.read(authStateProvider).value;
    if (user == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Must be logged in.')));
      return;
    }

    final path = BikePath(
      id: const Uuid().v4(),
      userId: user.uid,
      segments: _segments,
      status: _status,
      publishable: _publishable,
      distanceMeters: _totalPathDistance,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    try {
      await ref.read(contributeServiceProvider).addBikePath(path);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Bike Path Created Successfully!')));
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  void _showSearchDialog() {
    showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
              title: const Text('Add Street Segment'),
              content: TextField(
                controller: _searchController,
                decoration: const InputDecoration(
                    hintText: 'e.g. Main St', suffixIcon: Icon(Icons.search)),
                onSubmitted: (val) {
                  Navigator.pop(ctx);
                  _handleSearch(val);
                },
              ),
            ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create Bike Path')),
      body: Column(
        children: [
          Expanded(
            flex: 2,
            child: GoogleMap(
              initialCameraPosition: const CameraPosition(
                  target: LatLng(37.7749, -122.4194), zoom: 12),
              markers: _markers,
              polylines: _polylines,
              onMapCreated: (c) => _mapController = c,
            ),
          ),
          Expanded(
            flex: 3,
            child: Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  const Text('Path Composition',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 8),
                  if (_segments.isEmpty)
                    const Padding(
                        padding: EdgeInsets.all(8),
                        child: Text('No streets added yet.',
                            style: TextStyle(color: Colors.grey))),
                  ReorderableListView(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    onReorder: (oldIndex, newIndex) {
                      setState(() {
                        if (oldIndex < newIndex) newIndex -= 1;
                        final item = _segments.removeAt(oldIndex);
                        _segments.insert(newIndex, item);
                        _updateMapVisualization();
                      });
                    },
                    children: [
                      for (int i = 0; i < _segments.length; i++)
                        ListTile(
                          key: ValueKey(_segments[i].id),
                          leading: CircleAvatar(child: Text('${i + 1}')),
                          title: Text(_segments[i].streetName),
                          subtitle:
                              Text(_segments[i].formattedAddress, maxLines: 1),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () {
                              setState(() {
                                _segments.removeAt(i);
                                _updateMapVisualization();
                              });
                            },
                          ),
                        )
                    ],
                  ),
                  ElevatedButton.icon(
                    onPressed: _showSearchDialog,
                    icon: const Icon(Icons.add),
                    label: const Text('Add Street Segment'),
                  ),
                  const Divider(),
                  DropdownButtonFormField<PathRateStatus>(
                    value: _status,
                    decoration:
                        const InputDecoration(labelText: 'Overall Path Status'),
                    items: PathRateStatus.values
                        .map((s) =>
                            DropdownMenuItem(value: s, child: Text(s.label)))
                        .toList(),
                    onChanged: (v) => setState(() => _status = v!),
                  ),
                  SwitchListTile(
                    title: const Text('Make Public'),
                    value: _publishable,
                    onChanged: (v) => setState(() => _publishable = v),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _submit,
                    style: ElevatedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 50),
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white),
                    child: const Text('Submit Bike Path'),
                  )
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
