// File: lib/pages/ai_knowledge_page.dart
// Kelola Pengetahuan: impor PDF (dengan progres), daftar buku & catatan, hapus.

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'package:lisku/model/knowledge_models.dart';
import 'package:lisku/pages/ai_assistant_page.dart';
import 'package:lisku/services/ai_server_controller.dart';
import 'package:lisku/services/knowledge_service.dart';

class AiKnowledgePage extends StatefulWidget {
  const AiKnowledgePage({super.key});

  @override
  State<AiKnowledgePage> createState() => _AiKnowledgePageState();
}

class _AiKnowledgePageState extends State<AiKnowledgePage> {
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
        title: const Text('Kelola Pengetahuan'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _importPdf,
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.upload_file),
        label: const Text('Impor PDF'),
      ),
      body: ValueListenableBuilder(
        valueListenable: KnowledgeService.sources.listenable(),
        builder: (context, _, __) {
          final books = KnowledgeService.books();
          final notes = KnowledgeService.notes();
          if (books.isEmpty && notes.isEmpty) return _buildEmpty();
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
            children: [
              _header('Buku', Icons.menu_book, books.length),
              if (books.isEmpty) _hint('Belum ada buku. Tekan "Impor PDF".'),
              for (final book in books) _sourceTile(book),
              const SizedBox(height: 16),
              _header('Catatan pribadi', Icons.lightbulb, notes.length),
              if (notes.isEmpty) _hint('Belum ada catatan. Tambahkan di halaman Insight.'),
              for (final note in notes) _sourceTile(note),
            ],
          );
        },
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.library_books, size: 64, color: Colors.deepPurple[200]),
            const SizedBox(height: 12),
            const Text('Belum ada pengetahuan', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Text(
              'Impor e-book PDF agar Guru e-book bisa menjawab dari isinya, lengkap dengan nomor halaman.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _header(String title, IconData icon, int count) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(children: [
        Icon(icon, color: Colors.deepPurple, size: 20),
        const SizedBox(width: 8),
        Text('$title ($count)', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      ]),
    );
  }

  Widget _hint(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text, style: TextStyle(color: Colors.grey[600], fontSize: 13)),
      );

  Widget _sourceTile(KnowledgeSource source) {
    final date = DateFormat('d MMM yyyy').format(source.createdAt);
    final subtitle = source.isBook
        ? '${source.pageCount} halaman • ${source.chunkCount} potongan • $date'
        : '${source.text.length > 80 ? '${source.text.substring(0, 80)}…' : source.text}\n$date';
    return Card(
      elevation: 1,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: Icon(source.isBook ? Icons.picture_as_pdf : Icons.sticky_note_2,
            color: source.isBook ? Colors.red[400] : Colors.amber[700]),
        title: Text(source.title, maxLines: 2, overflow: TextOverflow.ellipsis),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
        isThreeLine: source.isNote,
        trailing: IconButton(
          tooltip: 'Hapus',
          icon: const Icon(Icons.delete_outline, color: Colors.red),
          onPressed: () => confirmDeleteSource(context, source),
        ),
      ),
    );
  }

  // ================= IMPOR =================

  Future<void> _importPdf() async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );
    final path = picked?.files.single.path;
    if (path == null || !mounted) return;

    final defaultTitle = picked!.files.single.name.replaceAll(RegExp(r'\.pdf$', caseSensitive: false), '');
    final title = await _askTitle(defaultTitle);
    if (title == null || !mounted) return;

    if (!await ensureTermuxPermission(context, _ai) || !mounted) return;

    final progress = ValueNotifier(const ImportProgress('Menyalakan AI...'));
    var cancelled = false;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _ImportDialog(progress: progress, onCancel: () => cancelled = true),
    );

    _ai.beginBusy();
    String message;
    try {
      if (!await _ai.ensureEmbedReady()) {
        throw KnowledgeException('Server embedding belum siap. ${_ai.errorMessage}');
      }
      final source = await _knowledge.importPdf(
        path,
        title: title,
        onProgress: (p) {
          _ai.touch();
          progress.value = p;
        },
        isCancelled: () => cancelled,
      );
      message = '"${source.title}" diimpor: ${source.pageCount} halaman, ${source.chunkCount} potongan.';
    } catch (e) {
      message = '$e';
    } finally {
      _ai.endBusy();
    }
    if (!mounted) return;
    Navigator.of(context, rootNavigator: true).pop();
    progress.dispose();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<String?> _askTitle(String initial) {
    final controller = TextEditingController(text: initial);
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Judul buku'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(border: OutlineInputBorder(), labelText: 'Judul'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
          ElevatedButton(
            onPressed: () {
              final t = controller.text.trim();
              Navigator.pop(context, t.isEmpty ? initial : t);
            },
            child: const Text('Impor'),
          ),
        ],
      ),
    );
  }
}

/// Konfirmasi lalu hapus buku/catatan beserta semua potongannya.
Future<void> confirmDeleteSource(BuildContext context, KnowledgeSource source) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(source.isBook ? 'Hapus buku' : 'Hapus catatan'),
      content: Text('Hapus "${source.title}" dari pengetahuan AI?'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Hapus', style: TextStyle(color: Colors.red)),
        ),
      ],
    ),
  );
  if (ok == true) await KnowledgeService.deleteSource(source);
}

class _ImportDialog extends StatelessWidget {
  final ValueNotifier<ImportProgress> progress;
  final VoidCallback onCancel;

  const _ImportDialog({required this.progress, required this.onCancel});

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: AlertDialog(
        title: const Text('Mengimpor PDF'),
        content: ValueListenableBuilder<ImportProgress>(
          valueListenable: progress,
          builder: (context, p, _) => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(p.stage),
              const SizedBox(height: 12),
              LinearProgressIndicator(value: p.fraction, color: Colors.deepPurple),
              const SizedBox(height: 8),
              if (p.total > 0)
                Text('${p.done} / ${p.total} potongan (${((p.fraction ?? 0) * 100).round()}%)',
                    style: TextStyle(color: Colors.grey[600], fontSize: 12)),
            ],
          ),
        ),
        actions: [TextButton(onPressed: onCancel, child: const Text('Batal'))],
      ),
    );
  }
}
