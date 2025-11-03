import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';
import 'package:lisku/services/theme_service.dart';
import 'package:lisku/model/task_daily_model.dart';
import 'package:lisku/model/transaction_model.dart';
import 'package:lisku/model/goal_task.dart';
import 'package:lisku/model/task_model.dart';
import 'package:lisku/model/note_model.dart';
import 'package:lisku/pages/analytics_page.dart';
import 'package:lisku/pages/theme_settings_page.dart';
import 'package:lisku/pages/backup_restore_page.dart';
import 'package:lisku/pages/money_management_page.dart';
import 'package:lisku/pages/daily_task_page.dart';
import 'package:lisku/pages/goal_page.dart';
import 'package:lisku/pages/task_page.dart';
import 'package:lisku/pages/notes_page.dart';
import 'package:intl/intl.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:lisku/pages/fitness_dashboard_page.dart';
import 'package:lisku/pages/water_tracking_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;
  final List<Widget> _pages = [];

  @override
  void initState() {
    super.initState();
    _pages.addAll([
      const HomeContent(),       // Dashboard
      const MoneyManagementPage(), // Money Management
      const ProfilePage(),        // Profile/Settings
    ]);
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_selectedIndex],
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: BottomNavigationBar(
          type: BottomNavigationBarType.fixed,
          currentIndex: _selectedIndex,
          onTap: _onItemTapped,
          backgroundColor: Colors.white,
          selectedItemColor: Colors.blue,
          unselectedItemColor: Colors.grey,
          elevation: 0,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.dashboard),
              label: 'Dashboard',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.account_balance_wallet),
              label: 'Keuangan',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person),
              label: 'Profil',
            ),
          ],
        ),
      ),
    );
  }
}

// Home Dashboard Content - CLEAN VERSION
class HomeContent extends StatefulWidget {
  const HomeContent({super.key});

  @override
  State<HomeContent> createState() => _HomeContentState();
}

class _HomeContentState extends State<HomeContent> {
  // User profile data
  String _userName = 'Pengguna';
  String? _profileImagePath;

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  Future<void> _loadUserProfile() async {
    try {
      final profileBox = await Hive.openBox('profile');
      setState(() {
        _userName = profileBox.get('user_name', defaultValue: 'Pengguna');
        _profileImagePath = profileBox.get('profile_image');
      });
    } catch (e) {
      print('Error loading profile: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeService = Provider.of<ThemeService>(context);

    return FutureBuilder(
      future: Future.wait([
        Hive.openBox<DailyTaskModel>('dailyTasks'),
        Hive.openBox<TransactionModel>('transactions'),
        Hive.openBox<GoalTask>('goal_tasks'),
        Hive.openBox<TaskModel>('taskBox'),
        Hive.openBox<NoteModel>('notes'),
      ]),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return Scaffold(
            body: Container(
              decoration: themeService.getBackgroundDecoration(),
              child: const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
            ),
          );
        }

        return Scaffold(
          body: Container(
            decoration: themeService.getBackgroundDecoration(),
            child: SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 10),
                    _buildSimpleHeader(),
                    const SizedBox(height: 30),
                    _buildBalanceWidget(),
                    const SizedBox(height: 20),
                    _buildTodaySchedulePreview(context),
                    const SizedBox(height: 20),
                    _buildQuickStats(),
                    const SizedBox(height: 20),
                    _buildMotivationalCard(),
                    const SizedBox(height: 20),
                    _buildQuickMenus(context),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSimpleHeader() {
    final hour = DateTime.now().hour;
    String greeting;
    IconData greetingIcon;

    if (hour < 12) {
      greeting = 'Selamat Pagi';
      greetingIcon = Icons.wb_sunny;
    } else if (hour < 17) {
      greeting = 'Selamat Siang';
      greetingIcon = Icons.wb_sunny_outlined;
    } else {
      greeting = 'Selamat Malam';
      greetingIcon = Icons.nights_stay;
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 25,
            backgroundColor: Colors.white.withOpacity(0.3),
            backgroundImage: _profileImagePath != null
                ? FileImage(File(_profileImagePath!))
                : null,
            child: _profileImagePath == null
                ? const Icon(Icons.person, color: Colors.white, size: 30)
                : null,
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(greetingIcon, color: Colors.white, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      greeting,
                      style: const TextStyle(
                        fontSize: 16,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  _userName,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBalanceWidget() {
    return ValueListenableBuilder(
      valueListenable: Hive.box<TransactionModel>('transactions').listenable(),
      builder: (context, Box<TransactionModel> box, _) {
        double totalIncome = 0;
        double totalExpense = 0;

        for (var transaction in box.values) {
          if (transaction.isExpense) {
            totalExpense += transaction.amount;
          } else {
            totalIncome += transaction.amount;
          }
        }

        double balance = totalIncome - totalExpense;
        final formatter = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp', decimalDigits: 0);

        return InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const MoneyManagementPage()),
            );
          },
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.green[50],
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.account_balance_wallet, color: Colors.green[700], size: 24),
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          'Saldo Sekarang',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                      ],
                    ),
                    Icon(Icons.arrow_forward_ios, color: Colors.grey[400], size: 16),
                  ],
                ),
                const SizedBox(height: 15),
                Text(
                  formatter.format(balance),
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: balance >= 0 ? Colors.green[700] : Colors.red[700],
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _buildMiniStat('Income', formatter.format(totalIncome), Colors.green),
                    const SizedBox(width: 20),
                    _buildMiniStat('Expense', formatter.format(totalExpense), Colors.red),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMiniStat(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildTodaySchedulePreview(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: Hive.box<DailyTaskModel>('dailyTasks').listenable(),
      builder: (context, Box<DailyTaskModel> box, _) {
        final todayName = DailyTaskModel.getDayName(DateTime.now().weekday);
        final todayTasks = box.values.where((task) =>
        task.dayOfWeek == todayName || task.repeatDays.contains(todayName)
        ).toList();

        todayTasks.sort((a, b) => a.startTimeInMinutes.compareTo(b.startTimeInMinutes));
        final upcomingTasks = todayTasks.take(3).toList();

        return InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const DailyTaskPage()),
            );
          },
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.blue[50],
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.schedule, color: Colors.blue[700], size: 24),
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          'Jadwal Hari Ini',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                      ],
                    ),
                    Icon(Icons.arrow_forward_ios, color: Colors.grey[400], size: 16),
                  ],
                ),
                const SizedBox(height: 15),
                if (upcomingTasks.isEmpty)
                  Center(
                    child: Text(
                      'Tidak ada jadwal hari ini',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  )
                else
                  ...upcomingTasks.map((task) => _buildMiniTaskItem(task)),
                if (todayTasks.length > 3)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      '+ ${todayTasks.length - 3} tugas lainnya',
                      style: TextStyle(
                        color: Colors.blue[600],
                        fontSize: 12,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMiniTaskItem(DailyTaskModel task) {
    final isCompleted = task.isCompletedToday();
    final isActive = task.isCurrentlyActive;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isActive ? Colors.blue[50] : Colors.grey[50],
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isActive ? Colors.blue[200]! : Colors.transparent,
        ),
      ),
      child: Row(
        children: [
          Icon(
            isCompleted ? Icons.check_circle : Icons.circle_outlined,
            color: isCompleted ? Colors.green : Colors.grey[400],
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              task.title,
              style: TextStyle(
                decoration: isCompleted ? TextDecoration.lineThrough : null,
                color: isCompleted ? Colors.grey : Colors.black87,
              ),
            ),
          ),
          Text(
            task.timeRange,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStats() {
    return FutureBuilder(
      future: Future.wait([
        Hive.openBox<DailyTaskModel>('dailyTasks'),
        Hive.openBox<GoalTask>('goal_tasks'),
        Hive.openBox<TaskModel>('taskBox'),
        Hive.openBox<NoteModel>('notes'),
      ]),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink();

        final dailyBox = Hive.box<DailyTaskModel>('dailyTasks');
        final goalBox = Hive.box<GoalTask>('goal_tasks');
        final taskBox = Hive.box<TaskModel>('taskBox');
        final noteBox = Hive.box<NoteModel>('notes');

        // Calculate progress
        final totalTasks = dailyBox.length + goalBox.length + taskBox.length;
        final completedTasks =
            dailyBox.values.where((e) => e.isCompleted).length +
                goalBox.values.where((e) => e.progress >= 1.0).length +
                taskBox.values.where((e) => e.isDone).length;

        final progress = totalTasks > 0 ? completedTasks / totalTasks : 0.0;

        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Progress Hari Ini',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  Text(
                    '${(progress * 100).toInt()}%',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              LinearProgressIndicator(
                value: progress,
                backgroundColor: Colors.grey[300],
                valueColor: AlwaysStoppedAnimation<Color>(
                  progress < 0.5 ? Colors.red : progress < 0.8 ? Colors.orange : Colors.green,
                ),
                minHeight: 6,
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildStatItem(Icons.task_alt, taskBox.values.where((e) => e.isDone).length,
                      taskBox.length, Colors.orange),
                  _buildStatItem(Icons.flag, goalBox.values.where((e) => e.progress >= 1.0).length,
                      goalBox.length, Colors.purple),
                  _buildStatItem(Icons.note, noteBox.length, null, Colors.green),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatItem(IconData icon, int completed, int? total, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 4),
        Text(
          total != null ? '$completed/$total' : completed.toString(),
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildMotivationalCard() {
    return FutureBuilder<List<String>>(
      future: _getMotivationalQuotes(),
      builder: (context, snapshot) {
        final quotes = snapshot.data ?? _getDefaultQuotes();
        final randomQuote = quotes[DateTime.now().day % quotes.length];

        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.pink.withOpacity(0.8), Colors.purple.withOpacity(0.8)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.pink.withOpacity(0.3),
                blurRadius: 10,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Row(
            children: [
              const Icon(Icons.auto_awesome, color: Colors.white, size: 30),
              const SizedBox(width: 15),
              Expanded(
                child: Text(
                  randomQuote,
                  style: const TextStyle(
                    fontSize: 16,
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<List<String>> _getMotivationalQuotes() async {
    try {
      final quotesBox = await Hive.openBox('motivational_quotes');
      final customQuotes = quotesBox.get('quotes', defaultValue: <String>[]);
      return customQuotes.isEmpty ? _getDefaultQuotes() : List<String>.from(customQuotes);
    } catch (e) {
      return _getDefaultQuotes();
    }
  }

  List<String> _getDefaultQuotes() {
    return [
      "Hari ini adalah kesempatan baru untuk mencapai yang terbaik!",
      "Setiap tugas yang diselesaikan adalah langkah menuju kesuksesan!",
      "Konsistensi adalah kunci untuk mencapai tujuan!",
      "Jangan tunda sampai besok apa yang bisa kamu lakukan hari ini!",
      "Kamu lebih kuat dari alasan-alasan untuk menyerah!",
    ];
  }

  Widget _buildQuickMenus(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Menu Cepat',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 15),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 3,
          mainAxisSpacing: 15,
          crossAxisSpacing: 15,
          childAspectRatio: 1,
          children: [
            _buildMenuItem(
              icon: Icons.calendar_today,
              label: 'Jadwal',
              color: Colors.blue,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const DailyTaskPage()),
              ),
            ),
            _buildMenuItem(
              icon: Icons.task,
              label: 'Tugas',
              color: Colors.orange,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const TaskPage()),
              ),
            ),
            _buildMenuItem(
              icon: Icons.flag,
              label: 'Target',
              color: Colors.purple,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const GoalPage()),
              ),
            ),
            _buildMenuItem(
              icon: Icons.note,
              label: 'Catatan',
              color: Colors.green,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const NotesPage()),
              ),
            ),
            _buildMenuItem(
              icon: Icons.analytics,
              label: 'Analitik',
              color: Colors.pink,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const AnalyticsPage()),
              ),
            ),
            _buildMenuItem(
              icon: Icons.account_balance_wallet,
              label: 'Keuangan',
              color: Colors.teal,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const MoneyManagementPage()),
              ),
            ),
            _buildMenuItem(
              icon: Icons.fitness_center,
              label: 'Fitness',
              color: Colors.red,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const FitnessDashboardPage()),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(15),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.grey[800],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Profile Page - SEMUA PENGATURAN DI SINI
class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  String? _profileImagePath;
  late Box _profileBox;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      _profileBox = await Hive.openBox('profile');
      setState(() {
        _nameController.text = _profileBox.get('user_name', defaultValue: 'Pengguna');
        _emailController.text = _profileBox.get('user_email', defaultValue: 'user@example.com');
        _profileImagePath = _profileBox.get('profile_image');
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading profile: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _pickImage() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
      );

      if (result != null && result.files.single.path != null) {
        final appDir = await getApplicationDocumentsDirectory();
        final fileName = 'profile_${DateTime.now().millisecondsSinceEpoch}.jpg';
        final newPath = '${appDir.path}/$fileName';

        final File originalFile = File(result.files.single.path!);
        final File newFile = await originalFile.copy(newPath);

        setState(() {
          _profileImagePath = newFile.path;
        });

        await _profileBox.put('profile_image', _profileImagePath);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Foto profil berhasil diupdate!')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error memilih foto: $e')),
      );
    }
  }

  Future<void> _saveProfile() async {
    await _profileBox.put('user_name', _nameController.text);
    await _profileBox.put('user_email', _emailController.text);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Profil berhasil disimpan!')),
    );
  }

  void _showEditProfileDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Profil'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Nama',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 15),
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(
                labelText: 'Email',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () {
              _saveProfile();
              Navigator.pop(context);
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeService = Provider.of<ThemeService>(context);

    if (_isLoading) {
      return Scaffold(
        body: Container(
          decoration: themeService.getBackgroundDecoration(),
          child: const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      body: Container(
        decoration: themeService.getBackgroundDecoration(),
        child: SafeArea(
          child: SingleChildScrollView(
            child: Column(
              children: [
                // Profile Header
                Container(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      const Text(
                        'Profil & Pengaturan',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 30),

                      // Profile Picture
                      Stack(
                        children: [
                          CircleAvatar(
                            radius: 60,
                            backgroundColor: Colors.white.withOpacity(0.3),
                            backgroundImage: _profileImagePath != null
                                ? FileImage(File(_profileImagePath!))
                                : null,
                            child: _profileImagePath == null
                                ? const Icon(Icons.person, size: 60, color: Colors.white)
                                : null,
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: const BoxDecoration(
                                color: Colors.blue,
                                shape: BoxShape.circle,
                              ),
                              child: InkWell(
                                onTap: _pickImage,
                                child: const Icon(Icons.camera_alt, color: Colors.white, size: 20),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // User Info
                      Text(
                        _nameController.text,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        _emailController.text,
                        style: const TextStyle(
                          fontSize: 16,
                          color: Colors.white70,
                        ),
                      ),
                      const SizedBox(height: 15),

                      // Edit Profile Button
                      ElevatedButton.icon(
                        onPressed: _showEditProfileDialog,
                        icon: const Icon(Icons.edit),
                        label: const Text('Edit Profil'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white.withOpacity(0.2),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        ),
                      ),
                    ],
                  ),
                ),

                // Settings Menu
                Container(
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(30),
                      topRight: Radius.circular(30),
                    ),
                  ),
                  child: Column(
                    children: [
                      const SizedBox(height: 30),

                      // Quick Stats
                      _buildQuickStatsSection(),

                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        child: Divider(),
                      ),

                      // Settings Menu Items
                      _buildSettingsSection(context),

                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        child: Divider(),
                      ),

                      // App Settings
                      _buildAppSettingsSection(context),

                      const SizedBox(height: 30),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildQuickStatsSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Statistik Singkat',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 15),
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'Hari Bergabung',
                  '${DateTime.now().difference(DateTime(2024, 1, 1)).inDays}',
                  Icons.calendar_today,
                  Colors.blue,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildStatCard(
                  'Total Tugas',
                  _getTotalTasks().toString(),
                  Icons.task,
                  Colors.orange,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildStatCard(
                  'Produktivitas',
                  '${_getProductivityScore()}%',
                  Icons.trending_up,
                  Colors.green,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.grey,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsSection(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Pengaturan Fitur',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 15),
          _buildSettingTile(
            icon: Icons.format_quote,
            title: 'Kelola Quotes Motivasi',
            subtitle: 'Atur quotes yang muncul di dashboard',
            color: Colors.purple,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const QuotesManagerPage()),
            ),
          ),
          _buildSettingTile(
            icon: Icons.analytics,
            title: 'Analitik Produktivitas',
            subtitle: 'Lihat progress dan statistik kamu',
            color: Colors.pink,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const AnalyticsPage()),
            ),
          ),
          _buildSettingTile(
            icon: Icons.backup,
            title: 'Backup & Restore',
            subtitle: 'Simpan dan pulihkan data kamu',
            color: Colors.green,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const BackupRestorePage()),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppSettingsSection(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Pengaturan Aplikasi',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 15),
          _buildSettingTile(
            icon: Icons.palette,
            title: 'Tema Aplikasi',
            subtitle: 'Ubah tampilan aplikasi',
            color: Colors.blue,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const ThemeSettingsPage()),
            ),
          ),
          _buildSettingTile(
            icon: Icons.notifications,
            title: 'Notifikasi',
            subtitle: 'Atur pengingat dan notifikasi',
            color: Colors.orange,
            onTap: () => _showNotificationSettings(),
          ),
          _buildSettingTile(
            icon: Icons.info,
            title: 'Tentang Aplikasi',
            subtitle: 'Versi dan informasi aplikasi',
            color: Colors.grey,
            onTap: () => _showAboutDialog(),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return ListTile(
      onTap: onTap,
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: color),
      ),
      title: Text(
        title,
        style: const TextStyle(
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          color: Colors.grey[600],
          fontSize: 12,
        ),
      ),
      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
    );
  }

  int _getTotalTasks() {
    try {
      final dailyTasks = Hive.box<DailyTaskModel>('dailyTasks').length;
      final regularTasks = Hive.box<TaskModel>('taskBox').length;
      final goals = Hive.box<GoalTask>('goal_tasks').length;
      return dailyTasks + regularTasks + goals;
    } catch (e) {
      return 0;
    }
  }

  int _getProductivityScore() {
    try {
      final dailyBox = Hive.box<DailyTaskModel>('dailyTasks');
      final taskBox = Hive.box<TaskModel>('taskBox');
      final goalBox = Hive.box<GoalTask>('goal_tasks');

      final totalTasks = dailyBox.length + taskBox.length + goalBox.length;
      if (totalTasks == 0) return 0;

      final completed =
          dailyBox.values.where((t) => t.isCompleted).length +
              taskBox.values.where((t) => t.isDone).length +
              goalBox.values.where((g) => g.progress >= 1.0).length;

      return ((completed / totalTasks) * 100).round();
    } catch (e) {
      return 0;
    }
  }

  void _showNotificationSettings() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Pengaturan Notifikasi'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.notifications_active),
              title: Text('Notifikasi Aktif'),
              subtitle: Text('Pengingat untuk tugas harian'),
              trailing: Switch(
                value: true,
                onChanged: null,
              ),
            ),
            ListTile(
              leading: Icon(Icons.schedule),
              title: Text('Reminder Pagi'),
              subtitle: Text('07:00 AM'),
            ),
            ListTile(
              leading: Icon(Icons.nightlight),
              title: Text('Reminder Malam'),
              subtitle: Text('08:00 PM'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Tutup'),
          ),
        ],
      ),
    );
  }

  void _showAboutDialog() {
    showAboutDialog(
      context: context,
      applicationName: 'Lisku',
      applicationVersion: '1.0.0',
      applicationIcon: Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          color: Colors.blue.withOpacity(0.1),
          borderRadius: BorderRadius.circular(15),
        ),
        child: const Icon(Icons.task_alt, color: Colors.blue, size: 40),
      ),
      applicationLegalese: '© 2024 Lisku App\nDeveloped with ❤️ in Flutter',
      children: [
        const SizedBox(height: 20),
        const Text(
          'Lisku adalah aplikasi produktivitas personal yang membantu kamu mengelola tugas harian, target, catatan, dan keuangan dalam satu tempat.',
          textAlign: TextAlign.justify,
        ),
      ],
    );
  }
}

// Quotes Manager Page (dipindah dari file terpisah)
class QuotesManagerPage extends StatefulWidget {
  const QuotesManagerPage({super.key});

  @override
  State<QuotesManagerPage> createState() => _QuotesManagerPageState();
}

class _QuotesManagerPageState extends State<QuotesManagerPage> {
  late Box _quotesBox;
  List<String> _quotes = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadQuotes();
  }

  Future<void> _loadQuotes() async {
    try {
      _quotesBox = await Hive.openBox('motivational_quotes');
      final savedQuotes = _quotesBox.get('quotes', defaultValue: <String>[]);

      setState(() {
        if (savedQuotes.isEmpty) {
          _quotes = _getDefaultQuotes();
        } else {
          _quotes = List<String>.from(savedQuotes);
        }
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _quotes = _getDefaultQuotes();
        _isLoading = false;
      });
    }
  }

  List<String> _getDefaultQuotes() {
    return [
      "Hari ini adalah kesempatan baru untuk mencapai yang terbaik!",
      "Setiap tugas yang diselesaikan adalah langkah menuju kesuksesan!",
      "Konsistensi adalah kunci untuk mencapai tujuan!",
      "Jangan tunda sampai besok apa yang bisa kamu lakukan hari ini!",
      "Kamu lebih kuat dari alasan-alasan untuk menyerah!",
    ];
  }

  Future<void> _saveQuotes() async {
    try {
      await _quotesBox.put('quotes', _quotes);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Quotes berhasil disimpan!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error menyimpan quotes: $e')),
      );
    }
  }

  void _addQuote() {
    final controller = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Tambah Quote Motivasi'),
        content: TextField(
          controller: controller,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: 'Masukkan quote motivasi...',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () {
              if (controller.text.isNotEmpty) {
                setState(() {
                  _quotes.add(controller.text);
                });
                _saveQuotes();
                Navigator.pop(context);
              }
            },
            child: const Text('Tambah'),
          ),
        ],
      ),
    );
  }

  void _editQuote(int index) {
    final controller = TextEditingController(text: _quotes[index]);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Quote Motivasi'),
        content: TextField(
          controller: controller,
          maxLines: 3,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () {
              if (controller.text.isNotEmpty) {
                setState(() {
                  _quotes[index] = controller.text;
                });
                _saveQuotes();
                Navigator.pop(context);
              }
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }

  void _deleteQuote(int index) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus Quote'),
        content: Text('Yakin ingin menghapus quote:\n\n"${_quotes[index]}"'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _quotes.removeAt(index);
              });
              _saveQuotes();
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Hapus', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Kelola Quotes')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Kelola Quotes Motivasi'),
      ),
      body: _quotes.isEmpty
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.format_quote, size: 80, color: Colors.grey[300]),
            const SizedBox(height: 20),
            Text(
              'Belum ada quotes',
              style: TextStyle(fontSize: 18, color: Colors.grey[600]),
            ),
          ],
        ),
      )
          : ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _quotes.length,
        itemBuilder: (context, index) {
          return Card(
            margin: const EdgeInsets.only(bottom: 10),
            child: ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.purple[50],
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.format_quote, color: Colors.purple[700]),
              ),
              title: Text(_quotes[index]),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit, color: Colors.blue),
                    onPressed: () => _editQuote(index),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () => _deleteQuote(index),
                  ),
                ],
              ),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addQuote,
        child: const Icon(Icons.add),
      ),
    );
  }
}