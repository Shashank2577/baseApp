import 'dart:async';
import 'dart:io';

import 'package:base_core/base_core.dart';
import 'package:burrow/app_config.dart';
import 'package:burrow/data/burrow_data.dart';
import 'package:burrow/data/models.dart';
import 'package:burrow/logic/audio_io.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// A memory store with a real files folder, so recordings and imports have somewhere to go.
class FilesMemoryStore extends MemoryJsonStore {
  FilesMemoryStore(this.dir);
  final Directory dir;

  @override
  String? get filesDir => dir.path;

  @override
  Future<void> deleteFiles() async {
    for (final e in dir.listSync()) {
      e.deleteSync(recursive: true);
    }
  }
}

/// Stands in for the microphone: "records" by writing a small file.
class FakeRecorder implements TalkRecorder {
  String? path;

  @override
  Future<bool> hasPermission() async => true;

  @override
  Future<void> start(String path) async => this.path = path;

  @override
  Future<void> pause() async {}

  @override
  Future<void> resume() async {}

  @override
  Future<String?> stop() async => path;

  @override
  Future<void> cancel() async {}

  @override
  Stream<double> levels() => const Stream.empty();

  @override
  void dispose() {}
}

void main() {
  late Directory models;
  late Directory files;
  late Directory picked;

  setUp(() {
    models = Directory.systemTemp.createTempSync('burrow-models-');
    files = Directory.systemTemp.createTempSync('burrow-files-');
    picked = Directory.systemTemp.createTempSync('burrow-picked-');
    AudioIo.recorder = FakeRecorder.new;
    final audio = File('${picked.path}/standup.m4a')..writeAsBytesSync(List.filled(64, 1));
    AudioIo.pickAudio = () async => audio.path;
  });
  tearDown(() {
    models.deleteSync(recursive: true);
    files.deleteSync(recursive: true);
    picked.deleteSync(recursive: true);
  });

  Future<BaseServices> services() => BaseServices.create(
    appConfig,
    store: FilesMemoryStore(files),
    modelsRoot: models.path,
    useNativeLocation: false,
    ai: AiRuntime.demo(),
  );

  // pumpAndSettle would wait forever on an indeterminate progress line, and file
  // copies need the real event loop: pump the clock and let real IO through.
  Future<void> settle(WidgetTester tester, [int rounds = 12]) async {
    for (var i = 0; i < rounds; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 5)));
    }
  }

  Future<BaseServices> boot(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    late BaseServices s;
    await tester.runAsync(() async => s = await services());
    await tester.pumpWidget(BaseApp(config: appConfig, services: Future.value(s)));
    await tester.pumpAndSettle();
    // Welcome, the speech models (later: the demo engine needs none), privacy.
    expect(find.text('burrow.'), findsOneWidget);
    await tester.tap(find.text("let's start"));
    await tester.pumpAndSettle();
    if (find.text('later').evaluate().isNotEmpty) {
      await tester.tap(find.text('later'));
      await settle(tester);
    }
    await tester.tap(find.text('start'));
    await settle(tester);
    return s;
  }

  Future<void> scrollTo(WidgetTester tester, Finder f) =>
      tester.scrollUntilVisible(f, 200, scrollable: find.byType(Scrollable).last);

  testWidgets('import a talk, process it, read the summary, tick a to-do, name a voice', (tester) async {
    final s = await boot(tester);
    expect(find.text('nothing yet.'), findsOneWidget);
    expect(find.text('today'), findsOneWidget);

    await tester.tap(find.text('talks'));
    await settle(tester);
    expect(find.text('no talks yet'), findsOneWidget);
    await tester.tap(find.text('import a recording'));
    await settle(tester, 60);

    // The talk page: processed on the demo engines, labelled as a demo.
    final data = BurrowData.forServices(s);
    final talk = data.talks.single;
    expect(talk.status, TalkStatus.ready, reason: talk.error);
    expect(talk.audioFile, isNotNull);
    expect(File('${files.path}/talks/${talk.audioFile}').existsSync(), isTrue);
    expect(find.text('the gist'), findsOneWidget);
    expect(find.textContaining('demo engine'), findsWidgets);
    expect(talk.lines, isNotEmpty);
    expect(talk.speakers.length, 2);
    expect(talk.summary!.todos, isNotEmpty);
    expect(talk.summary!.decisions.single.text, contains('launch moves to Thursday'));
    expect(s.ledger.total(AppLedger.talks), 1);

    // Tick the first to-do.
    final first = talk.summary!.todos.first;
    await scrollTo(tester, find.text(first.what));
    await tester.tap(find.bySemanticsLabel('to do: ${first.what}'));
    await settle(tester);
    expect(data.talk(talk.id)!.summary!.todos.first.done, isTrue);

    // Name speaker 1 as a new person.
    final voice = find.widgetWithText(Door, 'speaker 1');
    await scrollTo(tester, voice);
    await tester.tap(voice);
    await settle(tester);
    await tester.enterText(find.byType(TextField).last, 'Priya');
    await tester.tap(find.widgetWithText(InkButton, 'save'));
    await settle(tester);
    expect(data.people.single.name, 'Priya');
    expect(find.text('Priya'), findsWidgets);

    // Back to the list; people shows Priya and her talk.
    await tester.tap(find.byTooltip('back'));
    await settle(tester);
    await tester.tap(find.text('people'));
    await settle(tester);
    expect(find.text('Priya'), findsOneWidget);
    await tester.tap(find.text('Priya'));
    await settle(tester);
    expect(find.text(talk.title), findsOneWidget);
    await tester.tap(find.byTooltip('back'));
    await settle(tester);

    // Today's brief shows the talk.
    await tester.tap(find.text('today'));
    await settle(tester);
    expect(find.text('your brief'), findsOneWidget);
    expect(find.text(talk.title), findsWidgets);
  });

  testWidgets('record a talk with the microphone stand-in', (tester) async {
    final s = await boot(tester);
    await tester.tap(find.widgetWithText(InkButton, 'record a talk'));
    await settle(tester);
    expect(find.text('recording'), findsWidgets);
    await tester.tap(find.widgetWithText(InkButton, 'stop and write the notes'));
    await settle(tester, 60);
    final talk = BurrowData.forServices(s).talks.single;
    expect(talk.imported, isFalse);
    expect(talk.status, TalkStatus.ready, reason: talk.error);
    expect(find.text('the gist'), findsOneWidget);
  });

  testWidgets('ask Burrow looks things up with its tools and cites the talk', (tester) async {
    final s = await boot(tester);
    final data = BurrowData.forServices(s);
    await tester.tap(find.text('talks'));
    await settle(tester);
    await tester.tap(find.text('import a recording'));
    await settle(tester, 60);
    await tester.tap(find.byTooltip('back'));
    await settle(tester);

    await tester.tap(find.text('ask'));
    await settle(tester);
    await tester.enterText(find.byType(TextField).first, 'when is the launch?');
    await tester.tap(find.widgetWithText(InkButton, 'ask'));
    await settle(tester, 20);
    expect(find.text('what Burrow did'), findsOneWidget);
    expect(find.text('search talks'), findsOneWidget);
    expect(find.text('answer'), findsOneWidget);
    expect(find.textContaining('Demo engine, no model'), findsOneWidget);
    await scrollTo(tester, find.text('from'));
    expect(find.text(data.talks.single.title), findsWidgets);
    expect(s.ledger.total(AppLedger.questions), 1);
  });

  testWidgets('mask a message, copy it, and put the details back in a reply', (tester) async {
    final s = await boot(tester);
    String? clipboard;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') clipboard = (call.arguments as Map)['text'] as String;
      return null;
    });
    await tester.tap(find.text('mask a message'));
    await settle(tester);
    await tester.enterText(find.byType(TextField).first, 'Write to bob@acme.com or call +1 555 010 0199.');
    await tester.tap(find.widgetWithText(InkButton, 'mask'));
    await settle(tester);
    expect(find.text('Write to [EMAIL_1] or call [PHONE_1].'), findsOneWidget);
    await scrollTo(tester, find.text('copy masked text'));
    await tester.tap(find.text('copy masked text'));
    await settle(tester);
    expect(clipboard, 'Write to [EMAIL_1] or call [PHONE_1].');
    await scrollTo(tester, find.text('put the details back'));
    await tester.enterText(find.byType(TextField).last, 'Sure, I emailed [EMAIL_1].');
    await tester.tap(find.text('put the details back'));
    await settle(tester);
    await scrollTo(tester, find.text('Sure, I emailed bob@acme.com.'));
    expect(find.text('Sure, I emailed bob@acme.com.'), findsOneWidget);
    expect(s.ledger.total(AppLedger.masked), 1);
  });

  testWidgets('wipe everything forgets talks and deletes their audio', (tester) async {
    final s = await boot(tester);
    final data = BurrowData.forServices(s);
    await tester.tap(find.text('talks'));
    await settle(tester);
    await tester.tap(find.text('import a recording'));
    await settle(tester, 60);
    expect(Directory('${files.path}/talks').listSync(), isNotEmpty);
    await tester.runAsync(() => s.wipe());
    await settle(tester);
    expect(data.talks, isEmpty);
    expect(Directory(files.path).listSync(), isEmpty);
  });

  testWidgets('settings and the shared models page', (tester) async {
    final s = await boot(tester);
    await tester.tap(find.byTooltip('settings').first);
    await settle(tester);
    await tester.tap(find.text('dark'));
    await settle(tester);
    expect(s.settings.themeMode, ThemeMode.dark);
    await scrollTo(tester, find.text('models'));
    await tester.tap(find.text('models'));
    await settle(tester);
    expect(find.text('this app uses'), findsOneWidget);
    expect(find.text('Gemma 4 E2B'), findsOneWidget);
  });
}
