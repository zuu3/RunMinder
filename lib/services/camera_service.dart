// lib/services/camera_service.dart

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';

class CameraService {
  CameraController? _ctrl;

  /// 앱 시작 시 한 번만 호출
  Future<void> init() async {
    try {
      final cams = await availableCameras();
      if (cams.isEmpty) return;

      _ctrl = CameraController(cams.first, ResolutionPreset.medium);
      await _ctrl!.initialize();

      // 🛑 프리뷰 스트림 멈추기
      await _ctrl!.pausePreview();
    } catch (e) {
      if (kDebugMode) print('Camera init error: $e');
    }
  }

  /// 사진 촬영 (실패 시 null)
  Future<XFile?> takePicture() async {
    if (_ctrl == null || !_ctrl!.value.isInitialized) return null;
    try {
      // 촬영 직후에도 프리뷰가 꺼져 있으므로
      final file = await _ctrl!.takePicture();
      return file;
    } catch (e) {
      if (kDebugMode) print('Take picture error: $e');
      return null;
    }
  }

  void dispose() {
    _ctrl?.dispose();
    _ctrl = null;
  }
}
