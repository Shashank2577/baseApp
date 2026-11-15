import 'dart:math' as math;

import 'package:base_design/base_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('wobble matches Burrow (Kotlin Int arithmetic), so strokes look the same in every app', () {
    // Expected values computed with Kotlin's 32-bit wrap-around semantics.
    expect(wobble(1, 0, 1.0), closeTo(-0.1106431677729458, 1e-6));
    expect(wobble(7, 3, 2.0), closeTo(-0.35111009384298475, 1e-6));
    expect(wobble(9, 48, 1.2), closeTo(-0.050006866559853425, 1e-6));
    expect(wobble(12345, 6, 0.015), closeTo(-0.013780498970016021, 1e-6));
    expect(wobble(3, 10, 1.0), closeTo(0.1161364156557565, 1e-6));
  });

  test('every doodle parses', () {
    for (final d in Doodle.values) {
      final bounds = doodlePath(d).getBounds();
      expect(bounds.width, greaterThan(0), reason: d.name);
      expect(bounds.right, lessThanOrEqualTo(24.5), reason: d.name);
    }
  });

  test('voices: three, with the friendly sans as the default; retired voices map to neat', () {
    expect(Voice.all.map((v) => v.id), ['friendly', 'formal', 'neat']);
    expect(Voice.standard.id, 'friendly');
    for (final v in Voice.all) {
      expect(v.token.scale, 1.0, reason: v.id);
    }
    expect(Voice.byId('loose').id, 'neat');
    expect(Voice.byId('handwritten').id, 'neat');
    expect(Voice.byId('nonsense').id, 'friendly');
    final neat = Voice.byId('neat').style(16, 24, weight: 600);
    expect(neat.fontVariations!.map((f) => f.axis), containsAll(['wght', 'INFM']));
  });

  double luminance(Color c) {
    double ch(double v) => v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
    return 0.2126 * ch(c.r) + 0.7152 * ch(c.g) + 0.0722 * ch(c.b);
  }

  double contrast(Color a, Color b) {
    final la = luminance(a), lb = luminance(b);
    return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
  }

  for (final c in [BaseColors.light, BaseColors.dark]) {
    final mode = c.isDark ? 'dark' : 'light';
    test('every text colour reads at 4.5:1 or more on paper and smudge ($mode)', () {
      for (final (name, fg) in [('ink', c.ink), ('pencil', c.pencil), ('graphite', c.graphite), ('redPen', c.redPen)]) {
        for (final (bgName, bg) in [('paper', c.paper), ('smudge', c.smudge)]) {
          expect(contrast(fg, bg), greaterThanOrEqualTo(4.5), reason: '$name on $bgName');
        }
      }
      expect(contrast(c.markerInk, c.marker), greaterThanOrEqualTo(4.5), reason: 'markerInk on marker');
      expect(contrast(c.paper, c.ink), greaterThanOrEqualTo(4.5), reason: 'the ink button label');
    });

    test('series colours read on their paper ($mode)', () {
      final set = c.isDark ? seriesDarkTokens : seriesTokens;
      expect(set, hasLength(8));
      for (var i = 0; i < set.length; i++) {
        expect(c.series(i), set[i]);
        expect(contrast(set[i], c.paper), greaterThanOrEqualTo(c.isDark ? 6.0 : 3.0), reason: 'series $i');
      }
    });
  }

  for (final v in Voice.all) {
    test('no style is under 13, and no hand style under 24 (${v.id})', () {
      final t = BaseType(colors: BaseColors.light, voice: v);
      t.hand.forEach((name, s) => expect(s.fontSize, greaterThanOrEqualTo(SizeTokens.minHand), reason: name));
      t.bodyRoles.forEach((name, s) => expect(s.fontSize, greaterThanOrEqualTo(SizeTokens.minText), reason: name));
      for (final s in [...t.hand.values, ...t.bodyRoles.values]) {
        expect([400, 600, 700], contains(s.fontWeight!.value));
      }
      final theme = BaseTheme.build(brightness: Brightness.light, voice: v).textTheme;
      for (final s in [
        theme.displayLarge, theme.displayMedium, theme.displaySmall, theme.headlineLarge, theme.headlineMedium,
        theme.headlineSmall, theme.titleLarge, theme.titleMedium, theme.titleSmall, theme.bodyLarge,
        theme.bodyMedium, theme.bodySmall, theme.labelLarge, theme.labelMedium, theme.labelSmall,
      ]) {
        expect(s!.fontSize, greaterThanOrEqualTo(SizeTokens.minText));
      }
    });
  }

  testWidgets('hand styles grow with the OS text size up to 1.3x; body styles follow fully', (tester) async {
    late BaseType t;
    await tester.pumpWidget(
      MaterialApp(
        theme: BaseTheme.build(brightness: Brightness.light),
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2)),
          child: Builder(
            builder: (context) {
              t = context.type;
              return const SizedBox();
            },
          ),
        ),
      ),
    );
    expect(t.headline.fontSize! * 2, closeTo(HandTypeTokens.headline.size * maxHandTextScale, 1e-9));
    expect(t.body.fontSize, BodyTypeTokens.body.size);
  });

  test('mono has a real fallback list (no platform alias needed) and is ink', () {
    final t = BaseType(colors: BaseColors.light, voice: Voice.standard);
    expect(t.mono.fontFamilyFallback, contains('Menlo'));
    expect(t.mono.color, BaseColors.light.ink);
    expect(t.mono.fontSize, 13);
  });

  for (final brightness in Brightness.values) {
    testWidgets('the component catalogue lays out at phone width (${brightness.name})', (tester) async {
      tester.view.physicalSize = const Size(360 * 3, 4000 * 3);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          theme: BaseTheme.build(brightness: brightness, voice: Voice.byId('neat')),
          home: HandPage(
            wordmark: 'a rather long wordmark.',
            onBack: () {},
            actions: [DoodleButton(Doodle.gear, label: 'settings', onPressed: () {})],
            children: [
              const PageIntro(title: 'a page title', purpose: 'One plain sentence about what this page is for.', doodle: Doodle.spark),
              const SectionHead('a section head that is rather long', note: 'with a note that is long too, on its own line'),
              InkButton('the one primary action', trailing: Doodle.arrow, onPressed: () {}),
              const InkButton('a disabled action', trailing: Doodle.arrow, onPressed: null),
              PillButton('a secondary action with long words', leading: Doodle.plus, onPressed: () {}),
              const PillButton('disabled', onPressed: null),
              Wrap(children: [ChoicePill('like the device you hold', selected: true, onPressed: () {}, leading: Doodle.phone)]),
              HandLink('a minor link', onPressed: () {}),
              Door('a live row with a long title that wraps', mark: 'live', meta: 'meta line', alert: true, onTap: () {}),
              const Door('a dead row'),
              ItemRow(
                'Gemma 4 E2B, a model with a name long enough to wrap onto a second line',
                aside: '2.6 GB',
                meta: 'Default brain. Chat, reasoning, tool use, image and audio input, thinking mode.',
                caption: 'Sees · hears · uses tools · thinks',
                doodle: Doodle.spark,
                below: PillButton('download', leading: Doodle.arrow, onPressed: () {}),
              ),
              ItemRow('Priya Shah', initial: 'P', meta: '2 talks · today', onTap: () {}, selected: true),
              ItemRow('A row with a switch', trailing: HandSwitch(value: true, onChanged: (_) {})),
              SwitchRow(title: 'a switch row with a long title', body: 'and a body', value: true, onChanged: (_) {}, doodle: Doodle.cloudOff),
              Wrap(children: [const HandTag('tag'), const HandTag('marked', marked: true), HandTag('tap me', onTap: () {})]),
              const OnDeviceStamp(text: 'a long stamp that has to wrap on a narrow phone screen'),
              const HandField(placeholder: 'type here', leading: Doodle.search),
              const Steps(['one step', 'another step that is long enough to wrap'], current: 0),
              const StepHead(2, 'a stage', done: false),
              DoneNote('Done, and here is what happened.', action: 'undo', onAction: () {}),
              const HandEmpty(title: 'nothing yet', body: 'Something will appear here.'),
              const Prose(
                '# A heading\nThe team agreed to move the launch to **12 December** so the build can catch up.\n\n- Priya owns the notes\n- Tom re-runs `battery` tests\n\n1. first\n2. second\n\n> a quote that is long enough to wrap\n\n```\ncode block\n```',
              ),
              const PickMark(picked: true),
              const HandProgress(fraction: 0.4),
              const HandDivider(),
              const Snapshot(tilt: -2, child: SizedBox(width: 40, height: 40)),
              const MarkedText('only one thing gets the marker, and it wraps across lines', mark: 'marker, and it'),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('the one primary action'), findsOneWidget);
    });
  }

  testWidgets('the nav words shrink instead of overflowing', (tester) async {
    tester.view.physicalSize = const Size(320 * 3, 200 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    var picked = -1;
    await tester.pumpWidget(
      MaterialApp(
        theme: BaseTheme.build(brightness: Brightness.light),
        home: Scaffold(
          bottomNavigationBar: HandNav(words: const ['today', 'photos', 'talks', 'people'], selected: 0, onSelect: (i) => picked = i),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('·'), findsNothing);
    await tester.tap(find.text('talks'));
    expect(picked, 2);
    // Every word is at least 20 and its cell at least 48 high.
    for (final w in ['today', 'photos', 'talks', 'people']) {
      final text = tester.widget<Text>(find.text(w));
      expect(text.style!.fontSize! * text.textScaler!.scale(1), greaterThanOrEqualTo(HandNav.minWordSize - 1e-9));
      expect(tester.getSize(find.ancestor(of: find.text(w), matching: find.byType(GestureDetector)).first).height, greaterThanOrEqualTo(48));
    }
  });

  testWidgets('the rail: words down the left, wordmark on top, footer at the bottom', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    var picked = -1;
    await tester.pumpWidget(
      MaterialApp(
        theme: BaseTheme.build(brightness: Brightness.dark),
        home: Row(
          children: [
            HandNav.rail(
              words: const ['today', 'talks', 'ask', 'people'],
              selected: 1,
              onSelect: (i) => picked = i,
              wordmark: 'burrow.',
              footer: [DoodleButton(Doodle.gear, label: 'settings', onPressed: () {})],
            ),
            Expanded(
              child: HandLayout(
                rail: true,
                start: true,
                child: HandPage(wordmark: 'burrow.', children: const [PageIntro(title: 'talks', purpose: 'Everything you recorded.')]),
              ),
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(tester.getSize(find.byType(HandNav)).width, SpaceTokens.railWidth);
    expect(find.text('burrow.'), findsOneWidget, reason: 'the page leaves the wordmark to the rail');
    // The page column starts 40 after the rail.
    expect(tester.getTopLeft(find.text('talks').last).dx, SpaceTokens.railWidth + SpaceTokens.xl);
    await tester.tap(find.text('people'));
    expect(picked, 3);
  });

  testWidgets('a disabled ink button is smudge and graphite at full opacity', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: BaseTheme.build(brightness: Brightness.light),
        home: const Material(child: Center(child: InkButton('ask', trailing: Doodle.arrow, onPressed: null))),
      ),
    );
    expect(find.byType(Opacity), findsNothing);
    expect(tester.widget<Text>(find.text('ask')).style!.color, BaseColors.light.graphite);
    expect(find.byType(DoodleIcon), findsNothing);
    final m = tester.widget<Material>(find.descendant(of: find.byType(InkButton), matching: find.byType(Material)).first);
    expect(m.color, BaseColors.light.smudge);
  });

  testWidgets('prose renders markdown instead of showing it raw', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: BaseTheme.build(brightness: Brightness.light),
        home: const Material(child: Prose('## Plan\nUse **Gemma 4 E2B** now.\n- one\n- two')),
      ),
    );
    expect(find.textContaining('**'), findsNothing);
    expect(find.textContaining('##'), findsNothing);
    expect(find.text('Plan'), findsOneWidget);
    final heading = tester.widget<Text>(find.text('Plan'));
    expect(heading.textSpan!.style!.fontFamily, isNot(contains('Caveat')));
    expect(find.text('•'), findsNWidgets(2));
  });
}
