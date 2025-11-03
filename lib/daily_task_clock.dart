import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '/model/task_daily_model.dart';
import 'dart:math' as math;

class AnalogScheduleClock extends StatefulWidget {
  const AnalogScheduleClock({super.key});

  @override
  State<AnalogScheduleClock> createState() => _AnalogScheduleClockState();
}

class _AnalogScheduleClockState extends State<AnalogScheduleClock>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  late Box<DailyTaskModel> _taskBox;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    )..repeat();
    _taskBox = Hive.box<DailyTaskModel>('tasks');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: _taskBox.listenable(),
      builder: (context, Box<DailyTaskModel> box, _) {
        return Card(
          elevation: 8,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Container(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                const Text(
                  'Jadwal Hari Ini',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: 250,
                  height: 250,
                  child: CustomPaint(
                    painter: ClockPainter(
                      tasks: box.values.toList(),
                      animation: _controller,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                _buildLegend(box.values.toList()),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildLegend(List<DailyTaskModel> tasks) {
    if (tasks.isEmpty) {
      return const Text(
        'Belum ada jadwal tugas',
        style: TextStyle(color: Colors.grey),
      );
    }

    return Column(
      children: [
        const Text(
          'Keterangan:',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 10,
          runSpacing: 5,
          children: [
            _buildLegendItem(Colors.green, 'Selesai Tepat Waktu'),
            _buildLegendItem(Colors.orange, 'Selesai Terlambat'),
            _buildLegendItem(Colors.blue, 'Sedang Berlangsung'),
            _buildLegendItem(Colors.red, 'Belum Dikerjakan'),
          ],
        ),
      ],
    );
  }

  Widget _buildLegendItem(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 12),
        ),
      ],
    );
  }
}

class ClockPainter extends CustomPainter {
  final List<DailyTaskModel> tasks;
  final Animation<double> animation;

  ClockPainter({required this.tasks, required this.animation})
      : super(repaint: animation);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 10;

    // Draw clock background
    final backgroundPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius, backgroundPaint);

    // Draw clock border
    final borderPaint = Paint()
      ..color = Colors.grey.shade300
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawCircle(center, radius, borderPaint);

    // Draw hour markers
    _drawHourMarkers(canvas, center, radius);

    // Draw task schedules
    _drawTaskSchedules(canvas, center, radius);

    // Draw current time hands
    _drawClockHands(canvas, center, radius);

    // Draw center dot
    final centerPaint = Paint()..color = Colors.black;
    canvas.drawCircle(center, 5, centerPaint);
  }

  void _drawHourMarkers(Canvas canvas, Offset center, double radius) {
    final paint = Paint()
      ..color = Colors.black
      ..strokeWidth = 2;

    for (int i = 1; i <= 12; i++) {
      final angle = (i * 30 - 90) * math.pi / 180;
      final startPoint = Offset(
        center.dx + (radius - 15) * math.cos(angle),
        center.dy + (radius - 15) * math.sin(angle),
      );
      final endPoint = Offset(
        center.dx + radius * math.cos(angle),
        center.dy + radius * math.sin(angle),
      );

      canvas.drawLine(startPoint, endPoint, paint);

      // Draw hour numbers
      final textPainter = TextPainter(
        text: TextSpan(
          text: i.toString(),
          style: const TextStyle(
            color: Colors.black,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();

      final textOffset = Offset(
        center.dx + (radius - 25) * math.cos(angle) - textPainter.width / 2,
        center.dy + (radius - 25) * math.sin(angle) - textPainter.height / 2,
      );
      textPainter.paint(canvas, textOffset);
    }
  }

  void _drawTaskSchedules(Canvas canvas, Offset center, double radius) {
    for (final task in tasks) {
      final startAngle = _getAngleFromTime(task.startHour, task.startMinute);
      final endAngle = _getAngleFromTime(task.endHour, task.endMinute);

      Color taskColor;
      if (task.isCompleted) {
        taskColor = task.isCompletedOnTime ? Colors.green : Colors.orange;
      } else if (task.isCurrentlyActive) {
        taskColor = Colors.blue;
      } else {
        taskColor = Colors.red;
      }

      // Draw task arc
      final arcPaint = Paint()
        ..color = taskColor.withOpacity(0.3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 15;

      final rect = Rect.fromCircle(center: center, radius: radius - 30);
      canvas.drawArc(
        rect,
        startAngle,
        endAngle - startAngle,
        false,
        arcPaint,
      );

      // Draw task markers
      final markerPaint = Paint()
        ..color = taskColor
        ..style = PaintingStyle.fill;

      final startMarker = Offset(
        center.dx + (radius - 30) * math.cos(startAngle),
        center.dy + (radius - 30) * math.sin(startAngle),
      );
      canvas.drawCircle(startMarker, 4, markerPaint);

      final endMarker = Offset(
        center.dx + (radius - 30) * math.cos(endAngle),
        center.dy + (radius - 30) * math.sin(endAngle),
      );
      canvas.drawCircle(endMarker, 4, markerPaint);
    }
  }

  void _drawClockHands(Canvas canvas, Offset center, double radius) {
    final now = DateTime.now();
    final hour = now.hour % 12;
    final minute = now.minute;
    final second = now.second;

    // Hour hand
    final hourAngle = ((hour + minute / 60.0) * 30 - 90) * math.pi / 180;
    final hourHandPaint = Paint()
      ..color = Colors.black
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(
      center,
      Offset(
        center.dx + (radius * 0.5) * math.cos(hourAngle),
        center.dy + (radius * 0.5) * math.sin(hourAngle),
      ),
      hourHandPaint,
    );

    // Minute hand
    final minuteAngle = (minute * 6 - 90) * math.pi / 180;
    final minuteHandPaint = Paint()
      ..color = Colors.black
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(
      center,
      Offset(
        center.dx + (radius * 0.7) * math.cos(minuteAngle),
        center.dy + (radius * 0.7) * math.sin(minuteAngle),
      ),
      minuteHandPaint,
    );

    // Second hand (animated)
    final secondAngle = ((second + animation.value) * 6 - 90) * math.pi / 180;
    final secondHandPaint = Paint()
      ..color = Colors.red
      ..strokeWidth = 1
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(
      center,
      Offset(
        center.dx + (radius * 0.8) * math.cos(secondAngle),
        center.dy + (radius * 0.8) * math.sin(secondAngle),
      ),
      secondHandPaint,
    );
  }

  double _getAngleFromTime(int hour, int minute) {
    // Convert 12-hour format to angle
    final totalMinutes = (hour % 12) * 60 + minute;
    return (totalMinutes * 0.5 - 90) * math.pi / 180;
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}