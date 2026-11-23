// Fills in missing sha256 and sizes in catalog/models.json for files hosted on
// Hugging Face: LFS files from the API (no download), small files by
// downloading and hashing them. Gated repos need HF_TOKEN in the environment.
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;

import 'workspace.dart';

final _hf = RegExp(r'^https://huggingface\.co/([^/]+/[^/]+)/resolve/([^/]+)/([^?]+)');

Future<List<String>> fillChecksums(Workspace ws, {bool force = false}) async {
  final file = File(p.join(ws.root, 'catalog/models.json'));
  final catalog = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
  final client = HttpClient();
  final changed = <String>[];
  final trees = <String, List>{};
  try {
    for (final m in (catalog['models'] as List).cast<Map>()) {
      for (final f in (m['files'] as List).cast<Map>()) {
        if (f['sha256'] != null && !force) continue;
        final match = _hf.firstMatch(f['url'] as String);
        if (match == null) continue;
        final repo = match[1]!, rev = match[2]!, path = Uri.decodeFull(match[3]!);
        // One recursive listing per repo (the API rate-limits per-folder calls).
        final tree = trees['$repo@$rev'] ??= await _getJson(client, 'https://huggingface.co/api/models/$repo/tree/$rev?recursive=true') as List;
        final entry = tree.cast<Map>().where((e) => e['path'] == path).firstOrNull;
        if (entry == null) {
          stderr.writeln('not found on Hugging Face: ${f['url']}');
          continue;
        }
        final lfs = entry['lfs'] as Map?;
        if (lfs != null && !RegExp(r'^[0-9a-f]{64}$').hasMatch('${lfs['oid']}')) {
          // Gated repos (Gemma) hide hashes from anonymous callers.
          stderr.writeln('gated, set HF_TOKEN (licence accepted) to read its hash: ${f['url']}');
          continue;
        }
        if (lfs != null) {
          f['sha256'] = lfs['oid'];
          f['bytes'] = lfs['size'];
        } else {
          final bytes = await _getBytes(client, f['url'] as String);
          f['sha256'] = sha256.convert(bytes).toString();
          f['bytes'] = bytes.length;
        }
        changed.add('${m['id']}/${f['name']}');
      }
    }
  } finally {
    client.close();
  }
  if (changed.isNotEmpty) file.writeAsStringSync('${const JsonEncoder.withIndent('  ').convert(catalog)}\n');
  return changed;
}

Future<Object?> _getJson(HttpClient c, String url) async => jsonDecode(utf8.decode(await _getBytes(c, url)));

Future<List<int>> _getBytes(HttpClient c, String url) async {
  final token = Platform.environment['HF_TOKEN'];
  for (var attempt = 0; ; attempt++) {
    final req = await c.getUrl(Uri.parse(url));
    if (token != null && token.isNotEmpty) req.headers.set('Authorization', 'Bearer $token');
    final res = await req.close();
    if (res.statusCode == 429 && attempt < 4) {
      await res.drain<void>();
      await Future<void>.delayed(Duration(seconds: 5 << attempt));
      continue;
    }
    if (res.statusCode != 200) throw HttpException('HTTP ${res.statusCode} for $url');
    return (await res.toList()).expand((x) => x).toList();
  }
}
