import 'dart:async';
import 'package:flutter/services.dart';

class StepCounterService {
  static const _channel = EventChannel('step_counter_stream');
  int _base = 0;
  Stream<int> get stepStream =>
      _channel.receiveBroadcastStream().map((event) => event as int).map((raw) {
        if (_base == 0) _base = raw;
        return raw - _base;
      });

  void reset() {
    _base = 0;
  }
}
