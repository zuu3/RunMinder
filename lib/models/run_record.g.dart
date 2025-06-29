// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'run_record.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class RunRecordAdapter extends TypeAdapter<RunRecord> {
  @override
  final int typeId = 0;

  @override
  RunRecord read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return RunRecord(
      date: fields[0] as DateTime,
      distanceKm: fields[1] as double,
      timeMinutes: fields[2] as double,
      pace: fields[3] as double,
      steps: fields[4] as int,
    );
  }

  @override
  void write(BinaryWriter writer, RunRecord obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.date)
      ..writeByte(1)
      ..write(obj.distanceKm)
      ..writeByte(2)
      ..write(obj.timeMinutes)
      ..writeByte(3)
      ..write(obj.pace)
      ..writeByte(4)
      ..write(obj.steps);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RunRecordAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
