import 'package:flutter/services.dart';
import 'package:geocoding/geocoding.dart' as geo;
import 'package:google_maps_flutter/google_maps_flutter.dart';

class GeocodingService {
  GeocodingService();

  Future<GeocodingResult?> searchAddress(String query) async {
    try {
      print('DEBUG: Searching address via native geocoder: $query');
      
      List<geo.Location> locations = await geo.locationFromAddress(query);
      
      if (locations.isNotEmpty) {
        final loc = locations.first;
        final latLng = LatLng(loc.latitude, loc.longitude);
        
        // Native geocoding doesn't always return bounds. 
        // We can try to get placemarks to improve the address formatting
        List<geo.Placemark> placemarks = await geo.placemarkFromCoordinates(loc.latitude, loc.longitude);
        String formattedAddress = query;
        if (placemarks.isNotEmpty) {
           final p = placemarks.first;
           formattedAddress = '${p.street}, ${p.locality}, ${p.administrativeArea}';
        }

        // Create a small artificial viewport if needed, or null
        // For streets, native geocoding is just a point. 
        // We can't easily get the "extent" without the Web API geometry.bounds.
        // We will return a null viewport, meaning the UI will zoom to the point but not draw the "extent line".
        
        return GeocodingResult(
          formattedAddress: formattedAddress,
          location: latLng,
          viewport: null, 
        );
      }
    } on PlatformException catch (e) {
       print('DEBUG: Native Geocoding Platform Exception: $e');
    } catch (e) {
       print('DEBUG: Native Geocoding Exception: $e');
    }
    return null;
  }
}

class GeocodingResult {
  final String formattedAddress;
  final LatLng location;
  final LatLngBounds? viewport;

  GeocodingResult({required this.formattedAddress, required this.location, this.viewport});
}
