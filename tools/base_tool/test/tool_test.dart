import 'dart:io';

import 'package:base_tool/check.dart';
import 'package:base_tool/gen.dart';
import 'package:base_tool/new_app.dart';
import 'package:base_tool/workspace.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:yaml/yaml.dart';

void main() {
  final repo = Workspace.find(Directory.current.path);

  test('the generated files in the repo are up to date', () {
    expect(runGen(repo, check: true), isEmpty, reason: 'run ./base gen');
  });

  test('colour parsing: #RRGGBB and #AARRGGBB', () {
    expect(argb('#FFE45C'), 0xFFFFE45C);
    expect(argb('#261A1A1A'), 0x261A1A1A);
    expect(cssTokens(repo.readJson('design/tokens.json')), contains('--base-rule: rgba(26, 26, 26, 0.20);'));
  });

  test('2.0 token shapes: dark series, sizes and the mono font reach every language', () {
    final t = repo.readJson('design/tokens.json');
    final dart = dartTokens(t), css = cssTokens(t), kt = kotlinTokens(t), swift = swiftTokens(t);
    expect(dart, allOf(contains('const seriesDarkTokens = <Color>[Color(0xFFE8E3D8)'), contains('abstract final class SizeTokens'), contains('static const double minTap = 48.0;')));
    expect(dart, allOf(contains("const monoFontFamily = 'monospace';"), contains("'Menlo'")));
    expect(css, allOf(contains('--base-size-min-tap: 48px;'), contains('--base-font-mono: '), contains('--base-series-0: #e8e3d8;')));
    expect(kt, allOf(contains('val seriesDark = listOf('), contains('object Size {'), contains('val monoFallback = listOf(')));
    expect(swift, allOf(contains('public enum Size {'), contains('public static let seriesDark'), contains('public static let monoFallback')));
  });

  test('a token file without the 2.0 groups still generates (series used for dark, no sizes)', () {
    final t = {
      ...repo.readJson('design/tokens.json'),
      'size': null,
      'font': {'hand': 'Caveat', 'voices': <Object>[], 'defaultVoice': 'x'},
    };
    (t['color'] as Map).remove('seriesDark');
    expect(dartTokens(t), allOf(isNot(contains('SizeTokens')), contains("const monoFontFamily = 'monospace';")));
    expect(cssTokens(t), contains('--base-series-0: #1a1a1a;'));
  });

  test('app code: no font sizes, and graphite is not for text', () {
    expect(lintAppLine("Text('x', style: context.type.body.copyWith(fontSize: 18))"), hasLength(1));
    expect(lintAppLine("Text('x', style: context.type.meta.copyWith(color: c.graphite))"), hasLength(1));
    expect(lintAppLine('Meta(note, color: context.colors.graphite)'), hasLength(1));
    expect(lintAppLine("Text('x', style: context.type.meta)"), isEmpty);
    expect(lintAppLine('DoodleIcon(Doodle.squiggle, color: c.graphite)'), isEmpty);
    expect(lintAppLine('Text(hint, style: t.body.copyWith(color: c.graphite)), // base-check: ignore'), isEmpty);
  });

  group('new app', () {
    late Directory tmp;
    late Workspace ws;

    setUp(() {
      tmp = Directory.systemTemp.createTempSync('base-new-');
      File(p.join(tmp.path, 'platform.yaml')).writeAsStringSync('vendor:\n  id: com.acme\n');
      File(p.join(tmp.path, 'pubspec.yaml')).writeAsStringSync('name: ws\nworkspace:\n  - packages/base_core\n  - apps/starter\n');
      void put(String rel, String text) => (File(p.join(tmp.path, 'apps/starter', rel))..createSync(recursive: true)).writeAsStringSync(text);
      put('pubspec.yaml', 'name: starter\ndescription: "Starter: the template."\nresolution: workspace\n');
      put('lib/main.dart', "import 'package:starter/app_config.dart';\n");
      put('lib/app_config.dart', "const appConfig = BaseAppConfig(appId: 'com.acme.starter', name: 'Starter', wordmark: 'starter.');\n");
      put('android/app/build.gradle.kts', 'namespace = "com.acme.starter"\napplicationId = "com.acme.starter"\n');
      put('android/app/src/main/kotlin/com/acme/starter/MainActivity.kt', 'package com.acme.starter\n');
      put('ios/Runner.xcodeproj/project.pbxproj', 'PRODUCT_BUNDLE_IDENTIFIER = com.acme.starter;\n');
      put('linux/CMakeLists.txt', 'set(BINARY_NAME "starter")\nset(APPLICATION_ID "com.acme.starter")\n');
      put('web/manifest.json', '{"name": "Starter", "short_name": "starter"}\n');
      put('build/junk.txt', 'skip me');
      ws = Workspace(tmp.path);
    });

    tearDown(() => tmp.deleteSync(recursive: true));

    test('copies the starter and renames it on every platform', () {
      final r = newApp(ws, 'field_notes', displayName: 'Field Notes');
      expect(r.appId, 'com.acme.fieldnotes');
      String read(String rel) => File(p.join(tmp.path, 'apps/field_notes', rel)).readAsStringSync();
      expect(read('pubspec.yaml'), contains('name: field_notes'));
      expect(read('lib/main.dart'), contains('package:field_notes/app_config.dart'));
      expect(read('lib/app_config.dart'), allOf(contains("appId: 'com.acme.fieldnotes'"), contains("name: 'Field Notes'"), contains("'field_notes.'")));
      expect(read('android/app/build.gradle.kts'), contains('applicationId = "com.acme.fieldnotes"'));
      expect(read('android/app/src/main/kotlin/com/acme/fieldnotes/MainActivity.kt'), contains('package com.acme.fieldnotes'));
      expect(read('ios/Runner.xcodeproj/project.pbxproj'), contains('com.acme.fieldnotes'));
      expect(read('linux/CMakeLists.txt'), allOf(contains('"field_notes"'), contains('"com.acme.fieldnotes"')));
      expect(read('web/manifest.json'), contains('"Field Notes"'));
      expect(Directory(p.join(tmp.path, 'apps/field_notes/build')).existsSync(), isFalse);
      expect(File(p.join(tmp.path, 'pubspec.yaml')).readAsStringSync(), contains('  - apps/field_notes\n'));
    });

    test('refuses bad names, existing apps and colliding application ids', () {
      expect(() => newApp(ws, 'Bad-Name', displayName: 'x'), throwsArgumentError);
      expect(() => newApp(ws, 'starter', displayName: 'x'), throwsStateError);
      newApp(ws, 'field_notes', displayName: 'x');
      expect(() => newApp(ws, 'fieldnotes', displayName: 'x'), throwsStateError);
    });

    test('a name with quotes is escaped for each file format', () {
      newApp(ws, 'whats_new', displayName: "What's \"New\"");
      String read(String rel) => File(p.join(tmp.path, 'apps/whats_new', rel)).readAsStringSync();
      expect(read('lib/app_config.dart'), contains("name: 'What\\'s \"New\"'"));
      expect(read('web/manifest.json'), contains(r'"name": "What' "'" r's \"New\""'));
      final pubspec = loadYaml(read('pubspec.yaml')) as Map;
      expect(pubspec['description'], 'What' "'" 's "New": the template.');
    });
  });
}
