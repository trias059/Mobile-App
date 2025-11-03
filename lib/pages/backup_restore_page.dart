// lib/pages/backup_restore_page.dart
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';
import '/model/task_daily_model.dart';
import '/model/task_model.dart';
import '/model/goal_task.dart';
import '/model/note_model.dart';

class BackupRestorePage extends StatefulWidget {
  const BackupRestorePage({super.key});

  @override
  State<BackupRestorePage> createState() => _BackupRestorePageState();
}

class _BackupRestorePageState extends State<BackupRestorePage> {
  bool _isLoading = false;

  Future<void> _createBackup() async {
    setState(() => _isLoading = true);

    try {
      // Collect all data
      final backup = {
        'version': '1.0',
        'created_at': DateTime.now().toIso8601String(),
        'data': {
          'daily_tasks': Hive.box<DailyTaskModel>('tasks')
              .values
              .map((task) => {
            'title': task.title,
            'isCompleted': task.isCompleted,
            'startHour': task.startHour,
            'startMinute': task.startMinute,
            'endHour': task.endHour,
            'endMinute': task.endMinute,
            'startPeriod': task.startPeriod,
            'endPeriod': task.endPeriod,
            'completedAt': task.completedAt?.toIso8601String(),
            'customOrder': task.customOrder,
          })
              .toList(),
          'tasks': Hive.box<TaskModel>('taskBox')
              .values
              .map((task) => {
            'title': task.title,
            'isDone': task.isDone,
          })
              .toList(),
          'goals': Hive.box<GoalTask>('goal_tasks')
              .values
              .map((goal) => {
            'title': goal.title,
            'description': goal.description,
            'deadline': goal.deadline.toIso8601String(),
            'progress': goal.progress,
          })
              .toList(),
          'notes': Hive.box<NoteModel>('notes')
              .values
              .map((note) => {
            'title': note.title,
            'content': note.content,
            'createdAt': note.createdAt.toIso8601String(),
            'updatedAt': note.updatedAt.toIso8601String(),
            'category': note.category,
            'relatedTaskId': note.relatedTaskId,

            'tags': note.tags,
            'isPinned': note.isPinned,
            'colorCode': note.colorCode,
          })
              .toList(),
        }
      };

      // Save to file
      final directory = await getTemporaryDirectory();
      final file = File(
          '${directory.path}/lisku_backup_${DateTime.now().millisecondsSinceEpoch}.json');
      await file.writeAsString(jsonEncode(backup));

      // Share file
      await Share.shareXFiles([XFile(file.path)],
          text: 'Backup Lisku - ${DateTime.now().toString().split(' ')[0]}');
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error creating backup: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _restoreBackup() async {
    try {
      // Pick file
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      if (result == null || result.files.isEmpty) return;

      setState(() => _isLoading = true);

      final file = File(result.files.single.path!);
      final content = await file.readAsString();
      final backup = jsonDecode(content);

      // Show confirmation dialog
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Konfirmasi Restore'),
          content: Text(
            'Backup dibuat pada: ${backup['created_at']}\n\n'
                'Ini akan menghapus semua data yang ada dan menggantinya dengan data backup.\n\n'
                'Lanjutkan?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Restore'),
            ),
          ],
        ),
      );

      if (confirm != true) {
        setState(() => _isLoading = false);
        return;
      }

      // Clear existing data
      await Hive.box<DailyTaskModel>('tasks').clear();
      await Hive.box<TaskModel>('taskBox').clear();
      await Hive.box<GoalTask>('goal_tasks').clear();
      await Hive.box<NoteModel>('notes').clear();

      // Restore data
      final data = backup['data'];

      // Restore daily tasks
      for (final taskData in data['daily_tasks']) {
        final task = DailyTaskModel(
          title: taskData['title'],
          isCompleted: taskData['isCompleted'],
          startHour: taskData['startHour'],
          startMinute: taskData['startMinute'],
          endHour: taskData['endHour'],
          endMinute: taskData['endMinute'],
          startPeriod: taskData['startPeriod'],
          endPeriod: taskData['endPeriod'],
          completedAt: taskData['completedAt'] != null
              ? DateTime.parse(taskData['completedAt'])
              : null,
          customOrder: taskData['customOrder'],
        );
        await Hive.box<DailyTaskModel>('tasks').add(task);
      }

      // Restore regular tasks
      for (final taskData in data['tasks']) {
        final task = TaskModel(
          title: taskData['title'],
          isDone: taskData['isDone'],
        );
        await Hive.box<TaskModel>('taskBox').add(task);
      }

      // Restore goals
      for (final goalData in data['goals']) {
        final goal = GoalTask(
          title: goalData['title'],
          description: goalData['description'],
          deadline: DateTime.parse(goalData['deadline']),
          progress: goalData['progress'],
        );
        await Hive.box<GoalTask>('goal_tasks').add(goal);
      }

      // Restore notes
      for (final noteData in data['notes']) {
        final note = NoteModel(
          title: noteData['title'],
          content: noteData['content'],
          createdAt: DateTime.parse(noteData['createdAt']),
          updatedAt: DateTime.parse(noteData['updatedAt']),
          category: noteData['category'],
          relatedTaskId: noteData['relatedTaskId'],
          tags: List<String>.from(noteData['tags']),
          isPinned: noteData['isPinned'],
          colorCode: noteData['colorCode'],
        );
        await Hive.box<NoteModel>('notes').add(note);
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Backup berhasil di-restore!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error restoring backup: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Backup & Restore'),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFE3F2FD), Color(0xFF90CAF9)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              _buildInfoCard(),
              const SizedBox(height: 20),
              _buildBackupCard(),
              const SizedBox(height: 20),
              _buildRestoreCard(),
              const SizedBox(height: 20),
              _buildAutoBackupCard(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Icon(Icons.info_outline, size: 50, color: Colors.blue[700]),
            const SizedBox(height: 15),
            const Text(
              'Backup & Restore',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            const Text(
              'Backup semua data aplikasi kamu ke file JSON dan restore kapan saja. Data yang di-backup termasuk semua tugas, target, dan catatan.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBackupCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const Icon(Icons.backup, size: 40, color: Colors.green),
            const SizedBox(height: 15),
            const Text(
              'Buat Backup',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            const Text(
              'Export semua data ke file JSON',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _createBackup,
              icon: const Icon(Icons.upload_file),
              label: const Text('Buat Backup'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding:
                const EdgeInsets.symmetric(horizontal: 30, vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRestoreCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const Icon(Icons.restore, size: 40, color: Colors.orange),
            const SizedBox(height: 15),
            const Text(
              'Restore Backup',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            const Text(
              'Import data dari file backup JSON',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _restoreBackup,
              icon: const Icon(Icons.download),
              label: const Text('Restore Backup'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
                padding:
                const EdgeInsets.symmetric(horizontal: 30, vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAutoBackupCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const Icon(Icons.schedule, size: 40, color: Colors.blue),
            const SizedBox(height: 15),
            const Text(
              'Auto Backup',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.info, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 5),
                Text(
                  'Coming Soon!',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}