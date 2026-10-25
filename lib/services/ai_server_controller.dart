// File: lib/services/ai_server_controller.dart
// Mengatur siklus hidup llama-server di Termux:
// - halaman AI dibuka  -> nyalakan server, polling /health sampai siap
// - app di background / halaman AI tidak dipakai > 2 menit -> matikan (RAM bebas)

import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'package:lisku/services/llm_service.dart';
import 'package:lisku/services/termux_scripts.dart';
import 'package:lisku/services/termux_service.dart';

enum AiServerState { idle, starting, ready, stopping, setupRunning, error }

enum AiErrorKind {
  termuxMissing,
  permissionNeeded,
  permissionDenied,
  externalAppsDisabled,
  notSetup,
  serverFailed,
  modelFailed,
}

class AiModelChoice {
  static const String defaultModel = 'default';
  static const String uncensored = 'uncensored';

  static String label(String choice) =>
      choice == uncensored ? 'Uncensored (Gemma 4 E2B)' : 'Default (Qwen3 1.7B)';
}

class AiServerController extends ChangeNotifier with WidgetsBindingObserver {
  static const Duration idleTimeout = Duration(minutes: 2);
  static const Duration startTimeout = Duration(minutes: 4);
  static const String settingsBoxName = 'ai_settings';

  final TermuxService termux;
  final LlmService llm;

  AiServerController({TermuxService? termux, LlmService? llm})
      : termux = termux ?? TermuxService(),
        llm = llm ?? LlmService();

  Box? _settings;
  AiServerState _state = AiServerState.idle;
  AiErrorKind? _errorKind;
  String _errorMessage = '';
  String _errorDetail = '';
  String _progress = '';
  String? _notice;
  String _modelChoice = AiModelChoice.defaultModel;
  bool _embedReady = false;

  int _attachedPages = 0;
  int _busyCount = 0;
  Timer? _idleTimer;
  Future<bool>? _startFuture;
  int _startGeneration = 0;
  bool _inBackground = false;

  AiServerState get state => _state;
  AiErrorKind? get errorKind => _errorKind;
  String get errorMessage => _errorMessage;
  String get errorDetail => _errorDetail;
  String get progress => _progress;
  String get modelChoice => _modelChoice;
  bool get isReady => _state == AiServerState.ready;
  bool get embedReady => _embedReady;
  bool get setupDone => _settings?.get('setup_done', defaultValue: false) == true;

  /// Pesan satu kali (mis. "kembali ke model default"). Dibaca lalu dihapus.
  String? takeNotice() {
    final n = _notice;
    _notice = null;
    return n;
  }

  Future<void> init() async {
    _settings = await Hive.openBox(settingsBoxName);
    _modelChoice = _settings!.get('model', defaultValue: AiModelChoice.defaultModel) as String;
    WidgetsBinding.instance.addObserver(this);
    notifyListeners();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _idleTimer?.cancel();
    super.dispose();
  }

  // ================= SIKLUS HIDUP =================

  /// Dipanggil di initState halaman AI.
  void attachPage() {
    _attachedPages++;
    touch();
    ensureStarted();
  }

  /// Dipanggil di dispose halaman AI.
  void detachPage() {
    _attachedPages = (_attachedPages - 1).clamp(0, 1 << 20);
    touch();
  }

  /// Tanda halaman AI sedang dipakai (ketik, kirim, scroll, dsb).
  void touch() {
    _idleTimer?.cancel();
    _idleTimer = Timer(idleTimeout, _onIdle);
  }

  /// Selama ada proses (chat streaming / impor) server tidak dimatikan.
  void beginBusy() {
    _busyCount++;
    touch();
  }

  void endBusy() {
    _busyCount = (_busyCount - 1).clamp(0, 1 << 20);
    touch();
  }

  void _onIdle() {
    if (_busyCount > 0) {
      touch();
      return;
    }
    if (_state == AiServerState.ready || _state == AiServerState.starting) {
      debugPrint('🤖 AI idle > ${idleTimeout.inMinutes} menit, mematikan server');
      stop();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
        if (_inBackground) return;
        _inBackground = true;
        touch();
        if (_state == AiServerState.ready || _state == AiServerState.starting) {
          // Cadangan: Termux sendiri yang mematikan server setelah 2 menit,
          // karena timer Dart bisa tidak jalan saat app dibekukan Android.
          final token = DateTime.now().millisecondsSinceEpoch.toString();
          termux
              .runScript(TermuxScripts.delayedStopCommand(token, idleTimeout), waitForResult: false)
              .catchError((_) => const TermuxCommandResult());
        }
        break;
      case AppLifecycleState.resumed:
        if (!_inBackground) return;
        _inBackground = false;
        termux
            .runScript(TermuxScripts.cancelDelayedStop, waitForResult: false)
            .catchError((_) => const TermuxCommandResult());
        touch();
        if (_attachedPages > 0) ensureStarted();
        break;
      default:
        break;
    }
  }

  // ================= START / STOP =================

  /// Nyalakan server jika belum siap. Return true bila server chat siap.
  Future<bool> ensureStarted({bool force = false}) async {
    if (!force && _state == AiServerState.ready) {
      if (await llm.chatHealth() == LlmHealth.ok) return true;
      // Server sudah mati (mis. dimatikan Termux saat app di background).
      _embedReady = false;
      _setState(AiServerState.idle);
    }
    if (_state == AiServerState.setupRunning) return false;
    if (!force && _startFuture != null) return _startFuture!;
    final generation = ++_startGeneration;
    final future = _start(generation, force: force);
    _startFuture = future;
    future.whenComplete(() {
      if (_startGeneration == generation) _startFuture = null;
    });
    return future;
  }

  Future<bool> _start(int generation, {bool force = false, bool isFallback = false}) async {
    _setState(AiServerState.starting, progress: 'Memeriksa Termux...');

    if (!await _checkTermuxReady()) return false;

    // Server mungkin masih menyala dari sesi sebelumnya.
    if (!force && await llm.chatHealth() == LlmHealth.ok) {
      _markReady();
      return true;
    }

    _setState(AiServerState.starting, progress: 'Menyalakan AI...');
    try {
      final result = await termux.runScript(
        TermuxScripts.startCommand,
        label: 'Lisku AI: start',
        timeout: const Duration(seconds: 25),
      );
      if (result.stdout.contains('LISKU_ERR:NOT_SETUP') ||
          result.stdout.contains('LISKU_ERR:NO_LLAMA') ||
          result.exitCode == 3 ||
          result.exitCode == 4) {
        _setError(AiErrorKind.notSetup);
        return false;
      }
    } on TermuxException catch (e) {
      if (e.kind != TermuxErrorKind.timeout) {
        _handleTermuxException(e);
        return false;
      }
      // Hasil tidak kembali: tetap coba polling /health.
    }

    final ok = await _waitForChatServer(generation);
    if (ok) {
      _markReady();
      return true;
    }
    if (generation != _startGeneration) return false;

    // Gagal: periksa log untuk pesan yang jelas.
    final status = await _fetchStatus();
    final log = status?.chatLog ?? '';
    final modelFailed = LlmProcessStatus.looksLikeModelLoadFailure(log);

    if (modelFailed && _modelChoice == AiModelChoice.uncensored && !isFallback) {
      _notice = 'Model uncensored gagal dimuat, jadi Lisku kembali memakai model default.';
      await _saveModelChoice(AiModelChoice.defaultModel);
      await _writeModelChoiceToTermux(AiModelChoice.defaultModel);
      return _start(generation, force: true, isFallback: true);
    }

    _setError(modelFailed ? AiErrorKind.modelFailed : AiErrorKind.serverFailed, detail: log);
    return false;
  }

  /// Polling /health tiap detik. Tiap 10 detik cek apakah proses masih hidup.
  Future<bool> _waitForChatServer(int generation) async {
    final started = DateTime.now();
    var lastProcessCheck = DateTime.now();
    var everLoading = false;

    while (DateTime.now().difference(started) < startTimeout) {
      if (generation != _startGeneration) return false;
      final health = await llm.chatHealth();
      if (health == LlmHealth.ok) return true;
      if (health == LlmHealth.loading && !everLoading) {
        everLoading = true;
        _setState(AiServerState.starting, progress: 'Memuat model ke RAM...');
      }

      if (DateTime.now().difference(lastProcessCheck) > const Duration(seconds: 10)) {
        lastProcessCheck = DateTime.now();
        final status = await _fetchStatus();
        if (status != null && status.notSetup) {
          _setError(AiErrorKind.notSetup);
          return false;
        }
        if (status != null && !status.chatAlive) return false;
        if (status != null && status.chatLog.contains('downloading')) {
          _setState(AiServerState.starting, progress: 'Mengunduh model (sekali saja)...');
        }
      }
      await Future.delayed(const Duration(seconds: 1));
    }
    return false;
  }

  Future<LlmProcessStatus?> _fetchStatus() async {
    try {
      final result = await termux.runScript(
        TermuxScripts.statusCommand,
        label: 'Lisku AI: status',
        timeout: const Duration(seconds: 10),
      );
      return LlmProcessStatus.parse(result.stdout);
    } on TermuxException {
      return null;
    }
  }

  /// Server embedding (port 8081) dipakai untuk RAG & insight.
  Future<bool> ensureEmbedReady() async {
    if (!await ensureStarted()) return false;
    if (_embedReady && await llm.embedHealth() == LlmHealth.ok) return true;
    final started = DateTime.now();
    while (DateTime.now().difference(started) < const Duration(minutes: 2)) {
      if (await llm.embedHealth() == LlmHealth.ok) {
        _embedReady = true;
        notifyListeners();
        return true;
      }
      await Future.delayed(const Duration(seconds: 1));
    }
    return false;
  }

  Future<void> stop() async {
    _startGeneration++;
    _startFuture = null;
    if (_state == AiServerState.setupRunning) return;
    _setState(AiServerState.stopping, progress: 'Mematikan AI...');
    try {
      await termux.runScript(TermuxScripts.stopCommand,
          label: 'Lisku AI: stop', timeout: const Duration(seconds: 10));
    } on TermuxException catch (e) {
      debugPrint('stop AI: $e');
    }
    _embedReady = false;
    _setState(AiServerState.idle);
  }

  // ================= SETUP & MODEL =================

  /// Kirim skrip setup ke sesi foreground Termux (progres terlihat di Termux).
  Future<void> runSetup() async {
    if (!await _checkTermuxReady()) return;
    final script = await TermuxScripts.loadSetupScript(modelChoice: _modelChoice);
    _setState(AiServerState.setupRunning, progress: 'Setup berjalan di Termux...');

    final future = termux.runScript(
      script,
      background: false,
      sessionAction: '0', // sesi baru + buka Termux
      label: 'Lisku AI Setup',
      description: 'Memasang llama-cpp dan mengunduh model',
      timeout: const Duration(hours: 3),
    );
    // Pastikan Termux tampil di depan agar user melihat progres.
    Future.delayed(const Duration(milliseconds: 600), termux.openTermux);

    try {
      final result = await future;
      if (result.ok) {
        await _settings?.put('setup_done', true);
        _setState(AiServerState.idle);
        if (_attachedPages > 0) await ensureStarted(force: true);
      } else {
        _setError(AiErrorKind.notSetup,
            detail: 'Setup berhenti (exit ${result.exitCode}). Lihat pesan di Termux, lalu tekan Setup AI lagi.');
      }
    } on TermuxException catch (e) {
      if (e.kind == TermuxErrorKind.timeout) {
        _setState(AiServerState.idle);
      } else {
        _handleTermuxException(e);
      }
    }
  }

  /// Ganti model: simpan pilihan, tulis ~/.lisku-model, lalu restart server.
  Future<bool> setModel(String choice) async {
    if (choice == _modelChoice && _state == AiServerState.ready) return true;
    await _saveModelChoice(choice);
    if (!await _checkTermuxReady()) return false;
    try {
      await _writeModelChoiceToTermux(choice);
    } on TermuxException catch (e) {
      _handleTermuxException(e);
      return false;
    }
    final ok = await ensureStarted(force: true);
    return ok && _modelChoice == choice;
  }

  Future<void> _saveModelChoice(String choice) async {
    _modelChoice = choice;
    await _settings?.put('model', choice);
    notifyListeners();
  }

  Future<void> _writeModelChoiceToTermux(String choice) async {
    await termux.runScript(TermuxScripts.setModelCommand(choice),
        label: 'Lisku AI: model', timeout: const Duration(seconds: 10));
  }

  // ================= IZIN & ERROR =================

  Future<bool> _checkTermuxReady() async {
    final status = await termux.getStatus();
    if (!status.installed) {
      _setError(AiErrorKind.termuxMissing);
      return false;
    }
    if (!status.permissionGranted) {
      _setError(AiErrorKind.permissionNeeded);
      return false;
    }
    return true;
  }

  /// Dipanggil UI setelah user membaca penjelasan izin.
  Future<bool> requestPermission() async {
    try {
      final granted = await termux.requestPermission();
      if (!granted) {
        _setError(AiErrorKind.permissionDenied);
        return false;
      }
      _clearError();
      return true;
    } on TermuxException catch (e) {
      _handleTermuxException(e);
      return false;
    }
  }

  void _handleTermuxException(TermuxException e) {
    switch (e.kind) {
      case TermuxErrorKind.notInstalled:
        _setError(AiErrorKind.termuxMissing);
        break;
      case TermuxErrorKind.permissionDenied:
        _setError(AiErrorKind.permissionDenied, detail: e.message);
        break;
      case TermuxErrorKind.externalAppsDisabled:
        _setError(AiErrorKind.externalAppsDisabled, detail: e.message);
        break;
      case TermuxErrorKind.timeout:
      case TermuxErrorKind.failed:
        _setError(AiErrorKind.serverFailed, detail: e.message);
        break;
    }
  }

  static String messageFor(AiErrorKind kind) {
    switch (kind) {
      case AiErrorKind.termuxMissing:
        return 'Termux belum terinstall. Pasang Termux dari F-Droid atau GitHub (bukan Play Store), buka sekali, lalu kembali ke sini.';
      case AiErrorKind.permissionNeeded:
        return 'Lisku perlu izin "Run commands in Termux environment" untuk menyalakan AI lokal di Termux.';
      case AiErrorKind.permissionDenied:
        return 'Izin menjalankan perintah Termux ditolak. Aktifkan di Pengaturan > Aplikasi > Lisku > Izin > Izin tambahan.';
      case AiErrorKind.externalAppsDisabled:
        return 'Termux menolak perintah dari aplikasi lain (allow-external-apps belum aktif). Buka Termux lalu jalankan perintah di bawah ini.';
      case AiErrorKind.notSetup:
        return 'AI belum di-setup. Tekan tombol "Setup AI" untuk memasang llama-cpp dan mengunduh model.';
      case AiErrorKind.serverFailed:
        return 'Server AI gagal menyala. Coba lagi, atau jalankan Setup AI ulang.';
      case AiErrorKind.modelFailed:
        return 'Model gagal dimuat. File model mungkin rusak/belum lengkap atau RAM tidak cukup. Jalankan Setup AI lagi.';
    }
  }

  void _markReady() {
    _clearError();
    _setState(AiServerState.ready);
    // Siapkan embedding di belakang layar tanpa memblokir chat.
    llm.embedHealth().then((h) {
      _embedReady = h == LlmHealth.ok;
      notifyListeners();
    });
  }

  void _setError(AiErrorKind kind, {String detail = ''}) {
    _errorKind = kind;
    _errorMessage = messageFor(kind);
    _errorDetail = detail;
    _state = AiServerState.error;
    _progress = '';
    notifyListeners();
  }

  void _clearError() {
    _errorKind = null;
    _errorMessage = '';
    _errorDetail = '';
    if (_state == AiServerState.error) _state = AiServerState.idle;
    notifyListeners();
  }

  void _setState(AiServerState state, {String progress = ''}) {
    _state = state;
    _progress = progress;
    if (state != AiServerState.error) {
      _errorKind = null;
      _errorMessage = '';
      _errorDetail = '';
    }
    notifyListeners();
  }
}
