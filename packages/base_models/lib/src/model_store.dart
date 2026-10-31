import 'package:flutter/foundation.dart';

import 'catalog.dart';
import 'model_spec.dart';
import 'model_state.dart';
import 'store_stub.dart' if (dart.library.io) 'store_io.dart' if (dart.library.js_interop) 'store_web.dart';

/// Everything the store needs from the app.
class StoreOptions {
  const StoreOptions({
    required this.appId,
    required this.catalog,
    this.offline,
    this.rootOverride,
    this.sdkInstaller,
    this.headersFor,
    this.onNetworkBytes,
    this.useNativeLocation = true,
  });

  /// This app's bundle / application id. Recorded as a user of each model it claims.
  final String appId;
  final ModelCatalog catalog;

  /// The "never go online" switch. Checked before every network request.
  final bool Function()? offline;

  /// Put the store somewhere else (tests, a user-chosen folder on desktop).
  final String? rootOverride;
  final SdkInstaller? sdkInstaller;

  /// Extra request headers per file, e.g. a Hugging Face token for gated models.
  final Map<String, String> Function(ModelFile file)? headersFor;

  /// Called with every chunk of bytes received from the network (for the privacy ledger).
  final void Function(int bytes)? onNetworkBytes;

  /// False in widget tests, where there is no platform channel.
  final bool useNativeLocation;
}

/// The one on-device model store, shared by every app of the vendor.
///
/// A model is downloaded once per device into `<shared root>/<model id>/` and
/// every app that needs it is recorded in `<shared root>/registry.json`. A
/// model is only deleted when the last app that uses it lets it go.
/// Where the shared root is on each platform: docs/MODEL_STORE.md.
abstract class ModelStore extends ChangeNotifier {
  ModelStore(this.options);

  final StoreOptions options;

  static Future<ModelStore> open(StoreOptions options) => openPlatformStore(options);

  ModelCatalog get catalog => options.catalog;

  SharedLocation get location;

  ModelState stateOf(String id);

  bool isReady(String id) => stateOf(id).isReady;

  /// Re-reads the shared registry (another app may have added or removed a model).
  Future<void> refresh();

  /// The model's folder, or one of its files. On web, a cache URL.
  String pathOf(String id, [String? file]);

  /// Makes the model available to this app: uses the shared copy if one is on
  /// the device, copies it from a sibling app (Android), or downloads it.
  /// Throws [OfflineException] when "never go online" blocks a needed download.
  Future<void> ensure(String id);

  void cancel(String id);

  /// This app no longer needs the model. The files go when no app needs them.
  Future<void> release(String id);

  /// Removes the model for every app on the device.
  Future<void> deleteEverywhere(String id);

  /// How the model's files reached this device: 'network', 'sibling' (copied
  /// from another app, Android) or null when unknown.
  String? sourceOf(String id);

  /// Bytes of every model in the shared store, all apps together.
  int get bytesOnDisk;

  /// Model ids this app has claimed.
  Set<String> get claimedByThisApp => {
    for (final m in catalog.all)
      if (stateOf(m.id).users.contains(options.appId)) m.id,
  };

  /// Waits for [ensure] on several models, one at a time (so a phone does not
  /// open five big downloads at once).
  Future<void> ensureAll(Iterable<String> ids) async {
    for (final id in ids) {
      await ensure(id);
    }
  }

  ModelSpec spec(String id) => catalog.require(id);
}
