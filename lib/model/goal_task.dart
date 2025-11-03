// File: lib/model/goal_task.dart
// Model untuk Goal/Target dengan deadline dan progress tracking

import 'package:hive/hive.dart';

part 'goal_task.g.dart';

@HiveType(typeId: 0)
class GoalTask extends HiveObject {
  @HiveField(0)
  String title;

  @HiveField(1)
  String description;

  @HiveField(2)
  DateTime deadline;

  @HiveField(3)
  double progress; // 0.0 - 100.0 (percentage)

  @HiveField(4)
  DateTime? createdAt;

  @HiveField(5)
  DateTime? completedAt;

  @HiveField(6)
  bool isCompleted;

  @HiveField(7)
  String? category;

  @HiveField(8)
  int priority; // 0 = low, 1 = medium, 2 = high

  GoalTask({
    required this.title,
    required this.description,
    required this.deadline,
    this.progress = 0.0,
    DateTime? createdAt,
    this.completedAt,
    this.isCompleted = false,
    this.category,
    this.priority = 1,
  }) : createdAt = createdAt ?? DateTime.now();

  // ============= GETTERS =============

  /// Check apakah goal sudah melewati deadline
  bool get isOverdue {
    return !isCompleted && DateTime.now().isAfter(deadline);
  }

  /// Check apakah deadline sudah dekat (dalam 3 hari)
  bool get isDeadlineNear {
    if (isCompleted) return false;
    final daysUntilDeadline = deadline.difference(DateTime.now()).inDays;
    return daysUntilDeadline <= 3 && daysUntilDeadline >= 0;
  }

  /// Sisa hari sampai deadline
  int get daysUntilDeadline {
    return deadline.difference(DateTime.now()).inDays;
  }

  /// Sisa waktu sampai deadline dalam format Duration
  Duration get timeUntilDeadline {
    return deadline.difference(DateTime.now());
  }

  /// Progress dalam format persentase dengan 1 desimal
  String get progressPercentage {
    return '${progress.toStringAsFixed(1)}%';
  }

  /// Status goal
  String get status {
    if (isCompleted) return 'Selesai';
    if (isOverdue) return 'Terlambat';
    if (isDeadlineNear) return 'Mendesak';
    return 'Dalam Proses';
  }

  /// Warna status untuk UI
  String get statusColor {
    if (isCompleted) return 'green';
    if (isOverdue) return 'red';
    if (isDeadlineNear) return 'orange';
    return 'blue';
  }

  /// Priority label
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

  /// Check apakah progress sudah 100%
  bool get isProgressComplete {
    return progress >= 100.0;
  }

  /// Waktu yang dibutuhkan untuk menyelesaikan goal
  Duration? get completionTime {
    if (completedAt != null && createdAt != null) {
      return completedAt!.difference(createdAt!);
    }
    return null;
  }

  /// Format deadline dalam string readable
  String get deadlineFormatted {
    final now = DateTime.now();
    final difference = deadline.difference(now);

    if (difference.inDays > 0) {
      return '${difference.inDays} hari lagi';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} jam lagi';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} menit lagi';
    } else if (difference.inSeconds > 0) {
      return 'Beberapa detik lagi';
    } else {
      final overdueDays = now.difference(deadline).inDays;
      return 'Terlambat ${overdueDays} hari';
    }
  }

  // ============= METHODS =============

  /// Update progress (validasi 0-100)
  void updateProgress(double newProgress) {
    if (newProgress < 0) {
      progress = 0.0;
    } else if (newProgress > 100) {
      progress = 100.0;
    } else {
      progress = newProgress;
    }

    // Auto complete jika progress 100%
    if (progress >= 100.0 && !isCompleted) {
      markAsCompleted();
    }
  }

  /// Tambah progress
  void addProgress(double amount) {
    updateProgress(progress + amount);
  }

  /// Kurangi progress
  void subtractProgress(double amount) {
    updateProgress(progress - amount);
  }

  /// Mark goal sebagai completed
  void markAsCompleted() {
    isCompleted = true;
    completedAt = DateTime.now();
    progress = 100.0;
  }

  /// Mark goal sebagai not completed
  void markAsIncomplete() {
    isCompleted = false;
    completedAt = null;
  }

  /// Reset progress
  void resetProgress() {
    progress = 0.0;
    isCompleted = false;
    completedAt = null;
  }

  // ============= COPY METHOD =============

  /// Create a copy of this goal with optional modifications
  GoalTask copyWith({
    String? title,
    String? description,
    DateTime? deadline,
    double? progress,
    DateTime? createdAt,
    DateTime? completedAt,
    bool? isCompleted,
    String? category,
    int? priority,
  }) {
    return GoalTask(
      title: title ?? this.title,
      description: description ?? this.description,
      deadline: deadline ?? this.deadline,
      progress: progress ?? this.progress,
      createdAt: createdAt ?? this.createdAt,
      completedAt: completedAt ?? this.completedAt,
      isCompleted: isCompleted ?? this.isCompleted,
      category: category ?? this.category,
      priority: priority ?? this.priority,
    );
  }

  // ============= OVERRIDE METHODS =============

  @override
  String toString() {
    return 'GoalTask(title: $title, progress: $progressPercentage, status: $status, deadline: $deadlineFormatted)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is GoalTask &&
        other.title == title &&
        other.description == description &&
        other.deadline == deadline &&
        other.progress == progress;
  }

  @override
  int get hashCode {
    return title.hashCode ^
    description.hashCode ^
    deadline.hashCode ^
    progress.hashCode;
  }
}