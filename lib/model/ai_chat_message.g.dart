// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ai_chat_message.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class AiChatMessageAdapter extends TypeAdapter<AiChatMessage> {
  @override
  final int typeId = 50;

  @override
  AiChatMessage read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return AiChatMessage(
      id: fields[0] as String,
      role: fields[1] as String,
      content: fields[2] as String,
      reasoning: fields[3] as String,
      persona: fields[4] as String,
      createdAt: fields[5] as DateTime,
      sources: (fields[6] as List).cast<String>(),
      isError: fields[7] as bool,
      question: fields[8] as String?,
      model: fields[9] as String?,
      stopReason: fields[10] == null ? '' : fields[10] as String,
    );
  }

  @override
  void write(BinaryWriter writer, AiChatMessage obj) {
    writer
      ..writeByte(11)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.role)
      ..writeByte(2)
      ..write(obj.content)
      ..writeByte(3)
      ..write(obj.reasoning)
      ..writeByte(4)
      ..write(obj.persona)
      ..writeByte(5)
      ..write(obj.createdAt)
      ..writeByte(6)
      ..write(obj.sources)
      ..writeByte(7)
      ..write(obj.isError)
      ..writeByte(8)
      ..write(obj.question)
      ..writeByte(9)
      ..write(obj.model)
      ..writeByte(10)
      ..write(obj.stopReason);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AiChatMessageAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
