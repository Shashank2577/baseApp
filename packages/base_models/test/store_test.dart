import 'dart:convert';
import 'dart:io';

import 'package:base_models/base_models.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';

/// Two "apps" open the same store folder, as two apps on one Mac, PC or
/// iPhone (App Group) do. A tiny local server stands in for Hugging Face.
void main() {
  late HttpServer server;
  late Directory root;
  late List<int> payload;
  var requests = 0;
  var lastRange = '';

  setUp(() async {
    payload = List<int>.generate(300000, (i) => i % 251);
    requests = 0;
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((req) async {
      requests++;
      lastRange = req.headers.value(HttpHeaders.rangeHeader) ?? '';
      final m = RegExp(r'bytes=(\d+)-').firstMatch(lastRange);
      final from = m == null ? 0 : int.parse(m[1]!);
      req.response.statusCode = from > 0 ? 206 : 200;
      req.response.contentLength = payload.length - from;
      req.response.add(payload.sublist(from));
      await req.response.close();
    });
    root = await Directory.systemTemp.createTemp('shared-models-');
  });

  tearDown(() async {
    await server.close(force: true);
    await root.delete(recursive: true);
  });

  ModelCatalog catalog({String? sha}) => ModelCatalog(
    extra: [
      ModelSpec(
        id: 'test.tiny',
        name: 'Tiny',
        family: 'test',
        runtime: 'none',
        role: 'test',
        summary: 'A test model',
        capabilities: const {'text'},
        license: 'test',
        platforms: const {'linux'},
        source: ModelSource.file,
        files: [
          ModelFile(
            'weights.bin',
            'http://127.0.0.1:${server.port}/w',
            sha256: sha ?? sha256.convert(payload).toString(),
            bytes: payload.length,
          ),
        ],
      ),
    ],
  );

  Future<ModelStore> open(String appId, {String? sha, bool offline = false, void Function(int)? onBytes}) => ModelStore.open(
    StoreOptions(
      appId: appId,
      catalog: catalog(sha: sha),
      rootOverride: root.path,
      useNativeLocation: false,
      offline: () => offline,
      onNetworkBytes: onBytes,
    ),
  );

  test('a model downloaded by one app is reused by the next without the network', () async {
    var bytes = 0;
    final notes = await open('com.showcase.notes', onBytes: (n) => bytes += n);
    await notes.ensure('test.tiny');
    expect(notes.isReady('test.tiny'), isTrue);
    expect(requests, 1);
    expect(bytes, payload.length);
    expect(notes.sourceOf('test.tiny'), 'network');
    expect(File(notes.pathOf('test.tiny', 'weights.bin')).lengthSync(), payload.length);

    final talks = await open('com.showcase.talks');
    expect(talks.isReady('test.tiny'), isTrue, reason: 'the second app sees the shared copy at once');
    await talks.ensure('test.tiny');
    expect(requests, 1, reason: 'no second download');
    expect(talks.stateOf('test.tiny').users, {'com.showcase.notes', 'com.showcase.talks'});

    final reg = jsonDecode(File('${root.path}/registry.json').readAsStringSync()) as Map;
    expect((reg['models']['test.tiny']['users'] as Map).keys, containsAll(['com.showcase.notes', 'com.showcase.talks']));
  });

  test('files stay until the last app releases the model', () async {
    final a = await open('app.a');
    final b = await open('app.b');
    await a.ensure('test.tiny');
    await b.ensure('test.tiny');
    await a.release('test.tiny');
    expect(File(b.pathOf('test.tiny', 'weights.bin')).existsSync(), isTrue);
    await b.release('test.tiny');
    expect(Directory(b.pathOf('test.tiny')).existsSync(), isFalse);
    await a.refresh();
    expect(a.isReady('test.tiny'), isFalse);
  });

  test('"never go online" blocks a download that is needed', () async {
    final s = await open('app.a', offline: true);
    await expectLater(s.ensure('test.tiny'), throwsA(isA<OfflineException>()));
    expect(requests, 0);
  });

  test('a damaged download is thrown away', () async {
    final s = await open('app.a', sha: '0' * 64);
    await expectLater(s.ensure('test.tiny'), throwsA(isA<ChecksumMismatch>()));
    expect(s.stateOf('test.tiny').status, ModelStatus.failed);
    expect(File('${s.pathOf('test.tiny', 'weights.bin')}.part').existsSync(), isFalse);
  });

  test('an interrupted download resumes from where it stopped', () async {
    final s = await open('app.a');
    final dir = Directory(s.pathOf('test.tiny'))..createSync(recursive: true);
    File('${dir.path}/weights.bin.part').writeAsBytesSync(payload.sublist(0, 100000));
    await s.ensure('test.tiny');
    expect(lastRange, 'bytes=100000-');
    expect(File(s.pathOf('test.tiny', 'weights.bin')).readAsBytesSync(), payload);
  });

  test('a missing file makes the model absent again', () async {
    final s = await open('app.a');
    await s.ensure('test.tiny');
    File(s.pathOf('test.tiny', 'weights.bin')).deleteSync();
    await s.refresh();
    expect(s.isReady('test.tiny'), isFalse);
  });

  test('a model another app deleted after we saw it is installed again, not claimed', () async {
    final a = await open('app.a');
    final b = await open('app.b');
    await a.ensure('test.tiny');
    await b.refresh();
    expect(b.isReady('test.tiny'), isTrue);
    await a.release('test.tiny'); // the last user lets go: files and entry are gone
    await b.ensure('test.tiny'); // b's view was stale; it must not "claim" a missing entry
    expect(b.isReady('test.tiny'), isTrue);
    expect(File(b.pathOf('test.tiny', 'weights.bin')).existsSync(), isTrue);
    expect(b.stateOf('test.tiny').users, {'app.b'});
  });

  test('a bundled SDK model installs offline and is not counted as network', () async {
    var sdkBytes = 0;
    final s = await ModelStore.open(
      StoreOptions(
        appId: 'app.a',
        catalog: ModelCatalog(),
        rootOverride: root.path,
        useNativeLocation: false,
        offline: () => true,
        sdkInstaller: (id, key, dir, progress) async => progress(1),
        onNetworkBytes: (n) => sdkBytes += n,
      ),
    );
    await s.ensure('desertant.tongue');
    expect(s.isReady('desertant.tongue'), isTrue);
    expect(s.sourceOf('desertant.tongue'), 'bundled');
    expect(sdkBytes, 0);
    await expectLater(s.ensure('desertant.ear'), throwsA(isA<OfflineException>()));
  });

  test('bytes an SDK writes into the store count as downloaded', () async {
    var received = 0;
    final s = await ModelStore.open(
      StoreOptions(
        appId: 'app.a',
        catalog: ModelCatalog(),
        rootOverride: root.path,
        useNativeLocation: false,
        onNetworkBytes: (n) => received += n,
        sdkInstaller: (id, key, dir, progress) async => File('$dir/weights').writeAsBytesSync(List.filled(1234, 1)),
      ),
    );
    await s.ensure('desertant.ear');
    expect(received, 1234);
    expect(s.sourceOf('desertant.ear'), 'network');
  });

  test('claims of apps not seen for a long time are pruned; our own never', () async {
    final a = await open('app.a');
    final b = await open('app.b');
    await a.ensure('test.tiny');
    await b.ensure('test.tiny');
    // b was uninstalled long ago: age its claim.
    final reg = File('${root.path}/registry.json');
    final json = jsonDecode(reg.readAsStringSync()) as Map;
    json['models']['test.tiny']['users']['app.b'] = '2020-01-01T00:00:00Z';
    json['models']['test.tiny']['users']['app.a'] = '2020-01-01T00:00:00Z';
    reg.writeAsStringSync(jsonEncode(json));
    await a.pruneStaleClaims(const Duration(days: 180));
    expect(a.stateOf('test.tiny').users, {'app.a'});
    await a.touchClaims();
    final seen = DateTime.parse(((jsonDecode(reg.readAsStringSync()) as Map)['models']['test.tiny']['users'] as Map)['app.a'] as String);
    expect(DateTime.now().toUtc().difference(seen).inMinutes, lessThan(1));
    await a.release('test.tiny');
    expect(Directory(a.pathOf('test.tiny')).existsSync(), isFalse);
  });

  test('the shared catalog is valid', () {
    final c = ModelCatalog();
    expect(c.all.length, greaterThan(20));
    expect(c.byId('gemma-4-e2b')!.files.single.sha256, hasLength(64));
    expect(c.byId('desertant.voz')!.source, ModelSource.sdk);
  });
}
