import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Utility class for polyline encoding/decoding
class PolylineUtils {
  /// Decode a Google-encoded polyline string into a list of LatLng points
  static List<LatLng> decodePolyline(String encoded) {
    List<LatLng> poly = [];
    int index = 0, len = encoded.length;
    int lat = 0, lng = 0;

    while (index < len) {
      int b, shift = 0, result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lat += dlat;

      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lng += dlng;

      poly.add(LatLng(lat / 1E5, lng / 1E5));
    }
    return poly;
  }

  /// Encode a list of LatLng points into a Google-encoded polyline string
  static String encodePolyline(List<LatLng> points) {
    StringBuffer encoded = StringBuffer();
    int plat = 0, plng = 0;

    for (var point in points) {
      int lat = (point.latitude * 1E5).round();
      int lng = (point.longitude * 1E5).round();

      encoded.write(_encodeValue(lat - plat));
      encoded.write(_encodeValue(lng - plng));

      plat = lat;
      plng = lng;
    }

    return encoded.toString();
  }

  static String _encodeValue(int v) {
    int value = v < 0 ? ~(v << 1) : (v << 1);
    StringBuffer encoded = StringBuffer();
    while (value >= 0x20) {
      encoded.writeCharCode((0x20 | (value & 0x1f)) + 63);
      value >>= 5;
    }
    encoded.writeCharCode(value + 63);
    return encoded.toString();
  }
}
