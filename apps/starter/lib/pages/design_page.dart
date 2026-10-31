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
    return HandPage(
      actions: const [ShellActions()],
      children: [
        const PageIntro(
          title: 'design',
          purpose: 'Every piece of the hand-drawn system, as the apps draw it. One idea and one marker per screen.',
          mark: 'design',
          doodle: Doodle.pen,
        ),
        const SectionHead('type'),
        Text('display', style: context.type.display),
        Text('headline', style: context.type.headline),
        Text('title', style: context.type.title),
        Text('door', style: context.type.door),
        Text('label', style: context.type.label),
        const Body('Body text in the voice chosen in settings.'),
        const Meta('meta · 13 / 18 · pencil'),
        Text('[NAME_1] 00:42', style: context.type.mono),
        const SizedBox(height: 16),
        const SectionHead('colour'),
        const SizedBox(height: 8),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final e in swatches.entries)
              Column(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: ShapeDecoration(color: e.value, shape: CircleBorder(side: BorderSide(color: c.rule))),
                  ),
                  Meta(e.key),
                ],
              ),
            for (var i = 0; i < seriesTokens.length; i++)
              Container(width: 20, height: 20, margin: const EdgeInsets.only(top: 12), color: seriesColor(i)),
          ],
        ),
        const SizedBox(height: 16),
        const SectionHead('buttons'),
        const SizedBox(height: 8),
        InkButton('the one ink button', trailing: Doodle.arrow, onPressed: () {}),
        const SizedBox(height: 10),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            PillButton('secondary', leading: Doodle.plus, onPressed: () {}),
            for (var i = 0; i < 3; i++) ChoicePill(['one', 'two', 'three'][i], selected: _choice == i, onPressed: () => setState(() => _choice = i)),
          ],
        ),
        Row(
          children: [
            HandLink('a minor link', onPressed: () {}),
            const Spacer(),
            DoodleButton(Doodle.search, label: 'search', onPressed: () {}),
            GestureDetector(onTap: () => setState(() => _picked = !_picked), child: PickMark(picked: _picked)),
          ],
        ),
        const SizedBox(height: 16),
        const SectionHead('rows'),
        Door('a live row', meta: 'ends in a circled arrow', onTap: () {}),
        const Door('a row that leads nowhere', meta: 'drawn in pencil'),
        Door('something private', alert: true, onTap: () {}),
        SwitchRow(title: 'a switch', body: 'only for things you can switch back', value: _on, onChanged: (v) => setState(() => _on = v)),
        const SizedBox(height: 8),
        const Wrap(spacing: 8, runSpacing: 8, children: [HandTag('tag'), HandTag('the marked one', marked: true)]),
        const SizedBox(height: 16),
        const SectionHead('flows'),
        const Steps(['look', 'decide', 'done'], current: 1),
        const StepHead(1, 'a numbered stage', done: true),
        const SizedBox(height: 8),
        const DoneNote('Let go of 12 photos.', action: 'undo'),
        const SizedBox(height: 12),
        const HandProgress(fraction: 0.6),
        const HandProgress(fraction: null),
        const HandField(placeholder: 'a smudge well for typing', leading: Doodle.search, singleLine: true),
        const SizedBox(height: 16),
        Center(
          child: PillButton(
            'open a sheet',
            onPressed: () => confirmSheet(context, title: 'a confirm sheet', body: 'Ask before doing something that matters.', confirm: 'do it'),
          ),
        ),
        const SizedBox(height: 16),
        const SectionHead('doodles'),
        const SizedBox(height: 8),
        Wrap(
          spacing: 14,
          runSpacing: 14,
          children: [for (final d in Doodle.values) Tooltip(message: d.name, child: DoodleIcon(d, size: 28))],
        ),
        const SizedBox(height: 16),
        const SectionHead('snapshots'),
        const SizedBox(height: 12),
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
