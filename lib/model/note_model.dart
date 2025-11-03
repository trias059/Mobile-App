import 'package:hive/hive.dart';

part 'note_model.g.dart';

@HiveType(typeId: 3)
class NoteModel extends HiveObject {
  @HiveField(0)
  String title;

  @HiveField(1)
  String content;

  @HiveField(2)
  DateTime createdAt;

  @HiveField(3)
  DateTime updatedAt;

  @HiveField(4)
  String category; // 'general', 'learning', 'idea'

  @HiveField(5)
  String? relatedTaskId; // ID tugas harian yang terkait (optional)

  @HiveField(6)
  List<String> tags; // Tags untuk kategorisasi

  @HiveField(7)
  bool isPinned; // Pin note penting

  @HiveField(8)
  String colorCode; // Warna note untuk visual grouping

  NoteModel({
    required this.title,
    required this.content,
    required this.createdAt,
    required this.updatedAt,
    this.category = 'general',
    this.relatedTaskId,
    this.tags = const [],
    this.isPinned = false,
    this.colorCode = '#2196F3', // Default blue
  });

  // Helper methods
  String get formattedDate {
    final now = DateTime.now();
    final difference = now.difference(updatedAt);

    if (difference.inDays == 0) {
      if (difference.inHours == 0) {
        return '${difference.inMinutes} menit lalu';
      }
      return '${difference.inHours} jam lalu';
    } else if (difference.inDays == 1) {
      return 'Kemarin';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} hari lalu';
    } else {
      return '${updatedAt.day}/${updatedAt.month}/${updatedAt.year}';
    }
  }

  String get categoryDisplayName {
    switch (category) {
      case 'learning':
        return 'Belajar';
      case 'idea':
        return 'Ide';
      default:
        return 'Umum';
    }
  }

  // Copy with method untuk update
  NoteModel copyWith({
    String? title,
    String? content,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? category,
    String? relatedTaskId,
    List<String>? tags,
    bool? isPinned,
    String? colorCode,
  }) {
    return NoteModel(
      title: title ?? this.title,
      content: content ?? this.content,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      category: category ?? this.category,
      relatedTaskId: relatedTaskId ?? this.relatedTaskId,
      tags: tags ?? this.tags,
      isPinned: isPinned ?? this.isPinned,
      colorCode: colorCode ?? this.colorCode,
    );
  }

  // Factory constructor untuk create note baru
  factory NoteModel.create({
    required String title,
    required String content,
    String category = 'general',
    String? relatedTaskId,
    List<String> tags = const [],
    bool isPinned = false,
    String colorCode = '#2196F3',
  }) {
    final now = DateTime.now();
    return NoteModel(
      title: title,
      content: content,
      createdAt: now,
      updatedAt: now,
      category: category,
      relatedTaskId: relatedTaskId,
      tags: tags,
      isPinned: isPinned,
      colorCode: colorCode,
    );
  }

  // Update note dan set updatedAt
  void updateContent({
    String? title,
    String? content,
    String? category,
    String? relatedTaskId,
    List<String>? tags,
    bool? isPinned,
    String? colorCode,
  }) {
    if (title != null) this.title = title;
    if (content != null) this.content = content;
    if (category != null) this.category = category;
    if (relatedTaskId != null) this.relatedTaskId = relatedTaskId;
    if (tags != null) this.tags = tags;
    if (isPinned != null) this.isPinned = isPinned;
    if (colorCode != null) this.colorCode = colorCode;
    this.updatedAt = DateTime.now();
    save();
  }

  // Toggle pin status
  void togglePin() {
    isPinned = !isPinned;
    updatedAt = DateTime.now();
    save();
  }

  // Add tag
  void addTag(String tag) {
    if (!tags.contains(tag)) {
      tags = [...tags, tag];
      updatedAt = DateTime.now();
      save();
    }
  }

  // Remove tag
  void removeTag(String tag) {
    tags = tags.where((t) => t != tag).toList();
    updatedAt = DateTime.now();
    save();
  }

  // Get word count
  int get wordCount {
    return content.trim().split(RegExp(r'\s+')).length;
  }

  // Get character count
  int get characterCount {
    return content.length;
  }

  // Get preview (first 100 characters)
  String get preview {
    if (content.length <= 100) return content;
    return '${content.substring(0, 100)}...';
  }

  // Check if note is empty
  bool get isEmpty {
    return title.trim().isEmpty && content.trim().isEmpty;
  }

  // Check if note was recently updated (last 24 hours)
  bool get isRecentlyUpdated {
    final difference = DateTime.now().difference(updatedAt);
    return difference.inHours < 24;
  }

  // Get category icon
  String get categoryIcon {
    switch (category) {
      case 'learning':
        return '📚';
      case 'idea':
        return '💡';
      default:
        return '📝';
    }
  }

  @override
  String toString() {
    return 'NoteModel(title: $title, category: $category, tags: ${tags.length}, pinned: $isPinned)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is NoteModel &&
        other.title == title &&
        other.content == content &&
        other.createdAt == createdAt;
  }

  @override
  int get hashCode {
    return title.hashCode ^ content.hashCode ^ createdAt.hashCode;
  }
}