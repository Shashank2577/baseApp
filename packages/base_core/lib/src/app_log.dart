import 'dart:async';

import 'package:flutter/foundation.dart';

import 'storage/json_store.dart';

/// What the app did, step by step: model installs (claimed, copied from
/// another app, downloading, checksum ok), failures and errors. Shown on the
/// logs page, where the user copies it to report a problem. Kept on the device
/// only, newest last, at most [limit] lines.
class AppLog extends ChangeNotifier {
  AppLog._(this._store);

  static const _key = 'base.log';
  static const limit = 500;

  final JsonStore? _store;
  final List<String> _lines = [];
  Timer? _save;

  List<String> get lines => List.unmodifiable(_lines);

  /// A log kept in memory only (tests, or before services start).
  factory AppLog.memory() => AppLog._(null);

  static Future<AppLog> load(JsonStore store) async {
    final log = AppLog._(store);
    log._lines.addAll(((await store.read(_key) as List?) ?? const []).cast<String>());
    return log;
  }

  /// Adds one line: `2026-10-31 16:59:22 [models] gemma-4-e2b: checksum ok`.
  void add(String area, String message) {
    final t = DateTime.now();
    String two(int n) => n.toString().padLeft(2, '0');
    final stamp = '${t.year}-${two(t.month)}-${two(t.day)} ${two(t.hour)}:${two(t.minute)}:${two(t.second)}';
    _lines.add('$stamp [$area] $message');
    if (_lines.length > limit) _lines.removeRange(0, _lines.length - limit);
    notifyListeners();
    // Saved a moment later, so a fast download doesn't write once per line.
    _save ??= Timer(const Duration(seconds: 1), () {
      _save = null;
      unawaited(_store?.write(_key, _lines));
    });
  }

  /// Everything, with a header saying which app and device it came from.
  String text({required String header}) => '$header\n${_lines.join('\n')}\n';

  Future<void> clear() async {
    _lines.clear();
    notifyListeners();
    await _store?.delete(_key);
  }
}
