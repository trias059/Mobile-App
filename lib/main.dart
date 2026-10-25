// File: lib/main.dart
// Entry point aplikasi Lisku - Daily Task Manager

import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';
import 'package:timezone/data/latest.dart' as tz;

// ============= IMPORT MODELS (FIXED PATH) =============
// Semua import sudah disesuaikan dari 'models/' ke 'model/'
import 'package:lisku/model/task_daily_model.dart';
import 'package:lisku/model/goal_task.dart';
import 'package:lisku/model/note_model.dart';
import 'package:lisku/model/transaction_model.dart';
import 'package:lisku/model/fitness_models.dart';

// ============= IMPORT SERVICES =============
import 'package:lisku/services/notification_service.dart';
import 'package:lisku/services/ai_server_controller.dart';

// ============= IMPORT PAGES =============
import 'package:lisku/pages/ai_assistant_page.dart';

// ============= TASK PROVIDER (DENGAN ANTI-DUPLIKASI) =============
class TaskProvider extends ChangeNotifier {
  Box<DailyTaskModel>? _taskBox;
  Map<String, List<DailyTaskModel>> _tasksByDay = {};
  String _selectedDay = 'monday';
  bool _isLoading = false;

  // Getters
  Map<String, List<DailyTaskModel>> get tasksByDay => _tasksByDay;
  String get selectedDay => _selectedDay;
  bool get isLoading => _isLoading;
  List<DailyTaskModel> get currentDayTasks => _tasksByDay[_selectedDay] ?? [];

  // Inisialisasi TaskProvider
  Future<void> init() async {
    _taskBox = await Hive.openBox<DailyTaskModel>('dailyTasks');

    // Set hari ini sebagai default
    final now = DateTime.now();
    _selectedDay = getDayName(now.weekday);

    // Bersihkan duplikat lama
    await cleanupDuplicates();

    // Load semua task
    await loadAllTasks();

    debugPrint('✅ TaskProvider initialized - Current day: $_selectedDay');
  }

  // Fungsi untuk membersihkan tugas yang duplikat
  Future<void> cleanupDuplicates() async {
    if (_taskBox == null) return;

    Set<String> seenIds = {};
    List<DailyTaskModel> toDelete = [];

    for (var task in _taskBox!.values) {
      // Buat unique key berdasarkan properti task
      String key = '${task.title}_${task.startHour}_${task.startMinute}_${task.startPeriod}_${task.dayOfWeek}';

      if (seenIds.contains(key)) {
        toDelete.add(task);
        debugPrint('⚠️ Duplikat ditemukan: ${task.title}');
      } else {
        seenIds.add(key);
      }
    }

    // Hapus semua duplikat
    for (var task in toDelete) {
      await task.delete();
    }

    if (toDelete.isNotEmpty) {
      debugPrint('🧹 Membersihkan ${toDelete.length} tugas duplikat');
    }
  }

  // Load semua task untuk 7 hari
  Future<void> loadAllTasks() async {
    _isLoading = true;
    notifyListeners();

    if (_taskBox == null) return;

    try {
      final days = ['monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday'];

      for (String day in days) {
        _tasksByDay[day] = getTasksForDay(day);
      }

      debugPrint('📋 Tasks loaded for all days');
    } catch (e) {
      debugPrint('❌ Error loading tasks: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Ambil task untuk hari tertentu (dengan anti-duplikasi)
  List<DailyTaskModel> getTasksForDay(String day) {
    if (_taskBox == null) return [];

    Set<String> uniqueTaskIds = {};
    List<DailyTaskModel> tasksForDay = [];

    for (var task in _taskBox!.values) {
      // Cek apakah task harus muncul di hari ini
      bool shouldShow = false;

      if (task.repeatDays.isNotEmpty) {
        // Task berulang
        shouldShow = task.repeatDays.contains(day);
      } else {
        // Task single day
        shouldShow = task.dayOfWeek == day;
      }

      if (shouldShow) {
        // Buat unique identifier untuk mencegah duplikasi
        String taskId = '${task.title}_${task.startHour}_${task.startMinute}_${task.startPeriod}';

        if (!uniqueTaskIds.contains(taskId)) {
          uniqueTaskIds.add(taskId);
          tasksForDay.add(task);
        }
      }
    }

    // Sort berdasarkan waktu mulai
    tasksForDay.sort((a, b) {
      int aMinutes = _convertToMinutes(a.startHour, a.startMinute, a.startPeriod);
      int bMinutes = _convertToMinutes(b.startHour, b.startMinute, b.startPeriod);
      return aMinutes.compareTo(bMinutes);
    });

    return tasksForDay;
  }

  // Helper: Konversi waktu ke menit
  int _convertToMinutes(int hour, int minute, String period) {
    int hour24 = hour;
    if (period == 'PM' && hour != 12) {
      hour24 = hour + 12;
    } else if (period == 'AM' && hour == 12) {
      hour24 = 0;
    }
    return hour24 * 60 + minute;
  }

  // Pilih hari
  void selectDay(String day) {
    _selectedDay = day;
    notifyListeners();
    debugPrint('📅 Day changed to: $day');
  }

  // Tambah task baru (dengan pengecekan duplikasi)
  Future<void> addTask({
    required String title,
    required int startHour,
    required int startMinute,
    required String startPeriod,
    required int endHour,
    required int endMinute,
    required String endPeriod,
    required List<String> repeatDays,
  }) async {
    if (_taskBox == null) return;

    // Generate unique ID
    final uniqueId = '${title}_${startHour}_${startMinute}_${startPeriod}_${DateTime.now().millisecondsSinceEpoch}';

    // Cek apakah task dengan properti yang sama sudah ada
    final existingTask = _taskBox!.values.any((task) =>
    task.title == title &&
        task.startHour == startHour &&
        task.startMinute == startMinute &&
        task.startPeriod == startPeriod);

    if (existingTask) {
      debugPrint('⚠️ Task sudah ada, tidak menambahkan duplikat');
      return;
    }

    // Buat task baru
    final task = DailyTaskModel(
      title: title,
      startHour: startHour,
      startMinute: startMinute,
      startPeriod: startPeriod,
      endHour: endHour,
      endMinute: endMinute,
      endPeriod: endPeriod,
      dayOfWeek: repeatDays.isEmpty ? _selectedDay : repeatDays.first,
      repeatDays: repeatDays,
      uniqueId: uniqueId,
      isRepeating: repeatDays.isNotEmpty,
    );

    await _taskBox!.add(task);

    // Schedule notifikasi untuk task ini
    await TaskNotificationManager.scheduleTaskReminder(
      taskTitle: title,
      startHour: startHour,
      startMinute: startMinute,
      startPeriod: startPeriod,
    );

    await loadAllTasks();
    debugPrint('✅ Task added: $title');
  }

  // Toggle status task (selesai/belum)
  Future<void> toggleTask(DailyTaskModel task) async {
    task.isCompleted = !task.isCompleted;
    task.completedAt = task.isCompleted ? DateTime.now() : null;
    task.lastCompletedDate = task.isCompleted ? DateTime.now() : null;
    await task.save();
    notifyListeners();

    debugPrint('${task.isCompleted ? "✅" : "⬜"} Task toggled: ${task.title}');
  }

  // Hapus task
  Future<void> deleteTask(DailyTaskModel task) async {
    await task.delete();
    await loadAllTasks();
    debugPrint('🗑️ Task deleted: ${task.title}');
  }

  // Helper: Konversi nomor hari ke nama hari
  String getDayName(int weekday) {
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

  // Helper: Konversi nama hari ke Bahasa Indonesia
  String getDayDisplayName(String day) {
    switch (day) {
      case 'monday': return 'Senin';
      case 'tuesday': return 'Selasa';
      case 'wednesday': return 'Rabu';
      case 'thursday': return 'Kamis';
      case 'friday': return 'Jumat';
      case 'saturday': return 'Sabtu';
      case 'sunday': return 'Minggu';
      default: return day;
    }
  }
}

// ============= HOME SCREEN =============
class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  final List<Widget> _pages = [
    WeeklyScheduleTab(),
    Center(child: Text('Fitness (Coming Soon)', style: TextStyle(fontSize: 20))),
    Center(child: Text('Finance (Coming Soon)', style: TextStyle(fontSize: 20))),
    Center(child: Text('Notes (Coming Soon)', style: TextStyle(fontSize: 20))),
    const AiAssistantPage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Colors.blue,
        unselectedItemColor: Colors.grey,
        items: [
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_today),
            label: 'Tugas',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.fitness_center),
            label: 'Fitness',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.account_balance_wallet),
            label: 'Keuangan',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.note),
            label: 'Catatan',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.smart_toy),
            label: 'AI',
          ),
        ],
      ),
    );
  }
}

// ============= WEEKLY SCHEDULE TAB =============
class WeeklyScheduleTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer<TaskProvider>(
      builder: (context, provider, _) {
        if (provider.isLoading) {
          return Scaffold(
            appBar: AppBar(
              title: Text('Loading...'),
              backgroundColor: Colors.blue,
            ),
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final tasks = provider.currentDayTasks;

        return Scaffold(
          appBar: AppBar(
            title: Text('Tugas Harian - ${provider.getDayDisplayName(provider.selectedDay)}'),
            backgroundColor: Colors.blue,
            elevation: 0,
          ),
          body: Column(
            children: [
              // Day Selector
              Container(
                height: 70,
                color: Colors.blue.shade50,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  children: ['monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday']
                      .map((day) {
                    final isSelected = day == provider.selectedDay;
                    return Padding(
                      padding: EdgeInsets.symmetric(horizontal: 4),
                      child: GestureDetector(
                        onTap: () => provider.selectDay(day),
                        child: Container(
                          width: 60,
                          decoration: BoxDecoration(
                            color: isSelected ? Colors.blue : Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected ? Colors.blue : Colors.grey.shade300,
                            ),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                provider.getDayDisplayName(day).substring(0, 3),
                                style: TextStyle(
                                  color: isSelected ? Colors.white : Colors.black87,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),

              // Task List
              Expanded(
                child: tasks.isEmpty
                    ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.inbox_outlined, size: 80, color: Colors.grey.shade300),
                      SizedBox(height: 16),
                      Text(
                        'Tidak ada tugas hari ini',
                        style: TextStyle(fontSize: 16, color: Colors.grey),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Tap tombol + untuk menambah tugas',
                        style: TextStyle(fontSize: 14, color: Colors.grey.shade400),
                      ),
                    ],
                  ),
                )
                    : ListView.builder(
                  padding: EdgeInsets.all(16),
                  itemCount: tasks.length,
                  itemBuilder: (context, index) {
                    final task = tasks[index];
                    return Dismissible(
                      key: Key(task.uniqueId),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        alignment: Alignment.centerRight,
                        padding: EdgeInsets.only(right: 20),
                        margin: EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(Icons.delete, color: Colors.white),
                      ),
                      onDismissed: (_) => provider.deleteTask(task),
                      child: Card(
                        margin: EdgeInsets.only(bottom: 12),
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: ListTile(
                          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          leading: Checkbox(
                            value: task.isCompleted,
                            onChanged: (_) => provider.toggleTask(task),
                            activeColor: Colors.green,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          title: Text(
                            task.title,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              decoration: task.isCompleted
                                  ? TextDecoration.lineThrough
                                  : TextDecoration.none,
                              color: task.isCompleted ? Colors.grey : Colors.black87,
                            ),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(height: 4),
                              Row(
                                children: [
                                  Icon(Icons.access_time, size: 14, color: Colors.grey),
                                  SizedBox(width: 4),
                                  Text(
                                    task.timeRange,
                                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                  ),
                                ],
                              ),
                              if (task.repeatDays.isNotEmpty) ...[
                                SizedBox(height: 4),
                                Row(
                                  children: [
                                    Icon(Icons.repeat, size: 14, color: Colors.blue),
                                    SizedBox(width: 4),
                                    Text(
                                      'Berulang',
                                      style: TextStyle(fontSize: 12, color: Colors.blue),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                          trailing: Icon(
                            task.isCompleted ? Icons.check_circle : Icons.radio_button_unchecked,
                            color: task.isCompleted ? Colors.green : Colors.grey.shade400,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton(
            onPressed: () => _showAddTaskDialog(context, provider),
            child: Icon(Icons.add),
            backgroundColor: Colors.blue,
          ),
        );
      },
    );
  }

  void _showAddTaskDialog(BuildContext context, TaskProvider provider) {
    showDialog(
      context: context,
      builder: (context) => AddTaskDialog(),
    );
  }
}

// ============= ADD TASK DIALOG =============
class AddTaskDialog extends StatefulWidget {
  @override
  _AddTaskDialogState createState() => _AddTaskDialogState();
}

class _AddTaskDialogState extends State<AddTaskDialog> {
  final TextEditingController _titleController = TextEditingController();

  int _startHour = 9;
  int _startMinute = 0;
  String _startPeriod = 'AM';

  int _endHour = 10;
  int _endMinute = 0;
  String _endPeriod = 'AM';

  bool _isRepeating = false;
  List<String> _selectedDays = [];

  @override
  void initState() {
    super.initState();
    final provider = context.read<TaskProvider>();
    _selectedDays = [provider.selectedDay];
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.read<TaskProvider>();

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: EdgeInsets.all(20),
        constraints: BoxConstraints(maxHeight: 600),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Tambah Tugas Baru',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              SizedBox(height: 16),

              // Task Name
              TextField(
                controller: _titleController,
                decoration: InputDecoration(
                  labelText: 'Nama Tugas',
                  hintText: 'Contoh: Olahraga pagi',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  prefixIcon: Icon(Icons.task_alt),
                ),
                autofocus: true,
              ),
              SizedBox(height: 16),

              // Time Range
              Text('Waktu:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
              SizedBox(height: 8),
              Row(
                children: [
                  // Start Time
                  Expanded(
                    child: Container(
                      padding: EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Mulai', style: TextStyle(fontSize: 12, color: Colors.grey)),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              DropdownButton<int>(
                                value: _startHour,
                                underline: SizedBox(),
                                items: List.generate(12, (i) => i + 1)
                                    .map((h) => DropdownMenuItem(
                                  value: h,
                                  child: Text(h.toString().padLeft(2, '0')),
                                ))
                                    .toList(),
                                onChanged: (val) => setState(() => _startHour = val!),
                              ),
                              Text(':'),
                              DropdownButton<int>(
                                value: _startMinute,
                                underline: SizedBox(),
                                items: [0, 15, 30, 45]
                                    .map((m) => DropdownMenuItem(
                                  value: m,
                                  child: Text(m.toString().padLeft(2, '0')),
                                ))
                                    .toList(),
                                onChanged: (val) => setState(() => _startMinute = val!),
                              ),
                              SizedBox(width: 4),
                              DropdownButton<String>(
                                value: _startPeriod,
                                underline: SizedBox(),
                                items: ['AM', 'PM']
                                    .map((p) => DropdownMenuItem(value: p, child: Text(p)))
                                    .toList(),
                                onChanged: (val) => setState(() => _startPeriod = val!),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(width: 8),
                  // End Time
                  Expanded(
                    child: Container(
                      padding: EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Selesai', style: TextStyle(fontSize: 12, color: Colors.grey)),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              DropdownButton<int>(
                                value: _endHour,
                                underline: SizedBox(),
                                items: List.generate(12, (i) => i + 1)
                                    .map((h) => DropdownMenuItem(
                                  value: h,
                                  child: Text(h.toString().padLeft(2, '0')),
                                ))
                                    .toList(),
                                onChanged: (val) => setState(() => _endHour = val!),
                              ),
                              Text(':'),
                              DropdownButton<int>(
                                value: _endMinute,
                                underline: SizedBox(),
                                items: [0, 15, 30, 45]
                                    .map((m) => DropdownMenuItem(
                                  value: m,
                                  child: Text(m.toString().padLeft(2, '0')),
                                ))
                                    .toList(),
                                onChanged: (val) => setState(() => _endMinute = val!),
                              ),
                              SizedBox(width: 4),
                              DropdownButton<String>(
                                value: _endPeriod,
                                underline: SizedBox(),
                                items: ['AM', 'PM']
                                    .map((p) => DropdownMenuItem(value: p, child: Text(p)))
                                    .toList(),
                                onChanged: (val) => setState(() => _endPeriod = val!),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 16),

              // Repeat Option
              Container(
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SwitchListTile(
                  title: Text('Tugas Berulang'),
                  subtitle: Text('Ulangi tugas ini di hari lain', style: TextStyle(fontSize: 12)),
                  value: _isRepeating,
                  onChanged: (val) {
                    setState(() {
                      _isRepeating = val;
                      if (!val) {
                        _selectedDays = [provider.selectedDay];
                      }
                    });
                  },
                ),
              ),

              if (_isRepeating) ...[
                SizedBox(height: 16),
                Text('Pilih Hari:', style: TextStyle(fontWeight: FontWeight.w600)),
                SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: ['monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday']
                      .map((day) {
                    final displayName = provider.getDayDisplayName(day);
                    return FilterChip(
                      label: Text(displayName),
                      selected: _selectedDays.contains(day),
                      selectedColor: Colors.blue.shade100,
                      checkmarkColor: Colors.blue,
                      onSelected: (selected) {
                        setState(() {
                          if (selected) {
                            if (!_selectedDays.contains(day)) {
                              _selectedDays.add(day);
                            }
                          } else {
                            if (_selectedDays.length > 1) {
                              _selectedDays.remove(day);
                            }
                          }
                        });
                      },
                    );
                  }).toList(),
                ),
              ],

              SizedBox(height: 20),

              // Action Buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text('Batal'),
                  ),
                  SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _saveTask,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: Text('Simpan'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _saveTask() {
    if (_titleController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Nama tugas tidak boleh kosong')),
      );
      return;
    }

    final provider = context.read<TaskProvider>();

    provider.addTask(
      title: _titleController.text,
      startHour: _startHour,
      startMinute: _startMinute,
      startPeriod: _startPeriod,
      endHour: _endHour,
      endMinute: _endMinute,
      endPeriod: _endPeriod,
      repeatDays: _isRepeating ? _selectedDays : [],
    );

    Navigator.pop(context);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('✅ Tugas berhasil ditambahkan'),
        backgroundColor: Colors.green,
      ),
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }
}

// ============= MAIN FUNCTION =============
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inisialisasi Hive
  await Hive.initFlutter();

  // Register semua adapter Hive
  Hive.registerAdapter(DailyTaskModelAdapter());
  Hive.registerAdapter(GoalTaskAdapter());
  Hive.registerAdapter(NoteModelAdapter());
  Hive.registerAdapter(TransactionModelAdapter());
  Hive.registerAdapter(BudgetModelAdapter());
  Hive.registerAdapter(FinancialSummaryAdapter());

  // Fitness adapters
  Hive.registerAdapter(WorkoutPlanAdapter());
  Hive.registerAdapter(WorkoutDayAdapter());
  Hive.registerAdapter(ExerciseAdapter());
  Hive.registerAdapter(WorkoutSessionAdapter());
  Hive.registerAdapter(ExerciseLogAdapter());
  Hive.registerAdapter(SetLogAdapter());
  Hive.registerAdapter(NutritionPlanAdapter());
  Hive.registerAdapter(MacroTargetsAdapter());
  Hive.registerAdapter(MealPlanAdapter());
  Hive.registerAdapter(FoodAdapter());
  Hive.registerAdapter(MacrosAdapter());
  Hive.registerAdapter(FoodLogAdapter());
  Hive.registerAdapter(FoodEntryAdapter());
  Hive.registerAdapter(WaterIntakeLogAdapter());
  Hive.registerAdapter(WaterEntryAdapter());
  Hive.registerAdapter(BodyMeasurementAdapter());
  Hive.registerAdapter(FootballTrainingAdapter());
  Hive.registerAdapter(FootballDrillAdapter());
  Hive.registerAdapter(HealthMetricsAdapter());

  // Inisialisasi timezone
  tz.initializeTimeZones();

  // Inisialisasi NotificationService
  await NotificationService.initialize();
  await NotificationService.requestPermissions();

  debugPrint('🚀 App initialized successfully');

  runApp(MyApp());
}

// ============= APP =============
class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => TaskProvider()..init(),
        ),
        ChangeNotifierProvider(
          create: (_) => AiServerController()..init(),
        ),
      ],
      child: MaterialApp(
        title: 'Lisku - Daily Task Manager',
        theme: ThemeData(
          primarySwatch: Colors.blue,
          visualDensity: VisualDensity.adaptivePlatformDensity,
          fontFamily: 'Roboto',
          useMaterial3: true,
        ),
        home: HomeScreen(),
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}