import 'dart:io';

import 'package:base_core/base_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:starter/app_config.dart';

void main() {
  late Directory models;

  setUp(() => models = Directory.systemTemp.createTempSync('starter-models-'));
  tearDown(() => models.deleteSync(recursive: true));

  Future<BaseServices> services() => BaseServices.create(
    appConfig,
    store: MemoryJsonStore(),
    modelsRoot: models.path,
    useNativeLocation: false,
    ai: AiRuntime.demo(),
  );

  // pumpAndSettle would wait forever on the design tab's looping progress line.
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  testWidgets('onboarding, then the three tabs and the shared pages', (tester) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    // Services do real file IO, so build them outside the fake test clock.
    late BaseServices s;
    await tester.runAsync(() async => s = await services());
    await tester.pumpWidget(BaseApp(config: appConfig, services: Future.value(s)));
    await tester.pumpAndSettle();

    // Welcome, then the models step (skip the download), then privacy.
    expect(find.text('starter.'), findsOneWidget);
    await tester.tap(find.text("let's start"));
    await tester.pumpAndSettle();
    expect(find.text('Gemma 3 270M'), findsOneWidget);
    await tester.tap(find.text('later'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('start'));
    await settle(tester);

    // Today, with the nav words.
    expect(find.text('today'), findsOneWidget);
    expect(find.text('get the model'), findsOneWidget);

    await tester.tap(find.text('design'));
    await settle(tester);
    expect(find.text('the one ink button'), findsOneWidget);

    await tester.tap(find.text('ask'));
    await settle(tester);
    expect(find.textContaining('not on this device yet'), findsOneWidget);

    // Settings: switch to dark and to the handwritten voice.
    await tester.tap(find.byTooltip('settings').first);
    await settle(tester);
    await tester.tap(find.text('dark'));
    await settle(tester);
    await tester.scrollUntilVisible(find.text('all handwritten'), 200, scrollable: find.byType(Scrollable).last);
    await tester.tap(find.text('all handwritten'));
    await settle(tester);
    expect(s.settings.themeMode, ThemeMode.dark);
    expect(s.settings.voiceId, 'handwritten');

    // Models page lists what this app uses.
    await tester.scrollUntilVisible(find.text('models'), 200, scrollable: find.byType(Scrollable).last);
    await tester.tap(find.text('models'));
    await settle(tester);
    expect(find.text('this app uses'), findsOneWidget);
    expect(find.text('Gemma 3 270M'), findsOneWidget);
  });
}
