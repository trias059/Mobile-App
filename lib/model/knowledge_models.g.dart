// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'knowledge_models.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class KnowledgeSourceAdapter extends TypeAdapter<KnowledgeSource> {
  @override
  final int typeId = 52;

  @override
  KnowledgeSource read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return KnowledgeSource(
      id: fields[0] as String,
      type: fields[1] as String,
      title: fields[2] as String,
      createdAt: fields[3] as DateTime,
      pageCount: fields[4] as int,
      chunkCount: fields[5] as int,
      text: fields[6] as String,
    );
  }

  @override
  void write(BinaryWriter writer, KnowledgeSource obj) {
    writer
      ..writeByte(7)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.type)
      ..writeByte(2)
      ..write(obj.title)
      ..writeByte(3)
      ..write(obj.createdAt)
      ..writeByte(4)
      ..write(obj.pageCount)
      ..writeByte(5)
      ..write(obj.chunkCount)
      ..writeByte(6)
      ..write(obj.text);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is KnowledgeSourceAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class KnowledgeChunkAdapter extends TypeAdapter<KnowledgeChunk> {
  @override
  final int typeId = 51;

  @override
  KnowledgeChunk read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return KnowledgeChunk(
      id: fields[0] as String,
      sourceId: fields[1] as String,
      sourceType: fields[2] as String,
      title: fields[3] as String,
      startPage: fields[4] as int,
      endPage: fields[5] as int,
      text: fields[6] as String,
      embedding: (fields[7] as List).cast<double>(),
    );
  }

  @override
  void write(BinaryWriter writer, KnowledgeChunk obj) {
    writer
      ..writeByte(8)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.sourceId)
      ..writeByte(2)
      ..write(obj.sourceType)
      ..writeByte(3)
      ..write(obj.title)
      ..writeByte(4)
      ..write(obj.startPage)
      ..writeByte(5)
      ..write(obj.endPage)
      ..writeByte(6)
      ..write(obj.text)
      ..writeByte(7)
      ..write(obj.embedding);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is KnowledgeChunkAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
