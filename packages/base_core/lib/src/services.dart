import 'package:base_ai/base_ai.dart';
import 'package:base_models/base_models.dart';
import 'package:flutter/widgets.dart';

import 'app_config.dart';
import 'ledger.dart';
import 'settings.dart';
import 'storage/json_store.dart';

/// The platform services one app runs on. Built once at startup by [BaseApp]
/// and reachable anywhere below it with `BaseScope.of(context)`.
class BaseServices {
  BaseServices._(this.config, this.store, this.settings, this.ledger, this.models, this.ai);

  final BaseAppConfig config;
  final JsonStore store;
  final BaseSettings settings;
  final Ledger ledger;
  final ModelStore models;
  final AiRuntime ai;

  static Future<BaseServices> create(
    BaseAppConfig config, {
    JsonStore? store,
    String? modelsRoot,
    bool useNativeLocation = true,
    AiRuntime? ai,
  }) async {
    final json = store ?? await JsonStore.open(namespace: config.appId);
    final settings = await BaseSettings.load(json);
    final ledger = await Ledger.load(json);
    final runtime = ai ?? AiRuntime.forPlatform(nativeBridges: config.nativeAi);
    final models = await ModelStore.open(
      StoreOptions(
        appId: config.appId,
        catalog: ModelCatalog(extra: config.extraModels),
        offline: () => settings.neverOnline,
        rootOverride: modelsRoot,
        useNativeLocation: useNativeLocation,
        sdkInstaller: runtime.isDemo ? null : runtime.installSdkModel,
        headersFor: (f) =>
            settings.hfToken.isNotEmpty && f.url.contains('huggingface.co') ? {'Authorization': 'Bearer ${settings.hfToken}'} : const {},
        onNetworkBytes: ledger.addBytes,
      ),
    );
    if (!runtime.isDemo) await runtime.attachStore(models.location.path);
    // Show other apps this one is still installed, and forget apps that have
    // not been opened for half a year (likely uninstalled).
    await models.touchClaims();
    await models.pruneStaleClaims(const Duration(days: 180));
    return BaseServices._(config, json, settings, ledger, models, runtime);
  }

  /// Makes a model ready for this app and writes what happened to the ledger.
  Future<void> ensureModel(String id) async {
    final spec = models.spec(id);
    final wasOnDevice = models.isReady(id);
    final wasMine = models.stateOf(id).users.contains(config.appId);
    await models.ensure(id);
    final source = models.sourceOf(id);
    if (!wasOnDevice && source == 'bundled') {
      ledger.record('model', '${spec.name} is built into the app');
    } else if (wasOnDevice || source == 'sibling') {
      // Shared in place, or copied from a sibling app on this device: no network.
      if (!wasMine) {
        ledger
          ..add(LedgerEntry.modelsShared)
          ..record('model', 'reused ${spec.name} from another app');
      }
    } else {
      ledger
        ..add(LedgerEntry.modelsDownloaded)
        ..record('model', '${spec.name} is ready', network: true);
    }
  }

  /// Forgets everything this app keeps: settings, ledger, and its claim on
  /// models (files other apps still use stay).
  Future<void> wipe({bool releaseModels = true}) async {
    if (releaseModels) {
      for (final id in models.claimedByThisApp) {
        await models.release(id);
      }
    }
    for (final k in await store.keys('')) {
      await store.delete(k);
    }
    await ledger.clear();
    await settings.reset();
  }
}

class BaseScope extends InheritedWidget {
  const BaseScope({super.key, required this.services, required super.child});

  final BaseServices services;

  static BaseServices of(BuildContext context) {
    final scope = context.getInheritedWidgetOfExactType<BaseScope>();
    assert(scope != null, 'No BaseScope above this widget. Wrap the app in BaseApp.');
    return scope!.services;
  }

  @override
  bool updateShouldNotify(BaseScope oldWidget) => oldWidget.services != services;
}
