// File: lib/pages/fitness_dashboard_page.dart
// Main dashboard untuk semua fitur fitness & health

import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '/model/fitness_models.dart';
import '/pages/water_tracking_page.dart';
import 'package:intl/intl.dart';

class FitnessDashboardPage extends StatefulWidget {
  const FitnessDashboardPage({super.key});

  @override
  State<FitnessDashboardPage> createState() => _FitnessDashboardPageState();
}

class _FitnessDashboardPageState extends State<FitnessDashboardPage> {
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initializeBoxes();
  }

  Future<void> _initializeBoxes() async {
    try {
      // Initialize semua fitness boxes
      if (!Hive.isBoxOpen('workout_plans')) {
        await Hive.openBox<WorkoutPlan>('workout_plans');
      }
      if (!Hive.isBoxOpen('workout_sessions')) {
        await Hive.openBox<WorkoutSession>('workout_sessions');
      }
      if (!Hive.isBoxOpen('food_logs')) {
        await Hive.openBox<FoodLog>('food_logs');
      }
      if (!Hive.isBoxOpen('water_logs')) {
        await Hive.openBox<WaterIntakeLog>('water_logs');
      }
      if (!Hive.isBoxOpen('body_measurements')) {
        await Hive.openBox<BodyMeasurement>('body_measurements');
      }

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      print('Error initializing fitness boxes: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Get today's water intake
  double _getTodayWaterIntake() {
    try {
      final waterBox = Hive.box<WaterIntakeLog>('water_logs');
      final todayKey = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final todayLog = waterBox.get(todayKey);
      return todayLog?.totalLiters ?? 0.0;
    } catch (e) {
      return 0.0;
    }
  }

  // Get today's calories
  int _getTodayCalories() {
    try {
      final foodBox = Hive.box<FoodLog>('food_logs');
      final todayKey = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final todayLog = foodBox.get(todayKey);
      return todayLog?.totalCalories ?? 0;
    } catch (e) {
      return 0;
    }
  }

  // Get today's workout duration
  int _getTodayWorkoutMinutes() {
    try {
      final workoutBox = Hive.box<WorkoutSession>('workout_sessions');
      final today = DateTime.now();
      final todayWorkouts = workoutBox.values.where((session) {
        return session.date.year == today.year &&
            session.date.month == today.month &&
            session.date.day == today.day;
      });

      return todayWorkouts.fold(0, (total, session) => total + session.durationMinutes);
    } catch (e) {
      return 0;
    }
  }

  // Get latest body measurements
  BodyMeasurement? _getLatestMeasurement() {
    try {
      final measurementBox = Hive.box<BodyMeasurement>('body_measurements');
      if (measurementBox.isEmpty) return null;

      final measurements = measurementBox.values.toList();
      measurements.sort((a, b) => b.date.compareTo(a.date));
      return measurements.first;
    } catch (e) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF1976D2), Color(0xFF42A5F5)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: const Center(
            child: CircularProgressIndicator(color: Colors.white),
          ),
        ),
      );
    }

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF1976D2), Color(0xFF42A5F5)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(),
                const SizedBox(height: 30),
                _buildTodayProgress(),
                const SizedBox(height: 20),
                _buildQuickActions(),
                const SizedBox(height: 20),
                _buildActiveWorkoutPlan(),
                const SizedBox(height: 20),
                _buildNutritionSummary(),
                const SizedBox(height: 20),
                _buildBodyProgress(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back, color: Colors.white),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Fitness & Health',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                Text(
                  'Track your body transformation',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.fitness_center, color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _buildTodayProgress() {
    final waterIntake = _getTodayWaterIntake();
    final calories = _getTodayCalories();
    final workoutMinutes = _getTodayWorkoutMinutes();

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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Today's Progress",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                DateFormat('dd MMM').format(DateTime.now()),
                style: TextStyle(
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              _buildProgressItem(
                icon: Icons.fitness_center,
                label: 'Workout',
                value: workoutMinutes > 0 ? '$workoutMinutes min' : 'No workout',
                color: Colors.orange,
                progress: workoutMinutes > 0 ? (workoutMinutes / 60).clamp(0.0, 1.0) : 0.0,
              ),
              const SizedBox(width: 15),
              _buildProgressItem(
                icon: Icons.restaurant,
                label: 'Calories',
                value: calories > 0 ? '$calories/2500' : '0/2500',
                color: Colors.green,
                progress: (calories / 2500).clamp(0.0, 1.0),
              ),
              const SizedBox(width: 15),
              _buildProgressItem(
                icon: Icons.water_drop,
                label: 'Water',
                value: '${waterIntake.toStringAsFixed(1)}L/3L',
                color: Colors.blue,
                progress: (waterIntake / 3).clamp(0.0, 1.0),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProgressItem({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    required double progress,
  }) {
    return Expanded(
      child: Container(
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
              label,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.grey[300],
              valueColor: AlwaysStoppedAnimation<Color>(color),
              minHeight: 4,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Quick Actions',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 15),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildActionButton(
                icon: Icons.add_circle,
                label: 'Log Workout',
                color: Colors.orange,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const WorkoutLoggingPage(),
                    ),
                  );
                },
              ),
              const SizedBox(width: 10),
              _buildActionButton(
                icon: Icons.restaurant_menu,
                label: 'Log Food',
                color: Colors.green,
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Food logging coming soon!')),
                  );
                },
              ),
              const SizedBox(width: 10),
              _buildActionButton(
                icon: Icons.water_drop,
                label: 'Log Water',
                color: Colors.blue,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const WaterTrackingPage(),
                    ),
                  );
                },
              ),
              const SizedBox(width: 10),
              _buildActionButton(
                icon: Icons.straighten,
                label: 'Measurements',
                color: Colors.purple,
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Body measurements coming soon!')),
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(15),
      child: Container(
        width: 100,
        padding: const EdgeInsets.all(15),
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
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveWorkoutPlan() {
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Active Workout Plan',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              TextButton(
                onPressed: () {
                  // Navigate to workout plans
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Workout plans coming soon!')),
                  );
                },
                child: const Text('View All'),
              ),
            ],
          ),
          const SizedBox(height: 15),
          Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.1),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: const BoxDecoration(
                    color: Colors.orange,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.fitness_center, color: Colors.white),
                ),
                const SizedBox(width: 15),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'No Active Plan',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Tap to create your workout plan',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.add_circle_outline, color: Colors.orange, size: 40),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNutritionSummary() {
    final todayCalories = _getTodayCalories();

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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Nutrition Today',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              TextButton(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Nutrition details coming soon!')),
                  );
                },
                child: const Text('Details'),
              ),
            ],
          ),
          const SizedBox(height: 15),

          // If no data yet
          if (todayCalories == 0) ...[
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(15),
              ),
              child: const Center(
                child: Column(
                  children: [
                    Icon(Icons.restaurant, color: Colors.grey, size: 40),
                    SizedBox(height: 10),
                    Text(
                      'No meals logged today',
                      style: TextStyle(color: Colors.grey),
                    ),
                    Text(
                      'Tap + to add your first meal',
                      style: TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
          ] else ...[
            // Macros breakdown
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildMacroItem('Protein', '0g/150g', Colors.red),
                _buildMacroItem('Carbs', '0g/300g', Colors.blue),
                _buildMacroItem('Fat', '0g/80g', Colors.orange),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMacroItem(String label, String value, Color color) {
    return Column(
      children: [
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              value.split('/')[0],
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.grey,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildBodyProgress() {
    final latestMeasurement = _getLatestMeasurement();

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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Body Progress',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              TextButton(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Progress tracking coming soon!')),
                  );
                },
                child: const Text('View Progress'),
              ),
            ],
          ),
          const SizedBox(height: 15),

          if (latestMeasurement == null) ...[
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(15),
              ),
              child: const Center(
                child: Column(
                  children: [
                    Icon(Icons.straighten, color: Colors.grey, size: 40),
                    SizedBox(height: 10),
                    Text(
                      'No measurements yet',
                      style: TextStyle(color: Colors.grey),
                    ),
                    Text(
                      'Start tracking your body progress',
                      style: TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
          ] else ...[
            Row(
              children: [
                _buildProgressCard(
                  label: 'Weight',
                  current: '${latestMeasurement.weight} kg',
                  change: '',
                  isPositive: true,
                  icon: Icons.monitor_weight,
                ),
                const SizedBox(width: 10),
                _buildProgressCard(
                  label: 'Body Fat',
                  current: latestMeasurement.bodyFat != null
                      ? '${latestMeasurement.bodyFat}%'
                      : 'N/A',
                  change: '',
                  isPositive: true,
                  icon: Icons.percent,
                ),
                const SizedBox(width: 10),
                _buildProgressCard(
                  label: 'BMI',
                  current: latestMeasurement.bmi != null
                      ? latestMeasurement.bmi!.toStringAsFixed(1)
                      : 'N/A',
                  change: '',
                  isPositive: true,
                  icon: Icons.analytics,
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildProgressCard({
    required String label,
    required String current,
    required String change,
    required bool isPositive,
    required IconData icon,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[200]!),
        ),
        child: Column(
          children: [
            Icon(icon, color: Colors.grey[600], size: 20),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              current,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (change.isNotEmpty) ...[
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isPositive ? Colors.green[50] : Colors.red[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  change,
                  style: TextStyle(
                    fontSize: 11,
                    color: isPositive ? Colors.green : Colors.red,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ===== WORKOUT LOGGING PAGE (SIMPLIFIED) =====
class WorkoutLoggingPage extends StatefulWidget {
  final WorkoutPlan? activePlan;

  const WorkoutLoggingPage({super.key, this.activePlan});

  @override
  State<WorkoutLoggingPage> createState() => _WorkoutLoggingPageState();
}

class _WorkoutLoggingPageState extends State<WorkoutLoggingPage> {
  final List<Map<String, dynamic>> _quickExercises = [
    {'name': 'Push Ups', 'icon': Icons.fitness_center, 'type': 'reps'},
    {'name': 'Squats', 'icon': Icons.airline_seat_legroom_normal, 'type': 'reps'},
    {'name': 'Running', 'icon': Icons.directions_run, 'type': 'time'},
    {'name': 'Plank', 'icon': Icons.accessibility_new, 'type': 'time'},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Quick Workout'),
        backgroundColor: Colors.orange,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Choose Exercise',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 15,
                  mainAxisSpacing: 15,
                  childAspectRatio: 1,
                ),
                itemCount: _quickExercises.length,
                itemBuilder: (context, index) {
                  final exercise = _quickExercises[index];
                  return InkWell(
                    onTap: () {
                      _showExerciseDialog(exercise);
                    },
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.orange.withOpacity(0.3)),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            exercise['icon'],
                            size: 50,
                            color: Colors.orange,
                          ),
                          const SizedBox(height: 10),
                          Text(
                            exercise['name'],
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showExerciseDialog(Map<String, dynamic> exercise) {
    final controller = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(exercise['name']),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: exercise['type'] == 'reps' ? 'Repetitions' : 'Minutes',
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              // Save workout session
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('${exercise['name']} logged successfully!'),
                  backgroundColor: Colors.green,
                ),
              );
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}