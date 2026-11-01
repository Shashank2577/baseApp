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
      // A folder (trailing slash) is mirrored: every source file copied, and
      // files the source no longer has removed, so the copy never drifts.
      if ((from as String).endsWith('/')) {
        _syncDir(Directory(p.join(ws.root, from)), Directory(p.join(repoDir, to as String)), '$repo/$to', result, check);
        return;
      }
      final src = File(p.join(ws.root, from));
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

/// Build output and local state never travel with a synced folder.
const _skip = {'build', '.dart_tool', '.gradle', '.idea', '.kotlin', 'pubspec_overrides.yaml', '.flutter-plugins', '.flutter-plugins-dependencies', 'pubspec.lock', 'local.properties'};

void _syncDir(Directory src, Directory dst, String label, SyncResult result, bool check) {
  Iterable<String> files(Directory root) sync* {
    if (!root.existsSync()) return;
    for (final e in root.listSync(recursive: true, followLinks: false)) {
      final rel = p.relative(e.path, from: root.path);
      if (p.split(rel).any(_skip.contains) || e is! File) continue;
      yield rel;
    }
  }

  final want = files(src).toSet();
  for (final rel in want) {
    final from = File(p.join(src.path, rel));
    final to = File(p.join(dst.path, rel));
    final bytes = from.readAsBytesSync();
    if (to.existsSync() && _same(to.readAsBytesSync(), bytes)) continue;
    result.changed.add('$label$rel');
    if (!check) {
      to.parent.createSync(recursive: true);
      to.writeAsBytesSync(bytes);
    }
  }
  for (final rel in files(dst).where((r) => !want.contains(r)).toList()) {
    result.changed.add('$label$rel (removed)');
    if (!check) File(p.join(dst.path, rel)).deleteSync();
  }
}
