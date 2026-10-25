// File: lib/pages/ai_chat_page.dart
// Chat Asisten AI: streaming, animasi "Thinking...", jawaban muncul per kata,
// proses berpikir disimpan tapi tersembunyi (tombol "Lihat proses berpikir").

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'package:lisku/model/ai_chat_message.dart';
import 'package:lisku/pages/ai_knowledge_page.dart';
import 'package:lisku/pages/ai_settings_page.dart';
import 'package:lisku/services/ai_chat_repository.dart';
import 'package:lisku/services/ai_personas.dart';
import 'package:lisku/services/ai_server_controller.dart';
import 'package:lisku/services/knowledge_service.dart';
import 'package:lisku/services/llm_service.dart';

class AiChatPage extends StatefulWidget {
  final String initialPersona;

  const AiChatPage({super.key, this.initialPersona = 'advisor'});

  @override
  State<AiChatPage> createState() => _AiChatPageState();
}

class _AiChatPageState extends State<AiChatPage> {
  late final AiServerController _ai;
  late final KnowledgeService _knowledge;
  final TextEditingController _input = TextEditingController();
  final ScrollController _scroll = ScrollController();

  late AiPersona _persona;
  List<AiChatMessage> _messages = [];
  final Set<String> _openReasoning = {};
  final Set<String> _openCorrection = {};
  final Set<String> _savedInsight = {};
  final Map<String, TextEditingController> _correctionControllers = {};

  // Status streaming
  bool _streaming = false;
  bool _finalizing = false;
  bool _waitingServer = false;
  final StringBuffer _reasoning = StringBuffer();
  final StringBuffer _content = StringBuffer();
  ChatStream? _chatStream;
  List<String> _pendingSources = const [];
  StreamSubscription? _subscription;

  // Tampilan jawaban per kata
  Timer? _revealTimer;
  int _shownWords = 0;
  String? _revealingId;

  @override
  void initState() {
    super.initState();
    _ai = context.read<AiServerController>();
    _knowledge = KnowledgeService(_ai.llm);
    _persona = AiPersona.byKey(widget.initialPersona);
    _loadMessages();
    WidgetsBinding.instance.addPostFrameCallback((_) => _ai.attachPage());
  }

  @override
  void dispose() {
    if (_streaming) _stop();
    _revealTimer?.cancel();
    _subscription?.cancel();
    _input.dispose();
    _scroll.dispose();
    for (final c in _correctionControllers.values) {
      c.dispose();
    }
    _ai.detachPage();
    super.dispose();
  }

  void _loadMessages() {
    _messages = AiChatRepository.messagesFor(_persona.key);
  }

  // ================= KIRIM & STREAMING =================

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty || _streaming) return;
    _input.clear();
    _ai.beginBusy();

    final userMsg = await AiChatRepository.add(AiChatMessage(
      id: AiChatRepository.newId(),
      role: 'user',
      content: text,
      persona: _persona.key,
      createdAt: DateTime.now(),
    ));
    final history = List<AiChatMessage>.from(_messages);

    setState(() {
      _messages.add(userMsg);
      _streaming = true;
      _finalizing = false;
      _waitingServer = !_ai.isReady;
      _reasoning.clear();
      _content.clear();
      _shownWords = 0;
    });
    _scrollToBottom();

    try {
      final ready = await _ai.ensureStarted();
      if (!mounted) return;
      if (!ready) {
        await _finishWithError(text, 'AI belum siap. ${_ai.errorMessage}');
        return;
      }
      setState(() => _waitingServer = false);

      final prompt = await _buildPrompt(history, text);
      if (!mounted || prompt == null) return;
      _pendingSources = prompt.sources;

      _chatStream = _ai.llm.streamChat(prompt.messages);
      _subscription = _chatStream!.stream.listen(
        (delta) {
          _ai.touch();
          if (delta.reasoning.isNotEmpty) _reasoning.write(delta.reasoning);
          if (delta.content.isNotEmpty) {
            _content.write(delta.content);
            _startReveal();
          }
          if (mounted) setState(() {});
        },
        onError: (e) => _finishWithError(text, '$e'),
        onDone: () => _finishStream(text, prompt.sources),
        cancelOnError: true,
      );
    } catch (e) {
      await _finishWithError(text, '$e');
    }
  }

  /// Prompt + daftar sumber. Guru e-book: ambil 3 potongan termirip sebagai konteks.
  Future<_Prompt?> _buildPrompt(List<AiChatMessage> history, String text) async {
    if (!_persona.usesKnowledge) {
      return _Prompt(
        AiChatRepository.buildPrompt(persona: _persona, history: history, userText: text),
        const [],
      );
    }

    if (KnowledgeService.isEmpty) {
      _content.write('Belum ada buku atau catatan untuk dipelajari. Impor PDF di '
          '"Kelola Pengetahuan" atau tambahkan catatan di "Insight", lalu tanya lagi.');
      await _finishStream(text, const []);
      return null;
    }
    if (!await _ai.ensureEmbedReady()) {
      await _finishWithError(text, 'Server embedding (port 8081) belum siap. Coba lagi sebentar.');
      return null;
    }
    final retrieved = await _knowledge.retrieve(text);
    return _Prompt(
      // Konteks buku sudah besar, jadi riwayat chat tidak ikut dikirim.
      AiChatRepository.buildPrompt(
        persona: _persona,
        history: const [],
        userText: text,
        context: retrieved.promptText,
      ),
      retrieved.sourceLabels,
    );
  }

  Future<void> _finishStream(String question, List<String> sources, {bool stopped = false}) async {
    if (!_streaming || _finalizing) return;
    _finalizing = true;
    var content = _content.toString().trim();
    if (content.isEmpty && !stopped) {
      content = 'Model tidak memberi jawaban. Coba ulangi pertanyaannya.';
    }
    if (stopped) content = content.isEmpty ? '(dihentikan)' : '$content …';

    final msg = await AiChatRepository.add(AiChatMessage(
      id: AiChatRepository.newId(),
      role: 'assistant',
      content: content,
      reasoning: _reasoning.toString().trim(),
      persona: _persona.key,
      createdAt: DateTime.now(),
      sources: sources,
      question: question,
      model: _ai.modelChoice,
    ));
    _endBusy();
    if (!mounted) return;
    setState(() {
      _streaming = false;
      _messages.add(msg);
      _revealingId = msg.id;
    });
    _startReveal();
  }

  Future<void> _finishWithError(String question, String error) async {
    if (!_streaming || _finalizing) return;
    _finalizing = true;
    final msg = await AiChatRepository.add(AiChatMessage(
      id: AiChatRepository.newId(),
      role: 'assistant',
      content: error,
      reasoning: _reasoning.toString().trim(),
      persona: _persona.key,
      createdAt: DateTime.now(),
      isError: true,
      question: question,
    ));
    _endBusy();
    if (!mounted) return;
    setState(() {
      _streaming = false;
      _waitingServer = false;
      _messages.add(msg);
    });
    _scrollToBottom();
  }

  void _endBusy() {
    _subscription = null;
    _chatStream = null;
    _ai.endBusy();
  }

  void _stop() {
    _subscription?.cancel();
    _chatStream?.cancel();
    _finishStream(_messages.isNotEmpty ? _messages.last.content : '', _pendingSources, stopped: true);
  }

  // ================= TAMPILKAN PER KATA =================

  static final RegExp _wordPattern = RegExp(r'\s*\S+');

  void _startReveal() {
    _revealTimer ??= Timer.periodic(const Duration(milliseconds: 35), (_) => _revealTick());
  }

  String get _revealSource {
    if (_streaming) return _content.toString();
    final msg = _messages.where((m) => m.id == _revealingId);
    return msg.isEmpty ? '' : msg.first.content;
  }

  void _revealTick() {
    final total = _wordPattern.allMatches(_revealSource).length;
    if (_shownWords < total) {
      // Kejar ketertinggalan bila model lebih cepat dari animasi.
      final lag = total - _shownWords;
      _shownWords += lag > 30 ? lag ~/ 6 : 1;
      if (mounted) setState(() {});
      _scrollToBottom();
    } else if (!_streaming) {
      _revealTimer?.cancel();
      _revealTimer = null;
      if (mounted) setState(() => _revealingId = null);
    }
  }

  String _visibleWords(String text) {
    final matches = _wordPattern.allMatches(text).take(_shownWords);
    return matches.map((m) => m.group(0)).join();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    });
  }

  // ================= UI =================

  @override
  Widget build(BuildContext context) {
    final ai = context.watch<AiServerController>();
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Chat AI'),
        backgroundColor: _persona.color,
        foregroundColor: Colors.white,
        actions: [
          if (_persona.usesKnowledge)
            IconButton(
              tooltip: 'Kelola Pengetahuan',
              icon: const Icon(Icons.library_books),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AiKnowledgePage()),
              ),
            ),
          IconButton(
            tooltip: 'Pengaturan AI',
            icon: const Icon(Icons.tune),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AiSettingsPage()),
            ),
          ),
          PopupMenuButton<String>(
            onSelected: (v) {
              if (v == 'clear') _confirmClear();
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'clear', child: Text('Hapus riwayat peran ini')),
            ],
          ),
        ],
      ),
      body: Listener(
        onPointerDown: (_) => ai.touch(),
        child: Column(
          children: [
            _buildPersonaSelector(),
            _buildServerBanner(ai),
            Expanded(child: _buildMessageList()),
            _buildInput(),
          ],
        ),
      ),
    );
  }

  Widget _buildPersonaSelector() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: AiPersona.all.map((p) {
          final selected = p.key == _persona.key;
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: ChoiceChip(
                showCheckmark: false,
                avatar: Icon(p.icon, size: 16, color: selected ? Colors.white : p.color),
                label: Text(p.name, overflow: TextOverflow.ellipsis),
                labelStyle: TextStyle(
                  fontSize: 12,
                  color: selected ? Colors.white : Colors.grey[800],
                  fontWeight: FontWeight.w600,
                ),
                selected: selected,
                selectedColor: p.color,
                onSelected: _streaming
                    ? null
                    : (_) => setState(() {
                          _persona = p;
                          _loadMessages();
                          _scrollToBottom();
                        }),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildServerBanner(AiServerController ai) {
    if (ai.state == AiServerState.starting || ai.state == AiServerState.stopping) {
      return Container(
        width: double.infinity,
        color: Colors.blue[50],
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                ai.state == AiServerState.stopping
                    ? 'Mematikan AI...'
                    : (ai.progress.isEmpty ? 'Menyalakan AI...' : ai.progress),
                style: TextStyle(color: Colors.blue[900], fontSize: 13),
              ),
            ),
          ],
        ),
      );
    }
    if (ai.state == AiServerState.error) {
      return Container(
        width: double.infinity,
        color: Colors.red[50],
        padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
        child: Row(
          children: [
            Icon(Icons.error_outline, color: Colors.red[700], size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(ai.errorMessage, style: TextStyle(color: Colors.red[900], fontSize: 12)),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).maybePop(),
              child: const Text('Perbaiki'),
            ),
          ],
        ),
      );
    }
    if (ai.state == AiServerState.idle && !_streaming) {
      return Container(
        width: double.infinity,
        color: Colors.blueGrey[50],
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: Text(
          'AI dimatikan untuk menghemat RAM. Kirim pesan untuk menyalakannya lagi.',
          style: TextStyle(color: Colors.blueGrey[700], fontSize: 12),
        ),
      );
    }
    return const SizedBox.shrink();
  }

  Widget _buildMessageList() {
    final itemCount = _messages.length + (_streaming ? 1 : 0);
    if (itemCount == 0) return _buildEmptyState();
    return ListView.builder(
      controller: _scroll,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 20),
      itemCount: itemCount,
      itemBuilder: (context, index) {
        if (index == _messages.length) return _buildStreamingBubble();
        final msg = _messages[index];
        return msg.isUser ? _buildUserBubble(msg) : _buildAssistantBubble(msg);
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 32,
              backgroundColor: _persona.color.withValues(alpha: 0.1),
              child: Icon(_persona.icon, color: _persona.color, size: 32),
            ),
            const SizedBox(height: 12),
            Text(_persona.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(_persona.description,
                textAlign: TextAlign.center, style: TextStyle(color: Colors.grey[600])),
            const SizedBox(height: 12),
            Text(_persona.hint,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[500], fontStyle: FontStyle.italic, fontSize: 13)),
          ],
        ),
      ),
    );
  }

  Widget _buildUserBubble(AiChatMessage msg) {
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10, left: 48),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: _persona.color,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(15),
            topRight: Radius.circular(15),
            bottomLeft: Radius.circular(15),
            bottomRight: Radius.circular(4),
          ),
        ),
        child: SelectableText(msg.content, style: const TextStyle(color: Colors.white, fontSize: 15)),
      ),
    );
  }

  Widget _assistantContainer({required Widget child, bool error = false}) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10, right: 32),
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
        decoration: BoxDecoration(
          color: error ? Colors.red[50] : Colors.white,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(15),
            topRight: Radius.circular(15),
            bottomLeft: Radius.circular(4),
            bottomRight: Radius.circular(15),
          ),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 6, offset: const Offset(0, 2)),
          ],
        ),
        child: child,
      ),
    );
  }

  Widget _buildStreamingBubble() {
    if (_waitingServer) {
      return _assistantContainer(
        child: const Padding(
          padding: EdgeInsets.only(bottom: 6),
          child: ThinkingIndicator(label: 'Menyalakan AI'),
        ),
      );
    }
    final content = _content.toString();
    if (content.trim().isEmpty) {
      return _assistantContainer(
        child: const Padding(
          padding: EdgeInsets.only(bottom: 6),
          child: ThinkingIndicator(),
        ),
      );
    }
    return _assistantContainer(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: FormattedText(_visibleWords(content)),
      ),
    );
  }

  Widget _buildAssistantBubble(AiChatMessage msg) {
    final revealing = msg.id == _revealingId;
    final text = revealing ? _visibleWords(msg.content) : msg.content;
    final showReasoning = _openReasoning.contains(msg.id);

    return _assistantContainer(
      error: msg.isError,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (msg.isError)
            Row(children: [
              Icon(Icons.error_outline, size: 16, color: Colors.red[700]),
              const SizedBox(width: 6),
              Expanded(child: Text(text, style: TextStyle(color: Colors.red[900]))),
            ])
          else
            FormattedText(text),
          if (!revealing) ..._buildAssistantFooter(msg, showReasoning),
        ],
      ),
    );
  }

  List<Widget> _buildAssistantFooter(AiChatMessage msg, bool showReasoning) {
    final showCorrection = _openCorrection.contains(msg.id);
    return [
      if (msg.sources.isNotEmpty)
        Container(
          width: double.infinity,
          margin: const EdgeInsets.only(top: 8),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.deepPurple[50],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Sumber',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.deepPurple[700])),
              for (final source in msg.sources)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(source, style: TextStyle(fontSize: 12, color: Colors.deepPurple[900])),
                ),
            ],
          ),
        ),
      if (showReasoning && msg.reasoning.isNotEmpty)
        Container(
          width: double.infinity,
          margin: const EdgeInsets.only(top: 8),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(8),
            border: Border(left: BorderSide(color: Colors.grey.shade400, width: 3)),
          ),
          child: SelectableText(
            msg.reasoning,
            style: TextStyle(color: Colors.grey[700], fontSize: 12, fontStyle: FontStyle.italic),
          ),
        ),
      Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          if (msg.reasoning.isNotEmpty)
            _SmallButton(
              icon: showReasoning ? Icons.expand_less : Icons.lightbulb_outline,
              label: showReasoning ? 'Sembunyikan proses berpikir' : 'Lihat proses berpikir',
              onTap: () => setState(() {
                showReasoning ? _openReasoning.remove(msg.id) : _openReasoning.add(msg.id);
              }),
            ),
          if (!msg.isError)
            _SmallButton(
              icon: _savedInsight.contains(msg.id) ? Icons.check : Icons.bookmark_add_outlined,
              label: _savedInsight.contains(msg.id) ? 'Tersimpan' : 'Simpan sebagai insight',
              onTap: () => _saveAsInsight(msg),
            ),
          if (!msg.isError)
            _SmallButton(
              icon: Icons.edit_note,
              label: 'Koreksi',
              onTap: () => setState(() {
                showCorrection ? _openCorrection.remove(msg.id) : _openCorrection.add(msg.id);
              }),
            ),
          if (!msg.isError)
            _SmallButton(
              icon: Icons.copy,
              label: 'Salin',
              onTap: () {
                Clipboard.setData(ClipboardData(text: msg.content));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Jawaban disalin'), duration: Duration(seconds: 1)),
                );
              },
            ),
        ],
      ),
      if (showCorrection) _buildCorrectionField(msg),
    ];
  }

  Widget _buildCorrectionField(AiChatMessage msg) {
    final controller = _correctionControllers.putIfAbsent(msg.id, TextEditingController.new);
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              minLines: 1,
              maxLines: 4,
              onChanged: (_) => _ai.touch(),
              style: const TextStyle(fontSize: 13),
              decoration: InputDecoration(
                isDense: true,
                hintText: 'Tulis koreksi: jawaban yang benar...',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
          IconButton(
            tooltip: 'Simpan koreksi',
            icon: const Icon(Icons.save, color: Colors.deepPurple),
            onPressed: () => _saveCorrection(msg, controller),
          ),
        ],
      ),
    );
  }

  Future<void> _saveAsInsight(AiChatMessage msg) async {
    if (_savedInsight.contains(msg.id)) return;
    final question = msg.question ?? '';
    await _saveNote(
      title: question.isEmpty ? '' : 'Insight: $question',
      text: question.isEmpty ? msg.content : 'Pertanyaan: $question\n\nJawaban: ${msg.content}',
      onSaved: () => _savedInsight.add(msg.id),
      successText: 'Disimpan sebagai insight',
    );
  }

  Future<void> _saveCorrection(AiChatMessage msg, TextEditingController controller) async {
    final correction = controller.text.trim();
    if (correction.isEmpty) return;
    final question = msg.question ?? '';
    await _saveNote(
      title: 'Koreksi: ${question.isEmpty ? 'jawaban AI' : question}',
      text: 'Pertanyaan: $question\n'
          'Koreksi dari pengguna (lebih benar dari jawaban AI sebelumnya): $correction',
      onSaved: () {
        controller.clear();
        _openCorrection.remove(msg.id);
      },
      successText: 'Koreksi disimpan sebagai insight',
    );
  }

  Future<void> _saveNote({
    required String title,
    required String text,
    required VoidCallback onSaved,
    required String successText,
  }) async {
    final messenger = ScaffoldMessenger.of(context);
    _ai.beginBusy();
    try {
      if (!await _ai.ensureEmbedReady()) {
        throw KnowledgeException('Server embedding belum siap. ${_ai.errorMessage}');
      }
      await _knowledge.addNote(title: title, text: text);
      if (mounted) setState(onSaved);
      messenger.showSnackBar(SnackBar(content: Text(successText)));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      _ai.endBusy();
    }
  }

  Widget _buildInput() {
    return Container(
      padding: EdgeInsets.fromLTRB(12, 8, 8, 8 + MediaQuery.of(context).padding.bottom),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 8, offset: const Offset(0, -2)),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: TextField(
              controller: _input,
              minLines: 1,
              maxLines: 5,
              textCapitalization: TextCapitalization.sentences,
              onChanged: (_) => _ai.touch(),
              decoration: InputDecoration(
                hintText: 'Tulis pesan untuk ${_persona.name}...',
                filled: true,
                fillColor: Colors.grey[100],
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),
          _streaming
              ? IconButton.filled(
                  tooltip: 'Hentikan',
                  onPressed: _waitingServer ? null : _stop,
                  style: IconButton.styleFrom(backgroundColor: Colors.red),
                  icon: const Icon(Icons.stop),
                )
              : IconButton.filled(
                  tooltip: 'Kirim',
                  onPressed: _send,
                  style: IconButton.styleFrom(backgroundColor: _persona.color),
                  icon: const Icon(Icons.send),
                ),
        ],
      ),
    );
  }

  Future<void> _confirmClear() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus riwayat'),
        content: Text('Hapus semua pesan untuk peran ${_persona.name}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Hapus', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await AiChatRepository.clear(_persona.key);
    setState(_loadMessages);
  }
}

class _Prompt {
  final List<Map<String, String>> messages;
  final List<String> sources;

  _Prompt(this.messages, this.sources);
}

class _SmallButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _SmallButton({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: Colors.grey[600]),
            const SizedBox(width: 4),
            Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[700])),
            const SizedBox(width: 6),
          ],
        ),
      ),
    );
  }
}

/// Animasi "Thinking..." tanpa menampilkan isi pikiran model.
class ThinkingIndicator extends StatefulWidget {
  final String label;

  const ThinkingIndicator({super.key, this.label = 'Thinking'});

  @override
  State<ThinkingIndicator> createState() => _ThinkingIndicatorState();
}

class _ThinkingIndicatorState extends State<ThinkingIndicator> with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = _controller.value;
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Transform.rotate(
              angle: t * 6.283,
              child: Icon(Icons.auto_awesome, size: 16, color: Colors.deepPurple[300]),
            ),
            const SizedBox(width: 8),
            Text('${widget.label}...',
                style: TextStyle(color: Colors.grey[700], fontStyle: FontStyle.italic)),
            const SizedBox(width: 6),
            for (var i = 0; i < 3; i++)
              Container(
                width: 6,
                height: 6,
                margin: const EdgeInsets.symmetric(horizontal: 2),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.deepPurple.withValues(alpha: _dotOpacity(t, i)),
                ),
              ),
          ],
        );
      },
    );
  }

  double _dotOpacity(double t, int i) {
    final phase = (t * 3 - i) % 3;
    return phase < 1 ? 0.3 + 0.7 * (1 - (phase - 0.5).abs() * 2) : 0.3;
  }
}

/// Teks jawaban dengan dukungan sederhana **tebal** ala markdown.
class FormattedText extends StatelessWidget {
  final String text;

  const FormattedText(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    final base = TextStyle(color: Colors.grey[900], fontSize: 15, height: 1.4);
    final parts = text.split('**');
    return SelectableText.rich(
      TextSpan(
        style: base,
        children: [
          for (var i = 0; i < parts.length; i++)
            TextSpan(
              text: parts[i],
              style: i.isOdd ? const TextStyle(fontWeight: FontWeight.bold) : null,
            ),
        ],
      ),
    );
  }
}
