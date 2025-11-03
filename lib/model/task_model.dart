// File: lib/model/task_model.dart
// Model untuk Task umum (bukan daily task)

import 'package:hive/hive.dart';

part 'task_model.g.dart';

@HiveType(typeId: 2)
class TaskModel extends HiveObject {
  @HiveField(0)
  String title;

  @HiveField(1)
  bool isDone;

  @HiveField(2)
  DateTime? createdAt;

  @HiveField(3)
  DateTime? completedAt;

  @HiveField(4)
  String? description;

  @HiveField(5)
  int priority; // 0 = low, 1 = medium, 2 = high

  @HiveField(6)
  String? category;

  TaskModel({
    required this.title,
    this.isDone = false,
    DateTime? createdAt,
    this.completedAt,
    this.description,
    this.priority = 1, // default medium priority
    this.category,
  }) : createdAt = createdAt ?? DateTime.now();

  // ============= GETTERS =============

  /// Get priority label
  String get priorityLabel {
    switch (priority) {
      case 0:
        return 'Rendah';
      case 1:
        return 'Sedang';
      case 2:
        return 'Tinggi';
      default:
        return 'Sedang';
    }
  }

  /// Check if task is overdue (untuk task dengan deadline di masa depan)
  bool get isOverdue {
    // Implementasi bisa disesuaikan kalau ada deadline field
    return false;
  }

  /// Get elapsed time since creation
  Duration get timeSinceCreation {
    return DateTime.now().difference(createdAt ?? DateTime.now());
  }

  /// Get completion time (if completed)
  Duration? get completionTime {
    if (completedAt != null && createdAt != null) {
      return completedAt!.difference(createdAt!);
    }
    return null;
  }

  // ============= METHODS =============

  /// Mark task as done
  void markAsDone() {
    isDone = true;
    completedAt = DateTime.now();
  }

  /// Mark task as not done
  void markAsNotDone() {
    isDone = false;
    completedAt = null;
  }

  /// Toggle task completion status
  void toggle() {
    if (isDone) {
      markAsNotDone();
    } else {
      markAsDone();
    }
  }

  // ============= COPY METHOD =============

  /// Create a copy of this task with optional modifications
  TaskModel copyWith({
    String? title,
    bool? isDone,
    DateTime? createdAt,
    DateTime? completedAt,
    String? description,
    int? priority,
    String? category,
  }) {
    return TaskModel(
      title: title ?? this.title,
      isDone: isDone ?? this.isDone,
      createdAt: createdAt ?? this.createdAt,
      completedAt: completedAt ?? this.completedAt,
      description: description ?? this.description,
      priority: priority ?? this.priority,
      category: category ?? this.category,
    );
  }

  // ============= OVERRIDE METHODS =============

  @override
  String toString() {
    return 'TaskModel(title: $title, isDone: $isDone, priority: $priorityLabel, category: $category)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is TaskModel &&
        other.title == title &&
        other.isDone == isDone &&
        other.priority == priority &&
        other.category == category;
  }

  @override
  int get hashCode {
    return title.hashCode ^
    isDone.hashCode ^
    priority.hashCode ^
    (category?.hashCode ?? 0);
  }
}