// File: lib/services/termux_scripts.dart
// Skrip bash yang dikirim inline ke Termux. Sumber skrip ada di folder
// termux/ (dibundel sebagai asset) agar repo dan aplikasi selalu sama.

import 'package:flutter/services.dart' show rootBundle;

class TermuxScripts {
  static const String setupAsset = 'termux/setup-lisku-ai.sh';
  static const String startAsset = 'termux/start-llm.sh';
  static const String stopAsset = 'termux/stop-llm.sh';
  static const String statusAsset = 'termux/lisku-status.sh';
  static const String modelsLibAsset = 'termux/lisku-models-lib.sh';
  static const String downloadUncensoredAsset = 'termux/download-uncensored.sh';

  /// Skrip yang ditulis aplikasi ke ~ (nama file di Termux -> asset).
  static const Map<String, String> homeScripts = {
    'start-llm.sh': startAsset,
    'stop-llm.sh': stopAsset,
    'lisku-status.sh': statusAsset,
    'lisku-models-lib.sh': modelsLibAsset,
    'download-uncensored.sh': downloadUncensoredAsset,
  };

  static const String startCommand =
      'if [ -f ~/start-llm.sh ]; then bash ~/start-llm.sh; else echo LISKU_ERR:NOT_SETUP; exit 3; fi';
  static const String stopCommand =
      'if [ -f ~/stop-llm.sh ]; then bash ~/stop-llm.sh; else pkill llama-server; fi';
  static const String statusCommand =
      'if [ -f ~/lisku-status.sh ]; then bash ~/lisku-status.sh; else echo LISKU_ERR:NOT_SETUP; fi';

  /// Penanda dari start-llm.sh: uncensored dipilih tapi file belum lengkap,
  /// server dinyalakan dengan model default.
  static const String uncensoredMissingMarker = 'LISKU_WARN:UNCENSORED_MISSING';

  /// Cek apakah model uncensored sudah terunduh lengkap (tanpa penanda .lisku-partial).
  static const String uncensoredCheckCommand =
      'n=\$(cat ~/models/chat-uncensored.path 2>/dev/null); '
      'if [ -n "\$n" ] && [ -f ~/models/"\$n" ] && [ ! -f ~/models/"\$n".lisku-partial ]; '
      'then echo LISKU_UNCENSORED:READY; else echo LISKU_UNCENSORED:MISSING; fi';

  static Future<Map<String, String>> _loadHomeScripts() async {
    return {
      for (final entry in homeScripts.entries) entry.key: await rootBundle.loadString(entry.value),
    };
  }

  /// Skrip setup lengkap: tulis skrip ke ~ lalu jalankan setup.
  static Future<String> loadSetupScript({required String modelChoice}) async {
    return buildSetupScript(
      setup: await rootBundle.loadString(setupAsset),
      scripts: await _loadHomeScripts(),
      modelChoice: modelChoice,
    );
  }

  /// Unduh model uncensored: tulis ulang skrip ke ~ (agar start-llm.sh ikut
  /// versi terbaru) lalu jalankan ~/download-uncensored.sh.
  static Future<String> loadDownloadUncensoredScript() async {
    return buildDownloadUncensoredScript(await _loadHomeScripts());
  }

  static String buildSetupScript({
    required String setup,
    required Map<String, String> scripts,
    required String modelChoice,
  }) {
    final buffer = StringBuffer()
      ..write(writeHomeScripts(scripts))
      ..writeln(setModelCommand(modelChoice))
      ..writeln(setup);
    return buffer.toString();
  }

  static String buildDownloadUncensoredScript(Map<String, String> scripts) {
    final buffer = StringBuffer()
      ..write(writeHomeScripts(scripts))
      ..writeln('bash ~/download-uncensored.sh');
    return buffer.toString();
  }

  static String writeHomeScripts(Map<String, String> scripts) {
    final buffer = StringBuffer()..writeln('mkdir -p ~/models ~/llm-logs');
    for (final entry in scripts.entries) {
      buffer.write(writeFile('~/${entry.key}', entry.value));
    }
    buffer.writeln('chmod +x ${scripts.keys.map((name) => '~/$name').join(' ')}');
    return buffer.toString();
  }

  /// Heredoc dengan delimiter yang dijamin tidak muncul di isi file.
  static String writeFile(String path, String content) {
    var delimiter = 'LISKU_EOF';
    var i = 0;
    while (content.split('\n').any((line) => line.trim() == delimiter)) {
      delimiter = 'LISKU_EOF_${++i}';
    }
    final body = content.endsWith('\n') ? content : '$content\n';
    return "cat > $path <<'$delimiter'\n$body$delimiter\n";
  }

  static String setModelCommand(String modelChoice) {
    final safe = modelChoice == 'uncensored' ? 'uncensored' : 'default';
    return 'echo $safe > ~/.lisku-model';
  }

  /// Matikan server setelah [delay] kecuali dibatalkan [cancelDelayedStop].
  /// Dijalankan oleh Termux sendiri, jadi tetap jalan walau Lisku dibekukan
  /// Android saat di background.
  static String delayedStopCommand(String token, Duration delay) {
    return 'mkdir -p ~/llm-logs; echo $token > ~/llm-logs/stop-token; '
        "nohup bash -c 'sleep ${delay.inSeconds}; "
        '[ "\$(cat ~/llm-logs/stop-token 2>/dev/null)" = "$token" ] && '
        "bash ~/stop-llm.sh' >/dev/null 2>&1 </dev/null &";
  }

  static const String cancelDelayedStop = 'mkdir -p ~/llm-logs; echo cancel > ~/llm-logs/stop-token';
}

/// Hasil parsing keluaran `lisku-status.sh`.
class LlmProcessStatus {
  final bool chatAlive;
  final bool embedAlive;
  final String model;
  final String chatLog;
  final String embedLog;
  final bool notSetup;

  const LlmProcessStatus({
    required this.chatAlive,
    required this.embedAlive,
    required this.model,
    required this.chatLog,
    required this.embedLog,
    this.notSetup = false,
  });

  factory LlmProcessStatus.parse(String stdout) {
    if (stdout.contains('LISKU_ERR:NOT_SETUP')) {
      return const LlmProcessStatus(
          chatAlive: false, embedAlive: false, model: '', chatLog: '', embedLog: '', notSetup: true);
    }
    final chatIdx = stdout.indexOf('---CHAT_LOG---');
    final embedIdx = stdout.indexOf('---EMBED_LOG---');
    final header = chatIdx >= 0 ? stdout.substring(0, chatIdx) : stdout;
    String value(String key) {
      final match = RegExp('^$key=(.*)\$', multiLine: true).firstMatch(header);
      return match?.group(1)?.trim() ?? '';
    }

    return LlmProcessStatus(
      chatAlive: value('CHAT_ALIVE') == '1',
      embedAlive: value('EMBED_ALIVE') == '1',
      model: value('MODEL'),
      chatLog: chatIdx >= 0
          ? stdout.substring(chatIdx + 14, embedIdx > chatIdx ? embedIdx : stdout.length).trim()
          : '',
      embedLog: embedIdx >= 0 ? stdout.substring(embedIdx + 15).trim() : '',
    );
  }

  /// Log llama.cpp menandakan model gagal dimuat.
  static bool looksLikeModelLoadFailure(String log) {
    final lower = log.toLowerCase();
    return lower.contains('failed to load model') ||
        lower.contains('error loading model') ||
        lower.contains('unknown model architecture') ||
        (lower.contains('failed to load') && lower.contains('model')) ||
        lower.contains('unable to load model');
  }
}
