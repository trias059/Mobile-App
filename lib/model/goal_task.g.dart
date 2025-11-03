// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'goal_task.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class GoalTaskAdapter extends TypeAdapter<GoalTask> {
  @override
  final int typeId = 0;

  @override
  GoalTask read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return GoalTask(
      title: fields[0] as String,
      description: fields[1] as String,
      deadline: fields[2] as DateTime,
      progress: fields[3] as double,
    );
  }

  @override
  void write(BinaryWriter writer, GoalTask obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.title)
      ..writeByte(1)
      ..write(obj.description)
      ..writeByte(2)
      ..write(obj.deadline)
      ..writeByte(3)
      ..write(obj.progress);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GoalTaskAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
