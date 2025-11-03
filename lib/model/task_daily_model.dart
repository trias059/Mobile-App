// File: lib/model/task_daily_model.dart
// Model untuk Daily Task dengan support Hive database

import 'package:hive/hive.dart';

part 'task_daily_model.g.dart';

@HiveType(typeId: 10)
class DailyTaskModel extends HiveObject {
  @HiveField(0)
  String title;

  @HiveField(1)
  bool isCompleted;

  @HiveField(2)
  int startHour;

  @HiveField(3)
  int startMinute;

  @HiveField(4)
  int endHour;

  @HiveField(5)
  int endMinute;

  @HiveField(6)
  String startPeriod; // AM or PM

  @HiveField(7)
  String endPeriod; // AM or PM

  @HiveField(8)
  DateTime? completedAt;

  @HiveField(9)
  int customOrder;

  @HiveField(10)
  String dayOfWeek; // monday, tuesday, etc.

  @HiveField(11)
  DateTime? lastCompletedDate;

  @HiveField(12)
  List<String> repeatDays; // Hari-hari untuk repeating task

  @HiveField(13)
  String uniqueId; // ID unik untuk prevent duplicate

  @HiveField(14)
  bool isRepeating; // Flag untuk repeating task

  // Constructor
  DailyTaskModel({
    required this.title,
    this.isCompleted = false,
    this.startHour = 9,
    this.startMinute = 0,
    this.endHour = 10,
    this.endMinute = 0,
    this.startPeriod = 'AM',
    this.endPeriod = 'AM',
    this.completedAt,
    this.customOrder = 0,
    this.dayOfWeek = 'monday',
    this.lastCompletedDate,
    this.repeatDays = const [],
    String? uniqueId,
    this.isRepeating = false,
  }) : uniqueId = uniqueId ?? DateTime.now().millisecondsSinceEpoch.toString();

  // ============= GETTERS =============

  /// Menampilkan range waktu dalam format readable
  /// Contoh: "09:00 AM - 10:00 AM"
  String get timeRange {
    return '${startHour.toString().padLeft(2, '0')}:${startMinute.toString().padLeft(2, '0')} $startPeriod - ${endHour.toString().padLeft(2, '0')}:${endMinute.toString().padLeft(2, '0')} $endPeriod';
  }

  /// Menghitung waktu mulai dalam menit (dari 00:00)
  /// Digunakan untuk sorting dan comparison
  int get startTimeInMinutes {
    int hour24 = startPeriod == 'AM'
        ? (startHour == 12 ? 0 : startHour)
        : (startHour == 12 ? 12 : startHour + 12);
    return hour24 * 60 + startMinute;
  }

  /// Menghitung waktu selesai dalam menit (dari 00:00)
  int get endTimeInMinutes {
    int hour24 = endPeriod == 'AM'
        ? (endHour == 12 ? 0 : endHour)
        : (endHour == 12 ? 12 : endHour + 12);
    return hour24 * 60 + endMinute;
  }

  /// Mendapatkan durasi task dalam menit
  int get durationInMinutes {
    return endTimeInMinutes - startTimeInMinutes;
  }

  /// Check apakah task sedang aktif (waktu sekarang di antara start dan end)
  bool get isCurrentlyActive {
    final now = DateTime.now();
    final currentMinutes = now.hour * 60 + now.minute;
    return currentMinutes >= startTimeInMinutes && currentMinutes <= endTimeInMinutes;
  }

  // ============= HELPER METHODS =============

  /// Check apakah task harus ditampilkan untuk hari tertentu
  bool shouldShowForDay(String day) {
    if (isRepeating && repeatDays.isNotEmpty) {
      return repeatDays.contains(day);
    }
    return dayOfWeek == day;
  }

  /// Check apakah task sudah completed hari ini
  bool isCompletedToday() {
    if (!isCompleted || completedAt == null) return false;

    final completedDate = completedAt!;
    final today = DateTime.now();

    return completedDate.year == today.year &&
        completedDate.month == today.month &&
        completedDate.day == today.day;
  }

  /// Check apakah task completed tepat waktu (sebelum end time)
  bool get isCompletedOnTime {
    if (!isCompleted || completedAt == null) return false;

    final completedMinutes = completedAt!.hour * 60 + completedAt!.minute;
    return completedMinutes <= endTimeInMinutes;
  }

  /// Reset task completion untuk hari baru
  void resetForNewDay() {
    if (lastCompletedDate != null) {
      final today = DateTime.now();
      final lastCompleted = lastCompletedDate!;

      // Check apakah lastCompletedDate bukan hari ini
      final isSameDay = lastCompleted.year == today.year &&
          lastCompleted.month == today.month &&
          lastCompleted.day == today.day;

      if (!isSameDay) {
        isCompleted = false;
        completedAt = null;
      }
    }
  }

  /// Mark task sebagai completed
  void markCompleted() {
    isCompleted = true;
    completedAt = DateTime.now();
    lastCompletedDate = DateTime.now();
  }

  /// Mark task sebagai incomplete
  void markIncomplete() {
    isCompleted = false;
    completedAt = null;
  }

  // ============= STATIC METHODS =============

  /// Konversi weekday number (1-7) ke day name string
  static String getDayName(int weekday) {
    switch (weekday) {
      case 1:
        return 'monday';
      case 2:
        return 'tuesday';
      case 3:
        return 'wednesday';
      case 4:
        return 'thursday';
      case 5:
        return 'friday';
      case 6:
        return 'saturday';
      case 7:
        return 'sunday';
      default:
        return 'monday';
    }
  }

  /// Konversi day name ke Bahasa Indonesia
  static String getDayDisplayName(String day) {
    switch (day) {
      case 'monday':
        return 'Senin';
      case 'tuesday':
        return 'Selasa';
      case 'wednesday':
        return 'Rabu';
      case 'thursday':
        return 'Kamis';
      case 'friday':
        return 'Jumat';
      case 'saturday':
        return 'Sabtu';
      case 'sunday':
        return 'Minggu';
      default:
        return day;
    }
  }

  /// Konversi 12-hour format ke 24-hour format
  static int convertTo24Hour(int hour, String period) {
    if (period == 'AM') {
      return hour == 12 ? 0 : hour;
    } else {
      return hour == 12 ? 12 : hour + 12;
    }
  }

  /// Konversi 24-hour format ke 12-hour format
  static Map<String, dynamic> convertTo12Hour(int hour24) {
    if (hour24 == 0) {
      return {'hour': 12, 'period': 'AM'};
    } else if (hour24 < 12) {
      return {'hour': hour24, 'period': 'AM'};
    } else if (hour24 == 12) {
      return {'hour': 12, 'period': 'PM'};
    } else {
      return {'hour': hour24 - 12, 'period': 'PM'};
    }
  }

  // ============= OVERRIDE METHODS =============

  @override
  String toString() {
    return 'DailyTaskModel(title: $title, day: $dayOfWeek, time: $timeRange, completed: $isCompleted, repeating: $isRepeating)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is DailyTaskModel &&
        other.uniqueId == uniqueId &&
        other.title == title &&
        other.dayOfWeek == dayOfWeek &&
        other.startHour == startHour &&
        other.startMinute == startMinute &&
        other.startPeriod == startPeriod;
  }

  @override
  int get hashCode {
    return uniqueId.hashCode ^
    title.hashCode ^
    dayOfWeek.hashCode ^
    startHour.hashCode ^
    startMinute.hashCode ^
    startPeriod.hashCode;
  }

  // ============= COPY METHOD =============

  /// Buat copy dari task dengan property yang bisa diubah
  DailyTaskModel copyWith({
    String? title,
    bool? isCompleted,
    int? startHour,
    int? startMinute,
    int? endHour,
    int? endMinute,
    String? startPeriod,
    String? endPeriod,
    DateTime? completedAt,
    int? customOrder,
    String? dayOfWeek,
    DateTime? lastCompletedDate,
    List<String>? repeatDays,
    String? uniqueId,
    bool? isRepeating,
  }) {
    return DailyTaskModel(
      title: title ?? this.title,
      isCompleted: isCompleted ?? this.isCompleted,
      startHour: startHour ?? this.startHour,
      startMinute: startMinute ?? this.startMinute,
      endHour: endHour ?? this.endHour,
      endMinute: endMinute ?? this.endMinute,
      startPeriod: startPeriod ?? this.startPeriod,
      endPeriod: endPeriod ?? this.endPeriod,
      completedAt: completedAt ?? this.completedAt,
      customOrder: customOrder ?? this.customOrder,
      dayOfWeek: dayOfWeek ?? this.dayOfWeek,
      lastCompletedDate: lastCompletedDate ?? this.lastCompletedDate,
      repeatDays: repeatDays ?? this.repeatDays,
      uniqueId: uniqueId ?? this.uniqueId,
      isRepeating: isRepeating ?? this.isRepeating,
    );
  }
}