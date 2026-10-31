import 'dart:io';

import 'package:base_tool/gen.dart';
import 'package:base_tool/new_app.dart';
import 'package:base_tool/workspace.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  final repo = Workspace.find(Directory.current.path);

  test('the generated files in the repo are up to date', () {
    expect(runGen(repo, check: true), isEmpty, reason: 'run ./base gen');
  });

  test('colour parsing: #RRGGBB and #AARRGGBB', () {
    expect(argb('#FFE45C'), 0xFFFFE45C);
    expect(argb('#261A1A1A'), 0x261A1A1A);
    expect(cssTokens(repo.readJson('design/tokens.json')), contains('--base-rule: rgba(26, 26, 26, 0.15);'));
  });

  group('new app', () {
    late Directory tmp;
    late Workspace ws;

    setUp(() {
      tmp = Directory.systemTemp.createTempSync('base-new-');
      File(p.join(tmp.path, 'platform.yaml')).writeAsStringSync('vendor:\n  id: com.acme\n');
      File(p.join(tmp.path, 'pubspec.yaml')).writeAsStringSync('name: ws\nworkspace:\n  - packages/base_core\n  - apps/starter\n');
      void put(String rel, String text) => (File(p.join(tmp.path, 'apps/starter', rel))..createSync(recursive: true)).writeAsStringSync(text);
      put('pubspec.yaml', 'name: starter\nresolution: workspace\n');
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
    });
  });
}
