// File: lib/pages/ai_insight_page.dart
// Insight: catatan pribadi yang di-embed ke indeks pengetahuan yang sama dengan
// buku, sehingga Guru e-book juga bisa memakainya (ditandai "catatan pribadi").

import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'package:lisku/pages/ai_assistant_page.dart';
import 'package:lisku/pages/ai_knowledge_page.dart';
import 'package:lisku/services/ai_server_controller.dart';
import 'package:lisku/services/knowledge_service.dart';

class AiInsightPage extends StatefulWidget {
  const AiInsightPage({super.key});

  @override
  State<AiInsightPage> createState() => _AiInsightPageState();
}

class _AiInsightPageState extends State<AiInsightPage> {
  late final AiServerController _ai;
  late final KnowledgeService _knowledge;

  @override
  void initState() {
    super.initState();
    _ai = context.read<AiServerController>();
    _knowledge = KnowledgeService(_ai.llm);
    WidgetsBinding.instance.addPostFrameCallback((_) => _ai.attachPage());
  }

  @override
  void dispose() {
    _ai.detachPage();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Insight'),
        backgroundColor: Colors.amber[800],
        foregroundColor: Colors.white,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addNote,
        backgroundColor: Colors.amber[800],
        foregroundColor: Colors.white,
        tooltip: 'Tambah catatan',
        child: const Icon(Icons.add),
      ),
      body: ValueListenableBuilder(
        valueListenable: KnowledgeService.sources.listenable(),
        builder: (context, _, __) {
          final notes = KnowledgeService.notes();
          if (notes.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.lightbulb_outline, size: 64, color: Colors.amber[300]),
                    const SizedBox(height: 12),
                    const Text('Belum ada insight',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    Text(
                      'Tulis catatan pribadi, atau tekan "Simpan sebagai insight" di jawaban AI. '
                      'Guru e-book akan ikut memakai catatan ini sebagai sumber.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
            itemCount: notes.length,
            itemBuilder: (context, i) {
              final note = notes[i];
              return Card(
                elevation: 2,
                margin: const EdgeInsets.only(bottom: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 4, 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(note.title,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                            const SizedBox(height: 6),
                            SelectableText(note.text, style: TextStyle(color: Colors.grey[800])),
                            const SizedBox(height: 6),
                            Text(
                              'catatan pribadi • ${DateFormat('d MMM yyyy, HH:mm').format(note.createdAt)}',
                              style: TextStyle(color: Colors.grey[500], fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Hapus',
                        icon: const Icon(Icons.delete_outline, color: Colors.red),
                        onPressed: () => confirmDeleteSource(context, note),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _addNote() async {
    final titleController = TextEditingController();
    final textController = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Catatan pribadi'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                decoration: const InputDecoration(
                  labelText: 'Judul (opsional)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: textController,
                minLines: 4,
                maxLines: 10,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Isi catatan / insight',
                  alignLabelWithHint: true,
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Simpan')),
        ],
      ),
    );
    final text = textController.text.trim();
    final title = titleController.text.trim();
    if (result != true || text.isEmpty || !mounted) return;
    if (!await ensureTermuxPermission(context, _ai) || !mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(const SnackBar(content: Text('Menyimpan & membuat embedding...')));
    _ai.beginBusy();
    try {
      if (!await _ai.ensureEmbedReady()) {
        throw KnowledgeException('Server embedding belum siap. ${_ai.errorMessage}');
      }
      await _knowledge.addNote(title: title, text: text);
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(const SnackBar(content: Text('Insight disimpan')));
    } catch (e) {
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      _ai.endBusy();
    }
  }
}
