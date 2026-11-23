import 'dart:io';

import 'package:base_tool/check.dart';
import 'package:base_tool/checksums.dart';
import 'package:base_tool/gen.dart';
import 'package:base_tool/new_app.dart';
import 'package:base_tool/sync.dart';
import 'package:base_tool/workspace.dart';

const _usage = '''
Base platform tool.

  ./base gen [--check]             regenerate tokens, doodles and the model catalog for every consumer
  ./base new <slug> "<Name>"       create apps/<slug> from apps/starter, on all six platforms
  ./base check                     conformance rules for every app (CI runs this)
  ./base sync [--check] [repo]     copy generated files into the downstream repos in platform.yaml
  ./base checksums [--force]       fill in missing sha256/sizes in catalog/models.json from Hugging Face
''';

Future<void> main(List<String> args) async {
  if (args.isEmpty) {
    stdout.write(_usage);
    exit(64);
  }
  final ws = Workspace.find();
  final flags = args.where((a) => a.startsWith('--')).toSet();
  final rest = args.skip(1).where((a) => !a.startsWith('--')).toList();
  switch (args.first) {
    case 'gen':
      final stale = runGen(ws, check: flags.contains('--check'));
      if (flags.contains('--check')) {
        for (final s in stale) {
          stderr.writeln('stale: $s');
        }
        if (stale.isNotEmpty) {
          stderr.writeln('Run ./base gen and commit the result.');
          exit(1);
        }
        stdout.writeln('Generated files are up to date.');
      } else {
        stdout.writeln(stale.isEmpty ? 'Nothing changed.' : 'Wrote:\n  ${stale.join('\n  ')}');
      }
    case 'new':
      if (rest.isEmpty) {
        stderr.write(_usage);
        exit(64);
      }
      final slug = rest[0];
      final name = rest.length > 1 ? rest[1] : slug;
      final r = newApp(ws, slug, displayName: name);
      stdout.writeln('Created ${r.dir} (application id ${r.appId}).');
      stdout.writeln('Next: edit lib/app_config.dart, run flutter pub get at the repo root, then ./base check.');
    case 'check':
      final findings = runCheck(ws);
      for (final f in findings) {
        (f.error ? stderr : stdout).writeln(f);
      }
      final errors = findings.where((f) => f.error).length;
      stdout.writeln('${ws.apps.length} app(s) checked: $errors error(s), ${findings.length - errors} warning(s).');
      if (errors > 0) exit(1);
    case 'sync':
      final r = runSync(ws, check: flags.contains('--check'), only: rest.isEmpty ? null : rest.first);
      for (final m in r.missingRepos) {
        stdout.writeln('skipped $m (not checked out next to this repo)');
      }
      for (final c in r.changed) {
        stdout.writeln('${flags.contains('--check') ? 'out of date' : 'updated'}: $c');
      }
      if (r.changed.isEmpty) stdout.writeln('Downstream repos are up to date.');
      if (flags.contains('--check') && r.changed.isNotEmpty) exit(1);
    case 'checksums':
      final changed = await fillChecksums(ws, force: flags.contains('--force'));
      stdout.writeln(changed.isEmpty ? 'Every Hugging Face file already has a checksum.' : 'Filled in:\n  ${changed.join('\n  ')}');
      if (changed.isNotEmpty) stdout.writeln('Now run ./base gen.');
    default:
      stderr.write(_usage);
      exit(64);
  }
}
