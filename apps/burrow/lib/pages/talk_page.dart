import 'dart:async';

import 'package:base_core/base_core.dart';
import 'package:flutter/material.dart';

import '../data/burrow_data.dart';
import '../data/models.dart';
import '../logic/processor.dart';
import '../logic/summarizer.dart';
import '../widgets/talk_bits.dart';
import '../widgets/type_roles.dart';
import 'mask_page.dart';
import 'person_page.dart';

/// One talk: its summary (gist, decisions, key points, to-dos), who was
/// there, and the transcript with speakers and times.
class TalkPage extends StatelessWidget {
  const TalkPage({super.key, required this.talkId, this.embedded = false});
  final String talkId;

  /// Shown beside the list on a wide screen (no back arrow).
  final bool embedded;

  @override
  Widget build(BuildContext context) {
    final data = BurrowData.of(context);
    return ListenableBuilder(
      listenable: data,
      builder: (context, _) {
        final t = data.talk(talkId);
        if (t == null) {
          return HandPage(
            onBack: embedded ? null : () => Navigator.of(context).pop(),
            children: const [HandEmpty(title: 'this talk is gone', body: 'It was deleted, or everything was wiped.')],
          );
        }
        return _TalkView(data: data, talk: t, embedded: embedded);
      },
    );
  }
}

class _TalkView extends StatefulWidget {
  const _TalkView({required this.data, required this.talk, required this.embedded});
  final BurrowData data;
  final Talk talk;
  final bool embedded;

  @override
  State<_TalkView> createState() => _TalkViewState();
}

enum _Part { summary, todos, transcript }

class _TalkViewState extends State<_TalkView> {
  _Part _part = _Part.summary;

  BurrowData get data => widget.data;
  Talk get talk => widget.talk;
  bool get embedded => widget.embedded;

  @override
  Widget build(BuildContext context) {
    final t = talk;
    final s = t.summary;
    final lang = languageName(t.language);
    final running = TalkProcessor.isRunning(t.id);
    final open = t.todos.where((x) => !x.done).length;
    return HandPage(
      onBack: embedded ? null : () => Navigator.of(context).pop(),
      actions: [HandLink('more', onPressed: () => _more(context))],
      children: [
        // A talk's title is data, so it is set in the reading face, not hand-lettered.
        Text(t.title, style: contentTitle(context)),
        const SizedBox(height: 4),
        Meta([talkMeta(data, t), ?lang].join(' · ')),
        if (t.demo) ...[
          const SizedBox(height: 8),
          const OnDeviceStamp(text: 'demo engine: a sample transcript, not your audio'),
        ],
        const SizedBox(height: 16),
        if (t.status == TalkStatus.processing || running) ProcessingNote(t),
        if (t.status == TalkStatus.failed && !running)
          DoneNote(
            'Stopped: ${t.error ?? 'something went wrong'}',
            action: 'try again',
            onAction: () => unawaited(TalkProcessor(data).process(t)),
          ),
        if (t.status == TalkStatus.waiting && !running)
          DoneNote('Not processed yet.', action: 'write the notes', onAction: () => unawaited(TalkProcessor(data).process(t))),
        if (t.lines.isNotEmpty || s != null) ...[
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ChoicePill('summary', selected: _part == _Part.summary, onPressed: () => setState(() => _part = _Part.summary)),
              ChoicePill(
                open == 0 ? 'to-dos' : 'to-dos $open',
                selected: _part == _Part.todos,
                onPressed: () => setState(() => _part = _Part.todos),
              ),
              ChoicePill('transcript', selected: _part == _Part.transcript, onPressed: () => setState(() => _part = _Part.transcript)),
            ],
          ),
          const SizedBox(height: 16),
        ],
        if (s != null && _part == _Part.summary) ...[
          SelectableText(s.gist.isEmpty ? 'Nothing to sum up.' : s.gist, style: reading(context)),
          const SizedBox(height: 6),
          Meta(s.byModel ? 'Written by ${s.model} on this device.' : '${s.model[0].toUpperCase()}${s.model.substring(1)}.'),
          if (s.decisions.isNotEmpty) ...[
            const SizedBox(height: 24),
            const SectionHead('decided'),
            for (final d in s.decisions) PointRow(d),
          ],
          if (s.points.isNotEmpty) ...[
            const SizedBox(height: 24),
            const SectionHead('key points'),
            for (final p in s.points) PointRow(p),
          ],
          if (t.speakers.isNotEmpty) ...[
            const SizedBox(height: 24),
            const SectionHead('who was there'),
            const Meta('Tap a voice to say who it is.'),
            for (final sp in t.speakers) _speakerRow(context, sp),
          ],
        ],
        if (_part == _Part.todos) ...[
          if (t.todos.isEmpty) const Meta('No to-dos were said in this talk.'),
          for (final todo in t.todos) TodoRow(todo: todo, onTick: (v) => data.tick(t, todo, v)),
        ],
        if (_part == _Part.transcript) ...[
          for (final l in t.lines) _line(context, l),
        ],
      ],
    );
  }

  Future<void> _more(BuildContext context) async {
    final c = context.colors;
    final running = TalkProcessor.isRunning(talk.id);
    final choice = await showHandSheet<String>(
      context,
      builder: (context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('this talk', style: context.type.title),
          const SizedBox(height: 8),
          Door('rename', onTap: () => Navigator.pop(context, 'rename')),
          if (talk.status == TalkStatus.ready && !running) Door('summarise again', onTap: () => Navigator.pop(context, 'again')),
          if (talk.summary != null) Door('mask before sharing', onTap: () => Navigator.pop(context, 'mask')),
          const SizedBox(height: 8),
          Center(child: HandLink('delete this talk', color: c.redPen, onPressed: () => Navigator.pop(context, 'delete'))),
        ],
      ),
    );
    if (!context.mounted) return;
    switch (choice) {
      case 'rename':
        await _rename(context);
      case 'again':
        unawaited(TalkProcessor(data).resummarize(talk));
      case 'mask':
        await pushPage(context, MaskPage(initial: notesText(data, talk)));
      case 'delete':
        final ok = await confirmSheet(
          context,
          title: 'delete this talk?',
          body: 'Its audio, transcript and notes are deleted from this device. This cannot be undone.',
          confirm: 'delete it',
          danger: true,
        );
        if (!ok) return;
        await data.deleteTalk(talk);
        if (context.mounted && !embedded) Navigator.of(context).pop();
    }
  }

  Widget _speakerRow(BuildContext context, Speaker sp) {
    final total = talk.speakers.fold<double>(0, (a, s) => a + s.talkSec);
    final share = total == 0 ? 0 : (sp.talkSec * 100 / total).round();
    final person = data.person(sp.personId);
    return Row(
      children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: seriesColor(sp.index), shape: BoxShape.circle)),
        const SizedBox(width: 10),
        Expanded(
          child: ContentRow(
            data.speakerName(talk, sp.index),
            meta: '$share% of the talk${person == null ? ' · not named yet' : ''}',
            onTap: () => nameVoice(context, data, talk, sp.index),
          ),
        ),
      ],
    );
  }

  Widget _line(BuildContext context, Line l) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 3,
            height: 36,
            margin: const EdgeInsets.only(top: 2, right: 10),
            color: l.speaker == null ? c.rule : seriesColor(l.speaker!),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(child: Text(data.speakerName(talk, l.speaker), style: rowTitle(context))),
                    const SizedBox(width: 8),
                    Text(clock(l.at), style: context.type.mono),
                  ],
                ),
                SelectableText(l.text, style: reading(context)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _rename(BuildContext context) async {
    final controller = TextEditingController(text: talk.title);
    final title = await showHandSheet<String>(
      context,
      builder: (context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('rename this talk', style: context.type.title),
          const SizedBox(height: 14),
          HandField(controller: controller, singleLine: true, autofocus: true, placeholder: 'a title', leading: Doodle.pen),
          const SizedBox(height: 14),
          InkButton('save', onPressed: () => Navigator.pop(context, controller.text)),
        ],
      ),
    );
    if (title != null) await data.renameTalk(talk, title);
  }
}

/// "Who is this?": name a voice as someone already known, as you, or by a new name.
Future<void> nameVoice(BuildContext context, BurrowData data, Talk talk, int index) async {
  final controller = TextEditingController();
  final current = talk.speaker(index)?.personId;
  final picked = await showHandSheet<(String?, bool)>(
    context,
    builder: (context) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('who is this?', style: context.type.title),
        const SizedBox(height: 8),
        if (talk.lines.where((l) => l.speaker == index).firstOrNull case final l?) ...[
          Text('"${l.text}"', style: reading(context)),
          Meta('Speaker ${index + 1} at ${clock(l.at)}'),
          const SizedBox(height: 8),
        ],
        const Meta('Naming a voice puts this talk on that person\'s page. You can change it any time.'),
        const SizedBox(height: 14),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ChoicePill('this is me', selected: data.person(current)?.isMe ?? false, onPressed: () => Navigator.pop(context, (null, true))),
            for (final x in data.people.where((x) => !x.isMe))
              ChoicePill(x.name, selected: x.id == current, onPressed: () => Navigator.pop(context, (x.name, false))),
          ],
        ),
        const SizedBox(height: 14),
        HandField(controller: controller, singleLine: true, placeholder: 'or a new name', leading: Doodle.person),
        const SizedBox(height: 14),
        InkButton("that's them", onPressed: () => Navigator.pop(context, (controller.text, false))),
        if (current != null)
          Center(child: HandLink('not named', onPressed: () => Navigator.pop(context, ('', false)))),
      ],
    ),
  );
  if (picked == null) return;
  final (name, isMe) = picked;
  if (isMe) {
    await data.nameSpeaker(talk, index, await data.personNamed('me', isMe: true));
  } else if (name != null && name.trim().isNotEmpty) {
    await data.nameSpeaker(talk, index, await data.personNamed(name));
  } else if (name == '') {
    await data.nameSpeaker(talk, index, null);
  }
}

/// Opens a person's page.
void openPerson(BuildContext context, Person p) => pushPage(context, PersonPage(personId: p.id));

/// A talk's notes as plain text, for "mask before sharing".
String notesText(BurrowData data, Talk t) {
  final s = t.summary;
  final b = StringBuffer('${t.title}\n\n${s?.gist ?? ''}\n');
  if (s != null && s.decisions.isNotEmpty) b.writeln('\nDecided:\n${s.decisions.map((d) => '- ${d.text}').join('\n')}');
  if (t.todos.isNotEmpty) {
    b.writeln('\nTo-dos:\n${t.todos.map((x) => '- ${x.who == null ? '' : '${x.who}: '}${x.what}${x.dueWords == null ? '' : ' (${x.dueWords})'}').join('\n')}');
  }
  return b.toString().trim();
}
