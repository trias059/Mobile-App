// File: lib/pages/daily_task_page.dart
// Halaman untuk mengelola tugas harian dengan tab view per hari

import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';
import 'package:lisku/model/task_daily_model.dart';
import 'package:lisku/services/notification_service.dart';

// Import TaskProvider dari main.dart
// Note: Jika TaskProvider ada di file terpisah, sesuaikan import path-nya
// import 'package:lisku/providers/task_provider.dart';

class DailyTaskPage extends StatefulWidget {
  const DailyTaskPage({super.key});

  @override
  State<DailyTaskPage> createState() => _DailyTaskPageState();
}

class _DailyTaskPageState extends State<DailyTaskPage> with TickerProviderStateMixin {
  late Box<DailyTaskModel> _taskBox;
  late Box _settingsBox;
  late TabController _tabController;

  String _sortMethod = 'time';
  bool _notificationsEnabled = true;
  Map<String, int> _taskNotificationIds = {};

  // Days of week
  final List<String> _daysOfWeek = [
    'monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday'
  ];

  final Map<String, String> _dayNames = {
    'monday': 'Senin',
    'tuesday': 'Selasa',
    'wednesday': 'Rabu',
    'thursday': 'Kamis',
    'friday': 'Jumat',
    'saturday': 'Sabtu',
    'sunday': 'Minggu',
  };

  @override
  void initState() {
    super.initState();
    _initializeBoxes();
    _initializeSettings();
    _checkNotificationPermission();

    // Initialize tab controller dengan 7 tabs (satu untuk setiap hari)
    _tabController = TabController(length: 7, vsync: this);

    // Set tab awal ke hari ini
    final todayIndex = DateTime.now().weekday - 1;
    _tabController.index = todayIndex;

    // Reset tasks untuk hari baru
    _resetTasksForNewDay();
  }

  Future<void> _initializeBoxes() async {
    try {
      _taskBox = await Hive.openBox<DailyTaskModel>('dailyTasks');
      debugPrint('✅ Task box opened successfully');
    } catch (e) {
      debugPrint('❌ Error opening task box: $e');
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // Reset status completion untuk hari baru
  void _resetTasksForNewDay() {
    if (!mounted) return;

    final tasks = _taskBox.values.toList();
    final today = DateTime.now();

    for (var task in tasks) {
      // Reset jika lastCompletedDate bukan hari ini
      if (task.lastCompletedDate != null) {
        final lastCompleted = task.lastCompletedDate!;
        final isSameDay = lastCompleted.year == today.year &&
            lastCompleted.month == today.month &&
            lastCompleted.day == today.day;

        if (!isSameDay) {
          task.isCompleted = false;
          task.completedAt = null;
          task.save();
        }
      }
    }

    debugPrint('✅ Tasks reset for new day');
  }

  // RESET ALL TASKS METHOD
  void _fullResetTasks() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset Semua Tugas?'),
        content: const Text('Ini akan menghapus SEMUA tugas harian. Yakin?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Reset', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _taskBox.clear();

      // Cancel semua notifikasi
      for (var notificationId in _taskNotificationIds.values) {
        await NotificationService.cancelNotification(notificationId);
      }
      _taskNotificationIds.clear();
      _settingsBox.put('task_notification_ids', _taskNotificationIds);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Semua tugas telah dihapus'),
            backgroundColor: Colors.green,
          ),
        );
      }

      debugPrint('🗑️ All tasks deleted');
    }
  }

  Future<void> _initializeSettings() async {
    try {
      _settingsBox = await Hive.openBox('settings');
      setState(() {
        _notificationsEnabled = _settingsBox.get('notifications_enabled', defaultValue: true);
        final savedIds = _settingsBox.get('task_notification_ids', defaultValue: {});
        _taskNotificationIds = Map<String, int>.from(savedIds);
      });
      debugPrint('✅ Settings initialized');
    } catch (e) {
      debugPrint('❌ Error initializing settings: $e');
    }
  }

  Future<void> _checkNotificationPermission() async {
    if (_notificationsEnabled) {
      final granted = await NotificationService.requestPermissions();
      if (!granted) {
        setState(() {
          _notificationsEnabled = false;
        });
        _settingsBox.put('notifications_enabled', false);
        debugPrint('⚠️ Notification permission denied');
      }
    }
  }

  void _toggleNotifications() async {
    final newValue = !_notificationsEnabled;

    if (newValue) {
      final granted = await NotificationService.requestPermissions();
      if (!granted) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Izin notifikasi diperlukan. Silakan aktifkan di pengaturan.'),
            ),
          );
        }
        return;
      }
    } else {
      // Cancel semua notifikasi
      for (var notificationId in _taskNotificationIds.values) {
        await NotificationService.cancelNotification(notificationId);
      }
      _taskNotificationIds.clear();
    }

    setState(() {
      _notificationsEnabled = newValue;
    });

    _settingsBox.put('notifications_enabled', newValue);
    _settingsBox.put('task_notification_ids', _taskNotificationIds);

    debugPrint('🔔 Notifications ${newValue ? "enabled" : "disabled"}');
  }

  // SIMPLE ADD TASK - Hanya untuk hari yang dipilih
  void _addTask({
    required String title,
    required int startHour,
    required int startMinute,
    required String startPeriod,
    required int endHour,
    required int endMinute,
    required String endPeriod,
    required String dayOfWeek,
  }) async {
    // Generate unique ID
    final uniqueId = '${title}_${startHour}_${startMinute}_${startPeriod}_${DateTime.now().millisecondsSinceEpoch}';

    // Cek duplikasi
    final isDuplicate = _taskBox.values.any((task) =>
    task.title == title &&
        task.startHour == startHour &&
        task.startMinute == startMinute &&
        task.startPeriod == startPeriod &&
        task.dayOfWeek == dayOfWeek);

    if (isDuplicate) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('⚠️ Tugas dengan waktu yang sama sudah ada'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    final newTask = DailyTaskModel(
      title: title,
      startHour: startHour,
      startMinute: startMinute,
      startPeriod: startPeriod,
      endHour: endHour,
      endMinute: endMinute,
      endPeriod: endPeriod,
      customOrder: _getMaxCustomOrder() + 1,
      dayOfWeek: dayOfWeek,
      repeatDays: [], // Tidak ada repeat dalam page ini
      uniqueId: uniqueId,
      isRepeating: false,
    );

    await _taskBox.add(newTask);

    // Schedule notifikasi jika enabled
    if (_notificationsEnabled) {
      final notificationId = await TaskNotificationManager.scheduleTaskReminder(
        taskTitle: title,
        startHour: startHour,
        startMinute: startMinute,
        startPeriod: startPeriod,
      );
      _taskNotificationIds[uniqueId] = notificationId;
      _settingsBox.put('task_notification_ids', _taskNotificationIds);
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ Tugas "$title" berhasil ditambahkan'),
          backgroundColor: Colors.green,
        ),
      );
    }

    debugPrint('✅ Task added: $title');
  }

  int _getMaxCustomOrder() {
    if (_taskBox.values.isEmpty) return 0;
    return _taskBox.values.map((task) => task.customOrder).reduce((a, b) => a > b ? a : b);
  }

  // SIMPLE DELETE - Hapus task
  void _deleteTask(DailyTaskModel task) async {
    // Cancel notifikasi jika ada
    if (_taskNotificationIds.containsKey(task.uniqueId)) {
      final notificationId = _taskNotificationIds[task.uniqueId]!;
      await NotificationService.cancelNotification(notificationId);
      _taskNotificationIds.remove(task.uniqueId);
      _settingsBox.put('task_notification_ids', _taskNotificationIds);
    }

    await task.delete();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('🗑️ Tugas "${task.title}" dihapus'),
          backgroundColor: Colors.red,
        ),
      );
    }

    debugPrint('🗑️ Task deleted: ${task.title}');
  }

  void _toggleDone(DailyTaskModel task) {
    if (!task.isCompleted) {
      // Mark as completed
      task.isCompleted = true;
      task.completedAt = DateTime.now();
      task.lastCompletedDate = DateTime.now();
    } else {
      // Mark as incomplete
      task.isCompleted = false;
      task.completedAt = null;
    }
    task.save();

    debugPrint('${task.isCompleted ? "✅" : "⬜"} Task toggled: ${task.title}');
  }

  List<DailyTaskModel> _getTasksForDay(String dayOfWeek) {
    final allTasks = _taskBox.values.toList();

    // Filter tasks untuk hari ini
    final dayTasks = allTasks.where((task) {
      // Cek apakah task untuk hari ini
      if (task.repeatDays.isNotEmpty) {
        return task.repeatDays.contains(dayOfWeek);
      } else {
        return task.dayOfWeek == dayOfWeek;
      }
    }).toList();

    // Reset completion status jika bukan hari ini
    final today = DateTime.now();
    for (var task in dayTasks) {
      if (task.lastCompletedDate != null) {
        final lastCompleted = task.lastCompletedDate!;
        final isSameDay = lastCompleted.year == today.year &&
            lastCompleted.month == today.month &&
            lastCompleted.day == today.day;

        if (!isSameDay) {
          task.isCompleted = false;
          task.completedAt = null;
        }
      }
    }

    // Sort tasks
    if (_sortMethod == 'time') {
      dayTasks.sort((a, b) => a.startTimeInMinutes.compareTo(b.startTimeInMinutes));
    } else {
      dayTasks.sort((a, b) => a.customOrder.compareTo(b.customOrder));
    }

    return dayTasks;
  }

  void _showAddTaskDialog() {
    final titleController = TextEditingController();
    int startHour = 9;
    int startMinute = 0;
    String startPeriod = 'AM';
    int endHour = 10;
    int endMinute = 0;
    String endPeriod = 'AM';

    // Get current selected day
    String selectedDay = _daysOfWeek[_tabController.index];

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Tambah Tugas - ${_dayNames[selectedDay]}'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(
                    labelText: 'Nama Tugas',
                    hintText: 'Contoh: Olahraga pagi',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.task_alt),
                  ),
                  autofocus: true,
                ),
                const SizedBox(height: 16),

                // Waktu Mulai
                const Text('Waktu Mulai:', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    DropdownButton<int>(
                      value: startHour,
                      items: List.generate(12, (i) => i + 1)
                          .map((h) => DropdownMenuItem(value: h, child: Text(h.toString().padLeft(2, '0'))))
                          .toList(),
                      onChanged: (val) => setDialogState(() => startHour = val!),
                    ),
                    const Text(' : '),
                    DropdownButton<int>(
                      value: startMinute,
                      items: [0, 15, 30, 45]
                          .map((m) => DropdownMenuItem(value: m, child: Text(m.toString().padLeft(2, '0'))))
                          .toList(),
                      onChanged: (val) => setDialogState(() => startMinute = val!),
                    ),
                    const SizedBox(width: 8),
                    DropdownButton<String>(
                      value: startPeriod,
                      items: ['AM', 'PM'].map((p) => DropdownMenuItem(value: p, child: Text(p))).toList(),
                      onChanged: (val) => setDialogState(() => startPeriod = val!),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Waktu Selesai
                const Text('Waktu Selesai:', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    DropdownButton<int>(
                      value: endHour,
                      items: List.generate(12, (i) => i + 1)
                          .map((h) => DropdownMenuItem(value: h, child: Text(h.toString().padLeft(2, '0'))))
                          .toList(),
                      onChanged: (val) => setDialogState(() => endHour = val!),
                    ),
                    const Text(' : '),
                    DropdownButton<int>(
                      value: endMinute,
                      items: [0, 15, 30, 45]
                          .map((m) => DropdownMenuItem(value: m, child: Text(m.toString().padLeft(2, '0'))))
                          .toList(),
                      onChanged: (val) => setDialogState(() => endMinute = val!),
                    ),
                    const SizedBox(width: 8),
                    DropdownButton<String>(
                      value: endPeriod,
                      items: ['AM', 'PM'].map((p) => DropdownMenuItem(value: p, child: Text(p))).toList(),
                      onChanged: (val) => setDialogState(() => endPeriod = val!),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              onPressed: () {
                if (titleController.text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('⚠️ Nama tugas tidak boleh kosong')),
                  );
                  return;
                }

                _addTask(
                  title: titleController.text,
                  startHour: startHour,
                  startMinute: startMinute,
                  startPeriod: startPeriod,
                  endHour: endHour,
                  endMinute: endMinute,
                  endPeriod: endPeriod,
                  dayOfWeek: selectedDay,
                );

                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
              ),
              child: const Text('Simpan', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  // Check apakah task sedang aktif (waktu sekarang berada di range task)
  bool _isTaskActive(DailyTaskModel task) {
    final now = DateTime.now();
    final currentMinutes = now.hour * 60 + now.minute;
    final startMinutes = task.startTimeInMinutes;

    // Hitung end time dalam menit
    int endHour24 = task.endPeriod == 'PM' && task.endHour != 12
        ? task.endHour + 12
        : (task.endPeriod == 'AM' && task.endHour == 12 ? 0 : task.endHour);
    final endMinutes = endHour24 * 60 + task.endMinute;

    return currentMinutes >= startMinutes && currentMinutes <= endMinutes;
  }

  // Check apakah task sudah completed hari ini
  bool _isCompletedToday(DailyTaskModel task) {
    if (!task.isCompleted || task.completedAt == null) return false;

    final completedDate = task.completedAt!;
    final today = DateTime.now();

    return completedDate.year == today.year &&
        completedDate.month == today.month &&
        completedDate.day == today.day;
  }

  Widget _buildTaskCard({
    required Key key,
    required DailyTaskModel task,
    required bool isActive,
  }) {
    final isCompletedToday = _isCompletedToday(task);

    return Card(
      key: key,
      margin: const EdgeInsets.only(bottom: 12),
      elevation: isActive ? 8 : 2,
      color: isActive ? Colors.blue.shade50 : null,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isActive
            ? BorderSide(color: Colors.blue.shade300, width: 2)
            : BorderSide.none,
      ),
      child: InkWell(
        onTap: () => _toggleDone(task),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Checkbox
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isCompletedToday ? Colors.green : Colors.grey,
                    width: 2,
                  ),
                  color: isCompletedToday ? Colors.green : Colors.transparent,
                ),
                child: isCompletedToday
                    ? const Icon(Icons.check, size: 16, color: Colors.white)
                    : null,
              ),
              const SizedBox(width: 16),

              // Task info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      task.title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        decoration: isCompletedToday
                            ? TextDecoration.lineThrough
                            : null,
                        color: isCompletedToday ? Colors.grey : null,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.access_time,
                          size: 14,
                          color: Colors.grey[600],
                        ),
                        const SizedBox(width: 4),
                        Text(
                          task.timeRange,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                        if (isActive) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.blue,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Text(
                              'Sekarang',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                        if (isCompletedToday && task.completedAt != null) ...[
                          const SizedBox(width: 8),
                          const Icon(
                            Icons.check_circle,
                            size: 14,
                            color: Colors.green,
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),

              // Delete button
              IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.red),
                onPressed: () => _deleteTask(task),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Helper: Get day name dari weekday number
  String _getDayName(int weekday) {
    switch (weekday) {
      case 1: return 'monday';
      case 2: return 'tuesday';
      case 3: return 'wednesday';
      case 4: return 'thursday';
      case 5: return 'friday';
      case 6: return 'saturday';
      case 7: return 'sunday';
      default: return 'monday';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Jadwal Mingguan'),
        backgroundColor: Colors.blue,
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          indicatorColor: Colors.white,
          tabs: _daysOfWeek.map((day) {
            final dayIndex = _daysOfWeek.indexOf(day);
            final isToday = dayIndex == DateTime.now().weekday - 1;

            return Tab(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _dayNames[day]!,
                      style: TextStyle(
                        fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    if (isToday) ...[
                      const SizedBox(width: 4),
                      Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          }).toList(),
        ),
        actions: [
          // Reset All Button
          IconButton(
            onPressed: _fullResetTasks,
            icon: const Icon(Icons.delete_forever, color: Colors.red),
            tooltip: 'Reset All Tasks',
          ),

          // Notification Toggle
          IconButton(
            onPressed: _toggleNotifications,
            icon: Icon(
              _notificationsEnabled
                  ? Icons.notifications_active
                  : Icons.notifications_off,
              color: _notificationsEnabled ? Colors.white : Colors.white70,
            ),
            tooltip: _notificationsEnabled
                ? 'Notifikasi Aktif'
                : 'Notifikasi Nonaktif',
          ),

          // Toggle Sort Method
          IconButton(
            onPressed: () {
              setState(() {
                _sortMethod = _sortMethod == 'time' ? 'custom' : 'time';
              });
            },
            icon: Icon(_sortMethod == 'time' ? Icons.access_time : Icons.reorder),
            tooltip: _sortMethod == 'time' ? 'Urutkan Manual' : 'Urutkan Waktu',
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: _daysOfWeek.map((day) {
          return ValueListenableBuilder(
            valueListenable: _taskBox.listenable(),
            builder: (context, Box<DailyTaskModel> box, _) {
              final tasks = _getTasksForDay(day);

              if (tasks.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.calendar_today, size: 80, color: Colors.grey.shade300),
                      const SizedBox(height: 20),
                      Text(
                        'Belum ada tugas untuk hari ${_dayNames[day]}',
                        style: const TextStyle(fontSize: 18, color: Colors.grey),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Tap + untuk menambah tugas',
                        style: TextStyle(fontSize: 14, color: Colors.grey),
                      ),
                    ],
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: tasks.length,
                itemBuilder: (context, index) {
                  final task = tasks[index];
                  final currentDay = _daysOfWeek[_tabController.index];
                  final isToday = currentDay == _getDayName(DateTime.now().weekday);
                  final isActive = isToday && _isTaskActive(task);

                  return _buildTaskCard(
                    key: ValueKey('${task.key}_$day'),
                    task: task,
                    isActive: isActive,
                  );
                },
              );
            },
          );
        }).toList(),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddTaskDialog,
        tooltip: 'Tambah Tugas',
        backgroundColor: Colors.blue,
        child: const Icon(Icons.add),
      ),
    );
  }
}