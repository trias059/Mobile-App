// File: lib/services/termux_scripts.dart
// Skrip bash yang dikirim inline ke Termux. Sumber skrip ada di folder
// termux/ (dibundel sebagai asset) agar repo dan aplikasi selalu sama.

import 'package:flutter/services.dart' show rootBundle;

class TermuxScripts {
  static const String setupAsset = 'termux/setup-lisku-ai.sh';
  static const String startAsset = 'termux/start-llm.sh';
  static const String stopAsset = 'termux/stop-llm.sh';
  static const String statusAsset = 'termux/lisku-status.sh';

  static const String startCommand =
      'if [ -f ~/start-llm.sh ]; then bash ~/start-llm.sh; else echo LISKU_ERR:NOT_SETUP; exit 3; fi';
  static const String stopCommand =
      'if [ -f ~/stop-llm.sh ]; then bash ~/stop-llm.sh; else pkill llama-server; fi';
  static const String statusCommand =
      'if [ -f ~/lisku-status.sh ]; then bash ~/lisku-status.sh; else echo LISKU_ERR:NOT_SETUP; fi';

  /// Skrip setup lengkap: tulis start/stop/status ke ~ lalu jalankan setup.
  static Future<String> loadSetupScript({required String modelChoice}) async {
    return buildSetupScript(
      setup: await rootBundle.loadString(setupAsset),
      start: await rootBundle.loadString(startAsset),
      stop: await rootBundle.loadString(stopAsset),
      status: await rootBundle.loadString(statusAsset),
      modelChoice: modelChoice,
    );
  }

  static String buildSetupScript({
    required String setup,
    required String start,
    required String stop,
    required String status,
    required String modelChoice,
  }) {
    final buffer = StringBuffer()
      ..writeln('mkdir -p ~/models ~/llm-logs')
      ..write(writeFile('~/start-llm.sh', start))
      ..write(writeFile('~/stop-llm.sh', stop))
      ..write(writeFile('~/lisku-status.sh', status))
      ..writeln('chmod +x ~/start-llm.sh ~/stop-llm.sh ~/lisku-status.sh')
      ..writeln(setModelCommand(modelChoice))
      ..writeln(setup);
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
