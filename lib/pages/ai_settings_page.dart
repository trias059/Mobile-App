// File: lib/pages/ai_settings_page.dart
// Pengaturan Asisten AI: pilih model (Default / Uncensored), info server lokal.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:lisku/pages/ai_assistant_page.dart';
import 'package:lisku/services/ai_server_controller.dart';

class AiSettingsPage extends StatefulWidget {
  const AiSettingsPage({super.key});

  @override
  State<AiSettingsPage> createState() => _AiSettingsPageState();
}

class _AiSettingsPageState extends State<AiSettingsPage> {
  late final AiServerController _ai;
  bool _applying = false;
  String _progressText = '';

  @override
  void initState() {
    super.initState();
    _ai = context.read<AiServerController>();
    WidgetsBinding.instance.addPostFrameCallback((_) => _ai.attachPage());
  }

  @override
  void dispose() {
    _ai.detachPage();
    super.dispose();
  }

  Future<void> _selectModel(String choice) async {
    if (_applying || choice == _ai.modelChoice) return;
    if (!await ensureTermuxPermission(context, _ai)) return;
    setState(() => _applying = true);

    // Model uncensored baru diunduh saat pertama kali dipilih.
    if (choice == AiModelChoice.uncensored) {
      final downloaded = await _ai.isUncensoredDownloaded();
      if (!mounted) return;
      if (downloaded == null) {
        _finish('Tidak bisa memeriksa model di Termux. ${_ai.errorMessage}');
        return;
      }
      if (!downloaded) {
        if (await _confirmDownload() != true) {
          _finish('Unduhan dibatalkan. Tetap memakai ${AiModelChoice.label(_ai.modelChoice)}.');
          return;
        }
        setState(() => _progressText = 'Mengunduh di Termux... (lihat progres di Termux)');
        final ok = await _ai.downloadUncensored();
        if (!mounted) return;
        if (!ok) {
          _finish('Unduhan model uncensored gagal atau belum selesai. '
              'Tetap memakai ${AiModelChoice.label(_ai.modelChoice)}. Pilih Uncensored lagi untuk melanjutkan.');
          return;
        }
      }
    }

    setState(() => _progressText = 'Menyimpan pilihan & menyalakan ulang server...');
    final ok = await _ai.setModel(choice);
    if (!mounted) return;
    final notice = _ai.takeNotice();
    _finish(notice ??
        (ok
            ? 'Model aktif: ${AiModelChoice.label(_ai.modelChoice)}'
            : 'Gagal mengganti model. ${_ai.errorMessage}'));
  }

  void _finish(String message) {
    setState(() {
      _applying = false;
      _progressText = '';
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 5)),
    );
  }

  Future<bool?> _confirmDownload() {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Unduh model Uncensored?'),
        content: const Text(
          'Model Gemma 4 E2B uncensored belum ada di HP.\n\n'
          'Ukuran unduhan ±3,4 GB (sebaiknya pakai Wi-Fi). Termux akan terbuka dan '
          'menampilkan progres; unduhan bisa dilanjutkan bila terputus.\n\n'
          'Setelah selesai, Lisku menyalakan ulang AI dengan model ini. '
          'Jika dibatalkan atau gagal, Lisku tetap memakai model default.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Unduh ±3,4 GB')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ai = context.watch<AiServerController>();
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Pengaturan AI'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          AiStatusCard(ai: ai),
          const SizedBox(height: 16),
          _section(
            title: 'Model chat',
            icon: Icons.memory,
            children: [
              _modelTile(
                ai,
                AiModelChoice.defaultModel,
                'Qwen3 1.7B (Q4_K_M) • ±1,1 GB • bisa "berpikir" sebelum menjawab. Disarankan.',
              ),
              _modelTile(
                ai,
                AiModelChoice.uncensored,
                'Gemma 4 E2B uncensored (Q4_K_M) • ±3,4 GB, diunduh saat pertama kali dipilih • lebih bebas. Jika gagal dimuat, Lisku otomatis kembali ke Default.',
              ),
              if (_applying)
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(children: [
                    const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                    const SizedBox(width: 10),
                    Expanded(child: Text(_progressText.isEmpty ? 'Memeriksa model...' : _progressText)),
                  ]),
                ),
            ],
          ),
          const SizedBox(height: 16),
          _section(
            title: 'Server lokal',
            icon: Icons.dns,
            children: [
              const ListTile(
                dense: true,
                title: Text('Chat'),
                subtitle: Text('http://127.0.0.1:8080 • log: ~/llm-logs/chat.log'),
              ),
              ListTile(
                dense: true,
                title: const Text('Embedding'),
                subtitle: const Text('http://127.0.0.1:8081 • log: ~/llm-logs/embed.log'),
                trailing: Icon(
                  ai.embedReady ? Icons.check_circle : Icons.radio_button_unchecked,
                  color: ai.embedReady ? Colors.green : Colors.grey,
                ),
              ),
              const ListTile(
                dense: true,
                title: Text('Hemat RAM'),
                subtitle: Text('AI dimatikan otomatis jika app di background atau halaman AI tidak dipakai lebih dari 2 menit.'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _modelTile(AiServerController ai, String choice, String subtitle) {
    return RadioListTile<String>(
      value: choice,
      groupValue: ai.modelChoice,
      onChanged: _applying ? null : (v) => _selectModel(v!),
      title: Text(AiModelChoice.label(choice), style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
    );
  }

  Widget _section({required String title, required IconData icon, required List<Widget> children}) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Row(children: [
                Icon(icon, color: Colors.blue, size: 20),
                const SizedBox(width: 8),
                Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ]),
            ),
            ...children,
          ],
        ),
      ),
    );
  }
}
