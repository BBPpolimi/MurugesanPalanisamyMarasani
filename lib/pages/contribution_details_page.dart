import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../models/bike_path.dart';
import '../services/providers.dart';
import 'bike_path_form_page.dart';

class ContributionDetailsPage extends ConsumerStatefulWidget {
  final BikePath path;
  final bool isPublicView;

  const ContributionDetailsPage({
    super.key, 
    required this.path,
    this.isPublicView = false,
  });

  @override
  ConsumerState<ContributionDetailsPage> createState() => _ContributionDetailsPageState();
}

class _ContributionDetailsPageState extends ConsumerState<ContributionDetailsPage> {
  GoogleMapController? _mapController;
  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};

  @override
  void initState() {
    super.initState();
    _buildMapData();
  }

  void _buildMapData() {
    final path = widget.path;
    
    // Build markers
    _markers = {};
    for (int i = 0; i < path.segments.length; i++) {
      final seg = path.segments[i];
      _markers.add(Marker(
        markerId: MarkerId('seg_$i'),
        position: LatLng(seg.lat, seg.lng),
        infoWindow: InfoWindow(title: '${i + 1}. ${seg.streetName}'),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
      ));
    }

    // Build polyline (simplified - just connect the points)
    if (path.segments.length >= 2) {
      _polylines = {
        Polyline(
          polylineId: const PolylineId('path_preview'),
          points: path.segments.map((s) => LatLng(s.lat, s.lng)).toList(),
          color: Colors.blueAccent,
          width: 4,
        ),
      };
    }
  }

  @override
  Widget build(BuildContext context) {
    final path = widget.path;
    final isPublished = path.visibility == PathVisibility.published;

    return Scaffold(
      appBar: AppBar(
        title: Text(path.name ?? 'Path Details'),
        actions: widget.isPublicView
          ? null  // No actions for public view
          : [
              IconButton(
                icon: const Icon(Icons.edit),
                onPressed: () => _editPath(),
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
              child: GoogleMap(
                initialCameraPosition: CameraPosition(
                  target: path.segments.isNotEmpty
                      ? LatLng(path.segments.first.lat, path.segments.first.lng)
                      : const LatLng(37.7749, -122.4194),
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
            ),

            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Status Row
                  Row(
                    children: [
                      _buildStatusChip(path.status),
                      const SizedBox(width: 8),
                      _buildVisibilityChip(path.visibility),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Stats
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildStat(
                            Icons.route,
                            '${path.segments.length}',
                            'Segments',
                          ),
                          _buildStat(
                            Icons.straighten,
                            '${(path.distanceMeters / 1000).toStringAsFixed(2)}',
                            'km',
                          ),
                          _buildStat(
                            Icons.warning_amber,
                            '${path.obstacles.length}',
                            'Obstacles',
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Streets
                  Text(
                    'Route',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  ...path.segments.asMap().entries.map((entry) {
                    final i = entry.key;
                    final seg = entry.value;
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Colors.green.shade100,
                        radius: 16,
                        child: Text(
                          '${i + 1}',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                      title: Text(seg.streetName),
                      subtitle: Text(
                        seg.formattedAddress,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      dense: true,
                    );
                  }),

                  // Tags
                  if (path.tags.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Text(
                      'Tags',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: path.tags.map((tag) {
                        return Chip(
                          avatar: Icon(tag.icon, size: 16),
                          label: Text(tag.label),
                        );
                      }).toList(),
                    ),
                  ],

                  // Obstacles
                  if (path.obstacles.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Text(
                      'Reported Obstacles',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    ...path.obstacles.map((obs) {
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
                  Text(
                    'Details',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  _buildMetaRow('Created', _formatDateTime(path.createdAt)),
                  _buildMetaRow('Last Updated', _formatDateTime(path.updatedAt)),
                  if (path.publishedAt != null)
                    _buildMetaRow('Published', _formatDateTime(path.publishedAt!)),
                  if (path.city != null)
                    _buildMetaRow('City', path.city!),
                  _buildMetaRow('Version', 'v${path.version}'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _fitBounds() {
    if (_mapController == null || widget.path.segments.length < 2) return;

    double minLat = 90, maxLat = -90, minLng = 180, maxLng = -180;
    for (var seg in widget.path.segments) {
      if (seg.lat < minLat) minLat = seg.lat;
      if (seg.lat > maxLat) maxLat = seg.lat;
      if (seg.lng < minLng) minLng = seg.lng;
      if (seg.lng > maxLng) maxLng = seg.lng;
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

  Widget _buildStatusChip(dynamic status) {
    return Chip(
      label: Text(status.label),
      backgroundColor: Colors.blue.shade50,
    );
  }

  Widget _buildVisibilityChip(PathVisibility visibility) {
    Color color;
    String label;
    IconData icon;

    switch (visibility) {
      case PathVisibility.published:
        color = Colors.green;
        label = 'Public';
        icon = Icons.public;
        break;
      case PathVisibility.flagged:
        color = Colors.orange;
        label = 'Flagged';
        icon = Icons.flag;
        break;
      case PathVisibility.private:
      default:
        color = Colors.grey;
        label = 'Private';
        icon = Icons.lock;
    }

    return Chip(
      avatar: Icon(icon, size: 16, color: color),
      label: Text(label),
      backgroundColor: color.withOpacity(0.1),
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
      case 1:
        return Colors.green.shade200;
      case 2:
        return Colors.lime.shade200;
      case 3:
        return Colors.yellow.shade300;
      case 4:
        return Colors.orange.shade300;
      case 5:
        return Colors.red.shade300;
      default:
        return Colors.grey;
    }
  }

  String _formatDateTime(DateTime dt) {
    return '${dt.day}/${dt.month}/${dt.year} ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
  }

  void _editPath() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BikePathFormPage(existingPath: widget.path),
      ),
    ).then((_) => Navigator.pop(context));
  }

  Future<void> _togglePublish() async {
    final isPublished = widget.path.visibility == PathVisibility.published;
    
    try {
      await ref.read(contributeServiceProvider).togglePublish(
        widget.path.id,
        !isPublished,
      );
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isPublished 
              ? 'Path moved to drafts' 
              : 'Path published successfully!'),
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
