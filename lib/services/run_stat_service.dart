import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:run_minder_google/utils/distance_util.dart';

class RunStat {
  final double distance;
  final double timeMinutes;
  final double pace;

  RunStat(this.distance, this.timeMinutes, this.pace);
}

class RunStatService {
  final _stream = StreamController<RunStat>.broadcast();
  Stream<RunStat> get stream => _stream.stream;

  double _dist = 0;
  DateTime? _start;
  Position? _prev;
  Timer? _timer;

  RunStatService() {
    Geolocator.getPositionStream(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.best, distanceFilter: 2),
    ).listen(_onPos, onError: (_) {});
  }

  void _onPos(Position p) {
    // 위치 업데이트가 들어올 때마다 거리만 계산
    if (_start == null) return; // 아직 reset() 안 했으면 무시
    if (_prev != null) {
      _dist += DistanceUtil.haversine(_prev!.latitude, _prev!.longitude, p.latitude, p.longitude);
    }
    _prev = p;
    // 거리만 갱신, 시간과 페이스는 Timer 로 갱신
  }

  void reset() {
    // 기존 타이머 정리
    _timer?.cancel();

    _dist = 0;
    _prev = null;
    _start = DateTime.now();

    // 1초마다 시간/페이스 갱신
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      final elapsedSec = DateTime.now().difference(_start!).inSeconds;
      final mins = elapsedSec / 60.0;
      final pace = _dist < 1 ? 0.0 : mins / (_dist / 1000);
      _stream.add(RunStat(_dist, mins, pace));
    });
  }

  void dispose() {
    _timer?.cancel();
    _stream.close();
  }
}
