import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../models/contribution.dart';
import '../models/bike_path.dart';
import '../services/providers.dart';
import '../utils/polyline_utils.dart';
import 'bike_path_form_page.dart';

class ContributionDetailsPage extends ConsumerStatefulWidget {
  final Contribution? contribution;
  final BikePath? path; // Backward compatibility
  final bool isPublicView;

  const ContributionDetailsPage({
    super.key, 
    this.contribution,
    this.path,
    this.isPublicView = false,
  }) : assert(contribution != null || path != null, 'Either contribution or path must be provided');

  @override
  ConsumerState<ContributionDetailsPage> createState() => _ContributionDetailsPageState();
}

class _ContributionDetailsPageState extends ConsumerState<ContributionDetailsPage> {
  GoogleMapController? _mapController;
  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};
  bool _isLoadingRoute = false;
  
  // Unified contribution (either passed directly or converted from BikePath)
  late Contribution _contribution;

  @override
  void initState() {
    super.initState();
    _contribution = widget.contribution ?? _convertBikePathToContribution(widget.path!);
    _computeInitialCameraPosition();
    _buildMapData();
  }
  
  late LatLng _initialCameraPosition;
  
  /// Compute initial camera position from segments or polyline
  void _computeInitialCameraPosition() {
    final contribution = _contribution;
    
    // First try segments
    if (contribution.segments.isNotEmpty) {
      final seg = contribution.segments.first;
      _initialCameraPosition = LatLng(seg.lat, seg.lng);
      return;
    }
    
    // Try mapPreviewPolyline
    if (contribution.mapPreviewPolyline != null && contribution.mapPreviewPolyline!.isNotEmpty) {
      final points = PolylineUtils.decodePolyline(contribution.mapPreviewPolyline!);
      if (points.isNotEmpty) {
        _initialCameraPosition = points.first;
        return;
      }
    }
    
    // Try gpsPolyline
    if (contribution.gpsPolyline != null && contribution.gpsPolyline!.isNotEmpty) {
      final points = PolylineUtils.decodePolyline(contribution.gpsPolyline!);
      if (points.isNotEmpty) {
        _initialCameraPosition = points.first;
        return;
      }
    }
    
    // Default fallback (should rarely happen)
    _initialCameraPosition = const LatLng(45.4642, 9.1900); // Milan as default
  }
  
  /// Convert legacy BikePath to Contribution for display
  Contribution _convertBikePathToContribution(BikePath path) {
    final now = DateTime.now();
    return Contribution(
      id: path.id,
      userId: path.userId,
      pathId: path.id,
      tripId: null,
      name: path.name,
      source: ContributionSource.manual,
      state: path.visibility == PathVisibility.published 
          ? ContributionState.published 
          : ContributionState.privateSaved,
      statusRating: path.status,
      obstacles: path.obstacles,
      tags: path.tags,
      segments: path.segments,
      gpsPolyline: null,
      mapPreviewPolyline: path.mapPreviewPolyline,
      distanceMeters: path.distanceMeters,
      city: path.city,
      deleted: path.deleted,
      pathScore: null,
      capturedAt: path.createdAt,
      confirmedAt: now,
      publishedAt: path.publishedAt,
      createdAt: path.createdAt,
      updatedAt: path.updatedAt,
      version: path.version,
    );
  }

  Future<void> _buildMapData() async {
    final contribution = _contribution;
    
    // Build markers from segments (for manual paths)
    _markers = {};
    for (int i = 0; i < contribution.segments.length; i++) {
      final seg = contribution.segments[i];
      _markers.add(Marker(
        markerId: MarkerId('seg_$i'),
        position: LatLng(seg.lat, seg.lng),
        infoWindow: InfoWindow(title: '${i + 1}. ${seg.streetName}'),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
      ));
    }

    // Build polyline - prioritize mapPreviewPolyline, then gpsPolyline
    List<LatLng> polylinePoints = [];
    
    if (contribution.mapPreviewPolyline != null && contribution.mapPreviewPolyline!.isNotEmpty) {
      polylinePoints = PolylineUtils.decodePolyline(contribution.mapPreviewPolyline!);
    } else if (contribution.gpsPolyline != null && contribution.gpsPolyline!.isNotEmpty) {
      polylinePoints = PolylineUtils.decodePolyline(contribution.gpsPolyline!);
    } else if (contribution.segments.length >= 2) {
      // Fetch route dynamically for manual paths
      setState(() => _isLoadingRoute = true);
      
      final directionsService = ref.read(directionsServiceProvider);
      
      for (int i = 0; i < contribution.segments.length - 1; i++) {
        final start = contribution.segments[i];
        final end = contribution.segments[i + 1];
        
        try {
          var directions = await directionsService.getDirections(
            origin: LatLng(start.lat, start.lng),
            destination: LatLng(end.lat, end.lng),
            mode: 'bicycling',
          );
          
          directions ??= await directionsService.getDirections(
            origin: LatLng(start.lat, start.lng),
            destination: LatLng(end.lat, end.lng),
            mode: 'driving',
          );
          
          if (directions != null) {
            polylinePoints.addAll(directions.polylinePoints);
          } else {
            polylinePoints.add(LatLng(start.lat, start.lng));
            polylinePoints.add(LatLng(end.lat, end.lng));
          }
        } catch (e) {
          polylinePoints.add(LatLng(start.lat, start.lng));
          polylinePoints.add(LatLng(end.lat, end.lng));
        }
      }
      
      if (mounted) {
        setState(() => _isLoadingRoute = false);
      }
    }

    if (polylinePoints.length >= 2 && mounted) {
      setState(() {
        _polylines = {
          Polyline(
            polylineId: const PolylineId('path_preview'),
            points: polylinePoints,
            color: Colors.blueAccent,
            width: 4,
          ),
        };
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final contribution = _contribution;
    final isPublished = contribution.isPublished;

    return Scaffold(
      appBar: AppBar(
        title: Text(contribution.name ?? 'Contribution Details'),
        actions: widget.isPublicView
          ? null
          : [
              if (contribution.source == ContributionSource.manual)
                IconButton(
                  icon: const Icon(Icons.edit),
                  onPressed: () => _editContribution(),
                  tooltip: 'Edit',
                ),
              PopupMenuButton(
                itemBuilder: (ctx) => [
                  PopupMenuItem(
                    child: ListTile(
                      leading: Icon(isPublished ? Icons.visibility_off : Icons.visibility),
                      title: Text(isPublished ? 'Unpublish' : 'Publish'),
                      contentPadding: EdgeInsets.zero,
                    ),
                    onTap: () => _togglePublish(),
                  ),
                  const PopupMenuItem(
                    child: ListTile(
                      leading: Icon(Icons.delete, color: Colors.red),
                      title: Text('Delete', style: TextStyle(color: Colors.red)),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ],
              ),
            ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Map Preview
            SizedBox(
              height: 250,
              child: Stack(
                children: [
                  GoogleMap(
                    initialCameraPosition: CameraPosition(
                      target: _initialCameraPosition,
                      zoom: 13,
                    ),
                    markers: _markers,
                    polylines: _polylines,
                    onMapCreated: (controller) {
                      _mapController = controller;
                      _fitBounds();
                    },
                    myLocationButtonEnabled: false,
                    zoomControlsEnabled: false,
                  ),
                  if (_isLoadingRoute)
                    Container(
                      color: Colors.black26,
                      child: const Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircularProgressIndicator(color: Colors.white),
                            SizedBox(height: 8),
                            Text('Loading route...', style: TextStyle(color: Colors.white)),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Source, Status and Score Row
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildSourceChip(contribution.source),
                      _buildStatusChip(contribution.statusRating),
                      if (contribution.pathScore != null)
                        _buildScoreChip(contribution.pathScore!),
                      if (isPublished)
                        _buildVisibilityChip(),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Stats Card
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          if (contribution.segments.isNotEmpty)
                            _buildStat(Icons.route, '${contribution.segments.length}', 'Segments'),
                          _buildStat(Icons.straighten, 
                            '${(contribution.distanceMeters / 1000).toStringAsFixed(2)}', 'km'),
                          _buildStat(Icons.warning_amber, 
                            '${contribution.obstacles.length}', 'Obstacles'),
                          if (contribution.pathScore != null)
                            _buildStat(Icons.star_rate, 
                              contribution.pathScore!.toStringAsFixed(0), 'Score'),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Route/Segments section
                  if (contribution.segments.isNotEmpty) ...[
                    Text('Route', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    ...contribution.segments.asMap().entries.map((entry) {
                      final i = entry.key;
                      final seg = entry.value;
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.green.shade100,
                          radius: 16,
                          child: Text('${i + 1}', style: const TextStyle(fontSize: 12)),
                        ),
                        title: Text(seg.streetName),
                        subtitle: Text(seg.formattedAddress, maxLines: 1, overflow: TextOverflow.ellipsis),
                        dense: true,
                      );
                    }),
                  ],

                  // Tags
                  if (contribution.tags.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Text('Tags', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: contribution.tags.map((tag) {
                        return Chip(
                          avatar: Icon(tag.icon, size: 16),
                          label: Text(tag.label),
                        );
                      }).toList(),
                    ),
                  ],

                  // Obstacles
                  if (contribution.obstacles.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Text('Reported Obstacles', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    ...contribution.obstacles.map((obs) {
                      return Card(
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: _getSeverityColor(obs.severity),
                            child: Text('${obs.severity}'),
                          ),
                          title: Text(obs.type.label),
                          subtitle: obs.note != null ? Text(obs.note!) : null,
                        ),
                      );
                    }),
                  ],

                  // Metadata
                  const SizedBox(height: 24),
                  Text('Details', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  _buildMetaRow('Type', contribution.sourceLabel),
                  _buildMetaRow('Created', _formatDateTime(contribution.createdAt)),
                  _buildMetaRow('Last Updated', _formatDateTime(contribution.updatedAt)),
                  if (contribution.publishedAt != null)
                    _buildMetaRow('Published', _formatDateTime(contribution.publishedAt!)),
                  if (contribution.confirmedAt != null)
                    _buildMetaRow('Confirmed', _formatDateTime(contribution.confirmedAt!)),
                  if (contribution.city != null)
                    _buildMetaRow('City', contribution.city!),
                  _buildMetaRow('Version', 'v${contribution.version}'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _fitBounds() {
    if (_mapController == null) return;
    
    List<LatLng> points = [];
    
    // Get points from segments
    if (_contribution.segments.isNotEmpty) {
      points = _contribution.segments.map((s) => LatLng(s.lat, s.lng)).toList();
    } 
    // Or from polylines
    else if (_polylines.isNotEmpty) {
      for (var polyline in _polylines) {
        points.addAll(polyline.points);
      }
    }
    
    if (points.length < 2) return;

    double minLat = 90, maxLat = -90, minLng = 180, maxLng = -180;
    for (var point in points) {
      if (point.latitude < minLat) minLat = point.latitude;
      if (point.latitude > maxLat) maxLat = point.latitude;
      if (point.longitude < minLng) minLng = point.longitude;
      if (point.longitude > maxLng) maxLng = point.longitude;
    }

    _mapController!.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(minLat, minLng),
          northeast: LatLng(maxLat, maxLng),
        ),
        50,
      ),
    );
  }

  Widget _buildSourceChip(ContributionSource source) {
    final isManual = source == ContributionSource.manual;
    final color = isManual ? Colors.blue : Colors.purple;
    final icon = isManual ? Icons.edit_road : Icons.gps_fixed;
    
    return Chip(
      avatar: Icon(icon, size: 16, color: color),
      label: Text(isManual ? 'Manual Path' : 'Auto-Recorded Trip'),
      backgroundColor: color.withValues(alpha: 0.1),
    );
  }

  Widget _buildStatusChip(dynamic status) {
    return Chip(
      label: Text(status.label),
      backgroundColor: Colors.blue.shade50,
    );
  }

  Widget _buildScoreChip(double score) {
    Color color;
    if (score >= 75) {
      color = Colors.green;
    } else if (score >= 50) {
      color = Colors.orange;
    } else {
      color = Colors.red;
    }

    return Chip(
      avatar: Icon(Icons.star, size: 16, color: color),
      label: Text('Score: ${score.toStringAsFixed(0)}'),
      backgroundColor: color.withValues(alpha: 0.1),
    );
  }

  Widget _buildVisibilityChip() {
    return Chip(
      avatar: const Icon(Icons.public, size: 16, color: Colors.green),
      label: const Text('Public'),
      backgroundColor: Colors.green.withValues(alpha: 0.1),
    );
  }

  Widget _buildStat(IconData icon, String value, String label) {
    return Column(
      children: [
        Icon(icon, color: Colors.green),
        const SizedBox(height: 4),
        Text(value, style: Theme.of(context).textTheme.titleLarge),
        Text(label, style: TextStyle(color: Colors.grey.shade600)),
      ],
    );
  }

  Widget _buildMetaRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(label, style: TextStyle(color: Colors.grey.shade600)),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  Color _getSeverityColor(int severity) {
    switch (severity) {
      case 1: return Colors.green.shade200;
      case 2: return Colors.lime.shade200;
      case 3: return Colors.yellow.shade300;
      case 4: return Colors.orange.shade300;
      case 5: return Colors.red.shade300;
      default: return Colors.grey;
    }
  }

  String _formatDateTime(DateTime dt) {
    return '${dt.day}/${dt.month}/${dt.year} ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
  }

  void _editContribution() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BikePathFormPage(existingContribution: _contribution),
      ),
    ).then((_) => Navigator.pop(context));
  }

  Future<void> _togglePublish() async {
    final isPublished = _contribution.isPublished;
    
    try {
      await ref.read(contributionServiceProvider).togglePublish(
        _contribution.id,
        !isPublished,
      );
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isPublished 
              ? 'Contribution moved to drafts' 
              : 'Contribution published successfully!'),
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }
}
