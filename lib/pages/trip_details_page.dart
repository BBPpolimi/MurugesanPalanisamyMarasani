import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../models/trip.dart';
import '../models/contribution.dart';
import '../services/providers.dart';

class TripDetailsPage extends ConsumerStatefulWidget {
  final Trip trip;

  const TripDetailsPage({super.key, required this.trip});

  @override
  ConsumerState<TripDetailsPage> createState() => _TripDetailsPageState();
}

class _TripDetailsPageState extends ConsumerState<TripDetailsPage> {
  Contribution? _contribution;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadContribution();
  }

  Future<void> _loadContribution() async {
    if (widget.trip.contributionId != null) {
      final contribution = await ref
          .read(contributionServiceProvider)
          .getContribution(widget.trip.contributionId!);
      if (mounted) {
        setState(() {
          _contribution = contribution;
          _isLoading = false;
        });
      }
    } else {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final trip = widget.trip;

    Set<Polyline> polylines = {};
    Set<Marker> markers = {};
    CameraPosition initialPosition;

    if (trip.points.isNotEmpty) {
      final points =
          trip.points.map((p) => LatLng(p.latitude, p.longitude)).toList();

      polylines.add(
        Polyline(
          polylineId: PolylineId(trip.id),
          points: points,
          color: Colors.blue,
          width: 5,
        ),
      );

      markers.add(
        Marker(
          markerId: const MarkerId('start'),
          position: points.first,
          icon:
              BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
          infoWindow: const InfoWindow(title: 'Start'),
        ),
      );

      markers.add(
        Marker(
          markerId: const MarkerId('end'),
          position: points.last,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          infoWindow: const InfoWindow(title: 'End'),
        ),
      );

      initialPosition = CameraPosition(
        target: points.first,
        zoom: 15,
      );
    } else {
      initialPosition = const CameraPosition(
        target: LatLng(0, 0),
        zoom: 2,
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(trip.name ?? 'Trip Details'),
        actions: [
          if (_contribution != null)
            IconButton(
              icon: Icon(
                _contribution!.state == ContributionState.published
                    ? Icons.public
                    : Icons.public_off,
                color: _contribution!.state == ContributionState.published
                    ? Colors.green
                    : Colors.grey,
              ),
              tooltip: _getContributionStateTooltip(_contribution!.state),
              onPressed: () => _showContributionActions(),
            ),
        ],
      ),
      body: Column(
        children: [
          // Map
          Expanded(
            flex: 2,
            child: trip.points.isNotEmpty
                ? GoogleMap(
                    initialCameraPosition: initialPosition,
                    polylines: polylines,
                    markers: markers,
                    onMapCreated: (controller) {
                      if (trip.points.isNotEmpty) {
                        final bounds = _boundsFromLatLngList(trip.points
                            .map((p) => LatLng(p.latitude, p.longitude))
                            .toList());
                        Future.delayed(const Duration(milliseconds: 500), () {
                          try {
                            controller.animateCamera(
                                CameraUpdate.newLatLngBounds(bounds, 50));
                          } catch (e) {
                            debugPrint(
                                "Map animation error (expected if disposed): $e");
                          }
                        });
                      }
                    },
                  )
                : const Center(
                    child: Text('No GPS points recorded for this trip')),
          ),

          // Details panel
          Expanded(
            flex: 1,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Trip info badges row
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        if (trip.isAutoDetected)
                          _buildBadge(
                              'Auto-detected', Colors.blue, Icons.auto_awesome),
                        if (_contribution != null)
                          _buildContributionStateBadge(_contribution!),
                        if (trip.weatherData != null)
                          _buildBadge(
                            '${trip.weatherData!.conditions} ${trip.weatherData!.temperature.toStringAsFixed(0)}°C',
                            Colors.orange,
                            Icons.wb_sunny,
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Stats grid
                    Row(
                      children: [
                        _buildStatCard(
                            'Distance',
                            '${(trip.distanceMeters / 1000).toStringAsFixed(2)} km',
                            Icons.straighten),
                        const SizedBox(width: 12),
                        _buildStatCard('Duration',
                            '${trip.duration.inMinutes} min', Icons.timer),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        _buildStatCard(
                            'Avg Speed',
                            '${(trip.averageSpeed * 3.6).toStringAsFixed(1)} km/h',
                            Icons.speed),
                        const SizedBox(width: 12),
                        _buildStatCard('Points', '${trip.points.length}',
                            Icons.location_on),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Time info
                    Text(
                      'Start: ${_formatDateTime(trip.startTime)}',
                      style:
                          TextStyle(color: Colors.grey.shade600, fontSize: 12),
                    ),
                    Text(
                      'End: ${_formatDateTime(trip.endTime)}',
                      style:
                          TextStyle(color: Colors.grey.shade600, fontSize: 12),
                    ),

                    // Weather info if available
                    if (trip.weatherData != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.wb_cloudy, color: Colors.blue),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                      'Weather: ${trip.weatherData!.conditions}'),
                                  Text(
                                    'Temp: ${trip.weatherData!.temperature.toStringAsFixed(1)}°C | Wind: ${trip.weatherData!.windSpeed.toStringAsFixed(1)} m/s',
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    // Contribution section
                    const SizedBox(height: 16),
                    if (_isLoading)
                      const Center(child: CircularProgressIndicator())
                    else if (_contribution != null)
                      _buildContributionCard(_contribution!)
                    else
                      _buildNoContributionMessage(),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContributionCard(Contribution contribution) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.route, color: Colors.purple),
                const SizedBox(width: 8),
                const Text('Linked Contribution',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const Spacer(),
                _buildContributionStateBadge(contribution),
              ],
            ),
            const Divider(),
            Text('Status: ${contribution.statusRating.name}'),
            Text('Obstacles: ${contribution.obstacles.length}'),
            const SizedBox(height: 12),
            if (contribution.state == ContributionState.pendingConfirmation)
              FilledButton.icon(
                onPressed: _confirmContribution,
                icon: const Icon(Icons.check),
                label: const Text('Confirm & Edit'),
              )
            else if (contribution.state == ContributionState.privateSaved)
              FilledButton.icon(
                onPressed: _publishContribution,
                icon: const Icon(Icons.public),
                label: const Text('Publish to Community'),
              )
            else if (contribution.state == ContributionState.published)
              OutlinedButton.icon(
                onPressed: _unpublishContribution,
                icon: const Icon(Icons.public_off),
                label: const Text('Make Private'),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoContributionMessage() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.info_outline, color: Colors.grey.shade600),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'No contribution linked. This trip is for personal records only.',
                style: TextStyle(color: Colors.grey),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContributionStateBadge(Contribution contribution) {
    Color color;
    String text;
    IconData icon;

    switch (contribution.state) {
      case ContributionState.pendingConfirmation:
        color = Colors.orange;
        text = 'Pending';
        icon = Icons.hourglass_empty;
        break;
      case ContributionState.privateSaved:
        color = Colors.grey;
        text = 'Private';
        icon = Icons.lock;
        break;
      case ContributionState.published:
        color = Colors.green;
        text = 'Published';
        icon = Icons.public;
        break;
      default:
        color = Colors.grey;
        text = contribution.state.name;
        icon = Icons.help_outline;
    }

    return _buildBadge(text, color, icon);
  }

  String _getContributionStateTooltip(ContributionState state) {
    switch (state) {
      case ContributionState.pendingConfirmation:
        return 'Pending confirmation';
      case ContributionState.privateSaved:
        return 'Private (not published)';
      case ContributionState.published:
        return 'Published to community';
      default:
        return state.name;
    }
  }

  Future<void> _showContributionActions() async {
    if (_contribution == null) return;

    await showModalBottomSheet(
      context: context,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('Edit Contribution'),
              onTap: () {
                Navigator.pop(ctx);
                // TODO: Navigate to contribution edit page
              },
            ),
            if (_contribution!.state == ContributionState.pendingConfirmation)
              ListTile(
                leading: const Icon(Icons.check),
                title: const Text('Confirm Contribution'),
                onTap: () {
                  Navigator.pop(ctx);
                  _confirmContribution();
                },
              ),
            if (_contribution!.state == ContributionState.privateSaved)
              ListTile(
                leading: const Icon(Icons.public),
                title: const Text('Publish to Community'),
                onTap: () {
                  Navigator.pop(ctx);
                  _publishContribution();
                },
              ),
            if (_contribution!.state == ContributionState.published)
              ListTile(
                leading: const Icon(Icons.public_off),
                title: const Text('Make Private'),
                onTap: () {
                  Navigator.pop(ctx);
                  _unpublishContribution();
                },
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmContribution() async {
    if (_contribution == null) return;

    try {
      await ref
          .read(contributionServiceProvider)
          .confirmContribution(_contribution!.id);
      _loadContribution();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Contribution confirmed!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _publishContribution() async {
    if (_contribution == null) return;

    try {
      await ref
          .read(contributionServiceProvider)
          .publishContribution(_contribution!.id);
      _loadContribution();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Contribution published to community!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _unpublishContribution() async {
    if (_contribution == null) return;

    try {
      await ref
          .read(contributionServiceProvider)
          .unpublishContribution(_contribution!.id);
      _loadContribution();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Contribution is now private'),
            backgroundColor: Colors.grey,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Widget _buildBadge(String text, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(30),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withAlpha(100)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(text,
              style: TextStyle(
                  color: color, fontSize: 12, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.grey.shade600, size: 20),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 14)),
                Text(label,
                    style:
                        TextStyle(color: Colors.grey.shade600, fontSize: 11)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatDateTime(DateTime dt) {
    return '${dt.day}/${dt.month}/${dt.year} ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
  }

  LatLngBounds _boundsFromLatLngList(List<LatLng> list) {
    assert(list.isNotEmpty);
    double? x0, x1, y0, y1;
    for (LatLng latLng in list) {
      if (x0 == null) {
        x0 = x1 = latLng.latitude;
        y0 = y1 = latLng.longitude;
      } else {
        if (latLng.latitude > x1!) x1 = latLng.latitude;
        if (latLng.latitude < x0) x0 = latLng.latitude;
        if (latLng.longitude > y1!) y1 = latLng.longitude;
        if (latLng.longitude < y0!) y0 = latLng.longitude;
      }
    }
    return LatLngBounds(
        northeast: LatLng(x1!, y1!), southwest: LatLng(x0!, y0!));
  }
}
