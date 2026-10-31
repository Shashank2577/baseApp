import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

/// The repo root and its platform.yaml.
class Workspace {
  Workspace(this.root);

  /// Walks up from [start] to the folder that holds platform.yaml.
  factory Workspace.find([String? start]) {
    var dir = Directory(start ?? Directory.current.path).absolute;
    while (true) {
      if (File(p.join(dir.path, 'platform.yaml')).existsSync()) return Workspace(dir.path);
      final parent = dir.parent;
      if (parent.path == dir.path) throw StateError('platform.yaml not found above ${start ?? Directory.current.path}');
      dir = parent;
    }
  }

  final String root;

  Map readJson(String rel) => jsonDecode(File(p.join(root, rel)).readAsStringSync()) as Map;

  late final YamlMap platform = loadYaml(File(p.join(root, 'platform.yaml')).readAsStringSync()) as YamlMap;

  String get vendorId => (platform['vendor'] as YamlMap)['id'] as String;

  /// App folders under apps/ (each a Flutter app with a base.yaml).
  List<Directory> get apps {
    final dir = Directory(p.join(root, 'apps'));
    if (!dir.existsSync()) return [];
    return dir.listSync().whereType<Directory>().where((d) => File(p.join(d.path, 'pubspec.yaml')).existsSync()).toList()
      ..sort((a, b) => a.path.compareTo(b.path));
  }
}
