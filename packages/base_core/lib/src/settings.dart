import 'package:base_design/base_design.dart';
import 'package:flutter/material.dart';

import 'storage/json_store.dart';

/// The settings every app shares: appearance and the privacy switches.
/// App-specific settings go in [extra] (or the app's own JsonStore key).
class BaseSettings extends ChangeNotifier {
  BaseSettings._(this._store);

  static const _key = 'base.settings';
  static const _tokenKey = '${JsonStore.secretPrefix}hfToken';

  final JsonStore _store;

  ThemeMode themeMode = ThemeMode.system;
  String voiceId = defaultVoiceId;
  bool onboarded = false;

  /// "Never go online": the model store refuses every download.
  bool neverOnline = false;

  /// Hugging Face token, for gated models (Gemma needs its licence accepted).
  String hfToken = '';
  Map<String, Object?> extra = {};

  Voice get voice => Voice.byId(voiceId);

  static Future<BaseSettings> load(JsonStore store) async {
    final s = BaseSettings._(store);
    final raw = (await store.read(_key) as Map?)?.cast<String, Object?>() ?? const {};
    s
      ..themeMode = ThemeMode.values.asNameMap()[raw['themeMode']] ?? ThemeMode.system
      ..voiceId = raw['voice'] as String? ?? defaultVoiceId
      ..onboarded = raw['onboarded'] as bool? ?? false
      ..neverOnline = raw['neverOnline'] as bool? ?? false
      // Kept apart from the other settings so backups don't carry it; older
      // builds kept it in the settings document.
      ..hfToken = (await store.read(_tokenKey) as String?) ?? raw['hfToken'] as String? ?? ''
      ..extra = (raw['extra'] as Map?)?.cast<String, Object?>() ?? {};
    // Move a token saved by an older build out of the backed-up document.
    if (raw.containsKey('hfToken')) await s.update((_) {});
    return s;
  }

  /// Applies [change], tells listeners, and saves.
  Future<void> update(void Function(BaseSettings s) change) async {
    change(this);
    notifyListeners();
    await _store.write(_key, {
      'themeMode': themeMode.name,
      'voice': voiceId,
      'onboarded': onboarded,
      'neverOnline': neverOnline,
      'extra': extra,
    });
    if (hfToken.isEmpty) {
      await _store.delete(_tokenKey);
    } else {
      await _store.write(_tokenKey, hfToken);
    }
  }

  Future<void> reset() => update((s) {
    s
      ..themeMode = ThemeMode.system
      ..voiceId = defaultVoiceId
      ..onboarded = false
      ..neverOnline = false
      ..hfToken = ''
      ..extra = {};
  });
}
