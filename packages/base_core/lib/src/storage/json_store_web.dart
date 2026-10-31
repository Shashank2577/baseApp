import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'json_store.dart';

Future<JsonStore> openStore(String namespace) async => _PrefsStore(await SharedPreferences.getInstance(), 'base.$namespace.');

class _PrefsStore implements JsonStore {
  _PrefsStore(this._prefs, this._ns);

  final SharedPreferences _prefs;
  /// Per app: apps on the same origin share localStorage.
  final String _ns;

  @override
  String? get filesDir => null;

  @override
  Future<Object?> read(String key) async {
    final s = _prefs.getString('$_ns$key');
    return s == null ? null : jsonDecode(s);
  }

  @override
  Future<void> write(String key, Object? value) => _prefs.setString('$_ns$key', jsonEncode(value));

  @override
  Future<void> delete(String key) => _prefs.remove('$_ns$key');

  @override
  Future<List<String>> keys(String prefix) async =>
      _prefs.getKeys().where((k) => k.startsWith('$_ns$prefix')).map((k) => k.substring(_ns.length)).toList();
}
