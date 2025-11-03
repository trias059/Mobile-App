// File: lib/services/notification_service.dart
// Layanan notifikasi untuk Daily Task dengan timezone Asia/Jakarta

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import 'dart:convert';
import 'package:flutter/material.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notifications =
  FlutterLocalNotificationsPlugin();

  // Inisialisasi service notifikasi
  static Future<void> initialize() async {
    // Inisialisasi timezone database
    tz.initializeTimeZones();

    // Set timezone ke Jakarta (Indonesia) sebagai default
    tz.setLocalLocation(tz.getLocation('Asia/Jakarta'));

    // Konfigurasi Android
    const AndroidInitializationSettings androidSettings =
    AndroidInitializationSettings('@mipmap/ic_launcher');

    // Konfigurasi iOS
    const DarwinInitializationSettings iosSettings =
    DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    // Inisialisasi dengan callback ketika notifikasi di-tap
    await _notifications.initialize(
      const InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      ),
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // Buat notification channel untuk Android
    await _createNotificationChannel();
  }

  // Membuat notification channel khusus untuk Daily Tasks
  static Future<void> _createNotificationChannel() async {
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'daily_tasks_channel', // ID channel
      'Daily Tasks', // Nama channel
      description: 'Notifikasi pengingat tugas harian',
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
    );

    await _notifications
        .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  // Handler ketika notifikasi di-tap
  static void _onNotificationTapped(NotificationResponse response) {
    if (response.payload != null) {
      debugPrint('Notifikasi dibuka dengan payload: ${response.payload}');
      // TODO: Navigasi ke halaman task yang sesuai
      // Bisa parse payload untuk ambil task_id dan buka detail task
    }
  }

  // Minta izin notifikasi (khusus Android 13+)
  static Future<bool> requestPermissions() async {
    final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
    _notifications.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();

    if (androidImplementation != null) {
      final bool? granted =
      await androidImplementation.requestNotificationsPermission();
      return granted ?? false;
    }

    return true; // iOS handle otomatis
  }

  // Tampilkan notifikasi langsung (immediate)
  static Future<void> showNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    const AndroidNotificationDetails androidDetails =
    AndroidNotificationDetails(
      'daily_tasks_channel',
      'Daily Tasks',
      channelDescription: 'Notifikasi pengingat tugas harian',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
    );

    const NotificationDetails details = NotificationDetails(
      android: androidDetails,
      iOS: DarwinNotificationDetails(),
    );

    await _notifications.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      details,
      payload: payload,
    );
  }

  // Schedule notifikasi untuk daily task (repeat setiap hari)
  static Future<void> scheduleDailyTaskNotification({
    required int id,
    required String taskTitle,
    required int hour,
    required int minute,
    required String period, // AM/PM
  }) async {
    // Konversi ke format 24 jam
    int hour24 = hour;
    if (period == 'PM' && hour != 12) {
      hour24 = hour + 12;
    } else if (period == 'AM' && hour == 12) {
      hour24 = 0;
    }

    // Buat waktu terjadwal
    final now = tz.TZDateTime.now(tz.local);
    var scheduledDate = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour24,
      minute,
    );

    // Jika waktu sudah lewat hari ini, jadwalkan untuk besok
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    const AndroidNotificationDetails androidDetails =
    AndroidNotificationDetails(
      'daily_tasks_channel',
      'Daily Tasks',
      channelDescription: 'Notifikasi pengingat tugas harian',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
      icon: '@mipmap/ic_launcher',
    );

    const NotificationDetails details = NotificationDetails(
      android: androidDetails,
      iOS: DarwinNotificationDetails(),
    );

    await _notifications.zonedSchedule(
      id,
      '🔔 Waktunya: $taskTitle',
      'Tugas "$taskTitle" dimulai sekarang!',
      scheduledDate,
      details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
      UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time, // Repeat harian
      payload: json.encode({
        'task_id': id,
        'task_title': taskTitle,
        'type': 'daily_task',
      }),
    );

    debugPrint('Notifikasi terjadwal: $taskTitle pada $hour24:$minute');
  }

  // Schedule notifikasi sekali saja (tidak repeat)
  static Future<void> scheduleOneTimeNotification({
    required int id,
    required String taskTitle,
    required DateTime scheduledTime,
  }) async {
    const AndroidNotificationDetails androidDetails =
    AndroidNotificationDetails(
      'daily_tasks_channel',
      'Daily Tasks',
      channelDescription: 'Notifikasi pengingat tugas harian',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
    );

    const NotificationDetails details = NotificationDetails(
      android: androidDetails,
      iOS: DarwinNotificationDetails(),
    );

    await _notifications.zonedSchedule(
      id,
      '🔔 Reminder: $taskTitle',
      'Waktunya mengerjakan "$taskTitle"!',
      tz.TZDateTime.from(scheduledTime, tz.local),
      details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
      UILocalNotificationDateInterpretation.absoluteTime,
      // Tidak ada matchDateTimeComponents = one-time notification
      payload: json.encode({
        'task_id': id,
        'task_title': taskTitle,
        'type': 'one_time',
      }),
    );
  }

  // Batalkan notifikasi berdasarkan ID
  static Future<void> cancelNotification(int id) async {
    await _notifications.cancel(id);
    debugPrint('Notifikasi ID $id dibatalkan');
  }

  // Batalkan semua notifikasi
  static Future<void> cancelAllNotifications() async {
    await _notifications.cancelAll();
    debugPrint('Semua notifikasi dibatalkan');
  }

  // Ambil daftar notifikasi yang pending (untuk debugging)
  static Future<List<PendingNotificationRequest>>
  getPendingNotifications() async {
    return await _notifications.pendingNotificationRequests();
  }
}

// ============================================================================
// Helper class untuk manage notifikasi task
// ============================================================================
class TaskNotificationManager {
  static int _notificationIdCounter = 1000;

  // Generate ID unik untuk notifikasi
  static int _generateNotificationId() {
    return _notificationIdCounter++;
  }

  // Schedule notifikasi saat task dibuat
  static Future<int> scheduleTaskReminder({
    required String taskTitle,
    required int startHour,
    required int startMinute,
    required String startPeriod,
  }) async {
    final notificationId = _generateNotificationId();

    await NotificationService.scheduleDailyTaskNotification(
      id: notificationId,
      taskTitle: taskTitle,
      hour: startHour,
      minute: startMinute,
      period: startPeriod,
    );

    debugPrint('Task reminder dijadwalkan dengan ID: $notificationId');
    return notificationId;
  }

  // Schedule morning reminder (jam 7 pagi setiap hari)
  static Future<void> scheduleMorningReminder() async {
    const morningId = 1; // ID tetap untuk morning reminder

    await NotificationService.scheduleDailyTaskNotification(
      id: morningId,
      taskTitle: 'Review Tugas Hari Ini',
      hour: 7,
      minute: 0,
      period: 'AM',
    );

    debugPrint('Morning reminder dijadwalkan');
  }

  // Schedule evening summary (jam 8 malam setiap hari)
  static Future<void> scheduleEveningSummary() async {
    const eveningId = 2; // ID tetap untuk evening summary

    await NotificationService.scheduleDailyTaskNotification(
      id: eveningId,
      taskTitle: 'Evaluasi Tugas Hari Ini',
      hour: 8,
      minute: 0,
      period: 'PM',
    );

    debugPrint('Evening summary dijadwalkan');
  }

  // Fungsi test untuk coba semua jenis notifikasi
  static Future<void> testNotifications() async {
    // Test 1: Notifikasi langsung
    await NotificationService.showNotification(
      title: '✅ Test Immediate',
      body: 'Ini adalah notifikasi langsung untuk testing',
      payload: 'test_immediate',
    );

    // Test 2: Notifikasi terjadwal (10 detik dari sekarang)
    final testTime = DateTime.now().add(const Duration(seconds: 10));
    await NotificationService.scheduleOneTimeNotification(
      id: 9999,
      taskTitle: 'Test Scheduled',
      scheduledTime: testTime,
    );

    debugPrint('===== TEST NOTIFIKASI =====');
    debugPrint('✅ Immediate: Dikirim sekarang');
    debugPrint('⏰ Scheduled: Akan muncul dalam 10 detik');
    debugPrint('===========================');
  }

  // Debug: Tampilkan semua notifikasi yang pending
  static Future<void> debugPendingNotifications() async {
    final pending = await NotificationService.getPendingNotifications();

    debugPrint('===== PENDING NOTIFICATIONS =====');
    if (pending.isEmpty) {
      debugPrint('Tidak ada notifikasi pending');
    } else {
      debugPrint('Total: ${pending.length} notifikasi');
      for (var notification in pending) {
        debugPrint('---');
        debugPrint('ID: ${notification.id}');
        debugPrint('Title: ${notification.title}');
        debugPrint('Body: ${notification.body}');
        debugPrint('Payload: ${notification.payload}');
      }
    }
    debugPrint('=================================');
  }
}