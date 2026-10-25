// File: lib/services/termux_service.dart
// Jembatan Dart <-> Termux lewat platform channel (RUN_COMMAND intent).
// Sisi native: android/app/src/main/kotlin/com/example/lisku/TermuxBridge.kt

import 'package:flutter/services.dart';

const String termuxBash = '/data/data/com.termux/files/usr/bin/bash';
const String termuxHome = '/data/data/com.termux/files/home';

/// Perintah yang harus dijalankan user di Termux agar aplikasi lain
/// (Lisku) boleh mengirim perintah.
const String allowExternalAppsCommand =
    'mkdir -p ~/.termux && echo "allow-external-apps=true" >> ~/.termux/termux.properties && termux-reload-settings';

class TermuxStatus {
  final bool installed;
  final bool permissionGranted;
  final bool canAskPermission;

  const TermuxStatus({
    required this.installed,
    required this.permissionGranted,
    required this.canAskPermission,
  });
}

enum TermuxErrorKind { notInstalled, permissionDenied, externalAppsDisabled, timeout, failed }

class TermuxException implements Exception {
  final TermuxErrorKind kind;
  final String message;

  TermuxException(this.kind, this.message);

  @override
  String toString() => 'TermuxException($kind): $message';
}

class TermuxCommandResult {
  final String stdout;
  final String stderr;
  final int? exitCode;
  final int? err;
  final String errmsg;

  const TermuxCommandResult({
    this.stdout = '',
    this.stderr = '',
    this.exitCode,
    this.err,
    this.errmsg = '',
  });

  factory TermuxCommandResult.fromMap(Map<dynamic, dynamic> map) {
    return TermuxCommandResult(
      stdout: (map['stdout'] as String?) ?? '',
      stderr: (map['stderr'] as String?) ?? '',
      exitCode: map['exitCode'] as int?,
      err: map['err'] as int?,
      errmsg: (map['errmsg'] as String?) ?? '',
    );
  }

  /// Termux memakai err = -1 (Errno.ERRNO_SUCCESS) untuk sukses.
  bool get hasTermuxError => err != null && err != -1;

  bool get isExternalAppsDisabled =>
      errmsg.contains('allow-external-apps') || stderr.contains('allow-external-apps');

  bool get ok => !hasTermuxError && (exitCode == null || exitCode == 0);
}

class TermuxService {
  static const MethodChannel _channel = MethodChannel('com.example.lisku/termux');

  Future<TermuxStatus> getStatus() async {
    try {
      final map = await _channel.invokeMapMethod<String, dynamic>('getStatus') ?? {};
      return TermuxStatus(
        installed: map['installed'] == true,
        permissionGranted: map['permissionGranted'] == true,
        canAskPermission: map['canAskPermission'] == true,
      );
    } on MissingPluginException {
      // Platform selain Android (mis. saat test / desktop).
      return const TermuxStatus(installed: false, permissionGranted: false, canAskPermission: false);
    }
  }

  /// Menampilkan dialog izin sistem. Return true jika diizinkan.
  Future<bool> requestPermission() async {
    try {
      return await _channel.invokeMethod<bool>('requestPermission') ?? false;
    } on PlatformException catch (e) {
      throw _mapPlatformError(e);
    }
  }

  Future<bool> openTermux() async {
    try {
      return await _channel.invokeMethod<bool>('openTermux') ?? false;
    } on PlatformException {
      return false;
    }
  }

  Future<void> openAppSettings() async {
    try {
      await _channel.invokeMethod('openAppSettings');
    } on PlatformException {
      // abaikan
    }
  }

  /// Menjalankan skrip bash lewat `bash -c <script>` di Termux.
  ///
  /// [background] false = jalan di sesi terminal (foreground) agar progres terlihat.
  /// [waitForResult] true = tunggu hasil (stdout/exit code) dikirim balik Termux.
  /// Jika hasil tidak datang dalam [timeout], dilempar [TermuxErrorKind.timeout].
  Future<TermuxCommandResult> runScript(
    String script, {
    bool background = true,
    bool waitForResult = true,
    String? sessionAction,
    String? label,
    String? description,
    Duration timeout = const Duration(seconds: 30),
  }) async {
    Future<Map<dynamic, dynamic>?> call = _channel.invokeMethod<Map<dynamic, dynamic>>(
      'runCommand',
      {
        'path': termuxBash,
        'arguments': ['-c', script],
        'workdir': termuxHome,
        'background': background,
        'waitForResult': waitForResult,
        'sessionAction': sessionAction,
        'label': label,
        'description': description,
      },
    );
    if (waitForResult) {
      call = call.timeout(timeout, onTimeout: () {
        throw TermuxException(TermuxErrorKind.timeout, 'Termux tidak membalas dalam ${timeout.inSeconds} detik');
      });
    }

    final Map<dynamic, dynamic>? map;
    try {
      map = await call;
    } on PlatformException catch (e) {
      throw _mapPlatformError(e);
    } on MissingPluginException {
      throw TermuxException(TermuxErrorKind.notInstalled, 'Termux hanya tersedia di Android');
    }

    final result = TermuxCommandResult.fromMap(map ?? const {});
    if (result.isExternalAppsDisabled) {
      throw TermuxException(TermuxErrorKind.externalAppsDisabled, result.errmsg);
    }
    return result;
  }

  TermuxException _mapPlatformError(PlatformException e) {
    switch (e.code) {
      case 'TERMUX_NOT_INSTALLED':
        return TermuxException(TermuxErrorKind.notInstalled, e.message ?? 'Termux belum terinstall');
      case 'PERMISSION_DENIED':
        return TermuxException(TermuxErrorKind.permissionDenied, e.message ?? 'Izin ditolak');
      default:
        return TermuxException(TermuxErrorKind.failed, e.message ?? e.code);
    }
  }
}
