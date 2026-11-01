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

    // Welcome, then privacy (the starter requires no model while it runs the demo engine).
    expect(find.text('starter.'), findsOneWidget);
    await tester.tap(find.text("let's start"));
    await tester.pumpAndSettle();
    await tester.tap(find.text('start'));
    await settle(tester);

    // Today, with the nav words.
    expect(find.text('today'), findsOneWidget);
    expect(find.text('all quiet.'), findsOneWidget);

    await tester.tap(find.text('design'));
    await settle(tester);
    expect(find.text('the one ink button'), findsOneWidget);

    await tester.tap(find.text('ask'));
    await settle(tester);
    // Demo engine: asking works without a model file.
    await tester.enterText(find.byType(TextField).first, 'what is this?');
    await tester.tap(find.widgetWithText(InkButton, 'ask'));
    for (var i = 0; i < 5; i++) {
      await settle(tester);
    }
    expect(find.text('answer'), findsOneWidget);

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

    // The token for gated models can be entered and is saved in settings.
    await tester.scrollUntilVisible(find.text('save token'), 200, scrollable: find.byType(Scrollable).last);
    await tester.enterText(find.byType(TextField).last, 'hf_test');
    await tester.tap(find.text('save token'));
    await settle(tester);
    expect(s.settings.hfToken, 'hf_test');
  });
}
