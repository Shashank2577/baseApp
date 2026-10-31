// Copies apps/starter into apps/<slug> and renames every identifier on every
// platform (Android, iOS, macOS, Windows, Linux, web).
import 'dart:io';

import 'package:path/path.dart' as p;

import 'workspace.dart';

final _slugRe = RegExp(r'^[a-z][a-z0-9_]{1,30}$');

const _skipDirs = {'build', '.dart_tool', 'Pods', 'ephemeral', '.symlinks', '.gradle', '.idea', '.cxx'};
const _textExt = {
  '.dart', '.yaml', '.yml', '.json', '.md', '.kt', '.kts', '.gradle', '.xml', '.plist', '.swift', '.xcconfig',
  '.pbxproj', '.xcscheme', '.entitlements', '.cc', '.cpp', '.h', '.txt', '.rc', '.html', '.properties', '.storyboard',
  '.xib', '.cmake', '.manifest', '.desktop', '.xcworkspacedata',
};

class NewAppResult {
  NewAppResult(this.dir, this.appId);
  final String dir;
  final String appId;
}

/// [slug] becomes the Dart package name and the last part of the bundle id.
NewAppResult newApp(Workspace ws, String slug, {required String displayName, String template = 'starter'}) {
  if (!_slugRe.hasMatch(slug)) {
    throw ArgumentError('App slug must be lowercase letters, digits or _, 2-31 chars, starting with a letter: "$slug"');
  }
  final src = Directory(p.join(ws.root, 'apps', template));
  final dst = Directory(p.join(ws.root, 'apps', slug));
  if (!src.existsSync()) throw StateError('Template app not found: ${src.path}');
  if (dst.existsSync()) throw StateError('apps/$slug already exists');

  final templateId = '${ws.vendorId}.$template';
  final appId = '${ws.vendorId}.${slug.replaceAll('_', '')}';
  final templateName = _title(template);
  final word = RegExp('\\b$template\\b');
  final titleWord = RegExp('\\b$templateName\\b');

  for (final entity in src.listSync(recursive: true, followLinks: false)) {
    final rel = p.relative(entity.path, from: src.path);
    if (p.split(rel).any(_skipDirs.contains)) continue;
    if (entity is! File) continue;
    if (p.basename(rel) == 'pubspec_overrides.yaml' || p.basename(rel) == 'local.properties') continue;
    // The Android source folder follows the package name.
    final relOut = rel.replaceAll(p.joinAll(templateId.split('.')), p.joinAll(appId.split('.')));
    final out = File(p.join(dst.path, relOut))..parent.createSync(recursive: true);
    if (_textExt.contains(p.extension(rel)) || p.basename(rel) == 'CMakeLists.txt') {
      var text = entity.readAsStringSync();
      text = text
          .replaceAll(templateId, appId)
          .replaceAll('package:$template/', 'package:$slug/')
          .replaceAll(word, slug)
          .replaceAll(titleWord, displayName);
      out.writeAsStringSync(text);
    } else {
      entity.copySync(out.path);
    }
  }

  _addToWorkspace(ws, 'apps/$slug');
  return NewAppResult(dst.path, appId);
}

void _addToWorkspace(Workspace ws, String member) {
  final f = File(p.join(ws.root, 'pubspec.yaml'));
  final lines = f.readAsLinesSync();
  if (lines.any((l) => l.trim() == '- $member')) return;
  final last = lines.lastIndexWhere((l) => l.trimLeft().startsWith('- apps/') || l.trimLeft().startsWith('- tools/'));
  lines.insert(last + 1, '  - $member');
  f.writeAsStringSync('${lines.join('\n')}\n');
}

String _title(String slug) => slug.split('_').map((w) => w.isEmpty ? w : w[0].toUpperCase() + w.substring(1)).join(' ');
