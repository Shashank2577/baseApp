import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'json_store.dart';

// Each app already has its own support folder on device, so the namespace is unused here.
Future<JsonStore> openStore(String namespace) async {
  final support = await getApplicationSupportDirectory();
  final data = Directory('${support.path}/data')..createSync(recursive: true);
  final files = Directory('${support.path}/files')..createSync(recursive: true);
  // Secrets (keys starting with `secret.`) stay out of backups and device
  // transfers. Android's Auto Backup copies filesDir (the support folder) but
  // never the sibling no_backup folder.
  var secrets = data;
  if (Platform.isAndroid && support.uri.pathSegments.where((s) => s.isNotEmpty).last == 'files') {
    secrets = Directory('${support.parent.path}/no_backup/base-secrets')..createSync(recursive: true);
  }
  return _FileStore(data, files.path, secrets);
}

class _FileStore implements JsonStore {
  _FileStore(this._dir, this.filesDir, this._secrets);

  final Directory _dir;
  final Directory _secrets;

  @override
  final String filesDir;

  File _file(String key) =>
      File('${(key.startsWith(JsonStore.secretPrefix) ? _secrets : _dir).path}/${Uri.encodeComponent(key)}.json');

  @override
  Future<Object?> read(String key) async {
    final f = _file(key);
    if (!f.existsSync()) return null;
    try {
      return jsonDecode(await f.readAsString());
    } on FormatException {
      return null;
    }
  }

  final _queues = <String, Future<void>>{};
  var _seq = 0;

  /// Writes to one document run one after another (the ledger saves often),
  /// each through its own temp file, then an atomic rename.
  @override
  Future<void> write(String key, Object? value) {
    final encoded = jsonEncode(value);
    final next = (_queues[key] ?? Future<void>.value()).then((_) async {
      final f = _file(key);
      final tmp = File('${f.path}.${_seq++}.tmp');
      await tmp.writeAsString(encoded, flush: true);
      await tmp.rename(f.path);
    });
    _queues[key] = next.catchError((_) {});
    return next;
  }

  @override
  Future<void> deleteFiles() async {
    final dir = Directory(filesDir);
    if (!dir.existsSync()) return;
    for (final e in dir.listSync()) {
      e.deleteSync(recursive: true);
    }
  }

  @override
  Future<void> delete(String key) {
    // Queued behind pending writes of the same key, so a write that was
    // already on its way can't recreate the document after the delete.
    final next = (_queues[key] ?? Future<void>.value()).then((_) async {
      final f = _file(key);
      if (f.existsSync()) await f.delete();
    });
    _queues[key] = next.catchError((_) {});
    return next;
  }

  @override
  Future<List<String>> keys(String prefix) async {
    // Let writes on their way land first, so a caller deleting every key (wipe)
    // sees documents that don't exist on disk yet.
    await Future.wait(_queues.values.toList());
    return _listKeys(prefix);
  }

  List<String> _listKeys(String prefix) => {_dir.path: _dir, _secrets.path: _secrets}.values
      .expand((d) => d.listSync())
      .whereType<File>()
      .map((f) => f.uri.pathSegments.last)
      .where((n) => n.endsWith('.json'))
      .map((n) => Uri.decodeComponent(n.substring(0, n.length - 5)))
      .where((k) => k.startsWith(prefix))
      .toSet()
      .toList();
}
