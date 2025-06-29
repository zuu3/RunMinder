// lib/services/location_service.dart
import 'package:geolocator/geolocator.dart';

class LocationService {
  /// 위치 스트림 (거리 필터 5m, 최고 정확도)
  late final Stream<Position> positionStream = Geolocator.getPositionStream(
    locationSettings: const LocationSettings(accuracy: LocationAccuracy.best, distanceFilter: 5),
  ).asBroadcastStream();

  /// 현재 위치 1회 조회
  Future<Position> getCurrent() async {
    return Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.best),
    );
  }
}
