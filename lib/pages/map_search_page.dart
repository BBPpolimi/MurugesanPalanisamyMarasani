import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import '../services/providers.dart';
import '../services/directions_service.dart';

class MapSearchPage extends ConsumerStatefulWidget {
  const MapSearchPage({super.key});

  @override
  ConsumerState<MapSearchPage> createState() => _MapSearchPageState();
}

class _MapSearchPageState extends ConsumerState<MapSearchPage> {
  static const _initialCameraPosition = CameraPosition(
    target: LatLng(45.4782, 9.2272), // Default to Politecnico di Milano
    zoom: 14.5,
  );

  GoogleMapController? _googleMapController;
  Marker? _origin;
  Marker? _destination;
  Directions? _info;

  @override
  void dispose() {
    _googleMapController?.dispose();
    super.dispose();
  }

  void _addMarker(LatLng pos) async {
    if (_origin == null || (_origin != null && _destination != null)) {
      // Set Origin
      setState(() {
        _origin = Marker(
          markerId: const MarkerId('origin'),
          infoWindow: const InfoWindow(title: 'Origin'),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
          position: pos,
        );
        _destination = null;
        _info = null;
      });
    } else {
      // Set Destination and Calculate Route
      setState(() {
        _destination = Marker(
          markerId: const MarkerId('destination'),
          infoWindow: const InfoWindow(title: 'Destination'),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          position: pos,
        );
      });

      final directions = await ref.read(directionsServiceProvider).getDirections(
            origin: _origin!.position,
            destination: pos,
          );
      setState(() => _info = directions);

      // Fit bounds
      if (_info != null) {
        _googleMapController?.animateCamera(
          CameraUpdate.newLatLngBounds(_info!.bounds, 60.0),
        );
      }
    }
  }

  Future<void> _centerOnUser() async {
    try {
      final pos = await Geolocator.getCurrentPosition();
      final latLng = LatLng(pos.latitude, pos.longitude);
      _googleMapController?.animateCamera(
        CameraUpdate.newLatLngZoom(latLng, 15),
      );
      // Auto-set origin if not set
      if (_origin == null) {
         _addMarker(latLng); 
      }
    } catch (e) {
      debugPrint('Could not get location: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Plan a Route'),
        actions: [
          if (_origin != null)
            TextButton(
              onPressed: () => setState(() {
                _origin = null;
                _destination = null;
                _info = null;
              }),
              child: const Text('RESET', style: TextStyle(color: Colors.red)),
            ),
        ],
      ),
      body: Stack(
        alignment: Alignment.center,
        children: [
          GoogleMap(
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            initialCameraPosition: _initialCameraPosition,
            onMapCreated: (controller) {
               _googleMapController = controller;
               _centerOnUser(); // Try to locate user on startup
            },
            markers: {
              if (_origin != null) _origin!,
              if (_destination != null) _destination!,
            },
            polylines: {
              if (_info != null)
                Polyline(
                  polylineId: const PolylineId('overview_polyline'),
                  color: Colors.blue,
                  width: 5,
                  points: _info!.polylinePoints
                      .map((e) => LatLng(e.latitude, e.longitude))
                      .toList(),
                ),
            },
            onLongPress: _addMarker,
          ),
          
          // Info Chip
          if (_info != null)
            Positioned(
              top: 20,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  vertical: 6,
                  horizontal: 12,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black26,
                      offset: Offset(0, 2),
                      blurRadius: 6,
                    )
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.timer, color: Colors.orange),
                    const SizedBox(width: 4),
                    Text(
                      _info!.totalDuration,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(width: 12),
                    const Icon(Icons.directions_bike, color: Colors.blue),
                    const SizedBox(width: 4),
                    Text(
                      _info!.totalDistance,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ),
            
          // Helper Guide
          if (_origin == null)
             Positioned(
               bottom: 100,
               child: _buildGuideChip('Long press to set START point'),
             )
          else if (_destination == null)
             Positioned(
               bottom: 100,
               child: _buildGuideChip('Long press to set END point'),
             ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _centerOnUser,
        child: const Icon(Icons.my_location),
      ),
    );
  }

  Widget _buildGuideChip(String text) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text, 
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
      ),
    );
  }
}
