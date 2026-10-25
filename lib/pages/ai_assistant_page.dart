// File: lib/pages/ai_assistant_page.dart
// Halaman utama Asisten AI: status server lokal, Setup AI, dan menu fitur AI.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'package:lisku/pages/ai_chat_page.dart';
import 'package:lisku/pages/ai_insight_page.dart';
import 'package:lisku/pages/ai_knowledge_page.dart';
import 'package:lisku/pages/ai_settings_page.dart';
import 'package:lisku/services/ai_personas.dart';
import 'package:lisku/services/ai_server_controller.dart';
import 'package:lisku/services/termux_service.dart';

class AiAssistantPage extends StatefulWidget {
  const AiAssistantPage({super.key});

  @override
  State<AiAssistantPage> createState() => _AiAssistantPageState();
}

class _AiAssistantPageState extends State<AiAssistantPage> {
  late final AiServerController _ai;

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

  @override
  Widget build(BuildContext context) {
    final ai = context.watch<AiServerController>();
    _showNoticeIfAny(ai);

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Asisten AI'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: Listener(
        onPointerDown: (_) => ai.touch(),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            AiStatusCard(ai: ai),
            const SizedBox(height: 16),
            if (ai.state == AiServerState.error) ...[
              AiErrorCard(ai: ai),
              const SizedBox(height: 16),
            ],
            _buildMenu(),
            const SizedBox(height: 16),
            _buildSetupCard(ai),
          ],
        ),
      ),
    );
  }

  void _showNoticeIfAny(AiServerController ai) {
    final notice = ai.takeNotice();
    if (notice == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(notice), duration: const Duration(seconds: 5)),
      );
    });
  }

  Widget _buildMenu() {
    void open(Widget page) => Navigator.push(context, MaterialPageRoute(builder: (_) => page));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Mau dibantu apa?', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        for (final persona in AiPersona.all)
          _menuTile(
            icon: persona.icon,
            color: persona.color,
            title: persona.name,
            subtitle: persona.description,
            onTap: () => open(AiChatPage(initialPersona: persona.key)),
          ),
        _menuTile(
          icon: Icons.lightbulb,
          color: Colors.amber.shade800,
          title: 'Insight',
          subtitle: 'Catatan pribadi yang ikut dipelajari AI',
          onTap: () => open(const AiInsightPage()),
        ),
        _menuTile(
          icon: Icons.library_books,
          color: Colors.deepPurple,
          title: 'Kelola Pengetahuan',
          subtitle: 'Impor e-book PDF, lihat & hapus buku dan catatan',
          onTap: () => open(const AiKnowledgePage()),
        ),
        _menuTile(
          icon: Icons.tune,
          color: Colors.blueGrey,
          title: 'Pengaturan AI',
          subtitle: 'Pilih model Default / Uncensored',
          onTap: () => open(const AiSettingsPage()),
        ),
      ],
    );
  }

  Widget _menuTile({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: ListTile(
        onTap: onTap,
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: color.withValues(alpha: 0.1), shape: BoxShape.circle),
          child: Icon(icon, color: color),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
        trailing: const Icon(Icons.chevron_right),
      ),
    );
  }

  Widget _buildSetupCard(AiServerController ai) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.build_circle, color: Colors.blue),
                SizedBox(width: 8),
                Text('Setup AI', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              ai.setupDone
                  ? 'Setup sudah pernah dijalankan. Jalankan lagi untuk memperbarui llama-cpp atau melanjutkan unduhan model yang terputus.'
                  : 'Sekali saja: memasang llama-cpp di Termux dan mengunduh model (±4,5 GB). Progres terlihat di Termux.',
              style: TextStyle(color: Colors.grey[700], fontSize: 13),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: ai.state == AiServerState.setupRunning ? null : () => _runSetup(ai),
                icon: const Icon(Icons.download),
                label: Text(ai.state == AiServerState.setupRunning ? 'Setup berjalan di Termux...' : 'Setup AI'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _runSetup(AiServerController ai) async {
    final ok = await ensureTermuxPermission(context, ai);
    if (!ok || !mounted) return;
    await ai.runSetup();
  }
}

/// Minta izin RUN_COMMAND dengan penjelasan terlebih dahulu.
Future<bool> ensureTermuxPermission(BuildContext context, AiServerController ai) async {
  final status = await ai.termux.getStatus();
  if (!status.installed) {
    await ai.ensureStarted(); // memunculkan pesan "Termux belum terinstall"
    return false;
  }
  if (status.permissionGranted) return true;
  if (!context.mounted) return false;

  final agree = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Izin Termux'),
      content: const Text(
        'Asisten AI Lisku berjalan sepenuhnya di HP kamu lewat Termux.\n\n'
        'Lisku butuh izin "Run commands in Termux environment" untuk:\n'
        '• memasang llama-cpp & mengunduh model (Setup AI)\n'
        '• menyalakan AI saat halaman AI dibuka\n'
        '• mematikan AI saat tidak dipakai agar RAM bebas\n\n'
        'Lisku tidak menjalankan perintah lain di Termux.',
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Nanti')),
        ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Beri Izin')),
      ],
    ),
  );
  if (agree != true) return false;
  return ai.requestPermission();
}

class AiStatusCard extends StatelessWidget {
  final AiServerController ai;

  const AiStatusCard({super.key, required this.ai});

  @override
  Widget build(BuildContext context) {
    final (IconData icon, String title, List<Color> colors) = switch (ai.state) {
      AiServerState.ready => (Icons.check_circle, 'AI siap dipakai', [Colors.green, Colors.teal]),
      AiServerState.starting => (Icons.power_settings_new, ai.progress.isEmpty ? 'Menyalakan AI...' : ai.progress, [Colors.blue, Colors.indigo]),
      AiServerState.stopping => (Icons.power_off, 'Mematikan AI...', [Colors.blueGrey, Colors.grey]),
      AiServerState.setupRunning => (Icons.download, 'Setup berjalan di Termux...', [Colors.orange, Colors.deepOrange]),
      AiServerState.error => (Icons.error_outline, 'AI belum bisa dipakai', [Colors.red, Colors.redAccent]),
      AiServerState.idle => (Icons.power_settings_new, 'AI mati (hemat RAM)', [Colors.blueGrey, Colors.blueGrey.shade700]),
    };
    final busy = ai.state == AiServerState.starting ||
        ai.state == AiServerState.stopping ||
        ai.state == AiServerState.setupRunning;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: colors, begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(color: colors.first.withValues(alpha: 0.3), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Row(
        children: [
          busy
              ? const SizedBox(
                  width: 36,
                  height: 36,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3),
                )
              : Icon(icon, color: Colors.white, size: 36),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(
                  'Model: ${AiModelChoice.label(ai.modelChoice)}',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 13),
                ),
              ],
            ),
          ),
          if (ai.state == AiServerState.idle || ai.state == AiServerState.error)
            IconButton(
              tooltip: 'Nyalakan',
              icon: const Icon(Icons.play_circle_fill, color: Colors.white, size: 32),
              onPressed: () async {
                if (await ensureTermuxPermission(context, ai)) ai.ensureStarted();
              },
            ),
          if (ai.state == AiServerState.ready)
            IconButton(
              tooltip: 'Matikan',
              icon: const Icon(Icons.stop_circle, color: Colors.white, size: 32),
              onPressed: ai.stop,
            ),
        ],
      ),
    );
  }
}

class AiErrorCard extends StatelessWidget {
  final AiServerController ai;

  const AiErrorCard({super.key, required this.ai});

  @override
  Widget build(BuildContext context) {
    final kind = ai.errorKind;
    return Card(
      color: Colors.red[50],
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
        side: BorderSide(color: Colors.red.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(ai.errorMessage, style: TextStyle(color: Colors.red[900], fontSize: 14)),
            if (kind == AiErrorKind.externalAppsDisabled) ...[
              const SizedBox(height: 12),
              _CommandBox(command: allowExternalAppsCommand),
            ],
            if (ai.errorDetail.isNotEmpty && kind != AiErrorKind.externalAppsDisabled)
              Theme(
                data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  title: const Text('Detail teknis', style: TextStyle(fontSize: 13)),
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(8),
                      color: Colors.black87,
                      child: SelectableText(
                        ai.errorDetail,
                        style: const TextStyle(color: Colors.greenAccent, fontFamily: 'monospace', fontSize: 11),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 4, children: _actions(context, kind)),
          ],
        ),
      ),
    );
  }

  List<Widget> _actions(BuildContext context, AiErrorKind? kind) {
    switch (kind) {
      case AiErrorKind.permissionNeeded:
        return [
          ElevatedButton(
            onPressed: () async {
              if (await ensureTermuxPermission(context, ai)) ai.ensureStarted();
            },
            child: const Text('Beri Izin'),
          ),
        ];
      case AiErrorKind.permissionDenied:
        return [
          OutlinedButton(onPressed: ai.termux.openAppSettings, child: const Text('Buka Pengaturan')),
          TextButton(onPressed: () => ai.ensureStarted(), child: const Text('Coba lagi')),
        ];
      case AiErrorKind.externalAppsDisabled:
        return [
          OutlinedButton(onPressed: ai.termux.openTermux, child: const Text('Buka Termux')),
          TextButton(onPressed: () => ai.ensureStarted(), child: const Text('Sudah, coba lagi')),
        ];
      case AiErrorKind.termuxMissing:
        return [TextButton(onPressed: () => ai.ensureStarted(), child: const Text('Coba lagi'))];
      case AiErrorKind.notSetup:
        return [];
      default:
        return [
          TextButton(onPressed: () => ai.ensureStarted(force: true), child: const Text('Coba lagi')),
        ];
    }
  }
}

class _CommandBox extends StatelessWidget {
  final String command;

  const _CommandBox({required this.command});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 6, 0, 6),
      decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(8)),
      child: Row(
        children: [
          Expanded(
            child: SelectableText(
              command,
              style: const TextStyle(color: Colors.greenAccent, fontFamily: 'monospace', fontSize: 12),
            ),
          ),
          IconButton(
            tooltip: 'Salin',
            icon: const Icon(Icons.copy, color: Colors.white70, size: 18),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: command));
              ScaffoldMessenger.of(context)
                  .showSnackBar(const SnackBar(content: Text('Perintah disalin')));
            },
          ),
        ],
      ),
    );
  }
}
