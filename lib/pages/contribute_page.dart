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
import '../models/contribution.dart';

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



  void _onMapTap(LatLng position) {
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
      _polylines = {};
      _selectedLocation = null;
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



  @override
  Widget build(BuildContext context) {
    if (_selectedTrip == null) {
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
                // tripsStreamProvider already includes both trips and contributions
                final tripsAsync = ref.watch(tripsStreamProvider);

                return tripsAsync.when(
                  data: (combined) {
                    // Already sorted by date in provider
                    if (combined.isEmpty) {
                      return const Center(
                          child: Text('No recorded trips or paths found.'));
                        }

                        return ListView.builder(
                          itemCount: combined.length,
                          itemBuilder: (ctx, index) {
                            final item = combined[index];
                            if (item is Trip) {
                              // Display trip with a readable name or formatted date
                              final tripName = 'Trip on ${item.startTime.day}/${item.startTime.month}/${item.startTime.year} at ${item.startTime.hour.toString().padLeft(2, '0')}:${item.startTime.minute.toString().padLeft(2, '0')}';
                              return Card(
                                margin: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 8),
                                child: ListTile(
                                  leading: const Icon(Icons.directions_bike),
                                  title: Text(tripName),
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
                            } else if (item is Contribution) {
                              // Display contribution with name or formatted date
                              final displayName = item.name ?? 
                                  '${item.sourceLabel} - ${item.capturedAt.day}/${item.capturedAt.month}/${item.capturedAt.year}';
                              final isManual = item.source == ContributionSource.manual;
                              return Card(
                                margin: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 8),
                                child: ListTile(
                                  leading: Icon(
                                    isManual ? Icons.edit_road : Icons.route,
                                    color: isManual ? Colors.green : Colors.blue,
                                  ),
                                  title: Text(displayName),
                                  subtitle: Text(
                                      '${item.sourceShortLabel} • ${(item.distanceMeters / 1000).toStringAsFixed(2)} km • ${item.statusRating.label}'),
                                  trailing: Chip(
                                    label: Text(item.sourceShortLabel),
                                    backgroundColor: isManual ? Colors.green : Colors.blue,
                                    labelStyle: const TextStyle(
                                        color: Colors.white, fontSize: 10),
                                  ),
                                  onTap: () {
                                    // Navigate to contribution details page
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => BikePathFormPage(
                                          existingContribution: item,
                                        ),
                                      ),
                                    );
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
                      Center(child: Text('Error loading data: $e')),
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
    }

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _clearSelection,
        ),
        title: const Text('Tap Route to Report'),
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
              }
            },
            onTap: _onMapTap,
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
