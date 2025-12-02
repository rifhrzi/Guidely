import 'dart:math' as math;

class LatLng {
  final double lat;
  final double lng;
  const LatLng(this.lat, this.lng);
}

double haversineMeters(LatLng a, LatLng b) {
  const r = 6371000.0; // Earth radius in meters
  final dLat = _degToRad(b.lat - a.lat);
  final dLon = _degToRad(b.lng - a.lng);
  final la1 = _degToRad(a.lat);
  final la2 = _degToRad(b.lat);
  final h = _sin2(dLat / 2) + _sin2(dLon / 2) * math.cos(la1) * math.cos(la2);
  return 2 * r * math.asin(math.min(1.0, math.sqrt(h)));
}

double _degToRad(double d) => d * (3.141592653589793 / 180.0);
double _sin2(double x) => math.sin(x) * math.sin(x);
