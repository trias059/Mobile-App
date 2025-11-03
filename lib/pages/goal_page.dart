import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import '/model/goal_task.dart';

class GoalPage extends StatefulWidget {
  const GoalPage({super.key});

  @override
  State<GoalPage> createState() => _GoalPageState();
}

class _GoalPageState extends State<GoalPage> {
  late Box<GoalTask> goalBox;

  @override
  void initState() {
    super.initState();
    goalBox = Hive.box<GoalTask>('goal_tasks');
  }

  void _showGoalDialog({GoalTask? task, int? index}) {
    String title = task?.title ?? '';
    DateTime? deadline = task?.deadline;
    double progress = task?.progress ?? 0.0;
    final titleController = TextEditingController(text: title);
    final progressController = TextEditingController(text: (progress * 100).toString());

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(task == null ? 'Tambah Target Baru' : 'Edit Target'),
          content: SingleChildScrollView(
            child: Column(
              children: [
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(labelText: 'Judul Target'),
                ),
                const SizedBox(height: 10),
                ElevatedButton(
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: deadline ?? DateTime.now(),
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2100),
                    );
                    if (picked != null) {
                      setState(() {
                        deadline = picked;
                      });
                    }
                  },
                  child: Text(deadline == null
                      ? 'Pilih Deadline'
                      : 'Deadline: ${DateFormat('yyyy-MM-dd').format(deadline!)}'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: progressController,
                  decoration: const InputDecoration(labelText: 'Progress (%)'),
                  keyboardType: TextInputType.number,
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
                if (titleController.text.isNotEmpty && deadline != null) {
                  final double parsedProgress = double.tryParse(progressController.text) ?? 0.0;
                  final newTask = GoalTask(
                    title: titleController.text,
                    deadline: deadline!,
                    progress: parsedProgress / 100, description: '',
                  );

                  setState(() {
                    if (task == null) {
                      goalBox.add(newTask);
                    } else {
                      goalBox.putAt(index!, newTask);
                    }
                  });
                  Navigator.pop(context);
                }
              },
              child: const Text('Simpan'),
            ),
          ],
        );
      },
    );
  }

  void _deleteGoal(int index) {
    setState(() {
      goalBox.deleteAt(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Daftar Target Kamu!'),
      ),
      body: ValueListenableBuilder(
        valueListenable: goalBox.listenable(),
        builder: (context, Box<GoalTask> box, _) {
          if (box.isEmpty) {
            return const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.flag_outlined, size: 100, color: Colors.grey),
                  SizedBox(height: 20),
                  Text(
                    "Belum ada target. Yuk mulai bikin!",
                    style: TextStyle(fontSize: 16, color: Colors.grey),
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
              return Dismissible(
                key: Key(task.title + task.deadline.toString()),
                direction: DismissDirection.endToStart,
                background: Container(
                  color: Colors.red,
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: const Icon(Icons.delete_forever, color: Colors.white, size: 30),
                ),
                onDismissed: (direction) {
                  _deleteGoal(index);
                },
                child: Card(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  elevation: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  child: ListTile(
                    title: Text(task.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 8),
                        Text('Deadline: ${DateFormat('yyyy-MM-dd').format(task.deadline)}'),
                        const SizedBox(height: 8),
                        LinearProgressIndicator(value: task.progress),
                      ],
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.edit),
                      onPressed: () => _showGoalDialog(task: task, index: index),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showGoalDialog(),
        tooltip: 'Tambah Target',
        child: const Icon(Icons.add),
      ),
    );
  }
}