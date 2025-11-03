import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '/model/task_daily_model.dart';
import '/model/task_model.dart';
import '/model/goal_task.dart';
import '/model/note_model.dart';
import 'dart:math' as math;

class AnalyticsPage extends StatefulWidget {
  const AnalyticsPage({super.key});

  @override
  State<AnalyticsPage> createState() => _AnalyticsPageState();
}

class _AnalyticsPageState extends State<AnalyticsPage> {
  late Box<DailyTaskModel> dailyTaskBox;
  late Box<TaskModel> taskBox;
  late Box<GoalTask> goalBox;
  late Box<NoteModel> noteBox;

  String _selectedPeriod = 'week'; // week, month, all

  @override
  void initState() {
    super.initState();
    dailyTaskBox = Hive.box<DailyTaskModel>('tasks');
    taskBox = Hive.box<TaskModel>('taskBox');
    goalBox = Hive.box<GoalTask>('goal_tasks');
    noteBox = Hive.box<NoteModel>('notes');
  }

  Map<String, dynamic> _calculateStatistics() {
    // Daily Tasks Stats
    final dailyTasks = dailyTaskBox.values.toList();
    final completedDaily = dailyTasks.where((t) => t.isCompleted).length;
    final onTimeDaily = dailyTasks.where((t) => t.isCompletedOnTime).length;

    // Regular Tasks Stats
    final regularTasks = taskBox.values.toList();
    final completedRegular = regularTasks.where((t) => t.isDone).length;

    // Goals Stats
    final goals = goalBox.values.toList();
    final completedGoals = goals.where((g) => g.progress >= 1.0).length;
    final avgGoalProgress = goals.isEmpty
        ? 0.0
        : goals.map((g) => g.progress).reduce((a, b) => a + b) / goals.length;

    // Notes Stats - Without progress
    final notes = noteBox.values.toList();
    final learningNotes = notes.where((n) => n.category == 'learning').length;
    final ideaNotes = notes.where((n) => n.category == 'idea').length;
    final generalNotes = notes.where((n) => n.category == 'general').length;

    // Overall completion rate
    final totalTasks = dailyTasks.length + regularTasks.length;
    final totalCompleted = completedDaily + completedRegular;
    final completionRate = totalTasks > 0 ? (totalCompleted / totalTasks) * 100 : 0.0;

    // Productivity score (weighted calculation)
    final productivityScore = _calculateProductivityScore(
      dailyCompletion: dailyTasks.isEmpty ? 0 : completedDaily / dailyTasks.length,
      onTimeRate: dailyTasks.isEmpty ? 0 : onTimeDaily / dailyTasks.length,
      goalProgress: avgGoalProgress,
      notesActivity: notes.isEmpty ? 0 : math.min(notes.length / 20, 1.0), // Max at 20 notes
    );

    return {
      'totalDailyTasks': dailyTasks.length,
      'completedDailyTasks': completedDaily,
      'onTimeDailyTasks': onTimeDaily,
      'totalRegularTasks': regularTasks.length,
      'completedRegularTasks': completedRegular,
      'totalGoals': goals.length,
      'completedGoals': completedGoals,
      'avgGoalProgress': avgGoalProgress,
      'totalNotes': notes.length,
      'learningNotes': learningNotes,
      'ideaNotes': ideaNotes,
      'generalNotes': generalNotes,
      'completionRate': completionRate,
      'productivityScore': productivityScore,
    };
  }

  double _calculateProductivityScore({
    required double dailyCompletion,
    required double onTimeRate,
    required double goalProgress,
    required double notesActivity,
  }) {
    // Weighted scoring
    final score = (dailyCompletion * 0.3) +
        (onTimeRate * 0.3) +
        (goalProgress * 0.25) +
        (notesActivity * 0.15);

    return (score * 100).clamp(0, 100);
  }

  String _getProductivityGrade(double score) {
    if (score >= 90) return 'A+';
    if (score >= 85) return 'A';
    if (score >= 80) return 'B+';
    if (score >= 75) return 'B';
    if (score >= 70) return 'C+';
    if (score >= 65) return 'C';
    if (score >= 60) return 'D';
    return 'F';
  }

  Color _getGradeColor(String grade) {
    switch (grade[0]) {
      case 'A':
        return Colors.green;
      case 'B':
        return Colors.blue;
      case 'C':
        return Colors.orange;
      case 'D':
        return Colors.deepOrange;
      default:
        return Colors.red;
    }
  }

  @override
  Widget build(BuildContext context) {
    final stats = _calculateStatistics();
    final productivityGrade = _getProductivityGrade(stats['productivityScore']);

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF1565C0), Color(0xFF42A5F5)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header
              _buildHeader(context),

              // Content
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      // Productivity Score Card
                      _buildProductivityScoreCard(
                        stats['productivityScore'],
                        productivityGrade,
                      ),
                      const SizedBox(height: 20),

                      // Statistics Grid
                      _buildStatisticsGrid(stats),
                      const SizedBox(height: 20),

                      // Progress Charts
                      _buildProgressCharts(stats),
                      const SizedBox(height: 20),

                      // Insights
                      _buildInsights(stats),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back, color: Colors.white),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Analitik Produktivitas',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: DropdownButton<String>(
              value: _selectedPeriod,
              dropdownColor: Colors.blue[700],
              style: const TextStyle(color: Colors.white),
              underline: const SizedBox(),
              items: const [
                DropdownMenuItem(value: 'week', child: Text('Minggu Ini')),
                DropdownMenuItem(value: 'month', child: Text('Bulan Ini')),
                DropdownMenuItem(value: 'all', child: Text('Semua')),
              ],
              onChanged: (value) {
                setState(() {
                  _selectedPeriod = value!;
                });
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductivityScoreCard(double score, String grade) {
    return Card(
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        padding: const EdgeInsets.all(30),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              _getGradeColor(grade).withOpacity(0.1),
              Colors.white,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          children: [
            const Text(
              'Skor Produktivitas',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.black54,
              ),
            ),
            const SizedBox(height: 20),
            Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 150,
                  height: 150,
                  child: CircularProgressIndicator(
                    value: score / 100,
                    strokeWidth: 15,
                    backgroundColor: Colors.grey[300],
                    valueColor: AlwaysStoppedAnimation<Color>(
                      _getGradeColor(grade),
                    ),
                  ),
                ),
                Column(
                  children: [
                    Text(
                      grade,
                      style: TextStyle(
                        fontSize: 48,
                        fontWeight: FontWeight.bold,
                        color: _getGradeColor(grade),
                      ),
                    ),
                    Text(
                      '${score.toStringAsFixed(1)}%',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w500,
                        color: Colors.black54,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 20),
            _buildScoreInterpretation(score),
          ],
        ),
      ),
    );
  }

  Widget _buildScoreInterpretation(double score) {
    String interpretation;
    IconData icon;
    Color color;

    if (score >= 85) {
      interpretation = 'Luar biasa! Pertahankan performa kamu!';
      icon = Icons.star;
      color = Colors.amber;
    } else if (score >= 70) {
      interpretation = 'Bagus! Sedikit lagi untuk sempurna!';
      icon = Icons.thumb_up;
      color = Colors.green;
    } else if (score >= 50) {
      interpretation = 'Cukup baik, tingkatkan konsistensi!';
      icon = Icons.trending_up;
      color = Colors.blue;
    } else {
      interpretation = 'Ayo semangat! Mulai dari yang kecil!';
      icon = Icons.local_fire_department;
      color = Colors.orange;
    }

    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              interpretation,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatisticsGrid(Map<String, dynamic> stats) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: 15,
      crossAxisSpacing: 15,
      childAspectRatio: 1.5,
      children: [
        _buildStatCard(
          'Tugas Harian',
          '${stats['completedDailyTasks']}/${stats['totalDailyTasks']}',
          Icons.calendar_today,
          Colors.blue,
          subtitle: '${stats['onTimeDailyTasks']} tepat waktu',
        ),
        _buildStatCard(
          'Tugas Regular',
          '${stats['completedRegularTasks']}/${stats['totalRegularTasks']}',
          Icons.task_alt,
          Colors.green,
        ),
        _buildStatCard(
          'Target',
          '${stats['completedGoals']}/${stats['totalGoals']}',
          Icons.flag,
          Colors.purple,
          subtitle: '${(stats['avgGoalProgress'] * 100).toStringAsFixed(0)}% rata-rata',
        ),
        _buildStatCard(
          'Catatan',
          '${stats['totalNotes']}',
          Icons.note,
          Colors.orange,
          subtitle: '${stats['learningNotes']} belajar',
        ),
      ],
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color,
      {String? subtitle}) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [color.withOpacity(0.1), Colors.white],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(15),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 30),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[700],
              ),
            ),
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            if (subtitle != null)
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressCharts(Map<String, dynamic> stats) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Progress Overview',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            _buildProgressBar(
              'Completion Rate',
              stats['completionRate'],
              Colors.blue,
            ),
            const SizedBox(height: 15),
            _buildProgressBar(
              'On-Time Rate',
              stats['totalDailyTasks'] > 0
                  ? (stats['onTimeDailyTasks'] / stats['totalDailyTasks'] * 100)
                  : 0.0,
              Colors.green,
            ),
            const SizedBox(height: 15),
            _buildProgressBar(
              'Goal Progress',
              stats['avgGoalProgress'] * 100,
              Colors.purple,
            ),
            const SizedBox(height: 15),
            _buildProgressBar(
              'Notes Activity',
              math.min((stats['totalNotes'] / 20 * 100), 100.0),
              Colors.orange,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressBar(String label, double percentage, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: const TextStyle(fontSize: 14),
            ),
            Text(
              '${percentage.toStringAsFixed(1)}%',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 5),
        LinearProgressIndicator(
          value: percentage / 100,
          minHeight: 8,
          backgroundColor: Colors.grey[300],
          valueColor: AlwaysStoppedAnimation<Color>(color),
        ),
      ],
    );
  }

  Widget _buildInsights(Map<String, dynamic> stats) {
    final insights = _generateInsights(stats);

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.lightbulb, color: Colors.amber),
                SizedBox(width: 10),
                Text(
                  'Insights & Rekomendasi',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 15),
            ...insights.map((insight) => _buildInsightItem(insight)),
          ],
        ),
      ),
    );
  }

  Widget _buildInsightItem(Map<String, dynamic> insight) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: insight['color'].withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            insight['icon'],
            color: insight['color'],
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              insight['text'],
              style: TextStyle(
                color: Colors.grey[800],
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Map<String, dynamic>> _generateInsights(Map<String, dynamic> stats) {
    final insights = <Map<String, dynamic>>[];

    // Completion rate insight
    if (stats['completionRate'] < 50) {
      insights.add({
        'icon': Icons.warning,
        'color': Colors.red,
        'text': 'Tingkat penyelesaian rendah. Coba mulai dengan tugas yang lebih kecil dan mudah.',
      });
    } else if (stats['completionRate'] > 80) {
      insights.add({
        'icon': Icons.celebration,
        'color': Colors.green,
        'text': 'Excellent! Tingkat penyelesaian kamu sangat baik!',
      });
    }

    // On-time rate insight
    if (stats['totalDailyTasks'] > 0) {
      final onTimeRate = stats['onTimeDailyTasks'] / stats['totalDailyTasks'];
      if (onTimeRate < 0.5) {
        insights.add({
          'icon': Icons.access_time,
          'color': Colors.orange,
          'text': 'Banyak tugas yang terlambat. Pertimbangkan untuk mengatur waktu lebih realistis.',
        });
      }
    }

    // Goal progress insight
    if (stats['totalGoals'] > 0 && stats['avgGoalProgress'] < 0.3) {
      insights.add({
        'icon': Icons.trending_down,
        'color': Colors.purple,
        'text': 'Progress target masih rendah. Break down target jadi milestone kecil.',
      });
    }

    // Notes insight
    if (stats['learningNotes'] == 0) {
      insights.add({
        'icon': Icons.school,
        'color': Colors.blue,
        'text': 'Belum ada catatan belajar. Dokumentasikan materi belajarmu!',
      });
    } else if (stats['learningNotes'] >= 5) {
      insights.add({
        'icon': Icons.auto_awesome,
        'color': Colors.green,
        'text': 'Bagus! Kamu aktif mencatat materi belajar.',
      });
    }

    // General motivation
    insights.add({
      'icon': Icons.star,
      'color': Colors.amber,
      'text': 'Setiap progress kecil adalah langkah menuju kesuksesan. Keep going!',
    });

    return insights;
  }
}