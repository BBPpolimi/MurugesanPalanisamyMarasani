import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../models/trip.dart';
import '../services/providers.dart';

class TripDetailsPage extends ConsumerStatefulWidget {
  final Trip trip;

  const TripDetailsPage({super.key, required this.trip});

  @override
  ConsumerState<TripDetailsPage> createState() => _TripDetailsPageState();
}

class _TripDetailsPageState extends ConsumerState<TripDetailsPage> {
  late bool _isPublishable;

  @override
  void initState() {
    super.initState();
    _isPublishable = widget.trip.isPublishable;
  }

  @override
  Widget build(BuildContext context) {
    final trip = widget.trip;
    
    Set<Polyline> polylines = {};
    Set<Marker> markers = {};
    CameraPosition initialPosition;

    if (trip.points.isNotEmpty) {
      final points = trip.points
          .map((p) => LatLng(p.latitude, p.longitude))
          .toList();

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
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
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
          // Publishable toggle in app bar
          IconButton(
            icon: Icon(
              _isPublishable ? Icons.public : Icons.public_off,
              color: _isPublishable ? Colors.green : Colors.grey,
            ),
            tooltip: _isPublishable ? 'Published to community' : 'Private trip',
            onPressed: _togglePublishable,
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
                          final bounds = _boundsFromLatLngList(
                            trip.points.map((p) => LatLng(p.latitude, p.longitude)).toList()
                          );
                          Future.delayed(const Duration(milliseconds: 500), () {
                             try {
                               controller.animateCamera(CameraUpdate.newLatLngBounds(bounds, 50));
                             } catch (e) {
                               debugPrint("Map animation error (expected if disposed): $e");
                             }
                          });
                       }
                    },
                  )
                : const Center(child: Text('No GPS points recorded for this trip')),
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
                          _buildBadge('Auto-detected', Colors.blue, Icons.auto_awesome),
                        _buildBadge(
                          _isPublishable ? 'Public' : 'Private',
                          _isPublishable ? Colors.green : Colors.grey,
                          _isPublishable ? Icons.public : Icons.lock,
                        ),
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
                        _buildStatCard('Distance', '${(trip.distanceMeters / 1000).toStringAsFixed(2)} km', Icons.straighten),
                        const SizedBox(width: 12),
                        _buildStatCard('Duration', '${trip.duration.inMinutes} min', Icons.timer),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        _buildStatCard('Avg Speed', '${(trip.averageSpeed * 3.6).toStringAsFixed(1)} km/h', Icons.speed),
                        const SizedBox(width: 12),
                        _buildStatCard('Points', '${trip.points.length}', Icons.location_on),
                      ],
                    ),
                    const SizedBox(height: 16),
                    
                    // Time info
                    Text(
                      'Start: ${_formatDateTime(trip.startTime)}',
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                    ),
                    Text(
                      'End: ${_formatDateTime(trip.endTime)}',
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
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
                                  Text('Weather: ${trip.weatherData!.conditions}'),
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
                    
                    // Publish toggle
                    const SizedBox(height: 16),
                    SwitchListTile(
                      title: const Text('Share with Community'),
                      subtitle: Text(
                        _isPublishable 
                          ? 'This trip is visible to other users' 
                          : 'Only you can see this trip',
                      ),
                      value: _isPublishable,
                      onChanged: (val) => _togglePublishable(),
                      activeColor: Colors.green,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
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
          Text(text, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w500)),
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
                Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                Text(label, style: TextStyle(color: Colors.grey.shade600, fontSize: 11)),
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

  Future<void> _togglePublishable() async {
    final newValue = !_isPublishable;
    setState(() => _isPublishable = newValue);
    
    try {
      await ref.read(tripServiceProvider).setTripPublishable(widget.trip.id, newValue);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(newValue ? 'Trip is now public!' : 'Trip is now private'),
            backgroundColor: newValue ? Colors.green : Colors.grey,
          ),
        );
      }
    } catch (e) {
      // Revert on error
      setState(() => _isPublishable = !newValue);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating: $e'), backgroundColor: Colors.red),
        );
      }
    }
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
    return LatLngBounds(northeast: LatLng(x1!, y1!), southwest: LatLng(x0!, y0!));
  }
}
