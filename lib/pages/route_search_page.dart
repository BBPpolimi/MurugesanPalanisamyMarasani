import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:io' show Platform;
import '../services/providers.dart';
import '../models/scored_route.dart';

class RouteSearchPage extends ConsumerStatefulWidget {
  const RouteSearchPage({super.key});

  @override
  ConsumerState<RouteSearchPage> createState() => _RouteSearchPageState();
}

class _RouteSearchPageState extends ConsumerState<RouteSearchPage> {
  static const _initialCameraPosition = CameraPosition(
    target: LatLng(45.4782, 9.2272), // Milan
    zoom: 13,
  );

  GoogleMapController? _mapController;

  // Search State
  final _originController = TextEditingController();
  final _destController = TextEditingController();
  LatLng? _originLatLng;
  LatLng? _destLatLng;
  bool _isLoading = false;
  String? _errorMessage;

  // Route State
  List<ScoredRoute> _routes = [];
  ScoredRoute? _selectedRoute;
  bool _showObstacles = true;

  @override
  void dispose() {
    _mapController?.dispose();
    _originController.dispose();
    _destController.dispose();
    super.dispose();
  }

  // --- Actions ---

  Future<void> _searchRoutes() async {
    // Dismiss keyboard
    FocusScope.of(context).unfocus();

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _routes = [];
      _selectedRoute = null;
    });

    try {
      // 0. Resolve pending addresses if any
      if (_originLatLng == null && _originController.text.isNotEmpty) {
        final res = await ref.read(geocodingServiceProvider).searchAddress(_originController.text);
        if (res != null) {
           _originLatLng = res.location;
           // Don't update text here to avoid jarring changes, or do? maybe just latlng
        }
      }

      if (_destLatLng == null && _destController.text.isNotEmpty) {
        final res = await ref.read(geocodingServiceProvider).searchAddress(_destController.text);
         if (res != null) {
           _destLatLng = res.location;
        }
      }

      // Check if we have valid points now
      if (_originLatLng == null || _destLatLng == null) {
        setState(() {
          _isLoading = false;
          _errorMessage = "Please enter valid start and destination info.";
        });
        return;
      }

      // 1. Fetch Candidates
      final directionsService = ref.read(directionsServiceProvider);
      final candidates = await directionsService.getAlternativeDirections(
        origin: _originLatLng!,
        destination: _destLatLng!,
      );

      if (candidates.isEmpty) {
        setState(() {
          _errorMessage = "No routes found.";
          _isLoading = false;
        });
        return;
      }

      // 2. Score Routes
      final scoringService = ref.read(routeScoringServiceProvider);
      final scored = await scoringService.scoreAndRankRoutes(candidates);

      setState(() {
        _routes = scored;
        if (_routes.isNotEmpty) {
          _selectedRoute = _routes.first;
          _fitBounds(_selectedRoute!.route.bounds);
        }
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = "Error finding routes: $e";
        _isLoading = false;
      });
    }
  }

  void _onAddressSearch(String query, bool isOrigin) async {
    if (query.isEmpty) return;

    // Simple geocoding implementation
    final geocodingService = ref.read(geocodingServiceProvider);
    final result = await geocodingService.searchAddress(query);

    if (result != null) {
      setState(() {
        if (isOrigin) {
          _originLatLng = result.location;
          _originController.text = result.formattedAddress;
        } else {
          _destLatLng = result.location;
          _destController.text = result.formattedAddress;
        }
      });
      // Move map
      _mapController?.animateCamera(CameraUpdate.newLatLng(result.location));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Address not found: $query')),
      );
    }
  }

  Future<void> _useMyLocation() async {
    try {
      final pos = await Geolocator.getCurrentPosition();
      final latLng = LatLng(pos.latitude, pos.longitude);

      setState(() {
        _originLatLng = latLng;
        _originController.text = "My Location";
      });
      _mapController?.animateCamera(CameraUpdate.newLatLngZoom(latLng, 15));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not get current location')),
      );
    }
  }

  void _fitBounds(LatLngBounds bounds) {
    _mapController?.animateCamera(CameraUpdate.newLatLngBounds(bounds, 80));
  }

  // --- UI Builders ---

  Color _getScoreColor(double score) {
    if (score >= 0.8) return Colors.greenAccent[700]!;
    if (score >= 0.6) return Colors.yellow[700]!;
    if (score >= 0.4) return Colors.orange;
    return Colors.red;
  }

  // State for map picking
  String? _pickingField; // 'origin' or 'dest' or null

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false, // Prevent map resize on keyboard
      body: Stack(
        children: [
          // 1. Map Layer
          GoogleMap(
            initialCameraPosition: _initialCameraPosition,
            myLocationEnabled: true,
            myLocationButtonEnabled: false, // Custom button used
            zoomControlsEnabled: false,
            onMapCreated: (c) => _mapController = c,
            markers: _buildMarkers(),
            polylines: _buildPolylines(),
            onTap: (pos) {
               // Handle picking first
               if (_pickingField != null) {
                 _onMapPick(pos);
               } else {
                 FocusScope.of(context).unfocus();
               }
            },
          ),
          
          // Map Picking Banner
          if (_pickingField != null)
             Positioned(
               top: 100,
               left: 20,
               right: 20,
               child: Container(
                 padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
                 decoration: BoxDecoration(
                   color: Colors.blueAccent,
                   borderRadius: BorderRadius.circular(30),
                   boxShadow: const [BoxShadow(blurRadius: 10, color: Colors.black26)]
                 ),
                 child: Row(
                   mainAxisAlignment: MainAxisAlignment.center,
                   children: [
                     const Icon(Icons.touch_app, color: Colors.white),
                     const SizedBox(width: 10),
                     Text(
                       _pickingField == 'origin' ? "Tap map to set Start" : "Tap map to set Destination",
                       style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                     ),
                     const Spacer(),
                     InkWell(
                       onTap: () => setState(() => _pickingField = null),
                       child: const Icon(Icons.close, color: Colors.white),
                     )
                   ],
                 ),
               ),
             ),

          // 2. Search Box (Top)
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Card(
                elevation: 8,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Origin
                      TextField(
                        controller: _originController,
                        decoration: InputDecoration(
                          labelText: 'Start',
                          prefixIcon:
                              const Icon(Icons.my_location, color: Colors.blue),
                          suffixIcon: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                               IconButton(
                                icon: Icon(Icons.map, color: _pickingField == 'origin' ? Colors.blue : Colors.grey),
                                onPressed: () => setState(() => _pickingField = 'origin'),
                                tooltip: 'Pick on Map',
                              ),
                              IconButton(
                                icon: const Icon(Icons.gps_fixed),
                                onPressed: _useMyLocation,
                                tooltip: 'Use Current Location',
                              ),
                            ],
                          ),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12)),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                        ),
                        onSubmitted: (val) => _onAddressSearch(val, true),
                        onTap: () {
                           // If user taps text field, cancel map picking
                           if (_pickingField != null) setState(() => _pickingField = null);
                        },
                      ),
                      const SizedBox(height: 12),
                      // Destination
                      TextField(
                        controller: _destController,
                        decoration: InputDecoration(
                          labelText: 'Destination',
                          prefixIcon: const Icon(Icons.flag, color: Colors.red),
                          suffixIcon: IconButton(
                              icon: Icon(Icons.map, color: _pickingField == 'dest' ? Colors.blue : Colors.grey),
                              onPressed: () => setState(() => _pickingField = 'dest'),
                              tooltip: 'Pick on Map',
                          ),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12)),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                        ),
                        onSubmitted: (val) => _onAddressSearch(val, false),
                        onTap: () {
                           if (_pickingField != null) setState(() => _pickingField = null);
                        },
                      ),
                      const SizedBox(height: 16),
                      // Search Button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _searchRoutes,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue[800],
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                            elevation: 2,
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                      color: Colors.white, strokeWidth: 2))
                              : const Text('SEARCH BICYCLE ROUTES',
                                  style:
                                      TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // 3. Error Message
          if (_errorMessage != null)
            Positioned(
              top: 250,
              left: 20,
              right: 20,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                    color: Colors.redAccent,
                    borderRadius: BorderRadius.circular(8)),
                child: Text(_errorMessage!,
                    style: const TextStyle(color: Colors.white)),
              ),
            ),

          // 4. Route Results (Bottom)
          if (_routes.isNotEmpty)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _buildRouteList(),
            ),
        ],
      ),
    );
  }

  void _onMapPick(LatLng pos) async {
    final isOrigin = _pickingField == 'origin';
    setState(() {
      if (isOrigin) {
        _originLatLng = pos;
        _originController.text = "${pos.latitude.toStringAsFixed(4)}, ${pos.longitude.toStringAsFixed(4)}"; // Temporary
      } else {
        _destLatLng = pos;
        _destController.text = "${pos.latitude.toStringAsFixed(4)}, ${pos.longitude.toStringAsFixed(4)}";
      }
      _pickingField = null; // Exit picking mode
    });
    
    // Reverse Geocode for better name
    try {
      final res = await ref.read(geocodingServiceProvider).getAddressFromLatLng(pos);
      if (res != null && mounted) {
        setState(() {
          if (isOrigin) {
            _originController.text = res.formattedAddress;
          } else {
            _destController.text = res.formattedAddress;
          }
        });
      }
    } catch (_) {}
  }

  Widget _buildRouteList() {
    return Container(
      height: 240,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
              color: Colors.black12, blurRadius: 10, offset: Offset(0, -4))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Row(
              children: [
                Text(
                  '${_routes.length} Routes Found',
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                const Text("Show Obstacles"),
                Switch(
                  value: _showObstacles,
                  onChanged: (val) => setState(() => _showObstacles = val),
                  activeColor: Colors.blue[800],
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              scrollDirection: Axis.horizontal,
              itemCount: _routes.length,
              itemBuilder: (context, index) {
                final route = _routes[index];
                final isSelected = _selectedRoute == route;
                return GestureDetector(
                  onTap: () {
                    setState(() => _selectedRoute = route);
                    _fitBounds(route.route.bounds);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    width: 280,
                    margin:
                        const EdgeInsets.only(right: 16, bottom: 16, top: 4),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isSelected ? Colors.blue[50] : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color:
                            isSelected ? Colors.blue[800]! : Colors.grey[300]!,
                        width: isSelected ? 2 : 1,
                      ),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                  color: Colors.blue.withOpacity(0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 4))
                            ]
                          : [
                              const BoxShadow(
                                  color: Colors.black12,
                                  blurRadius: 4,
                                  offset: Offset(0, 2))
                            ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: _getScoreColor(route.totalScore),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '${(route.totalScore * 100).toInt()}%',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                            ),
                            const Spacer(),
                            if (!route.hasDbData)
                              const Icon(Icons.info_outline,
                                  color: Colors.grey, size: 20),
                          ],
                        ),
                        // Stats
                        Row(
                          children: [
                            const Icon(Icons.timer_outlined,
                                size: 18, color: Colors.grey),
                            const SizedBox(width: 4),
                            Text(route.route.totalDuration,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600)),
                            const SizedBox(width: 16),
                            const Icon(Icons.directions_bike,
                                size: 18, color: Colors.grey),
                            const SizedBox(width: 4),
                            Text(route.route.totalDistance,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600)),
                          ],
                        ),
                        // Explanation
                        if (route.explanations.isNotEmpty)
                          Text(
                            route.explanations.first,
                            style: TextStyle(
                                color: Colors.grey[700],
                                fontStyle: FontStyle.italic),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 2,
                          ),
                        // Navigate Button (only for selected)
                        if (isSelected)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: () => _launchNavigation(route.route.polylinePoints.last),
                                icon: const Icon(Icons.navigation, size: 18),
                                label: const Text('Navigate'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _launchNavigation(LatLng destination) async {
    final lat = destination.latitude;
    final lng = destination.longitude;
    
    Uri uri;
    
    if (Platform.isAndroid) {
      // Google Maps with bicycling mode
      uri = Uri.parse('google.navigation:q=$lat,$lng&mode=b');
    } else if (Platform.isIOS) {
      // Apple Maps with directions
      uri = Uri.parse('maps://?daddr=$lat,$lng&dirflg=b');
    } else {
      // Web fallback
      uri = Uri.parse('https://www.google.com/maps/dir/?api=1&destination=$lat,$lng&travelmode=bicycling');
    }
    
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        // Fallback to web URL
        final webUri = Uri.parse('https://www.google.com/maps/dir/?api=1&destination=$lat,$lng&travelmode=bicycling');
        await launchUrl(webUri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not launch navigation: $e')),
        );
      }
    }
  }

  Set<Polyline> _buildPolylines() {
    return _routes.map((scored) {
      final isSelected = scored == _selectedRoute;
      // High score -> Green, Low -> Red
      // We also use opacity to dim unselected routes
      final color = _getScoreColor(scored.totalScore);

      return Polyline(
        polylineId: PolylineId(scored.route.id),
        points: scored.route.polylinePoints,
        color: color.withOpacity(isSelected ? 1.0 : 0.6),
        width: isSelected ? 6 : 4,
        zIndex: isSelected ? 10 : 1,
        onTap: () => setState(() => _selectedRoute = scored),
      );
    }).toSet();
  }

  Set<Marker> _buildMarkers() {
    Set<Marker> markers = {};
    if (_originLatLng != null) {
      markers.add(Marker(
        markerId: const MarkerId('origin'),
        position: _originLatLng!,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
        infoWindow: const InfoWindow(title: 'Start'),
      ));
    }
    if (_destLatLng != null) {
      markers.add(Marker(
        markerId: const MarkerId('dest'),
        position: _destLatLng!,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        infoWindow: const InfoWindow(title: 'End'),
      ));
    }

    // Add Obstacles/Reports for SELECTED route
    if (_selectedRoute != null && _showObstacles) {
      for (var obs in _selectedRoute!.nearbyObstacles) {
        markers.add(Marker(
          markerId: MarkerId('obs_${obs.id}'),
          position: LatLng(obs.lat, obs.lng),
          icon:
              BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
          infoWindow: InfoWindow(
              title: obs.obstacleType.label,
              snippet: 'Severity: ${obs.severity.label}'),
        ));
      }
      for (var rep in _selectedRoute!.nearbyReports) {
        // Only show reports if they are warnings? Or all?
        // Showing detailed markers might clutter, let's just show issues.
        // Actually, let's keep it simple for MVP - maybe just obstacles.
        // Or show "Poor quality" spots.
      }
    }
    return markers;
  }
}
