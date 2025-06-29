// lib/components/photo_marker.dart
import 'package:google_maps_flutter/google_maps_flutter.dart';

class PhotoMarker {
  final LatLng position;
  final String assetPath;

  PhotoMarker({required this.position, required this.assetPath});

  Marker toMarker() {
    return Marker(
      markerId: MarkerId(assetPath),
      position: position,
      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
    );
  }
}
