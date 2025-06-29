import 'dart:async';
import 'package:pedometer/pedometer.dart';

class SensorService {
  final _ctrl = StreamController<int>.broadcast();
  Stream<int> get stepStream => _ctrl.stream;

  late StreamSubscription<StepCount> _sub;
  int _base = 0;
  bool _running = false;

  SensorService() {
    // 센서 구독은 앱 시작 시 한 번만
    _sub = Pedometer.stepCountStream.listen(
      _onStepCount,
      onError: (_) {
        _ctrl.add(0);
      },
    );
  }

  void _onStepCount(StepCount event) {
    if (!_running) {
      // 런 시작 시점에만 기준점으로 잡고, 그 전까지 이벤트 무시
      _base = event.steps;
      _running = true;
      _ctrl.add(0);
      return;
    }
    final current = event.steps - _base;
    _ctrl.add(current);
  }

  /// 러닝이 시작될 때, 또는 finish 후에 호출하세요.
  void reset() {
    // 다음 이벤트가 오면 기준점을 다시 잡도록 _running을 false로
    _running = false;
    // UI에는 0으로 초기화
    if (!_ctrl.isClosed) _ctrl.add(0);
  }

  void dispose() {
    _sub.cancel();
    _ctrl.close();
  }
}
