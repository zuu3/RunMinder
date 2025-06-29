import 'dart:math';

class DistanceUtil {
  /// 하버사인 공식으로 위경도 간 거리(미터) 계산
  static double haversine(double lat1, double lon1, double lat2, double lon2) {
    const R = 6371000.0; // 지구 반지름(m)
    final latitude1InRadians = lat1 * pi / 180;
    final latitude2InRadians = lat2 * pi / 180;
    final deltaLatitude = (lat2 - lat1) * pi / 180;
    final deltaLongitude = (lon2 - lon1) * pi / 180;
    final a =
        sin(deltaLatitude / 2) * sin(deltaLatitude / 2) +
        cos(latitude1InRadians) *
            cos(latitude2InRadians) *
            sin(deltaLongitude / 2) *
            sin(deltaLongitude / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return R * c;
  }
}
