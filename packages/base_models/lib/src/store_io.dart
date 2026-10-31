import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart' as crypto;
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'generated/platform.g.dart';
import 'model_spec.dart';
import 'model_state.dart';
import 'model_store.dart';

const _channel = MethodChannel('base/models');

Future<ModelStore> openPlatformStore(StoreOptions options) async {
  final location = await resolveLocation(options);
  Directory(location.path).createSync(recursive: true);
  final local = options.appLocalDir ?? (options.useNativeLocation ? (await getApplicationSupportDirectory()).path : null);
  final store = IoModelStore(
    options,
    location,
    Platform.isAndroid && options.useNativeLocation ? AndroidSiblings() : null,
    appLocalDir: local,
  );
  await store.refresh();
  return store;
}

/// Picks the shared root for this platform (docs/MODEL_STORE.md).
Future<SharedLocation> resolveLocation(StoreOptions o) async {
  const vendor = PlatformConfig.vendorName;
  const folder = PlatformConfig.sharedModelsFolder;
  if (o.rootOverride != null) return SharedLocation(o.rootOverride!, ShareScope.device, 'a folder you chose');

  if (o.useNativeLocation && (Platform.isIOS || Platform.isMacOS)) {
    final group = await _channel.invokeMethod<String>('appGroupDir', {'group': PlatformConfig.appleAppGroup});
    if (group != null) {
      return SharedLocation(p.join(group, folder), ShareScope.device, 'shared by every $vendor app on this device');
    }
  }
  if (o.useNativeLocation && Platform.isAndroid) {
    final dir = await _channel.invokeMethod<String>('storeDir');
    return SharedLocation(
      dir!,
      ShareScope.siblingCopy,
      "this app's copy; other $vendor apps on this phone hand theirs over instead of downloading again",
    );
  }
  if (Platform.isWindows) {
    final local = Platform.environment['LOCALAPPDATA'] ?? p.join(Platform.environment['USERPROFILE'] ?? '.', 'AppData', 'Local');
    return SharedLocation(p.join(local, vendor, folder), ShareScope.device, 'shared by every $vendor app on this PC');
  }
  if (Platform.isLinux) {
    final home = Platform.environment['HOME'] ?? '.';
    final data = Platform.environment['XDG_DATA_HOME'] ?? p.join(home, '.local', 'share');
    return SharedLocation(
      p.join(data, PlatformConfig.vendorSlug, folder.toLowerCase()),
      ShareScope.device,
      'shared by every $vendor app on this computer',
    );
  }
  // macOS without the App Group lands here too: a sandboxed app may only write
  // inside its own container, so the honest fallback is this app's support folder.
  final support = await getApplicationSupportDirectory();
  return SharedLocation(p.join(support.path, folder), ShareScope.appOnly, 'this app only (the App Group is not set up)');
}

/// Android: other apps signed with the same key that expose their models.
abstract class SiblingSource {
  Future<List<String>> authorities();
  Future<int> copy(String authority, String modelId, String file, String dest);
}

class AndroidSiblings implements SiblingSource {
  @override
  Future<List<String>> authorities() async =>
      ((await _channel.invokeListMethod<String>('siblings', {'action': PlatformConfig.androidDiscoveryAction})) ?? const []);

  @override
  Future<int> copy(String authority, String modelId, String file, String dest) async =>
      (await _channel.invokeMethod<int>('copyFromSibling', {'authority': authority, 'modelId': modelId, 'file': file, 'dest': dest}))!;
}

class _Cancel {
  bool _cancelled = false;
  bool get cancelled => _cancelled;

  /// Aborts whatever is in flight (an HTTP request stalled before its headers
  /// or between chunks would otherwise never notice the flag).
  void Function()? onCancel;

  void cancel() {
    _cancelled = true;
    onCancel?.call();
  }
}

/// File-system store for Android, iOS, macOS, Windows and Linux.
class IoModelStore extends ModelStore {
  IoModelStore(super.options, this.location, this.siblings, {this.appLocalDir});

  /// Deleted with the app; holds markers for per-app SDK installs.
  final String? appLocalDir;

  @override
  final SharedLocation location;
  final SiblingSource? siblings;

  final _states = <String, ModelState>{};
  final _inflight = <String, Future<void>>{};
  final _cancels = <String, _Cancel>{};
  final _installing = <String>{};
  Map<String, dynamic> _registry = {};
  Future<void> _registryQueue = Future.value();

  Directory get root => Directory(location.path);
  File get _registryFile => File(p.join(root.path, 'registry.json'));

  @override
  ModelState stateOf(String id) => _states[id] ?? ModelState.absent;

  @override
  String pathOf(String id, [String? file]) => file == null ? p.join(root.path, id) : p.join(root.path, id, file);

  @override
  String? sourceOf(String id) {
    final files = ((_models[id] as Map?)?['files'] as Map?)?.values.cast<Map>() ?? const <Map>[];
    if (files.isEmpty) {
      final entry = _models[id] as Map?;
      return entry?['sdkReady'] == true ? (entry?['sdkSource'] as String? ?? 'network') : null;
    }
    return files.any((f) => f['source'] == 'network') ? 'network' : 'sibling';
  }

  @override
  int get bytesOnDisk {
    var total = 0;
    for (final entry in _models.values) {
      final files = ((entry as Map)['files'] as Map?) ?? const {};
      for (final f in files.values) {
        total += ((f as Map)['bytes'] as int?) ?? 0;
      }
      total += (entry['sdkBytes'] as int?) ?? 0;
    }
    return total;
  }

  Map<String, dynamic> get _models => ((_registry['models'] as Map?) ?? const {}).cast<String, dynamic>();

  @override
  Future<void> refresh() async {
    _registry = await _readRegistry();
    for (final m in catalog.all) {
      final current = _states[m.id];
      if (current != null && _installing.contains(m.id)) continue;
      final entry = _models[m.id] as Map?;
      final users = ((entry?['users'] as Map?) ?? const {}).keys.cast<String>().toSet();
      final ready = entry != null && _filesPresent(m, entry);
      _states[m.id] = ModelState(ready ? ModelStatus.ready : ModelStatus.absent, users: ready ? users : const {});
    }
    notifyListeners();
  }

  bool _filesPresent(ModelSpec m, Map entry) {
    if (m.source == ModelSource.sdk) {
      if (entry['sdkReady'] != true || !Directory(pathOf(m.id)).existsSync()) return false;
      // Where the SDK keeps weights per app, only the apps that ran its installer have them.
      if (!_sdkPerApp || m.sdk!.bundled) return true;
      // The registry survives an uninstall but the app's own SDK weights do
      // not, so a reinstalled app must also find its local marker.
      final marker = _sdkMarker(m.id);
      return ((entry['sdkApps'] as List?) ?? const []).contains(options.appId) && (marker == null || marker.existsSync());
    }
    final files = (entry['files'] as Map?) ?? const {};
    for (final f in m.files) {
      final rec = files[f.name] as Map?;
      final file = File(pathOf(m.id, f.name));
      if (rec == null || !file.existsSync() || file.lengthSync() != rec['bytes']) return false;
    }
    return true;
  }

  void _set(String id, ModelState s) {
    _states[id] = s;
    notifyListeners();
  }

  @override
  Future<void> ensure(String id) {
    final spec = catalog.require(id);
    return _inflight[id] ??= _ensure(spec).whenComplete(() {
      _inflight.remove(id);
    });
  }

  Future<void> _ensure(ModelSpec spec) async {
    await refresh();
    // Claimed under the lock; if another app deleted it in between, install it again.
    if (stateOf(spec.id).isReady && await _claim(spec.id)) return;
    final dir = Directory(pathOf(spec.id))..createSync(recursive: true);
    final lockFile = await File(p.join(dir.path, '.download.lock')).open(mode: FileMode.append);
    // Registered before waiting for the lock, so cancel (and wipe) work while
    // another app holds it.
    final cancel = _cancels[spec.id] = _Cancel();
    var locked = false;
    try {
      // Another app on this device may be downloading the same model.
      while (true) {
        if (cancel.cancelled) {
          _set(spec.id, ModelState.absent);
          throw DownloadCancelled();
        }
        try {
          await lockFile.lock(FileLock.exclusive);
          locked = true;
          break;
        } on FileSystemException {
          _set(spec.id, stateOf(spec.id).copyWith(status: ModelStatus.downloading, busyElsewhere: true));
          await Future<void>.delayed(const Duration(seconds: 2));
          if (cancel.cancelled) continue;
          final entry = (await _readRegistry())['models']?[spec.id] as Map?;
          if (entry != null && _filesPresent(spec, entry)) {
            await refresh();
            if (await _claim(spec.id)) return;
          }
        }
      }
      if (cancel.cancelled) {
        _set(spec.id, ModelState.absent);
        throw DownloadCancelled();
      }
      await refresh();
      if (stateOf(spec.id).isReady && await _claim(spec.id)) return;
      _installing.add(spec.id);
      _set(spec.id, ModelState(ModelStatus.downloading, progress: 0, users: stateOf(spec.id).users));
      try {
        final recorded = spec.source == ModelSource.sdk ? await _installSdk(spec, cancel) : await _installFiles(spec, cancel);
        // A cancel (or wipe) that landed after the last chunk still wins.
        if (cancel.cancelled) throw DownloadCancelled();
        _installing.remove(spec.id);
        // Marked locally first, so the refresh after registering sees it.
        if (spec.source == ModelSource.sdk && _sdkPerApp) _sdkMarker(spec.id)?.createSync(recursive: true);
        await _register(spec, recorded);
      } on DownloadCancelled {
        _installing.remove(spec.id);
        _set(spec.id, ModelState.absent);
        rethrow;
      } catch (e) {
        _installing.remove(spec.id);
        _set(spec.id, ModelState(ModelStatus.failed, error: e.toString()));
        rethrow;
      }
    } finally {
      if (identical(_cancels[spec.id], cancel)) _cancels.remove(spec.id);
      if (locked) {
        try {
          await lockFile.unlock();
        } on FileSystemException {
          // Already released.
        }
      }
      await lockFile.close();
    }
  }

  File? _sdkMarker(String id) => appLocalDir == null ? null : File(p.join(appLocalDir!, 'base-sdk-installed', id));

  bool get _offline => options.offline?.call() ?? false;

  bool get _sdkPerApp => options.sdkWeightsPerApp ?? (Platform.isIOS && options.useNativeLocation);

  Future<Map<String, dynamic>> _installSdk(ModelSpec spec, _Cancel cancel) async {
    final installer = options.sdkInstaller;
    if (installer == null) throw StateError('${spec.name} is installed by its SDK, and this app has no SdkInstaller wired up.');
    final bundled = spec.sdk!.bundled;
    if (_offline && !bundled) throw OfflineException(spec.name);
    await installer(spec.id, spec.sdk!.key, pathOf(spec.id), (f) {
      if (cancel.cancelled) throw DownloadCancelled();
      _set(spec.id, stateOf(spec.id).copyWith(status: ModelStatus.downloading, progress: f));
    });
    final bytes = _dirSize(Directory(pathOf(spec.id)));
    // The SDK downloads on its own; count what it wrote to the store as received
    // (on iOS it writes elsewhere, so this undercounts there; see docs/MODEL_STORE.md).
    if (!bundled && bytes > 0) options.onNetworkBytes?.call(bytes);
    return {'sdkReady': true, 'sdkBytes': bytes, 'sdkSource': bundled ? 'bundled' : 'network'};
  }

  Future<Map<String, dynamic>> _installFiles(ModelSpec spec, _Cancel cancel) async {
    final total = spec.bytes;
    var done = 0;
    final files = <String, dynamic>{};
    for (final f in spec.files) {
      final dest = pathOf(spec.id, f.name);
      void progress(int received) {
        if (total > 0) _set(spec.id, stateOf(spec.id).copyWith(progress: ((done + received) / total).clamp(0, 1)));
      }

      final fromSibling = await _copyFromSibling(spec, f, dest, cancel);
      if (!fromSibling) {
        if (_offline) throw OfflineException(spec.name);
        await _download(f, dest, cancel, progress);
      }
      final size = File(dest).lengthSync();
      files[f.name] = {'bytes': size, 'sha256': f.sha256, 'source': fromSibling ? 'sibling' : 'network'};
      done += f.bytes ?? size;
    }
    return {'files': files};
  }

  Future<bool> _copyFromSibling(ModelSpec spec, ModelFile f, String dest, _Cancel cancel) async {
    final s = siblings;
    if (s == null) return false;
    for (final authority in await s.authorities()) {
      if (cancel.cancelled) throw DownloadCancelled();
      try {
        await s.copy(authority, spec.id, f.name, '$dest.part');
        // The native copy can't be interrupted; honour a cancel before accepting it.
        if (cancel.cancelled) {
          File('$dest.part').deleteSync();
          throw DownloadCancelled();
        }
        await _verify(f, File('$dest.part'));
        await File('$dest.part').rename(dest);
        return true;
      } on DownloadCancelled {
        rethrow;
      } catch (_) {
        // That sibling doesn't have it (or it was damaged); try the next, then the network.
        final part = File('$dest.part');
        if (part.existsSync()) part.deleteSync();
      }
    }
    return false;
  }

  /// Resumable download through `<dest>.part`, verified by SHA-256 when known.
  Future<void> _download(ModelFile f, String dest, _Cancel cancel, void Function(int) progress) async {
    final part = File('$dest.part');
    var existing = part.existsSync() ? part.lengthSync() : 0;
    final client = HttpClient()..autoUncompress = false;
    cancel.onCancel = () => client.close(force: true);
    try {
      if (cancel.cancelled) throw DownloadCancelled();
      final request = await client.getUrl(Uri.parse(f.url));
      options.headersFor?.call(f).forEach(request.headers.set);
      if (existing > 0) request.headers.set(HttpHeaders.rangeHeader, 'bytes=$existing-');
      final response = await request.close();
      if (response.statusCode == 416) {
        await response.drain<void>(); // The part file is already complete.
      } else {
        if (response.statusCode != 200 && response.statusCode != 206) {
          await response.drain<void>();
          throw HttpException(
            response.statusCode == 401 || response.statusCode == 403
                ? 'HTTP ${response.statusCode}: this model needs its licence accepted and an access token'
                : 'HTTP ${response.statusCode} for ${f.name}',
          );
        }
        if (response.statusCode == 200) existing = 0; // The server ignored the range.
        final sink = part.openWrite(mode: existing > 0 ? FileMode.append : FileMode.write);
        var received = existing;
        var last = DateTime.now();
        try {
          await for (final chunk in response) {
            if (cancel.cancelled) throw DownloadCancelled();
            sink.add(chunk);
            received += chunk.length;
            options.onNetworkBytes?.call(chunk.length);
            final now = DateTime.now();
            if (now.difference(last).inMilliseconds > 200) {
              last = now;
              progress(received);
            }
          }
        } finally {
          await sink.close();
        }
        progress(received);
      }
      await _verify(f, part);
      await part.rename(dest);
    } on DownloadCancelled {
      rethrow;
    } catch (_) {
      // Closing the client on cancel fails the request or the body stream.
      if (cancel.cancelled) throw DownloadCancelled();
      rethrow;
    } finally {
      cancel.onCancel = null;
      client.close(force: true);
    }
  }

  Future<void> _verify(ModelFile f, File file) async {
    final want = f.sha256;
    if (want == null) return;
    final digest = (await crypto.sha256.bind(file.openRead()).first).toString();
    if (digest != want) {
      await file.delete();
      throw ChecksumMismatch(f.name, want, digest);
    }
  }

  @override
  void cancel(String id) => _cancels[id]?.cancel();

  @override
  Future<void> touchClaims() => _mutate((models) {
    final now = DateTime.now().toUtc().toIso8601String();
    for (final entry in models.values.cast<Map>()) {
      final users = entry['users'] as Map?;
      if (users != null && users.containsKey(options.appId)) users[options.appId] = now;
    }
  });

  @override
  Future<void> pruneStaleClaims(Duration maxAge) => _mutate((models) {
    final cutoff = DateTime.now().toUtc().subtract(maxAge);
    for (final entry in models.values.cast<Map>()) {
      (entry['users'] as Map?)?.removeWhere((app, seen) {
        if (app == options.appId) return false;
        final at = DateTime.tryParse('$seen');
        return at != null && at.isBefore(cutoff);
      });
    }
  });

  @override
  Set<String> get claimedByThisApp => {
    for (final e in ((_registry['models'] as Map?) ?? const {}).entries)
      if (catalog.byId(e.key as String) != null && (((e.value as Map)['users'] as Map?)?.containsKey(options.appId) ?? false))
        e.key as String,
  };

  @override
  Future<void> release(String id) => _mutate((models) {
    final marker = _sdkMarker(id);
    if (marker != null && marker.existsSync()) marker.deleteSync();
    final entry = models[id] as Map?;
    if (entry == null) return;
    (entry['users'] as Map?)?.remove(options.appId);
    if (((entry['users'] as Map?) ?? const {}).isEmpty) {
      models.remove(id);
      _deleteDir(id);
    }
  });

  @override
  Future<void> deleteEverywhere(String id) => _mutate((models) {
    models.remove(id);
    _deleteDir(id);
  });

  /// Deletes the model's files unless an install of it is running, here or in
  /// another app (which holds `.download.lock` before it has a claim). That
  /// install then registers the files it finishes.
  void _deleteDir(String id) {
    final dir = Directory(pathOf(id));
    if (!dir.existsSync() || _installing.contains(id)) return;
    final lockPath = p.join(dir.path, '.download.lock');
    final RandomAccessFile lock;
    try {
      lock = File(lockPath).openSync(mode: FileMode.append);
    } on FileSystemException {
      return;
    }
    try {
      try {
        lock.lockSync(FileLock.exclusive);
      } on FileSystemException {
        return; // Another app is installing it.
      }
      for (final e in dir.listSync()) {
        if (p.basename(e.path) != '.download.lock') e.deleteSync(recursive: true);
      }
    } finally {
      lock.closeSync(); // Also releases the lock.
    }
    try {
      File(lockPath).deleteSync();
      dir.deleteSync(); // Not recursive: leaves anything an install started since.
    } on FileSystemException {
      // An install began in between; it owns the folder now.
    }
  }

  /// Adds this app to the model's users under the registry lock. False when
  /// the entry vanished meanwhile (the last other user released it).
  Future<bool> _claim(String id) async {
    var claimed = false;
    await _mutate((models) {
      final entry = models[id] as Map?;
      if (entry == null) return;
      ((entry['users'] ??= <String, dynamic>{}) as Map)[options.appId] = DateTime.now().toUtc().toIso8601String();
      claimed = true;
    });
    return claimed;
  }

  Future<void> _register(ModelSpec spec, Map<String, dynamic> recorded) => _mutate((models) {
    final now = DateTime.now().toUtc().toIso8601String();
    final previous = models[spec.id] as Map?;
    models[spec.id] = {
      ...recorded,
      'addedAt': now,
      'addedBy': options.appId,
      'users': {...?(previous?['users'] as Map?), options.appId: now},
      if (spec.source == ModelSource.sdk) 'sdkApps': {...?(previous?['sdkApps'] as List?), options.appId}.toList(),
    };
  });

  /// Read-modify-write of registry.json under an exclusive file lock, so
  /// several apps (processes) can update it safely.
  Future<void> _mutate(void Function(Map<String, dynamic> models) change) {
    final next = _registryQueue.then((_) async {
      final lock = await File(p.join(root.path, '.registry.lock')).open(mode: FileMode.append);
      try {
        await lock.lock(FileLock.blockingExclusive);
        final reg = await _readRegistry();
        final models = ((reg['models'] as Map?) ?? {}).cast<String, dynamic>();
        change(models);
        reg
          ..['version'] = 1
          ..['models'] = models;
        final tmp = File('${_registryFile.path}.$pid.tmp');
        await tmp.writeAsString(const JsonEncoder.withIndent('  ').convert(reg), flush: true);
        await tmp.rename(_registryFile.path);
        _registry = reg;
      } finally {
        try {
          await lock.unlock();
        } on FileSystemException {
          // Already released.
        }
        await lock.close();
      }
    });
    _registryQueue = next.catchError((_) {});
    return next.then((_) => refresh());
  }

  Future<Map<String, dynamic>> _readRegistry() async {
    final f = _registryFile;
    if (!f.existsSync()) return {'version': 1, 'models': <String, dynamic>{}};
    try {
      return (jsonDecode(await f.readAsString()) as Map).cast<String, dynamic>();
    } on FormatException {
      // A damaged registry must not brick every app: start over; files are re-verified on next use.
      return {'version': 1, 'models': <String, dynamic>{}};
    }
  }

  int _dirSize(Directory d) => d.existsSync()
      ? d.listSync(recursive: true).whereType<File>().where((f) => !f.path.endsWith('.lock')).fold(0, (s, f) => s + f.lengthSync())
      : 0;
}
