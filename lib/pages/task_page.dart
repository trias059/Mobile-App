import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:lisku/model/task_model.dart';

class TaskPage extends StatefulWidget {
  const TaskPage({super.key});

  @override
  State<TaskPage> createState() => _TaskPageState();
}

class _TaskPageState extends State<TaskPage> {
  late Box<TaskModel> taskBox;
  late Box summaryBox; // FIX: Declare summaryBox

  @override
  void initState() {
    super.initState();
    taskBox = Hive.box<TaskModel>('taskBox');
    summaryBox = Hive.box('tasksBox'); // FIX: Initialize summaryBox
  }

  void _addTask(String title) {
    final newTask = TaskModel(title: title);
    taskBox.add(newTask);
    _updateSummaryBox();
  }

  void _deleteTask(int index) {
    taskBox.deleteAt(index);
    _updateSummaryBox();
  }

  void _toggleDone(int index) {
    final task = taskBox.getAt(index);
    if (task != null) {
      task.isDone = !task.isDone;
      task.save();
      _updateSummaryBox();
    }
  }

  void _updateSummaryBox() {
    try {
      final allTasks = taskBox.values.toList();
      final selesai = allTasks.where((t) => t.isDone).length;
      final belum = allTasks.where((t) => !t.isDone).length;

      summaryBox.put('selesai', selesai);
      summaryBox.put('belum', belum);
    } catch (e) {
      debugPrint('Error updating summary box: $e');
    }
  }

  void _showAddTaskDialog() {
    final titleController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Tambah Tugas'),
        content: TextField(
          controller: titleController,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Masukkan nama tugas...',
            border: OutlineInputBorder(),
          ),
          onSubmitted: (value) {
            if (value.trim().isNotEmpty) {
              _addTask(value.trim());
              Navigator.pop(context);
            }
          },
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Batal')
          ),
          ElevatedButton(
            onPressed: () {
              final title = titleController.text.trim();
              if (title.isNotEmpty) {
                _addTask(title);
                Navigator.pop(context);
              }
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }

  void _showTaskStats() {
    final allTasks = taskBox.values.toList();
    final completed = allTasks.where((t) => t.isDone).length;
    final pending = allTasks.where((t) => !t.isDone).length;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('📊 Statistik Tugas'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildStatRow('Total Tugas', allTasks.length, Colors.blue),
            _buildStatRow('Selesai', completed, Colors.green),
            _buildStatRow('Belum Selesai', pending, Colors.orange),
            if (allTasks.isNotEmpty) ...[
              const SizedBox(height: 10),
              LinearProgressIndicator(
                value: completed / allTasks.length,
                backgroundColor: Colors.grey[300],
                valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
              ),
              const SizedBox(height: 5),
              Text('${((completed / allTasks.length) * 100).toInt()}% selesai'),
            ],
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

  Widget _buildStatRow(String label, int count, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 16)),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: color.withOpacity(0.3)),
            ),
            child: Text(
              count.toString(),
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _clearCompletedTasks() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus Tugas Selesai'),
        content: const Text('Yakin ingin menghapus semua tugas yang sudah selesai?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () {
              // Hapus semua tugas yang sudah selesai
              final completedIndices = <int>[];
              for (int i = 0; i < taskBox.length; i++) {
                if (taskBox.getAt(i)?.isDone == true) {
                  completedIndices.add(i);
                }
              }

              // Hapus dari index tertinggi agar tidak mengubah index lainnya
              for (int i = completedIndices.length - 1; i >= 0; i--) {
                taskBox.deleteAt(completedIndices[i]);
              }

              _updateSummaryBox();
              Navigator.pop(context);

              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('${completedIndices.length} tugas selesai dihapus')),
              );
            },
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tugas'),
        actions: [
          IconButton(
            onPressed: _showTaskStats,
            icon: const Icon(Icons.bar_chart),
            tooltip: 'Statistik',
          ),
          PopupMenuButton(
            icon: const Icon(Icons.more_vert),
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'clear_completed',
                child: Row(
                  children: [
                    Icon(Icons.clear_all, color: Colors.orange),
                    SizedBox(width: 8),
                    Text('Hapus yang Selesai'),
                  ],
                ),
              ),
            ],
            onSelected: (value) {
              if (value == 'clear_completed') {
                _clearCompletedTasks();
              }
            },
          ),
        ],
      ),
      body: ValueListenableBuilder(
        valueListenable: taskBox.listenable(),
        builder: (context, Box<TaskModel> box, _) {
          if (box.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.task_outlined, size: 80, color: Colors.grey),
                  SizedBox(height: 20),
                  Text(
                    'Belum ada tugas.',
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                  Text(
                    'Tap + untuk menambah tugas',
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: box.length,
            itemBuilder: (context, index) {
              final task = box.getAt(index)!;
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                elevation: 2,
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  title: Text(
                    task.title,
                    style: TextStyle(
                      decoration: task.isDone ? TextDecoration.lineThrough : TextDecoration.none,
                      fontSize: 16,
                      color: task.isDone ? Colors.grey : Colors.black87,
                    ),
                  ),
                  leading: GestureDetector(
                    onTap: () => _toggleDone(index),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: task.isDone ? Colors.green : Colors.grey.shade300,
                        border: Border.all(
                          color: task.isDone ? Colors.green : Colors.grey,
                          width: 2,
                        ),
                      ),
                      child: Icon(
                        task.isDone ? Icons.check : Icons.circle_outlined,
                        color: task.isDone ? Colors.white : Colors.grey,
                        size: 20,
                      ),
                    ),
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    onPressed: () {
                      // Konfirmasi sebelum hapus
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Hapus Tugas'),
                          content: Text('Yakin ingin menghapus "${task.title}"?'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('Batal'),
                            ),
                            ElevatedButton(
                              onPressed: () {
                                _deleteTask(index);
                                Navigator.pop(context);
                              },
                              child: const Text('Hapus'),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddTaskDialog,
        tooltip: 'Tambah Tugas',
        child: const Icon(Icons.add),
      ),
    );
  }
}