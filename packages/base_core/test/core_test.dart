import 'dart:io';

import 'package:base_core/base_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('settings persist through the store', () async {
    final store = MemoryJsonStore();
    final s = await BaseSettings.load(store);
    await s.update((x) {
      x
        ..themeMode = ThemeMode.dark
        ..voiceId = 'loose'
        ..neverOnline = true;
    });
    final again = await BaseSettings.load(store);
    expect(again.themeMode, ThemeMode.dark);
    expect(again.voice.id, 'loose');
    expect(again.neverOnline, isTrue);
  });

  test('the ledger counts today and in total, and says it in words', () async {
    final store = MemoryJsonStore();
    final l = await Ledger.load(store);
    const photos = LedgerEntry('photos', 'checked 1 photo', 'checked %d photos');
    l
      ..add(photos, 311)
      ..add(photos)
      ..addBytes(2048);
    expect(l.today(photos), 312);
    expect(l.summary([photos]), ['checked 312 photos']);
    expect(l.summary([LedgerEntry.modelsDownloaded]), isEmpty);
    await Future<void>.delayed(const Duration(milliseconds: 1100));
    final again = await Ledger.load(store);
    expect(again.total(photos), 312);
    expect(again.bytesDownloaded, 2048);
  });

  test('wipe forgets settings and the ledger', () async {
    final models = Directory.systemTemp.createTempSync('core-models-');
    addTearDown(() => models.deleteSync(recursive: true));
    const config = BaseAppConfig(appId: 'com.test.app', name: 'Test', tagline: 't', tabs: []);
    final s = await BaseServices.create(config, store: MemoryJsonStore(), modelsRoot: models.path, useNativeLocation: false, ai: AiRuntime.demo());
    await s.settings.update((x) => x.onboarded = true);
    s.ledger.record('x', 'did a thing');
    await s.wipe();
    expect(s.settings.onboarded, isFalse);
    expect(s.ledger.events, isEmpty);
    expect(s.models.location.path, models.path);
  });

  test('formatBytes and greeting', () {
    expect(formatBytes(2588147712), '2.6 GB');
    expect(formatBytes(164626432), '165 MB');
    expect(greeting(DateTime(2026, 1, 1, 3)), 'hello, night owl');
    expect(greeting(DateTime(2026, 1, 1, 9)), 'good morning');
  });
}
