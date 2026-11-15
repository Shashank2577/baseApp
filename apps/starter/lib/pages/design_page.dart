import 'package:base_core/base_core.dart';
import 'package:flutter/material.dart';

/// The design system on one page: every component, doodle and colour, in the
/// current theme and handwriting. New apps keep this tab while they are built,
/// then drop it from app_config.dart.
class DesignPage extends StatefulWidget {
  const DesignPage(BuildContext context, {super.key});

  @override
  State<DesignPage> createState() => _DesignPageState();
}

class _DesignPageState extends State<DesignPage> {
  bool _on = true;
  int _choice = 0;
  bool _picked = true;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final swatches = {
      'paper': c.paper,
      'ink': c.ink,
      'pencil': c.pencil,
      'graphite': c.graphite,
      'rule': c.rule,
      'smudge': c.smudge,
      'marker': c.marker,
      'red pen': c.redPen,
    };
    final t = context.type;
    Widget role(String name, TextStyle style, String use) => Padding(
      padding: const EdgeInsets.only(bottom: SpaceTokens.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(name, style: style),
          Text('${style.fontSize!.round()} / ${(style.fontSize! * style.height!).round()} · $use', style: t.caption),
        ],
      ),
    );
    return HandPage(
      actions: const [ShellActions()],
      children: [
        const PageIntro(
          title: 'design',
          purpose: 'Every piece of the hand-drawn system, as the apps draw it. You read in the body face; you tap, and find your place, in hand-lettering.',
          doodle: Doodle.pen,
        ),
        const SectionHead('hand-lettering', first: true, note: 'The app\'s own short words. Never below 24, never data.'),
        role('display', t.display, 'wordmark, welcome, a timer'),
        role('headline', t.headline, 'page title'),
        role('title', t.title, 'section head, sheet title'),
        role('door', t.door, 'a place in the app, switch titles'),
        role('label', t.label, 'buttons, links, nav words'),
        const SectionHead('the body face', note: 'Everything you read, in the voice chosen in settings.'),
        role('Q3 roadmap sync', t.contentTitle, 'content title'),
        role('Summaries and answers read at 17.', t.reading, 'reading'),
        role('Gemma 4 E2B', t.rowTitle, 'row title'),
        role('Sentences and intros are 16, in ink.', t.body, 'body'),
        role('The second line of a row.', t.meta, 'meta, pencil'),
        role('Sat 31 Oct · 42 min', t.caption, 'caption, pencil'),
        role('roadmap', t.tag, 'tag'),
        role('[NAME_1] 00:42', t.mono, 'mono'),
        const SectionHead('colour'),
        Wrap(
          spacing: SpaceTokens.sm,
          runSpacing: SpaceTokens.sm,
          children: [
            for (final e in swatches.entries)
              SizedBox(
                width: 64,
                child: Column(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: ShapeDecoration(color: e.value, shape: CircleBorder(side: BorderSide(color: c.rule))),
                    ),
                    Text(e.key, style: t.caption, textAlign: TextAlign.center),
                  ],
                ),
              ),
          ],
        ),
        const SizedBox(height: SpaceTokens.sm),
        Text('Series, for charts and people (lifted on dark paper)', style: t.caption),
        const SizedBox(height: SpaceTokens.xs),
        Wrap(
          spacing: SpaceTokens.s,
          runSpacing: SpaceTokens.s,
          children: [
            for (var i = 0; i < seriesTokens.length; i++)
              Container(width: 24, height: 24, decoration: BoxDecoration(color: c.series(i), shape: BoxShape.circle)),
          ],
        ),
        const SectionHead('buttons'),
        InkButton('the one ink button', trailing: Doodle.arrow, onPressed: () {}),
        const SizedBox(height: SpaceTokens.sm),
        const InkButton('disabled', trailing: Doodle.arrow, onPressed: null),
        const SizedBox(height: SpaceTokens.sm),
        Wrap(
          spacing: SpaceTokens.s,
          runSpacing: SpaceTokens.s,
          children: [
            PillButton('secondary', leading: Doodle.plus, onPressed: () {}),
            const PillButton('disabled', onPressed: null),
            for (var i = 0; i < 3; i++) ChoicePill(['one', 'two', 'three'][i], selected: _choice == i, onPressed: () => setState(() => _choice = i)),
          ],
        ),
        Row(
          children: [
            Flexible(child: HandLink('a minor link', onPressed: () {})),
            const Spacer(),
            DoodleButton(Doodle.search, label: 'search', onPressed: () {}),
            GestureDetector(onTap: () => setState(() => _picked = !_picked), child: PickMark(picked: _picked)),
          ],
        ),
        const SectionHead('rows', note: 'A door leads to a place in the app; an item row shows content.'),
        Door('a place in the app', meta: 'Ends in a circled arrow', onTap: () {}),
        const Door('a row that leads nowhere', meta: 'Drawn in pencil'),
        Door('something private', alert: true, onTap: () {}),
        ItemRow('Q3 roadmap sync', meta: '1 decision · 3 to-dos', caption: 'Fri 30 Oct · 42 min', onTap: () {}),
        ItemRow('Priya Shah', initial: 'P', initialColor: c.series(2), meta: '2 talks · today', onTap: () {}, selected: true),
        ItemRow(
          'Gemma 4 E2B',
          aside: '2.6 GB',
          meta: 'Default brain. Chat, reasoning, tool use, image and audio input.',
          caption: 'Planner',
          below: Align(alignment: Alignment.centerLeft, child: PillButton('download', leading: Doodle.arrow, onPressed: () {})),
        ),
        SwitchRow(title: 'a switch', body: 'Only for things you can switch back.', value: _on, onChanged: (v) => setState(() => _on = v)),
        const SizedBox(height: SpaceTokens.s),
        const Wrap(spacing: SpaceTokens.s, runSpacing: SpaceTokens.s, children: [HandTag('tag'), HandTag('the marked one', marked: true)]),
        const SectionHead('long text'),
        const Prose(
          'The team agreed to move the launch to **12 December** so the Android build can catch up.\n\n'
          '- Priya owns the release notes.\n'
          '- Tom re-runs the `battery` tests on the Pixel 8.\n\n'
          '> Prose renders the markdown models write, at 17 / 26, at most 600 wide.',
        ),
        const SectionHead('flows'),
        const Steps(['look', 'decide', 'done'], current: 1),
        const StepHead(1, 'a numbered stage', done: true),
        const SizedBox(height: SpaceTokens.s),
        const DoneNote('Let go of 12 photos.', action: 'undo'),
        const SizedBox(height: SpaceTokens.sm),
        const HandProgress(fraction: 0.6),
        const HandProgress(fraction: null),
        const SizedBox(height: SpaceTokens.s),
        const HandField(placeholder: 'a smudge well for typing', leading: Doodle.search, singleLine: true),
        const SizedBox(height: SpaceTokens.m),
        Center(
          child: PillButton(
            'open a sheet',
            onPressed: () => confirmSheet(context, title: 'a confirm sheet', body: 'Ask before doing something that matters.', confirm: 'do it'),
          ),
        ),
        const SectionHead('wide screens', note: 'From 840 a list and its detail sit side by side; from 1000 the nav words become a rail on the left.'),
        const Body('Widen the window to see the rail. Detail text stops at 600 wide and stays left-aligned.'),
        const SectionHead('doodles'),
        Wrap(
          spacing: SpaceTokens.m,
          runSpacing: SpaceTokens.m,
          children: [for (final d in Doodle.values) Tooltip(message: d.name, child: DoodleIcon(d, size: 28))],
        ),
        const SizedBox(height: 16),
        const SectionHead('snapshots'),
        Row(
          children: [
            for (final (i, tilt) in [-2.5, 1.8, -1.2].indexed)
              Padding(
                padding: const EdgeInsets.only(right: 14),
                child: Snapshot(
                  tilt: tilt,
                  faded: i == 2,
                  child: Container(width: 64, height: 64, color: c.smudge, child: DoodleIcon(Doodle.camera, color: c.pencil)),
                ),
              ),
          ],
        ),
        const HandEmpty(title: 'nothing here yet', body: 'An empty state says what will appear, and how.'),
      ],
    );
  }
}
