import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '/model/fitness_models.dart';
import 'package:intl/intl.dart';
import 'dart:math' as math;

class WaterTrackingPage extends StatefulWidget {
  const WaterTrackingPage({super.key});

  @override
  State<WaterTrackingPage> createState() => _WaterTrackingPageState();
}

class _WaterTrackingPageState extends State<WaterTrackingPage>
    with SingleTickerProviderStateMixin {
  late Box<WaterIntakeLog> waterLogBox;
  late AnimationController _animationController;
  late Animation<double> _waveAnimation;

  double _dailyTarget = 3.0; // 3 liters default
  double _currentIntake = 0.0;
  final List<double> _quickAddAmounts = [250, 500, 750, 1000]; // in ml

  @override
  void initState() {
    super.initState();
    waterLogBox = Hive.box<WaterIntakeLog>('water_logs');
    _loadTodayData();

    // Setup wave animation
    _animationController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    )..repeat();

    _waveAnimation = Tween<double>(
      begin: 0,
      end: 2 * math.pi,
    ).animate(_animationController);
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _loadTodayData() {
    final today = DateTime.now();
    final todayKey = DateFormat('yyyy-MM-dd').format(today);

    final todayLog = waterLogBox.get(todayKey);
    if (todayLog != null) {
      setState(() {
        _currentIntake = todayLog.totalLiters;
        _dailyTarget = todayLog.targetLiters;
      });
    }
  }

  void _addWater(double amountInMl) {
    final today = DateTime.now();
    final todayKey = DateFormat('yyyy-MM-dd').format(today);

    WaterIntakeLog? todayLog = waterLogBox.get(todayKey);

    if (todayLog == null) {
      // Create new log for today
      todayLog = WaterIntakeLog(
        id: todayKey,
        date: today,
        entries: [],
        totalLiters: 0,
        targetLiters: _dailyTarget,
      );
    }

    // Add new entry
    final newEntry = WaterEntry(
      time: DateTime.now(),
      amount: amountInMl,
      type: 'water',
    );

    todayLog.entries.add(newEntry);
    todayLog.totalLiters += amountInMl / 1000; // Convert to liters

    // Save to Hive
    waterLogBox.put(todayKey, todayLog);

    setState(() {
      _currentIntake = todayLog!.totalLiters;
    });

    // Show achievement if target reached
    if (_currentIntake >= _dailyTarget && _currentIntake - (amountInMl / 1000) < _dailyTarget) {
      _showAchievementDialog();
    }
  }

  void _showAchievementDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.celebration, color: Colors.blue, size: 30),
            SizedBox(width: 10),
            Text('Target Tercapai!'),
          ],
        ),
        content: const Text(
          'Selamat! Kamu sudah mencapai target minum air hari ini. Tetap jaga hidrasi tubuhmu!',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Awesome!'),
          ),
        ],
      ),
    );
  }

  void _showCustomAmountDialog() {
    final controller = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Tambah Air Custom'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Jumlah (ml)',
            border: OutlineInputBorder(),
            suffixText: 'ml',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () {
              final amount = double.tryParse(controller.text);
              if (amount != null && amount > 0) {
                _addWater(amount);
                Navigator.pop(context);
              }
            },
            child: const Text('Tambah'),
          ),
        ],
      ),
    );
  }

  void _showTargetSettingDialog() {
    final controller = TextEditingController(text: _dailyTarget.toString());

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Set Target Harian'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Target (Liter)',
                border: OutlineInputBorder(),
                suffixText: 'L',
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Rekomendasi: 2.5-3.5L per hari',
              style: TextStyle(fontSize: 12, color: Colors.grey),
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
              final target = double.tryParse(controller.text);
              if (target != null && target > 0) {
                setState(() {
                  _dailyTarget = target;
                });

                // Update today's log
                final today = DateTime.now();
                final todayKey = DateFormat('yyyy-MM-dd').format(today);
                final todayLog = waterLogBox.get(todayKey);
                if (todayLog != null) {
                  todayLog.targetLiters = target;
                  waterLogBox.put(todayKey, todayLog);
                }

                Navigator.pop(context);
              }
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final percentage = (_currentIntake / _dailyTarget).clamp(0.0, 1.0);

    return Scaffold(
      backgroundColor: Colors.blue[50],
      appBar: AppBar(
        title: const Text('Water Tracker'),
        backgroundColor: Colors.blue,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: _showTargetSettingDialog,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Water bottle visualization
            _buildWaterBottle(percentage),
            const SizedBox(height: 30),

            // Progress info
            _buildProgressInfo(),
            const SizedBox(height: 30),

            // Quick add buttons
            _buildQuickAddButtons(),
            const SizedBox(height: 20),

            // Custom amount button
            _buildCustomAmountButton(),
            const SizedBox(height: 30),

            // Today's intake list
            _buildTodayIntakeList(),
            const SizedBox(height: 20),

            // Weekly summary
            _buildWeeklySummary(),
          ],
        ),
      ),
    );
  }

  Widget _buildWaterBottle(double percentage) {
    return Container(
      height: 300,
      width: 200,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          // Bottle outline
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: Colors.blue, width: 3),
              borderRadius: BorderRadius.circular(30),
            ),
          ),

          // Water fill with wave animation
          AnimatedBuilder(
            animation: _waveAnimation,
            builder: (context, child) {
              return ClipRRect(
                borderRadius: BorderRadius.circular(27),
                child: CustomPaint(
                  size: Size(194, 294 * percentage),
                  painter: WavePainter(
                    animationValue: _waveAnimation.value,
                    percentage: percentage,
                  ),
                ),
              );
            },
          ),

          // Percentage text
          Center(
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.9),
                shape: BoxShape.circle,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${(percentage * 100).toInt()}%',
                    style: const TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                    ),
                  ),
                  Text(
                    '${_currentIntake.toStringAsFixed(1)}L / ${_dailyTarget}L',
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressInfo() {
    final remaining = (_dailyTarget - _currentIntake).clamp(0.0, _dailyTarget);
    final glasses = (remaining * 1000 / 250).ceil(); // 250ml per glass

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
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildInfoItem(
                icon: Icons.water_drop,
                label: 'Diminum',
                value: '${_currentIntake.toStringAsFixed(1)}L',
                color: Colors.blue,
              ),
              _buildInfoItem(
                icon: Icons.flag,
                label: 'Target',
                value: '${_dailyTarget}L',
                color: Colors.green,
              ),
              _buildInfoItem(
                icon: Icons.local_drink,
                label: 'Sisa',
                value: '$glasses gelas',
                color: Colors.orange,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoItem({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
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
        ),
      ],
    );
  }

  Widget _buildQuickAddButtons() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Quick Add',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 15),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: _quickAddAmounts.map((amount) {
            return _buildQuickAddButton(amount);
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildQuickAddButton(double amountInMl) {
    return InkWell(
      onTap: () => _addWater(amountInMl),
      borderRadius: BorderRadius.circular(15),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
        decoration: BoxDecoration(
          color: Colors.blue.withOpacity(0.1),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: Colors.blue.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Icon(Icons.local_drink, color: Colors.blue[700]),
            const SizedBox(height: 5),
            Text(
              '${amountInMl.toInt()}',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.blue[700],
              ),
            ),
            Text(
              'ml',
              style: TextStyle(
                fontSize: 12,
                color: Colors.blue[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomAmountButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _showCustomAmountDialog,
        icon: const Icon(Icons.add),
        label: const Text('Tambah Jumlah Custom'),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.blue,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 15),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
        ),
      ),
    );
  }

  Widget _buildTodayIntakeList() {
    final today = DateTime.now();
    final todayKey = DateFormat('yyyy-MM-dd').format(today);
    final todayLog = waterLogBox.get(todayKey);

    if (todayLog == null || todayLog.entries.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Center(
          child: Text(
            'Belum ada konsumsi air hari ini',
            style: TextStyle(color: Colors.grey),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Riwayat Hari Ini',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 15),
          ...todayLog.entries.reversed.take(5).map((entry) {
            return ListTile(
              leading: const Icon(Icons.water_drop, color: Colors.blue),
              title: Text('${entry.amount.toInt()} ml'),
              subtitle: Text(DateFormat('HH:mm').format(entry.time)),
              trailing: IconButton(
                icon: const Icon(Icons.delete, color: Colors.red),
                onPressed: () {
                  // Remove entry
                  todayLog.entries.remove(entry);
                  todayLog.totalLiters -= entry.amount / 1000;
                  waterLogBox.put(todayKey, todayLog);
                  _loadTodayData();
                },
              ),
            );
          }),
          if (todayLog.entries.length > 5)
            Center(
              child: TextButton(
                onPressed: () {
                  // Show all entries
                },
                child: Text('Lihat semua (${todayLog.entries.length} entries)'),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildWeeklySummary() {
    final List<double> weeklyData = [];
    final List<String> weekDays = [];

    // Get last 7 days data
    for (int i = 6; i >= 0; i--) {
      final date = DateTime.now().subtract(Duration(days: i));
      final key = DateFormat('yyyy-MM-dd').format(date);
      final log = waterLogBox.get(key);

      weeklyData.add(log?.totalLiters ?? 0);
      weekDays.add(DateFormat('E').format(date));
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Minggu Ini',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 150,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(7, (index) {
                final percentage = weeklyData[index] / _dailyTarget;
                final isToday = index == 6;

                return Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Container(
                      width: 30,
                      height: 100 * percentage.clamp(0.0, 1.0),
                      decoration: BoxDecoration(
                        color: isToday ? Colors.blue : Colors.blue.withOpacity(0.5),
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(5),
                        ),
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      weekDays[index],
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    Text(
                      '${weeklyData[index].toStringAsFixed(1)}L',
                      style: const TextStyle(
                        fontSize: 10,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}

// Custom wave painter
class WavePainter extends CustomPainter {
  final double animationValue;
  final double percentage;

  WavePainter({
    required this.animationValue,
    required this.percentage,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.blue.withOpacity(0.8)
      ..style = PaintingStyle.fill;

    final path = Path();
    final waveHeight = 10.0;
    final waveLength = size.width / 2;

    path.moveTo(0, size.height);

    for (double x = 0; x <= size.width; x++) {
      final y = size.height * (1 - percentage) +
          waveHeight * math.sin((x / waveLength * 2 * math.pi) + animationValue);
      path.lineTo(x, y);
    }

    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}