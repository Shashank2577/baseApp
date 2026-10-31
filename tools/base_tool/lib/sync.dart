// Copies generated tokens and the model catalog into the repos listed under
// `downstream:` in platform.yaml (Burrow, PhoneDots, Spreix, ...).
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

import 'workspace.dart';

class SyncResult {
  final changed = <String>[];
  final missingRepos = <String>[];
}

SyncResult runSync(Workspace ws, {bool check = false, String? only}) {
  final result = SyncResult();
  final parent = p.dirname(ws.root);
  for (final entry in (ws.platform['downstream'] as YamlList? ?? YamlList()).cast<YamlMap>()) {
    final repo = entry['repo'] as String;
    if (only != null && only != repo) continue;
    final repoDir = p.join(parent, repo);
    if (!Directory(repoDir).existsSync()) {
      result.missingRepos.add(repo);
      continue;
    }
    (entry['files'] as YamlMap).forEach((from, to) {
      final src = File(p.join(ws.root, from as String));
      final dst = File(p.join(repoDir, to as String));
      // Bytes, not text: the vendor's test signing key is synced too.
      final content = src.readAsBytesSync();
      if (dst.existsSync() && _same(dst.readAsBytesSync(), content)) return;
      result.changed.add('$repo/$to');
      if (!check) {
        dst.parent.createSync(recursive: true);
        dst.writeAsBytesSync(content);
      }
    });
  }
  return result;
}

bool _same(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
