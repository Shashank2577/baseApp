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

  test('voices: five, with the neat hand as the default', () {
    expect(Voice.all.map((v) => v.id), ['formal', 'friendly', 'neat', 'loose', 'handwritten']);
    expect(Voice.standard.id, 'neat');
    final loose = Voice.byId('loose').style(15, 22);
    expect(loose.fontVariations!.map((f) => f.axis), contains('INFM'));
    expect(Voice.byId('handwritten').style(15, 22).fontSize, closeTo(15 * 1.14, 1e-9));
  });

  for (final brightness in Brightness.values) {
    testWidgets('the component catalogue lays out at phone width (${brightness.name})', (tester) async {
      tester.view.physicalSize = const Size(360 * 3, 4000 * 3);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          theme: BaseTheme.build(brightness: brightness, voice: Voice.byId('handwritten')),
          home: HandPage(
            wordmark: 'a rather long wordmark.',
            onBack: () {},
            actions: [DoodleButton(Doodle.gear, label: 'settings', onPressed: () {})],
            children: [
              const PageIntro(title: 'a page title', purpose: 'One plain sentence about what this page is for.', mark: 'title', doodle: Doodle.spark),
              const SectionHead('a section head that is rather long', note: 'with a note that is long too'),
              InkButton('the one primary action', trailing: Doodle.arrow, onPressed: () {}),
              PillButton('a secondary action with long words', leading: Doodle.plus, onPressed: () {}),
              Wrap(children: [ChoicePill('like the device you hold', selected: true, onPressed: () {}, leading: Doodle.phone)]),
              HandLink('a minor link', onPressed: () {}),
              Door('a live row with a long title that wraps', mark: 'live', meta: 'meta line', alert: true, onTap: () {}),
              const Door('a dead row'),
              SwitchRow(title: 'a switch row with a long title', body: 'and a body', value: true, onChanged: (_) {}, doodle: Doodle.cloudOff),
              const Wrap(children: [HandTag('tag'), HandTag('marked', marked: true)]),
              const OnDeviceStamp(text: 'a long stamp that has to wrap on a narrow phone screen'),
              const HandField(placeholder: 'type here', leading: Doodle.search),
              const Steps(['one step', 'another step that is long enough to wrap'], current: 0),
              const StepHead(2, 'a stage', done: false),
              DoneNote('Done, and here is what happened.', action: 'undo', onAction: () {}),
              const HandEmpty(title: 'nothing yet', body: 'Something will appear here.'),
              const PickMark(picked: true),
              const HandProgress(fraction: 0.4),
              const HandDivider(),
              const Snapshot(tilt: -2, child: SizedBox(width: 40, height: 40)),
              const MarkedText('only one thing gets the marker, and it wraps across lines', mark: 'marker, and it wraps'),
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
    await tester.tap(find.text('talks'));
    expect(picked, 2);
  });
}
