import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../models/trip.dart';

class TripDetailsPage extends StatelessWidget {
  final Trip trip;

  const TripDetailsPage({super.key, required this.trip});

  @override
  Widget build(BuildContext context) {
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
      appBar: AppBar(title: const Text('Trip Details')),
      body: Column(
        children: [
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
          Expanded(
            flex: 1,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Start: ${trip.startTime}'),
                    Text('End: ${trip.endTime}'),
                    const SizedBox(height: 12),
                    Text('Distance: ${(trip.distanceMeters / 1000).toStringAsFixed(2)} km'),
                    Text('Duration: ${trip.duration.inMinutes} minutes'),
                    Text('Avg speed: ${trip.averageSpeed.toStringAsFixed(2)} m/s'),
                    const SizedBox(height: 12),
                    Text('Points recorded: ${trip.points.length}'),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
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
