// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'task_daily_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class DailyTaskModelAdapter extends TypeAdapter<DailyTaskModel> {
  @override
  final int typeId = 10;

  @override
  DailyTaskModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return DailyTaskModel(
      title: fields[0] as String,
      isCompleted: fields[1] as bool,
      startHour: fields[2] as int,
      startMinute: fields[3] as int,
      endHour: fields[4] as int,
      endMinute: fields[5] as int,
      startPeriod: fields[6] as String,
      endPeriod: fields[7] as String,
      completedAt: fields[8] as DateTime?,
      customOrder: fields[9] as int,
      dayOfWeek: fields[10] as String,
      lastCompletedDate: fields[11] as DateTime?,
      repeatDays: (fields[12] as List).cast<String>(),
      uniqueId: fields[13] as String?,
      isRepeating: fields[14] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, DailyTaskModel obj) {
    writer
      ..writeByte(15)
      ..writeByte(0)
      ..write(obj.title)
      ..writeByte(1)
      ..write(obj.isCompleted)
      ..writeByte(2)
      ..write(obj.startHour)
      ..writeByte(3)
      ..write(obj.startMinute)
      ..writeByte(4)
      ..write(obj.endHour)
      ..writeByte(5)
      ..write(obj.endMinute)
      ..writeByte(6)
      ..write(obj.startPeriod)
      ..writeByte(7)
      ..write(obj.endPeriod)
      ..writeByte(8)
      ..write(obj.completedAt)
      ..writeByte(9)
      ..write(obj.customOrder)
      ..writeByte(10)
      ..write(obj.dayOfWeek)
      ..writeByte(11)
      ..write(obj.lastCompletedDate)
      ..writeByte(12)
      ..write(obj.repeatDays)
      ..writeByte(13)
      ..write(obj.uniqueId)
      ..writeByte(14)
      ..write(obj.isRepeating);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DailyTaskModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
