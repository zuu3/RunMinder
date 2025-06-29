import 'package:hive/hive.dart';

part 'run_record.g.dart';

@HiveType(typeId: 0)
class RunRecord {
  @HiveField(0)
  final DateTime date;

  @HiveField(1)
  final double distanceKm;

  @HiveField(2)
  final double timeMinutes;

  @HiveField(3)
  final double pace;

  @HiveField(4)
  final int steps;

  RunRecord({
    required this.date,
    required this.distanceKm,
    required this.timeMinutes,
    required this.pace,
    required this.steps,
  });
}
