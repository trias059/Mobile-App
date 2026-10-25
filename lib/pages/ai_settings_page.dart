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
    final ok = await _ai.setModel(choice);
    if (!mounted) return;
    setState(() => _applying = false);

    final notice = _ai.takeNotice();
    final message = notice ??
        (ok
            ? 'Model aktif: ${AiModelChoice.label(_ai.modelChoice)}'
            : 'Gagal mengganti model. ${_ai.errorMessage}');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 5)),
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
                'Gemma 4 E2B uncensored (Q4_K_M) • lebih besar & lebih bebas. Jika gagal dimuat, Lisku otomatis kembali ke Default.',
              ),
              if (_applying)
                const Padding(
                  padding: EdgeInsets.all(12),
                  child: Row(children: [
                    SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                    SizedBox(width: 10),
                    Text('Menyimpan pilihan & menyalakan ulang server...'),
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
