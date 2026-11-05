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

  Map<String, String> homeScripts() => {
        for (final e in TermuxScripts.homeScripts.entries) e.key: File(e.value).readAsStringSync(),
      };

  test('setup script menulis semua skrip lalu menjalankan setup', () {
    final script = TermuxScripts.buildSetupScript(
      setup: File('termux/setup-lisku-ai.sh').readAsStringSync(),
      scripts: homeScripts(),
      modelChoice: 'default',
    );
    for (final name in TermuxScripts.homeScripts.keys) {
      expect(script, contains('cat > ~/$name'));
    }
    expect(script, contains('echo default > ~/.lisku-model'));
    expect(script.indexOf('cat > ~/start-llm.sh'), lessThan(script.indexOf('Lisku AI - Setup Otomatis')));
    expect(script, contains('--reasoning-format deepseek'));
  });

  test('setup awal tidak mengunduh model uncensored', () {
    final setup = File('termux/setup-lisku-ai.sh').readAsStringSync();
    final downloads = setup.split('\n').where((l) => l.trimLeft().startsWith('download '));
    expect(downloads, hasLength(2));
    expect(downloads.join(), isNot(contains('uncensored')));
    expect(File('termux/download-uncensored.sh').readAsStringSync(),
        contains('download chat-uncensored "TrevorJS/gemma-4-E2B-it-uncensored-GGUF" "Q4_K_M"'));
  });

  test('unduh uncensored menulis ulang skrip lalu menjalankan download-uncensored.sh', () {
    final script = TermuxScripts.buildDownloadUncensoredScript(homeScripts());
    expect(script, contains('cat > ~/lisku-models-lib.sh'));
    expect(script, contains('cat > ~/start-llm.sh'));
    expect(script.trimRight(), endsWith('bash ~/download-uncensored.sh'));
    // Pilihan model baru ditulis aplikasi setelah unduhan sukses.
    expect(script, isNot(contains(TermuxScripts.setModelCommand('uncensored'))));
  });

  test('start-llm tidak memakai -hf untuk model uncensored', () {
    final start = File('termux/start-llm.sh').readAsStringSync();
    expect(start, isNot(contains('TrevorJS')));
    expect(start, contains(TermuxScripts.uncensoredMissingMarker));
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
