import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as crypto;
import 'package:web/web.dart' as web;

import 'model_spec.dart';
import 'model_state.dart';
import 'model_store.dart';

const _cacheName = 'base-shared-models-v1';
const _registryKey = 'base.sharedModels.registry';

Future<ModelStore> openPlatformStore(StoreOptions options) async {
  final store = WebModelStore(options);
  await store.refresh();
  return store;
}

/// Web: model files live in the browser's Cache Storage. Every app served
/// from the same origin (e.g. apps.example.com/notes/, apps.example.com/talks/)
/// sees the same cache and the same registry, so a model is fetched once.
class WebModelStore extends ModelStore {
  WebModelStore(super.options);

  @override
  final location = const SharedLocation(_cacheName, ShareScope.browser, 'shared by every app on this website, in this browser');

  final _states = <String, ModelState>{};
  final _cancels = <String, web.XMLHttpRequest>{};
  final _installing = <String>{};
  final _inflight = <String, Future<void>>{};

  Map<String, dynamic> _readRegistry() {
    final raw = web.window.localStorage.getItem(_registryKey);
    if (raw == null) return {};
    try {
      return (jsonDecode(raw) as Map).cast<String, dynamic>();
    } on FormatException {
      return {};
    }
  }

  void _writeRegistry(Map<String, dynamic> reg) => web.window.localStorage.setItem(_registryKey, jsonEncode(reg));

  @override
  ModelState stateOf(String id) => _states[id] ?? ModelState.absent;

  @override
  String pathOf(String id, [String? file]) {
    final spec = catalog.require(id);
    final f = file == null ? spec.files.firstOrNull : spec.files.where((x) => x.name == file).firstOrNull;
    return f?.url ?? '$_cacheName/$id';
  }

  @override
  String? sourceOf(String id) => _readRegistry().containsKey(id) ? 'network' : null;

  @override
  int get bytesOnDisk => _readRegistry().values.fold<int>(0, (s, e) => s + (((e as Map)['bytes'] as int?) ?? 0));

  @override
  Future<void> refresh() async {
    final reg = _readRegistry();
    for (final m in catalog.all) {
      if (_installing.contains(m.id)) continue;
      final e = reg[m.id] as Map?;
      _states[m.id] = e == null
          ? ModelState.absent
          : ModelState(ModelStatus.ready, users: ((e['users'] as Map?) ?? const {}).keys.cast<String>().toSet());
    }
    notifyListeners();
  }

  @override
  Future<void> ensure(String id) => _inflight[id] ??= _ensure(id).whenComplete(() {
    _inflight.remove(id);
  });

  Future<void> _ensure(String id) async {
    final spec = catalog.require(id);
    await refresh();
    if (stateOf(id).isReady && !await _cached(spec)) {
      // The browser evicted a file but the registry still lists the model: start over.
      final reg = _readRegistry()..remove(id);
      _writeRegistry(reg);
      await refresh();
    }
    if (!stateOf(id).isReady) {
      if (spec.source == ModelSource.sdk) throw UnsupportedError('${spec.name} needs its native SDK; it cannot run in a browser.');
      if (options.offline?.call() ?? false) throw OfflineException(spec.name);
      final cache = await web.window.caches.open(_cacheName).toDart;
      _installing.add(id);
      _set(id, const ModelState(ModelStatus.downloading));
      var total = 0;
      try {
        var done = 0;
        for (final f in spec.files) {
          final hit = await cache.match(f.url.toJS).toDart;
          if (hit != null) {
            done += f.bytes ?? 0;
            total += f.bytes ?? 0;
            continue;
          }
          final bytes = await _fetch(id, f, (received) {
            if (spec.bytes > 0) _set(id, stateOf(id).copyWith(progress: ((done + received) / spec.bytes).clamp(0, 1)));
          });
          final want = f.sha256;
          if (want != null) {
            final got = crypto.sha256.convert(bytes).toString();
            if (got != want) throw ChecksumMismatch(f.name, want, got);
          }
          await cache.put(f.url.toJS, web.Response(bytes.toJS)).toDart;
          options.onNetworkBytes?.call(bytes.length);
          done += bytes.length;
          total += bytes.length;
        }
      } on DownloadCancelled {
        _installing.remove(id);
        _set(id, ModelState.absent);
        rethrow;
      } catch (e) {
        _installing.remove(id);
        _set(id, ModelState(ModelStatus.failed, error: e.toString()));
        rethrow;
      }
      _installing.remove(id);
      // Re-read: another tab may have finished the same install meanwhile; keep its claims.
      final reg = _readRegistry();
      final previous = ((reg[id] as Map?)?['users'] as Map?) ?? const {};
      reg[id] = {'bytes': total, 'users': {...previous}};
      _writeRegistry(reg);
    }
    final reg = _readRegistry();
    ((reg[id] as Map)['users'] as Map)[options.appId] = DateTime.now().toUtc().toIso8601String();
    _writeRegistry(reg);
    await refresh();
  }

  /// Whether every file of [spec] is still in Cache Storage (browsers may evict it).
  Future<bool> _cached(ModelSpec spec) async {
    final cache = await web.window.caches.open(_cacheName).toDart;
    for (final f in spec.files) {
      if (await cache.match(f.url.toJS).toDart == null) return false;
    }
    return true;
  }

  Future<Uint8List> _fetch(String id, ModelFile f, void Function(int) progress) {
    final done = Completer<Uint8List>();
    final xhr = web.XMLHttpRequest()
      ..open('GET', f.url)
      ..responseType = 'arraybuffer';
    _cancels[id] = xhr;
    xhr.onprogress = ((web.ProgressEvent e) => progress(e.loaded)).toJS;
    xhr.onload = ((web.Event _) {
      _cancels.remove(id);
      if (xhr.status == 200) {
        done.complete((xhr.response as JSArrayBuffer).toDart.asUint8List());
      } else {
        done.completeError(StateError('HTTP ${xhr.status} for ${f.name}'));
      }
    }).toJS;
    xhr.onerror = ((web.Event _) {
      _cancels.remove(id);
      done.completeError(StateError('Network error for ${f.name}'));
    }).toJS;
    xhr.onabort = ((web.Event _) {
      _cancels.remove(id);
      done.completeError(DownloadCancelled());
    }).toJS;
    // The saved Hugging Face token for gated models, like the native store sends.
    options.headersFor?.call(f).forEach((name, value) => xhr.setRequestHeader(name, value));
    xhr.send();
    return done.future;
  }

  void _set(String id, ModelState s) {
    _states[id] = s;
    notifyListeners();
  }

  @override
  void cancel(String id) => _cancels[id]?.abort();

  @override
  Future<void> release(String id) async {
    final reg = _readRegistry();
    final e = reg[id] as Map?;
    if (e == null) return;
    (e['users'] as Map).remove(options.appId);
    if ((e['users'] as Map).isEmpty) {
      await _drop(id, reg);
    } else {
      _writeRegistry(reg);
    }
    await refresh();
  }

  @override
  Future<void> deleteEverywhere(String id) async {
    await _drop(id, _readRegistry());
    await refresh();
  }

  Future<void> _drop(String id, Map<String, dynamic> reg) async {
    final cache = await web.window.caches.open(_cacheName).toDart;
    reg.remove(id);
    // Several models can share a file URL (the speech packs' tokens.txt): keep
    // any entry another registered model still uses.
    final stillUsed = {
      for (final other in reg.keys)
        if (catalog.byId(other) != null)
          for (final f in catalog.require(other).files) f.url,
    };
    for (final f in catalog.require(id).files) {
      if (!stillUsed.contains(f.url)) await cache.delete(f.url.toJS).toDart;
    }
    _writeRegistry(reg);
  }
}
