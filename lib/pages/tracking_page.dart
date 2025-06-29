// lib/pages/tracking_page.dart
import 'dart:ui';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:geolocator/geolocator.dart';
import 'package:hive/hive.dart';
import 'package:permission_handler/permission_handler.dart';

import 'package:run_minder_google/models/run_record.dart';
import 'package:run_minder_google/services/location_service.dart';
import 'package:run_minder_google/services/run_stat_service.dart';
// import 'package:run_minder_google/services/sensor_service.dart';
import 'package:run_minder_google/services/step_counter_service.dart';
import 'package:run_minder_google/services/camera_service.dart';
import 'package:run_minder_google/services/notification_service.dart';
import 'package:run_minder_google/components/photo_marker.dart';
import 'package:run_minder_google/pages/history_page.dart';

enum RunState { idle, running, paused, finished }

class TrackingPage extends StatefulWidget {
  const TrackingPage({super.key});
  @override
  State<TrackingPage> createState() => _TrackingPageState();
}

class _TrackingPageState extends State<TrackingPage> with TickerProviderStateMixin {
  final locSvc = LocationService();
  final runSvc = RunStatService();
  final stepSvc = StepCounterService();
  final camSvc = CameraService();

  GoogleMapController? _mapCtrl;
  StreamSubscription<Position>? _positionSub;
  final _path = <LatLng>[];
  final _markers = <Marker>{};
  Polyline? _polyline;

  int _steps = 0;
  double _dist = 0, _pace = 0, _time = 0;
  RunState _state = RunState.idle;
  bool _locationGranted = false;

  late AnimationController _pulseController;
  late AnimationController _fadeController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(duration: const Duration(seconds: 2), vsync: this)
      ..repeat(reverse: true);

    _fadeController = AnimationController(duration: const Duration(milliseconds: 300), vsync: this);

    NotificationService.init();
    camSvc.init();
    stepSvc.stepStream.listen((s) {
      if (_state == RunState.running) setState(() => _steps = s);
    });
    runSvc.stream.listen((stat) {
      if (_state == RunState.running) {
        setState(() {
          _dist = stat.distance / 1000;
          _time = stat.timeMinutes;
          _pace = stat.pace;
        });
      }
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _fadeController.dispose();
    runSvc.dispose();
    camSvc.dispose();
    _positionSub?.cancel();
    super.dispose();
  }

  void _onMapCreated(GoogleMapController controller) async {
    _mapCtrl = controller;

    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.deniedForever || perm == LocationPermission.denied) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('위치 권한이 필요합니다. 설정에서 허용해주세요.'),
          backgroundColor: Colors.red.shade600,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }

    _locationGranted = perm == LocationPermission.always || perm == LocationPermission.whileInUse;
    setState(() {});

    final pos0 = await Geolocator.getCurrentPosition();
    final start = LatLng(pos0.latitude, pos0.longitude);
    _moveCamera(start);
    _addCurrentMarker(start);

    _positionSub =
        Geolocator.getPositionStream(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.best,
            distanceFilter: 1,
            timeLimit: Duration(seconds: 1),
          ),
        ).listen(
          (pos) {
            final pt = LatLng(pos.latitude, pos.longitude);
            setState(() {
              _updateCurrentMarker(pt);
              if (_state == RunState.running) {
                _path.add(pt);
                _updatePolyline();
              }
            });
            _mapCtrl?.animateCamera(
              CameraUpdate.newCameraPosition(CameraPosition(target: pt, zoom: 16)),
            );
          },
          onError: (e) {
            debugPrint('위치 스트림 에러: $e');
            _positionSub?.cancel();
          },
        );
  }

  void _moveCamera(LatLng p) {
    _mapCtrl?.animateCamera(CameraUpdate.newCameraPosition(CameraPosition(target: p, zoom: 16)));
  }

  void _addCurrentMarker(LatLng p) {
    _markers.removeWhere((m) => m.markerId.value == 'current');
    _markers.add(
      Marker(
        markerId: const MarkerId('current'),
        position: p,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
      ),
    );
  }

  void _updateCurrentMarker(LatLng p) => _addCurrentMarker(p);

  void _updatePolyline() {
    _polyline = Polyline(
      polylineId: const PolylineId('track'),
      points: List.from(_path),
      color: const Color(0xFF00E676),
      width: 8,
      patterns: [PatternItem.dot, PatternItem.gap(10)],
    );
  }

  Future _takePhoto() async {
    final img = await camSvc.takePicture();
    if (img == null) return;
    final pos = await locSvc.getCurrent();
    final pt = LatLng(pos.latitude, pos.longitude);
    final photo = PhotoMarker(position: pt, assetPath: img.path).toMarker();
    setState(() => _markers.add(photo));
  }

  Future<bool> _requestActivityPermission() async {
    final status = await Permission.activityRecognition.request();
    return status == PermissionStatus.granted;
  }

  void _start() async {
    final ok = await _requestActivityPermission();
    if (!ok) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('걸음수 수집 권한이 필요합니다.')));
      return;
    }
    setState(() {
      _state = RunState.running;
      _steps = 0;
      _dist = _time = _pace = 0;
      _path.clear();
      _polyline = null;
      _markers.clear();
      NotificationService.show('운동 시작', '좋은 러닝 되세요!');
      runSvc.reset();
      stepSvc.reset();
    });
    _fadeController.forward();
  }

  void _pause() {
    setState(() => _state = RunState.paused);
    _fadeController.reverse();
  }

  void _resume() {
    setState(() => _state = RunState.running);
    _fadeController.forward();
  }

  void _finish() {
    final box = Hive.box<RunRecord>('run_records');
    box.add(
      RunRecord(
        date: DateTime.now(),
        distanceKm: _dist,
        timeMinutes: _time,
        pace: _pace,
        steps: _steps,
      ),
    );

    NotificationService.show(
      '운동 완료',
      '총 ${_dist.toStringAsFixed(2)} km, ${_time.toStringAsFixed(1)}분',
    );

    setState(() {
      _state = RunState.finished;
      _path.clear();
      _polyline = null;
      _markers.clear();
      _dist = 0;
      _time = 0;
      _pace = 0;
      _steps = 0;
    });

    _fadeController.reset();
    runSvc.reset();
    stepSvc.reset();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: _buildAppBar(),
      body: Stack(
        children: [
          _buildMap(),
          _buildStatsCard(),
          if (_state == RunState.running) _buildCameraButton(),
          _buildControlButtons(),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      title: Text(
        'Run Minder',
        style: GoogleFonts.poppins(fontSize: 24, fontWeight: FontWeight.w600, color: Colors.white),
      ),
      actions: [
        Container(
          margin: const EdgeInsets.only(right: 16),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.15),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withOpacity(0.2)),
          ),
          child: IconButton(
            icon: const Icon(Icons.history_rounded, color: Colors.white),
            tooltip: '운동 기록',
            onPressed: () => Navigator.pushNamed(context, HistoryPage.routeName),
          ),
        ),
      ],
    );
  }

  Widget _buildMap() {
    return ClipRRect(
      borderRadius: const BorderRadius.only(
        bottomLeft: Radius.circular(24),
        bottomRight: Radius.circular(24),
      ),
      child: GoogleMap(
        initialCameraPosition: const CameraPosition(target: LatLng(37.5665, 126.9780), zoom: 14),
        onMapCreated: _onMapCreated,
        myLocationEnabled: _locationGranted,
        myLocationButtonEnabled: false,
        markers: _markers,
        polylines: _polyline != null ? {_polyline!} : {},
        // style: '''
        // [
        //   {
        //     "featureType": "all",
        //     "elementType": "geometry",
        //     "stylers": [{"color": "#242f3e"}]
        //   },
        //   {
        //     "featureType": "all",
        //     "elementType": "labels.text.stroke",
        //     "stylers": [{"lightness": -80}]
        //   },
        //   {
        //     "featureType": "administrative",
        //     "elementType": "labels.text.fill",
        //     "stylers": [{"color": "#746855"}]
        //   },
        //   {
        //     "featureType": "poi",
        //     "elementType": "labels.text.fill",
        //     "stylers": [{"color": "#d59563"}]
        //   },
        //   {
        //     "featureType": "road.highway",
        //     "elementType": "geometry.stroke",
        //     "stylers": [{"color": "#1f2835"}, {"lightness": -40}]
        //   },
        //   {
        //     "featureType": "road.highway",
        //     "elementType": "labels.text.fill",
        //     "stylers": [{"color": "#f3d19c"}]
        //   },
        //   {
        //     "featureType": "water",
        //     "elementType": "geometry",
        //     "stylers": [{"color": "#17263c"}]
        //   }
        // ]
        // ''',
      ),
    );
  }

  Widget _buildStatsCard() {
    return Positioned(
      top: 120,
      left: 20,
      right: 20,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.white.withOpacity(0.25), Colors.white.withOpacity(0.1)],
          ),
          border: Border.all(color: Colors.white.withOpacity(0.2), width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
            child: Container(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Row(
                    children: [
                      _buildStatItem(
                        Icons.straighten_rounded,
                        '거리',
                        '${_dist.toStringAsFixed(2)}',
                        'km',
                        const Color(0xFF00E676),
                      ),
                      const SizedBox(width: 16),
                      _buildStatItem(
                        Icons.timer_rounded,
                        '시간',
                        '${_time.toStringAsFixed(1)}',
                        '분',
                        const Color(0xFF2196F3),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      _buildStatItem(
                        Icons.speed_rounded,
                        '페이스',
                        '${_pace.toStringAsFixed(1)}',
                        '분/km',
                        const Color(0xFFFF9800),
                      ),
                      const SizedBox(width: 16),
                      _buildStatItem(
                        Icons.directions_walk_rounded,
                        '걸음',
                        '$_steps',
                        '보',
                        const Color(0xFF9C27B0),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ).animate().fadeIn(duration: 600.ms).slideY(begin: -0.3),
    );
  }

  Widget _buildStatItem(IconData icon, String label, String value, String unit, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: Colors.white70,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            RichText(
              text: TextSpan(
                children: [
                  TextSpan(
                    text: value,
                    style: GoogleFonts.poppins(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  TextSpan(
                    text: ' $unit',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: Colors.white60,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCameraButton() {
    return Positioned(
      bottom: 140,
      right: 24,
      child: AnimatedBuilder(
        animation: _pulseController,
        builder: (context, child) {
          return Transform.scale(
            scale: 1.0 + (_pulseController.value * 0.1),
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    const Color(0xFF00E676).withOpacity(0.8),
                    const Color(0xFF00C853).withOpacity(0.9),
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF00E676).withOpacity(0.4),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: FloatingActionButton(
                backgroundColor: Colors.transparent,
                elevation: 0,
                onPressed: _takePhoto,
                child: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 28),
              ),
            ),
          );
        },
      ).animate().scale(delay: 200.ms),
    );
  }

  Widget _buildControlButtons() {
    return Positioned(bottom: 40, left: 24, right: 24, child: _buildControlButtonsContent());
  }

  Widget _buildControlButtonsContent() {
    switch (_state) {
      case RunState.idle:
      case RunState.finished:
        return _buildStartButton();
      case RunState.running:
        return Row(
          children: [
            Expanded(child: _buildPauseButton()),
            const SizedBox(width: 16),
            Expanded(child: _buildStopButton()),
          ],
        );
      case RunState.paused:
        return Row(
          children: [
            Expanded(child: _buildResumeButton()),
            const SizedBox(width: 16),
            Expanded(child: _buildStopButton()),
          ],
        );
    }
  }

  Widget _buildStartButton() {
    return Container(
      height: 64,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF00E676), Color(0xFF00C853)],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF00E676).withOpacity(0.4),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
        ),
        onPressed: _start,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 28),
            const SizedBox(width: 8),
            Text(
              '시작하기',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    ).animate().scale(delay: 400.ms);
  }

  Widget _buildPauseButton() {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(colors: [Colors.orange.shade400, Colors.orange.shade600]),
        boxShadow: [
          BoxShadow(
            color: Colors.orange.withOpacity(0.4),
            blurRadius: 15,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        ),
        onPressed: _pause,
        child: const Icon(Icons.pause_rounded, color: Colors.white, size: 24),
      ),
    );
  }

  Widget _buildResumeButton() {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(colors: [Color(0xFF00E676), Color(0xFF00C853)]),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF00E676).withOpacity(0.4),
            blurRadius: 15,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        ),
        onPressed: _resume,
        child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 24),
      ),
    );
  }

  Widget _buildStopButton() {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(colors: [Colors.red.shade400, Colors.red.shade600]),
        boxShadow: [
          BoxShadow(color: Colors.red.withOpacity(0.4), blurRadius: 15, offset: const Offset(0, 6)),
        ],
      ),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        ),
        onPressed: _finish,
        child: const Icon(Icons.stop_rounded, color: Colors.white, size: 24),
      ),
    );
  }
}
