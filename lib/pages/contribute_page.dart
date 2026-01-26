import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:uuid/uuid.dart';
import '../services/providers.dart';
import '../models/path_quality_report.dart';
import '../models/obstacle.dart';
import '../models/trip.dart';
import '../models/gps_point.dart';
import '../models/bike_path.dart';
import '../models/route_candidate.dart';
import 'bike_path_form_page.dart';

class ContributePage extends ConsumerStatefulWidget {
  const ContributePage({super.key});

  @override
  ConsumerState<ContributePage> createState() => _ContributePageState();
}

class _ContributePageState extends ConsumerState<ContributePage> {
  GoogleMapController? _mapController;
  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};

  Trip? _selectedTrip;

  // Defines the currently selected point on the map for reporting
  LatLng? _selectedLocation;

  // Search State
  bool _isSearching = false;
  GeocodingResult? _searchResult;

  @override
  void initState() {
    super.initState();
    _loadPublicReports();
  }

  Future<void> _loadPublicReports() async {
    final contributeService = ref.read(contributeServiceProvider);

    // In a real app, combine these or fetch based on viewport
    final qualityReports =
        await contributeService.getPublicPathQualityReports();
    final obstacles = await contributeService.getPublicObstacles();

    final newMarkers = <Marker>{};

    for (var report in qualityReports) {
      newMarkers.add(
        Marker(
          markerId: MarkerId('quality_${report.id}'),
          position: LatLng(report.lat, report.lng),
          icon:
              BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
          infoWindow: InfoWindow(
            title: 'Path Quality: ${report.status.label}',
            snippet: 'Reported on ${report.createdAt.toString().split(' ')[0]}',
          ),
        ),
      );
    }

    for (var obs in obstacles) {
      newMarkers.add(
        Marker(
          markerId: MarkerId('obstacle_${obs.id}'),
          position: LatLng(obs.lat, obs.lng),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          infoWindow: InfoWindow(
            title: 'Obstacle: ${obs.obstacleType.label}',
            snippet: 'Severity: ${obs.severity.label}',
          ),
        ),
      );
    }

    setState(() {
      _markers = newMarkers;
    });
  }

  // Updated search to support picking from candidates (simulated suggestions)
  Future<void> _handleSearch(String query) async {
    if (query.isEmpty) return;

    setState(() => _isSearching = true);

    // In a real implementation with Places API, we would get autocomplete suggestions here.
    // With native geocoder, we just get a precise match or a list of matches.
    final result =
        await ref.read(geocodingServiceProvider).searchAddress(query);

    setState(() => _isSearching = false);

    if (result != null) {
      _selectSearchResult(result);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Address not found.')));
      }
    }
  }

  void _selectSearchResult(GeocodingResult result) async {
    // 1. Update State with marker immediately
    setState(() {
      _searchResult = result;
      _selectedTrip = null; // Clear selected trip
      _selectedLocation = result.location;

      _markers = {};
      _markers.add(Marker(
        markerId: const MarkerId('searched_location'),
        position: result.location,
        infoWindow: InfoWindow(title: result.formattedAddress),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueViolet),
      ));

      // Default to point zoom first
      _polylines = {};
    });

    // 2. Calculate Navigation Route (Navigation Map)
    // Get current location to start navigation from
    Position? currentPos;
    try {
      currentPos = await Geolocator.getCurrentPosition();
    } catch (_) {
      // Permission might be denied or service disabled
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Could not get current location for navigation.')));
      return;
    }

    final directionsService = ref.read(directionsServiceProvider);

    // 3. Try Bicycling Mode
    RouteCandidate? directions = await directionsService.getDirections(
      origin: LatLng(currentPos.latitude, currentPos.longitude),
      destination: result.location,
      mode: 'bicycling',
    );

    bool isBikePath = true;

    // 4. Fallback to Driving if no bike route found
    if (directions == null) {
      isBikePath = false;
      directions = await directionsService.getDirections(
        origin: LatLng(currentPos.latitude, currentPos.longitude),
        destination: result.location,
        mode: 'driving',
      );
    }

    if (mounted && directions != null) {
      setState(() {
        // Add Route Polyline
        _polylines.add(Polyline(
          polylineId: const PolylineId('navigation_route'),
          points: directions!.polylinePoints,
          color: isBikePath
              ? Colors.blue
              : Colors.grey, // Blue for bike, Grey for road
          width: 5,
        ));
      });

      // Show Message
      final msg = isBikePath
          ? 'Access via Cycle Path found!'
          : 'No dedicated bike path available. Showing road route.';

      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(msg),
        backgroundColor: isBikePath ? Colors.green : Colors.orange,
        duration: const Duration(seconds: 4),
      ));

      // Zoom to fit route
      _mapController
          ?.animateCamera(CameraUpdate.newLatLngBounds(directions.bounds, 50));
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Could not find a route to this location.')));
    }
  }

  void _onMapTap(LatLng position) {
    if (_searchResult != null) {
      // In search mode, any tap updates location or opens dialog
      setState(() {
        _selectedLocation = position;
      });
      _showReportOptions(position);
      return;
    }

    if (_selectedTrip == null) return;

    // Snap logic: Find closest point on the route
    GpsPoint? closestPoint;
    double minDistance = double.infinity;

    for (var point in _selectedTrip!.points) {
      double distance = Geolocator.distanceBetween(position.latitude,
          position.longitude, point.latitude, point.longitude);
      if (distance < minDistance) {
        minDistance = distance;
        closestPoint = point;
      }
    }

    // Threshold: 50 meters
    if (closestPoint != null && minDistance <= 50) {
      final snappedPosition =
          LatLng(closestPoint.latitude, closestPoint.longitude);
      setState(() {
        _selectedLocation = snappedPosition;
      });
      _showReportOptions(snappedPosition);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content:
                Text('Please tap closer to the route line to report issues.')),
      );
    }
  }

  void _showReportOptions(LatLng position) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.show_chart, color: Colors.green),
                title: const Text('Report Path Quality Here'),
                subtitle: const Text('Rate specific segment quality'),
                onTap: () {
                  Navigator.pop(context);
                  _showPathQualityForm(position);
                },
              ),
              ListTile(
                leading: const Icon(Icons.warning_amber_rounded,
                    color: Colors.orange),
                title: const Text('Report Obstacle'),
                onTap: () {
                  Navigator.pop(context);
                  _showObstacleForm(position);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _selectTrip(Trip trip) {
    setState(() {
      _selectedTrip = trip;
      _searchResult = null; // Clear search
      _polylines = {
        Polyline(
            polylineId: PolylineId(trip.id),
            points: trip.points
                .map((p) => LatLng(p.latitude, p.longitude))
                .toList(),
            color: Colors.blueAccent,
            width: 5,
            consumeTapEvents: true,
            onTap: () {
              // If they tap the line, offer to rate the whole trip or start point
              _rateFullTrip(trip);
            }),
      };
    });
  }

  void _rateFullTrip(Trip trip) {
    if (trip.points.isEmpty) return;
    // Use the start point as the anchor for the "Trip Report"
    // In a real system you might have a different way to store "whole route" ratings.
    final startPos =
        LatLng(trip.points.first.latitude, trip.points.first.longitude);
    _showPathQualityForm(startPos, isFullTrip: true);
  }

  void _clearSelection() {
    setState(() {
      _selectedTrip = null;
      _searchResult = null;
      _polylines = {};
      _selectedLocation = null;
      _markers.removeWhere((m) => m.markerId.value == 'searched_location');
    });
  }

  void _showPathQualityForm(LatLng position, {bool isFullTrip = false}) {
    showDialog(
      context: context,
      builder: (context) => _ReportPathQualityDialog(
        position: position,
        routeContext: _selectedTrip?.id,
        isFullTrip: isFullTrip,
        onSubmit: (report) async {
          await ref
              .read(contributeServiceProvider)
              .addPathQualityReport(report);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Report submitted!')));
            _loadPublicReports(); // Refresh map
          }
        },
      ),
    );
  }

  void _showObstacleForm(LatLng position) {
    showDialog(
      context: context,
      builder: (context) => _ReportObstacleDialog(
        position: position,
        onSubmit: (obstacle) async {
          await ref.read(contributeServiceProvider).addObstacle(obstacle);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Obstacle reported!')));
            _loadPublicReports(); // Refresh map
          }
        },
      ),
    );
  }

  void _showSearchDialog() {
    // Show a full screen search page
    Navigator.of(context).push(MaterialPageRoute(builder: (context) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Search Street'),
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: TextField(
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'Enter street name (e.g. Main St, Boston)',
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.search),
                    onPressed: () {}, // Triggered by submitted
                  ),
                ),
                onSubmitted: (val) {
                  Navigator.pop(context);
                  _handleSearch(val);
                },
              ),
            ),
            const ListTile(
              leading: Icon(Icons.info_outline),
              title: Text('Tip: Include city name for better results'),
            )
          ],
        ),
      );
    }));
  }

  @override
  Widget build(BuildContext context) {
    if (_selectedTrip == null && _searchResult == null) {
      return _buildTripList();
    } else {
      return _buildMap();
    }
  }

  Widget _buildTripList() {
    final tripsAsync = ref.watch(tripsStreamProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Contribute')),
      body: Column(
        children: [
          // Manual Mode: Create Bike Path
          Card(
            margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            color: Colors.green.shade50,
            child: ListTile(
              leading: const Icon(Icons.add_road, color: Colors.green),
              title: const Text('Create New Bike Path'),
              subtitle: const Text('Compose a path from multiple streets'),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () {
                Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const BikePathFormPage()))
                    .then((_) => ref.refresh(myBikePathsFutureProvider));
              },
            ),
          ),

          // Quick Report
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: Colors.blue.shade50,
            child: ListTile(
              leading: const Icon(Icons.search, color: Colors.blue),
              title: const Text('Quick Report by Address'),
              subtitle: const Text('Locate a specific spot to report quality'),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: _showSearchDialog,
            ),
          ),
          const Divider(height: 1),
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Align(
                alignment: Alignment.centerLeft,
                child: Text('OR Select a Recent Trip',
                    style: TextStyle(
                        fontWeight: FontWeight.bold, color: Colors.grey))),
          ),
          Expanded(
            child: Consumer(
              builder: (context, ref, child) {
                final tripsAsync = ref.watch(tripsStreamProvider);
                final pathsAsync = ref.watch(myBikePathsFutureProvider);

                return tripsAsync.when(
                  data: (trips) {
                    return pathsAsync.when(
                      data: (paths) {
                        // Merge and Sort
                        final combined = <dynamic>[...trips, ...paths];
                        combined.sort((a, b) {
                          DateTime timeA = a is Trip
                              ? a.startTime
                              : (a as BikePath).createdAt;
                          DateTime timeB = b is Trip
                              ? b.startTime
                              : (b as BikePath).createdAt;
                          return timeB.compareTo(timeA); // Descending
                        });

                        if (combined.isEmpty) {
                          return const Center(
                              child: Text('No recorded trips or paths found.'));
                        }

                        return ListView.builder(
                          itemCount: combined.length,
                          itemBuilder: (ctx, index) {
                            final item = combined[index];
                            if (item is Trip) {
                              return Card(
                                margin: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 8),
                                child: ListTile(
                                  leading: const Icon(Icons.directions_bike),
                                  title: Text(
                                      item.startTime.toString().split('.')[0]),
                                  subtitle: Text(
                                      '${(item.distanceMeters / 1000).toStringAsFixed(2)} km'),
                                  trailing: TextButton(
                                    child: const Text('Rate'),
                                    onPressed: () {
                                      _selectTrip(item);
                                      Future.delayed(
                                          const Duration(milliseconds: 500),
                                          () {
                                        if (mounted) _rateFullTrip(item);
                                      });
                                    },
                                  ),
                                  onTap: () => _selectTrip(item),
                                ),
                              );
                            } else if (item is BikePath) {
                              return Card(
                                margin: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 8),
                                child: ListTile(
                                  leading: const Icon(Icons.edit_road,
                                      color: Colors.green),
                                  title: Text(
                                      item.createdAt.toString().split('.')[0]),
                                  subtitle: Text(
                                      'Manual Path • ${(item.distanceMeters / 1000).toStringAsFixed(2)} km'),
                                  trailing: const Chip(
                                      label: Text('Manual'),
                                      backgroundColor: Colors.green,
                                      labelStyle: TextStyle(
                                          color: Colors.white, fontSize: 10)),
                                  onTap: () {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                            content: Text(
                                                'Viewing manual paths is coming soon!')));
                                  },
                                ),
                              );
                            }
                            return const SizedBox.shrink();
                          },
                        );
                      },
                      loading: () =>
                          const Center(child: CircularProgressIndicator()),
                      error: (e, s) =>
                          Center(child: Text('Error loading paths: $e')),
                    );
                  },
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, s) =>
                      Center(child: Text('Error loading trips: $e')),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMap() {
    LatLng initialPos = const LatLng(37.7749, -122.4194);
    if (_selectedTrip != null && _selectedTrip!.points.isNotEmpty) {
      initialPos = LatLng(_selectedTrip!.points.first.latitude,
          _selectedTrip!.points.first.longitude);
    } else if (_searchResult != null) {
      initialPos = _searchResult!.location;
    }

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _clearSelection,
        ),
        title:
            Text(_searchResult != null ? 'Tap to Rate' : 'Tap Route to Report'),
      ),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: initialPos,
              zoom: 15,
            ),
            markers: _markers,
            polylines: _polylines,
            onMapCreated: (controller) {
              _mapController = controller;
              if (_selectedTrip != null && _selectedTrip!.points.isNotEmpty) {
                controller.animateCamera(CameraUpdate.newLatLng(initialPos));
              } else if (_searchResult != null) {
                controller
                    .animateCamera(CameraUpdate.newLatLngZoom(initialPos, 16));
                // Try to bounds zoom if viewport exists
                // With native geocoder this is usually null, so we just zoom to point.
                if (_searchResult!.viewport != null) {
                  controller.animateCamera(CameraUpdate.newLatLngBounds(
                      _searchResult!.viewport!, 50));
                }
              }
            },
            onTap: _onMapTap,
          ),
          if (_searchResult != null)
            Positioned(
              bottom: 40,
              left: 16,
              right: 16,
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_searchResult!.formattedAddress,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center),
                      const SizedBox(height: 8),
                      ElevatedButton(
                        onPressed: () =>
                            _showPathQualityForm(_searchResult!.location),
                        child: const Text('Rate This Location'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          if (_selectedTrip != null)
            Positioned(
              bottom: 80,
              right: 16,
              child: FloatingActionButton.extended(
                label: const Text('Rate Full Route'),
                icon: const Icon(Icons.star),
                onPressed: () {
                  _rateFullTrip(_selectedTrip!);
                },
              ),
            ),
          if (_isSearching) const Center(child: CircularProgressIndicator()),
        ],
      ),
    );
  }
}

class _ReportPathQualityDialog extends StatefulWidget {
  final LatLng position;
  final String? routeContext;
  final bool isFullTrip;
  final Function(PathQualityReport) onSubmit;

  const _ReportPathQualityDialog(
      {required this.position,
      this.routeContext,
      this.isFullTrip = false,
      required this.onSubmit});

  @override
  State<_ReportPathQualityDialog> createState() =>
      _ReportPathQualityDialogState();
}

class _ReportPathQualityDialogState extends State<_ReportPathQualityDialog> {
  PathRateStatus? _status; // Nullable to force selection
  bool _publishable = true;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title:
          Text(widget.isFullTrip ? 'Rate Entire Trip' : 'Report Path Quality'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(widget.isFullTrip
              ? 'How was the quality of this entire trip?'
              : 'How is the path quality at this specific location?'),
          const SizedBox(height: 16),
          DropdownButtonFormField<PathRateStatus>(
            value: _status,
            decoration: const InputDecoration(labelText: 'Select Status'),
            items: PathRateStatus.values.map((s) {
              return DropdownMenuItem(value: s, child: Text(s.label));
            }).toList(),
            onChanged: (val) => setState(() => _status = val!),
          ),
          const SizedBox(height: 16),
          if (widget.routeContext != null)
            const Padding(
              padding: EdgeInsets.only(bottom: 16.0),
              child: Row(
                children: [
                  Icon(Icons.link, size: 16, color: Colors.blue),
                  SizedBox(width: 8),
                  Text('Report will be linked to this trip',
                      style: TextStyle(fontSize: 12, color: Colors.blue)),
                ],
              ),
            ),
          SwitchListTile(
            title: const Text('Public Report'),
            subtitle: const Text('Allow others to see this report'),
            value: _publishable,
            onChanged: (val) => setState(() => _publishable = val),
          ),
        ],
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel')),
        Consumer(builder: (context, ref, child) {
          return ElevatedButton(
            onPressed: _status == null
                ? null
                : () {
                    // Disable if no status selected
                    final user = ref.read(authStateProvider).value;
                    if (user == null) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                          content: Text('You must be logged in.')));
                      return;
                    }

                    final report = PathQualityReport(
                      id: const Uuid().v4(),
                      userId: user.uid,
                      lat: widget.position.latitude,
                      lng: widget.position.longitude,
                      routeContext: widget.routeContext,
                      status: _status!,
                      publishable: _publishable,
                      createdAt: DateTime.now(),
                    );

                    widget.onSubmit(report);
                    Navigator.pop(context);
                  },
            child: const Text('Submit'),
          );
        }),
      ],
    );
  }
}

class _ReportObstacleDialog extends StatefulWidget {
  final LatLng position;
  final Function(Obstacle) onSubmit;

  const _ReportObstacleDialog({required this.position, required this.onSubmit});

  @override
  State<_ReportObstacleDialog> createState() => _ReportObstacleDialogState();
}

class _ReportObstacleDialogState extends State<_ReportObstacleDialog> {
  ObstacleType _type = ObstacleType.pothole;
  ObstacleSeverity _severity = ObstacleSeverity.medium;
  bool _publishable = true;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Report Obstacle'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('What kind of obstacle is this?'),
            const SizedBox(height: 16),
            DropdownButtonFormField<ObstacleType>(
              value: _type,
              decoration: const InputDecoration(labelText: 'Type'),
              items: ObstacleType.values.map((t) {
                return DropdownMenuItem(value: t, child: Text(t.label));
              }).toList(),
              onChanged: (val) => setState(() => _type = val!),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<ObstacleSeverity>(
              value: _severity,
              decoration: const InputDecoration(labelText: 'Severity'),
              items: ObstacleSeverity.values.map((s) {
                return DropdownMenuItem(value: s, child: Text(s.label));
              }).toList(),
              onChanged: (val) => setState(() => _severity = val!),
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              title: const Text('Public Report'),
              subtitle: const Text('Allow others to see this report'),
              value: _publishable,
              onChanged: (val) => setState(() => _publishable = val),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel')),
        Consumer(builder: (context, ref, child) {
          return ElevatedButton(
            onPressed: () {
              final user = ref.read(authStateProvider).value;
              if (user == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('You must be logged in.')));
                return;
              }

              final obstacle = Obstacle(
                id: const Uuid().v4(),
                userId: user.uid,
                lat: widget.position.latitude,
                lng: widget.position.longitude,
                obstacleType: _type,
                severity: _severity,
                publishable: _publishable,
                createdAt: DateTime.now(),
              );

              widget.onSubmit(obstacle);
              Navigator.pop(context);
            },
            child: const Text('Submit'),
          );
        }),
      ],
    );
  }
}
