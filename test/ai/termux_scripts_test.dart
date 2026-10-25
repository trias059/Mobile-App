import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lisku/services/termux_scripts.dart';

void main() {
  group('TermuxScripts.writeFile', () {
    test('membungkus isi dengan heredoc berkutip', () {
      final out = TermuxScripts.writeFile('~/a.sh', 'echo \$HOME\n');
      expect(out, "cat > ~/a.sh <<'LISKU_EOF'\necho \$HOME\nLISKU_EOF\n");
    });

    test('mengganti delimiter bila bentrok dengan isi', () {
      final out = TermuxScripts.writeFile('~/a.sh', 'x\nLISKU_EOF\ny');
      expect(out, startsWith("cat > ~/a.sh <<'LISKU_EOF_1'\n"));
      expect(out, endsWith('\nLISKU_EOF_1\n'));
    });
  });

  test('setup script menulis semua skrip lalu menjalankan setup', () {
    final script = TermuxScripts.buildSetupScript(
      setup: File('termux/setup-lisku-ai.sh').readAsStringSync(),
      start: File('termux/start-llm.sh').readAsStringSync(),
      stop: File('termux/stop-llm.sh').readAsStringSync(),
      status: File('termux/lisku-status.sh').readAsStringSync(),
      modelChoice: 'uncensored',
    );
    expect(script, contains('cat > ~/start-llm.sh'));
    expect(script, contains('cat > ~/stop-llm.sh'));
    expect(script, contains('cat > ~/lisku-status.sh'));
    expect(script, contains('echo uncensored > ~/.lisku-model'));
    expect(script.indexOf('cat > ~/start-llm.sh'), lessThan(script.indexOf('Lisku AI - Setup Otomatis')));
    expect(script, contains('--reasoning-format deepseek'));
  });

  test('pilihan model selain uncensored jadi default', () {
    expect(TermuxScripts.setModelCommand('rm -rf /'), 'echo default > ~/.lisku-model');
  });

  test('parse status lisku-status.sh', () {
    const stdout = 'CHAT_ALIVE=0\nEMBED_ALIVE=1\nMODEL=uncensored\n---CHAT_LOG---\n'
        'llama_model_load: error loading model: unknown model architecture\n'
        '---EMBED_LOG---\nserver is listening\n';
    final status = LlmProcessStatus.parse(stdout);
    expect(status.chatAlive, isFalse);
    expect(status.embedAlive, isTrue);
    expect(status.model, 'uncensored');
    expect(status.chatLog, contains('error loading model'));
    expect(status.embedLog, 'server is listening');
    expect(LlmProcessStatus.looksLikeModelLoadFailure(status.chatLog), isTrue);
    expect(LlmProcessStatus.parse('LISKU_ERR:NOT_SETUP').notSetup, isTrue);
  });
}
