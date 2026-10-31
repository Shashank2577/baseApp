// Conformance check: the rules that keep 20 apps behaving like one platform.
// Run by `./base check`, by CI, and by the propagate-change skill.
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

import 'gen.dart';
import 'workspace.dart';

class Finding {
  Finding(this.error, this.where, this.message);
  final bool error;
  final String where;
  final String message;
  @override
  String toString() => '${error ? 'ERROR' : 'warn '} $where: $message';
}

const requiredPlatforms = ['android', 'ios', 'macos', 'windows', 'linux', 'web'];
const knownPlatforms = {'android', 'ios', 'macos', 'windows', 'linux', 'web'};

/// Patterns that must not appear in app code (lib/). Each has a reason and the fix.
final _appRules = <(RegExp, String)>[
  (RegExp(r'Color\(0x[0-9A-Fa-f]{8}\)'), 'hard-coded colour; use context.colors (tokens) or seriesColor()'),
  (RegExp(r'Colors\.(?!transparent\b)[a-z]+'), 'Material colour; use context.colors (tokens)'),
  (RegExp(r'''fontFamily:\s*['"]'''), 'hard-coded font; use context.hand / context.body styles'),
  (RegExp(r'huggingface\.co|HttpClient\(|package:http/'), 'network or model download in app code; use SharedModelStore (base_models)'),
  (RegExp(r'getApplicationSupportDirectory|getApplicationDocumentsDirectory'), 'own storage paths; use JsonStore (base_core) or SharedModelStore'),
  (RegExp(r'\bElevatedButton\b|\bFloatingActionButton\b|\bCard\('), 'Material widget outside the design system; use InkButton/PillButton/Door'),
];

List<Finding> runCheck(Workspace ws) {
  final out = <Finding>[];
  for (final stale in runGen(ws, check: true)) {
    out.add(Finding(true, stale, 'generated file is stale; run ./base gen'));
  }
  out.addAll(_checkCatalog(ws));
  final members = ((loadYaml(File(p.join(ws.root, 'pubspec.yaml')).readAsStringSync()) as YamlMap)['workspace'] as YamlList)
      .cast<String>()
      .toSet();
  for (final app in ws.apps) {
    out.addAll(_checkApp(ws, app, members));
  }
  return out;
}

List<Finding> _checkCatalog(Workspace ws) {
  final out = <Finding>[];
  final models = ((jsonDecode(File(p.join(ws.root, 'catalog/models.json')).readAsStringSync()) as Map)['models'] as List)
      .cast<Map>();
  final ids = <String>{};
  for (final m in models) {
    final id = m['id'] as String;
    final where = 'catalog/models.json#$id';
    if (!ids.add(id)) out.add(Finding(true, where, 'duplicate id'));
    for (final pl in (m['platforms'] as List).cast<String>()) {
      if (!knownPlatforms.contains(pl)) out.add(Finding(true, where, 'unknown platform "$pl"'));
    }
    final files = (m['files'] as List).cast<Map>();
    if (m['source'] == 'file' && files.isEmpty) out.add(Finding(true, where, 'source "file" needs at least one file'));
    if (m['source'] == 'sdk' && m['sdk'] == null) out.add(Finding(true, where, 'source "sdk" needs an sdk block'));
    final names = <String>{};
    for (final f in files) {
      final name = f['name'] as String;
      if (!names.add(name)) out.add(Finding(true, where, 'duplicate file name $name'));
      if (name.contains('/') || name.contains('..')) out.add(Finding(true, where, 'file name must be a plain name: $name'));
      if (!(f['url'] as String).startsWith('https://')) out.add(Finding(true, where, 'download URLs must be https'));
      if (f['sha256'] == null) out.add(Finding(false, where, '$name has no sha256, so the download is not verified'));
    }
  }
  return out;
}

List<Finding> _checkApp(Workspace ws, Directory app, Set<String> members) {
  final out = <Finding>[];
  final rel = p.relative(app.path, from: ws.root);
  final pub = loadYaml(File(p.join(app.path, 'pubspec.yaml')).readAsStringSync()) as YamlMap;
  if (!members.contains(rel)) out.add(Finding(true, rel, 'not listed under workspace: in the root pubspec.yaml'));
  if (pub['resolution'] != 'workspace') out.add(Finding(true, '$rel/pubspec.yaml', 'needs `resolution: workspace`'));
  final deps = (pub['dependencies'] as YamlMap?)?.keys.cast<String>().toSet() ?? {};
  for (final d in ['base_core', 'base_design', 'base_models']) {
    if (!deps.contains(d)) out.add(Finding(true, '$rel/pubspec.yaml', 'must depend on $d'));
  }
  for (final pl in requiredPlatforms) {
    if (!Directory(p.join(app.path, pl)).existsSync()) out.add(Finding(true, rel, 'missing the $pl platform folder'));
  }
  if (!File(p.join(app.path, 'lib', 'app_config.dart')).existsSync()) {
    out.add(Finding(true, rel, 'missing lib/app_config.dart (the BaseAppConfig for this app)'));
  }

  final lib = Directory(p.join(app.path, 'lib'));
  if (lib.existsSync()) {
    for (final f in lib.listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart'))) {
      final lines = f.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i];
        if (line.contains('base-check: ignore')) continue;
        for (final (re, why) in _appRules) {
          if (re.hasMatch(line)) out.add(Finding(true, '${p.relative(f.path, from: ws.root)}:${i + 1}', why));
        }
      }
    }
  }

  final group = (ws.platform['sharedModels'] as YamlMap)['appleAppGroup'] as String;
  for (final ent in ['ios/Runner/Runner.entitlements', 'macos/Runner/DebugProfile.entitlements', 'macos/Runner/Release.entitlements']) {
    final f = File(p.join(app.path, ent));
    if (!f.existsSync() || !f.readAsStringSync().contains(group)) {
      out.add(Finding(true, '$rel/$ent', 'must join the App Group $group (shared model store)'));
    }
  }
  final gradle = File(p.join(app.path, 'android', 'app', 'build.gradle.kts'));
  if (!gradle.existsSync() || !gradle.readAsStringSync().contains('baseModelsPermission')) {
    out.add(Finding(true, '$rel/android/app/build.gradle.kts', 'must set the baseModelsPermission manifest placeholders'));
  }
  return out;
}
