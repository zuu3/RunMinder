import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:run_minder_google/models/run_record.dart';
import 'dart:ui';

class HistoryPage extends StatefulWidget {
  const HistoryPage({Key? key}) : super(key: key);
  static const routeName = '/history';

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> with TickerProviderStateMixin {
  late AnimationController _fadeController;
  String _selectedFilter = 'all'; // all, week, month

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(duration: const Duration(milliseconds: 300), vsync: this);
    _fadeController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  List<MapEntry<dynamic, RunRecord>> _filterRecords(List<MapEntry<dynamic, RunRecord>> entries) {
    final now = DateTime.now();
    switch (_selectedFilter) {
      case 'week':
        final weekAgo = now.subtract(const Duration(days: 7));
        return entries.where((entry) => entry.value.date.isAfter(weekAgo)).toList();
      case 'month':
        final monthAgo = now.subtract(const Duration(days: 30));
        return entries.where((entry) => entry.value.date.isAfter(monthAgo)).toList();
      default:
        return entries;
    }
  }

  Map<String, dynamic> _calculateStats(List<MapEntry<dynamic, RunRecord>> entries) {
    if (entries.isEmpty) {
      return {
        'totalDistance': 0.0,
        'totalTime': 0.0,
        'totalRuns': 0,
        'avgPace': 0.0,
        'totalSteps': 0,
      };
    }

    double totalDistance = 0;
    double totalTime = 0;
    int totalSteps = 0;

    for (final entry in entries) {
      totalDistance += entry.value.distanceKm;
      totalTime += entry.value.timeMinutes;
      totalSteps += entry.value.steps;
    }

    final avgPace = totalTime / totalDistance;

    return {
      'totalDistance': totalDistance,
      'totalTime': totalTime,
      'totalRuns': entries.length,
      'avgPace': avgPace.isNaN ? 0.0 : avgPace,
      'totalSteps': totalSteps,
    };
  }

  @override
  Widget build(BuildContext context) {
    final box = Hive.box<RunRecord>('run_records');

    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: _buildAppBar(),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0a0a0a), Color(0xFF1a1a1a)],
          ),
        ),
        child: ValueListenableBuilder<Box<RunRecord>>(
          valueListenable: box.listenable(),
          builder: (context, box, _) {
            final entries = box.toMap().entries.cast<MapEntry<dynamic, RunRecord>>().toList();

            if (entries.isEmpty) {
              return _buildEmptyState();
            }

            entries.sort((a, b) => b.value.date.compareTo(a.value.date));
            final filteredEntries = _filterRecords(entries);
            final stats = _calculateStats(filteredEntries);

            return CustomScrollView(
              slivers: [
                const SliverToBoxAdapter(child: SizedBox(height: 120)),
                SliverToBoxAdapter(child: _buildFilterTabs()),
                SliverToBoxAdapter(child: _buildStatsCards(stats)),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate((context, index) {
                      if (filteredEntries.isEmpty) {
                        return _buildNoResultsForFilter();
                      }
                      final key = filteredEntries[index].key;
                      final rec = filteredEntries[index].value;
                      return _buildRecordCard(context, key, rec, index, box);
                    }, childCount: filteredEntries.isEmpty ? 1 : filteredEntries.length),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 100)),
              ],
            );
          },
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      leading: Container(
        margin: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.15),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(0.2)),
        ),
        child: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      title: Text(
        '운동 기록',
        style: GoogleFonts.poppins(fontSize: 24, fontWeight: FontWeight.w600, color: Colors.white),
      ),
      centerTitle: true,
    );
  }

  Widget _buildFilterTabs() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      child: Row(
        children: [
          _buildFilterTab('전체', 'all'),
          const SizedBox(width: 12),
          _buildFilterTab('최근 7일', 'week'),
          const SizedBox(width: 12),
          _buildFilterTab('최근 30일', 'month'),
        ],
      ),
    ).animate().fadeIn(delay: 200.ms).slideX(begin: -0.2);
  }

  Widget _buildFilterTab(String label, String value) {
    final isSelected = _selectedFilter == value;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() => _selectedFilter = value);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: isSelected
                ? const LinearGradient(colors: [Color(0xFF00E676), Color(0xFF00C853)])
                : null,
            color: isSelected ? null : Colors.white.withOpacity(0.1),
            border: Border.all(
              color: isSelected ? Colors.transparent : Colors.white.withOpacity(0.2),
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatsCards(Map<String, dynamic> stats) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Column(
        children: [
          Row(
            children: [
              _buildStatCard(
                Icons.straighten_rounded,
                '총 거리',
                '${stats['totalDistance'].toStringAsFixed(1)}',
                'km',
                const Color(0xFF00E676),
              ),
              const SizedBox(width: 12),
              _buildStatCard(
                Icons.timer_rounded,
                '총 시간',
                '${(stats['totalTime'] / 60).toStringAsFixed(1)}',
                '시간',
                const Color(0xFF2196F3),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildStatCard(
                Icons.directions_run_rounded,
                '총 런닝',
                '${stats['totalRuns']}',
                '회',
                const Color(0xFFFF9800),
              ),
              const SizedBox(width: 12),
              _buildStatCard(
                Icons.speed_rounded,
                '평균 페이스',
                '${stats['avgPace'].toStringAsFixed(1)}',
                '분/km',
                const Color(0xFF9C27B0),
              ),
            ],
          ),
        ],
      ),
    ).animate().fadeIn(delay: 400.ms).slideY(begin: 0.3);
  }

  Widget _buildStatCard(IconData icon, String label, String value, String unit, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.white.withOpacity(0.15), Colors.white.withOpacity(0.05)],
          ),
          border: Border.all(color: color.withOpacity(0.3)),
          boxShadow: [
            BoxShadow(color: color.withOpacity(0.1), blurRadius: 20, offset: const Offset(0, 8)),
          ],
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 8),
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: Colors.white70,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            RichText(
              text: TextSpan(
                children: [
                  TextSpan(
                    text: value,
                    style: GoogleFonts.poppins(
                      fontSize: 18,
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

  Widget _buildRecordCard(
    BuildContext context,
    dynamic key,
    RunRecord rec,
    int index,
    Box<RunRecord> box,
  ) {
    final formattedDate = DateFormat('MM월 dd일').format(rec.date);
    final formattedTime = DateFormat('HH:mm').format(rec.date);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Dismissible(
        key: Key(key.toString()),
        direction: DismissDirection.endToStart,
        background: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(colors: [Colors.red.shade600, Colors.red.shade800]),
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Icon(Icons.delete_rounded, color: Colors.white, size: 28),
              SizedBox(width: 8),
              Text(
                '삭제',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 16),
              ),
            ],
          ),
        ),
        onDismissed: (_) {
          box.delete(key);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('기록이 삭제되었습니다.'),
              backgroundColor: Colors.red.shade600,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          );
        },
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Colors.white.withOpacity(0.15), Colors.white.withOpacity(0.05)],
            ),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 15,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            formattedDate,
                            style: GoogleFonts.poppins(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            formattedTime,
                            style: GoogleFonts.poppins(fontSize: 14, color: Colors.white60),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: GestureDetector(
                          onTap: () {
                            box.delete(key);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: const Text('기록이 삭제되었습니다.'),
                                backgroundColor: Colors.red.shade600,
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            );
                          },
                          child: Icon(
                            Icons.delete_outline_rounded,
                            color: Colors.red.shade300,
                            size: 20,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      _buildRecordStat(
                        Icons.straighten_rounded,
                        '${rec.distanceKm.toStringAsFixed(2)} km',
                        const Color(0xFF00E676),
                      ),
                      const SizedBox(width: 16),
                      _buildRecordStat(
                        Icons.timer_rounded,
                        '${rec.timeMinutes.toStringAsFixed(1)}분',
                        const Color(0xFF2196F3),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _buildRecordStat(
                        Icons.speed_rounded,
                        '${rec.pace.toStringAsFixed(2)} 분/km',
                        const Color(0xFFFF9800),
                      ),
                      const SizedBox(width: 16),
                      _buildRecordStat(
                        Icons.directions_walk_rounded,
                        '${rec.steps}보',
                        const Color(0xFF9C27B0),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ).animate(delay: Duration(milliseconds: 200 + (index * 100))).fadeIn().slideX(begin: 0.3);
  }

  Widget _buildRecordStat(IconData icon, String value, Color color) {
    return Expanded(
      child: Row(
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              value,
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: Colors.white70,
                fontWeight: FontWeight.w500,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [Colors.white.withOpacity(0.1), Colors.white.withOpacity(0.05)],
              ),
              border: Border.all(color: Colors.white.withOpacity(0.2)),
            ),
            child: const Icon(Icons.directions_run_rounded, size: 64, color: Color(0xFF00E676)),
          ),
          const SizedBox(height: 24),
          Text(
            '아직 운동 기록이 없습니다',
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text('첫 번째 러닝을 시작해보세요!', style: GoogleFonts.poppins(fontSize: 16, color: Colors.white60)),
        ],
      ),
    ).animate().fadeIn(delay: 400.ms).scale();
  }

  Widget _buildNoResultsForFilter() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 40),
      child: Center(
        child: Column(
          children: [
            Icon(Icons.search_off_rounded, size: 48, color: Colors.white.withOpacity(0.5)),
            const SizedBox(height: 16),
            Text(
              '선택한 기간에 기록이 없습니다',
              style: GoogleFonts.poppins(fontSize: 16, color: Colors.white60),
            ),
          ],
        ),
      ),
    );
  }
}
