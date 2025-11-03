// ============= COMPLETE TASK SYSTEM IMPLEMENTATION =============
// Simpan file ini sebagai: lib/task_system_complete.dart
// Ini adalah sistem lengkap untuk manage daily tasks tanpa duplikasi

import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';

// ============= PART 1: MODEL (Sudah ada, tapi saya update) =============
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
  String startPeriod;

  @HiveField(7)
  String endPeriod;

  @HiveField(8)
  DateTime? completedAt;

  @HiveField(9)
  int customOrder;

  @HiveField(10)
  String dayOfWeek;

  @HiveField(11)
  DateTime? lastCompletedDate;

  @HiveField(12)
  List<String> repeatDays;

  @HiveField(13)
  String uniqueId; // TAMBAHAN: untuk prevent duplicate

  @HiveField(14)
  bool isRepeating; // TAMBAHAN: flag repeating task

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

  String get timeRange {
    return '${startHour.toString().padLeft(2, '0')}:${startMinute.toString().padLeft(2, '0')} $startPeriod - ${endHour.toString().padLeft(2, '0')}:${endMinute.toString().padLeft(2, '0')} $endPeriod';
  }

  int get startTimeInMinutes {
    int hour24 = startPeriod == 'AM'
        ? (startHour == 12 ? 0 : startHour)
        : (startHour == 12 ? 12 : startHour + 12);
    return hour24 * 60 + startMinute;
  }

  bool shouldShowForDay(String day) {
    if (isRepeating && repeatDays.isNotEmpty) {
      return repeatDays.contains(day);
    }
    return dayOfWeek == day;
  }
}

// ============= PART 2: PROVIDER =============
class TaskProvider extends ChangeNotifier {
  Box<DailyTaskModel>? _taskBox;
  Map<String, List<DailyTaskModel>> _tasksByDay = {};
  String _selectedDay = 'monday';
  bool _isLoading = false;

  Map<String, List<DailyTaskModel>> get tasksByDay => _tasksByDay;
  String get selectedDay => _selectedDay;
  bool get isLoading => _isLoading;
  List<DailyTaskModel> get currentDayTasks => _tasksByDay[_selectedDay] ?? [];

  Future<void> init() async {
    _taskBox = await Hive.openBox<DailyTaskModel>('dailyTasks');

    // Set current day
    final now = DateTime.now();
    _selectedDay = getDayName(now.weekday);

    // Clean duplicates first
    await cleanupDuplicates();

    // Load tasks
    await loadAllTasks();
  }

  Future<void> cleanupDuplicates() async {
    if (_taskBox == null) return;

    Map<String, DailyTaskModel> uniqueTasks = {};
    List<DailyTaskModel> toDelete = [];

    for (var task in _taskBox!.values) {
      if (!uniqueTasks.containsKey(task.uniqueId)) {
        uniqueTasks[task.uniqueId] = task;
      } else {
        toDelete.add(task);
      }
    }

    // Delete duplicates
    for (var task in toDelete) {
      await task.delete();
    }
  }

  Future<void> loadAllTasks() async {
    _isLoading = true;
    notifyListeners();

    if (_taskBox == null) return;

    try {
      final days = ['monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday'];

      for (String day in days) {
        _tasksByDay[day] = getTasksForDay(day);
      }
    } catch (e) {
      print('Error loading tasks: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  List<DailyTaskModel> getTasksForDay(String day) {
    if (_taskBox == null) return [];

    Map<String, DailyTaskModel> uniqueTasks = {};

    for (var task in _taskBox!.values) {
      if (task.shouldShowForDay(day)) {
        if (!uniqueTasks.containsKey(task.uniqueId)) {
          uniqueTasks[task.uniqueId] = task;
        }
      }
    }

    var tasks = uniqueTasks.values.toList();
    tasks.sort((a, b) => a.startTimeInMinutes.compareTo(b.startTimeInMinutes));
    return tasks;
  }

  void selectDay(String day) {
    _selectedDay = day;
    notifyListeners();
  }

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

    final task = DailyTaskModel(
      title: title,
      startHour: startHour,
      startMinute: startMinute,
      startPeriod: startPeriod,
      endHour: endHour,
      endMinute: endMinute,
      endPeriod: endPeriod,
      dayOfWeek: _selectedDay,
      repeatDays: repeatDays,
      isRepeating: repeatDays.isNotEmpty,
    );

    await _taskBox!.add(task);
    await loadAllTasks();
  }

  Future<void> toggleTask(DailyTaskModel task) async {
    task.isCompleted = !task.isCompleted;
    task.completedAt = task.isCompleted ? DateTime.now() : null;
    task.lastCompletedDate = task.isCompleted ? DateTime.now() : null;
    await task.save();
    notifyListeners();
  }

  Future<void> deleteTask(DailyTaskModel task) async {
    await task.delete();
    await loadAllTasks();
  }

  Future<void> updateTask(DailyTaskModel task) async {
    await task.save();
    await loadAllTasks();
  }

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

// ============= PART 3: UI - MAIN SCREEN =============
class WeeklyScheduleScreen extends StatefulWidget {
  @override
  _WeeklyScheduleScreenState createState() => _WeeklyScheduleScreenState();
}

class _WeeklyScheduleScreenState extends State<WeeklyScheduleScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => context.read<TaskProvider>().init());
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<TaskProvider>(
      builder: (context, provider, child) {
        if (provider.isLoading) {
          return Scaffold(
            appBar: AppBar(title: Text('Jadwal Mingguan')),
            body: Center(child: CircularProgressIndicator()),
          );
        }

        return Scaffold(
          appBar: AppBar(
            title: Text('Jadwal Mingguan'),
            actions: [
              IconButton(
                icon: Icon(Icons.notifications),
                onPressed: () {},
              ),
              IconButton(
                icon: Icon(Icons.timer),
                onPressed: () {},
              ),
            ],
          ),
          body: Column(
            children: [
              // Day Selector
              Container(
                height: 60,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  children: ['monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday']
                      .map((day) => Padding(
                    padding: EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(provider.getDayDisplayName(day)),
                      selected: provider.selectedDay == day,
                      onSelected: (_) => provider.selectDay(day),
                      selectedColor: Theme.of(context).primaryColor,
                      labelStyle: TextStyle(
                        color: provider.selectedDay == day
                            ? Colors.white
                            : Colors.black,
                      ),
                    ),
                  ))
                      .toList(),
                ),
              ),

              // Task List
              Expanded(
                child: provider.currentDayTasks.isEmpty
                    ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.event_available, size: 64, color: Colors.grey),
                      SizedBox(height: 16),
                      Text(
                        'Belum ada tugas',
                        style: TextStyle(fontSize: 18, color: Colors.grey),
                      ),
                    ],
                  ),
                )
                    : ListView.builder(
                  padding: EdgeInsets.all(16),
                  itemCount: provider.currentDayTasks.length,
                  itemBuilder: (context, index) {
                    final task = provider.currentDayTasks[index];
                    return TaskCard(task: task);
                  },
                ),
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton(
            onPressed: () => _showAddTaskDialog(context),
            child: Icon(Icons.add),
            backgroundColor: Theme.of(context).primaryColor,
          ),
        );
      },
    );
  }

  void _showAddTaskDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AddTaskDialog(),
    );
  }
}

// ============= PART 4: TASK CARD WIDGET =============
class TaskCard extends StatelessWidget {
  final DailyTaskModel task;

  const TaskCard({Key? key, required this.task}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final provider = context.read<TaskProvider>();

    return Card(
      margin: EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: Checkbox(
          value: task.isCompleted,
          onChanged: (_) => provider.toggleTask(task),
          activeColor: Colors.green,
          shape: CircleBorder(),
        ),
        title: Text(
          task.title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            decoration: task.isCompleted ? TextDecoration.lineThrough : null,
            color: task.isCompleted ? Colors.grey : null,
          ),
        ),
        subtitle: Row(
          children: [
            Icon(Icons.access_time, size: 14, color: Colors.grey),
            SizedBox(width: 4),
            Text(task.timeRange, style: TextStyle(fontSize: 12)),
            if (task.isRepeating) ...[
              SizedBox(width: 8),
              Icon(Icons.repeat, size: 14, color: Colors.blue),
            ],
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: Icon(Icons.edit, size: 20, color: Colors.blue),
              onPressed: () => _showEditDialog(context, task),
            ),
            IconButton(
              icon: Icon(Icons.delete, size: 20, color: Colors.red),
              onPressed: () => _confirmDelete(context, task),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditDialog(BuildContext context, DailyTaskModel task) {
    showDialog(
      context: context,
      builder: (context) => AddTaskDialog(existingTask: task),
    );
  }

  void _confirmDelete(BuildContext context, DailyTaskModel task) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Hapus Tugas'),
        content: Text('Yakin ingin menghapus "${task.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () {
              context.read<TaskProvider>().deleteTask(task);
              Navigator.pop(context);
            },
            child: Text('Hapus'),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
          ),
        ],
      ),
    );
  }
}

// ============= PART 5: ADD/EDIT TASK DIALOG =============
class AddTaskDialog extends StatefulWidget {
  final DailyTaskModel? existingTask;

  const AddTaskDialog({Key? key, this.existingTask}) : super(key: key);

  @override
  State<AddTaskDialog> createState() => _AddTaskDialogState();
}

class _AddTaskDialogState extends State<AddTaskDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();

  int _startHour = 9;
  int _startMinute = 0;
  String _startPeriod = 'AM';

  int _endHour = 10;
  int _endMinute = 0;
  String _endPeriod = 'AM';

  bool _isRepeating = false;
  List<String> _selectedDays = [];

  final List<String> _allDays = [
    'monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday'
  ];

  @override
  void initState() {
    super.initState();
    final provider = context.read<TaskProvider>();

    if (widget.existingTask != null) {
      _titleController.text = widget.existingTask!.title;
      _startHour = widget.existingTask!.startHour;
      _startMinute = widget.existingTask!.startMinute;
      _startPeriod = widget.existingTask!.startPeriod;
      _endHour = widget.existingTask!.endHour;
      _endMinute = widget.existingTask!.endMinute;
      _endPeriod = widget.existingTask!.endPeriod;
      _isRepeating = widget.existingTask!.isRepeating;
      _selectedDays = List.from(widget.existingTask!.repeatDays);
    } else {
      _selectedDays = [provider.selectedDay];
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.read<TaskProvider>();

    return AlertDialog(
      title: Text(widget.existingTask != null ? 'Edit Tugas' : 'Tambah Tugas'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title Field
              TextFormField(
                controller: _titleController,
                decoration: InputDecoration(
                  labelText: 'Nama Tugas',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.task),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Masukkan nama tugas';
                  }
                  return null;
                },
              ),
              SizedBox(height: 16),

              // Time Selection
              Text('Waktu', style: TextStyle(fontWeight: FontWeight.bold)),
              SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Mulai', style: TextStyle(fontSize: 12)),
                        Row(
                          children: [
                            DropdownButton<int>(
                              value: _startHour,
                              isDense: true,
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
                              isDense: true,
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
                              isDense: true,
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
                  SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Selesai', style: TextStyle(fontSize: 12)),
                        Row(
                          children: [
                            DropdownButton<int>(
                              value: _endHour,
                              isDense: true,
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
                              isDense: true,
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
                              isDense: true,
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
                ],
              ),
              SizedBox(height: 16),

              // Repeat Option
              SwitchListTile(
                title: Text('Tugas Berulang'),
                value: _isRepeating,
                contentPadding: EdgeInsets.zero,
                onChanged: (val) {
                  setState(() {
                    _isRepeating = val;
                    if (!val) {
                      _selectedDays = [provider.selectedDay];
                    }
                  });
                },
              ),

              if (_isRepeating) ...[
                Text('Pilih Hari:', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _allDays.map((day) {
                    final displayName = provider.getDayDisplayName(day);
                    return FilterChip(
                      label: Text(displayName),
                      selected: _selectedDays.contains(day),
                      selectedColor: Theme.of(context).primaryColor.withOpacity(0.2),
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
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Batal'),
        ),
        ElevatedButton(
          onPressed: _saveTask,
          child: Text('Simpan'),
        ),
      ],
    );
  }

  void _saveTask() {
    if (_formKey.currentState!.validate()) {
      final provider = context.read<TaskProvider>();

      if (widget.existingTask != null) {
        // Update existing task
        widget.existingTask!.title = _titleController.text;
        widget.existingTask!.startHour = _startHour;
        widget.existingTask!.startMinute = _startMinute;
        widget.existingTask!.startPeriod = _startPeriod;
        widget.existingTask!.endHour = _endHour;
        widget.existingTask!.endMinute = _endMinute;
        widget.existingTask!.endPeriod = _endPeriod;
        widget.existingTask!.repeatDays = _isRepeating ? _selectedDays : [];
        widget.existingTask!.isRepeating = _isRepeating;

        provider.updateTask(widget.existingTask!);
      } else {
        // Add new task
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
      }

      Navigator.pop(context);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }
}

// ============= PART 6: MAIN APP SETUP =============
class TaskApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => TaskProvider()),
      ],
      child: MaterialApp(
        title: 'Task Manager',
        theme: ThemeData(
          primarySwatch: Colors.blue,
          visualDensity: VisualDensity.adaptivePlatformDensity,
        ),
        home: WeeklyScheduleScreen(),
      ),
    );
  }
}

// ============= PART 7: MAIN FUNCTION =============
// Update your main.dart file:
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Hive
  await Hive.initFlutter();

  // Register adapters
  Hive.registerAdapter(DailyTaskModelAdapter());

  // Run app
  runApp(TaskApp());
}