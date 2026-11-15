import 'dart:async';

import 'package:base_core/base_core.dart';
import 'package:flutter/material.dart';

import '../data/burrow_data.dart';
import '../data/models.dart';
import '../logic/processor.dart';
import '../logic/summarizer.dart';
import '../widgets/talk_bits.dart';
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

class _TalkView extends StatelessWidget {
  const _TalkView({required this.data, required this.talk, required this.embedded});
  final BurrowData data;
  final Talk talk;
  final bool embedded;

  @override
  Widget build(BuildContext context) {
    final t = talk;
    final c = context.colors;
    final s = t.summary;
    final lang = languageName(t.language);
    final running = TalkProcessor.isRunning(t.id);
    return HandPage(
      onBack: embedded ? null : () => Navigator.of(context).pop(),
      children: [
        PageIntro(
          title: t.title,
          purpose: t.status == TalkStatus.ready
              ? 'What was said, who said it, and what happens next. Written on this device.'
              : 'Burrow is writing this talk\'s notes on this device.',
          doodle: t.imported ? Doodle.plus : Doodle.mic,
        ),
        Meta([talkMeta(data, t), ?lang].join(' · ')),
        const SizedBox(height: 4),
        Wrap(
          spacing: 12,
          children: [
            HandLink('rename', onPressed: () => _rename(context)),
            if (t.status == TalkStatus.ready && !running) HandLink('summarise again', onPressed: () => TalkProcessor(data).resummarize(t)),
          ],
        ),
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
        if (s != null) ...[
          const HandDivider(seed: 3),
          const SectionHead('the gist'),
          Body(s.gist.isEmpty ? 'Nothing to sum up.' : s.gist),
          const SizedBox(height: 6),
          Meta(s.byModel ? 'written by ${s.model} on this device' : s.model),
          if (s.decisions.isNotEmpty) ...[
            const SizedBox(height: 16),
            SectionHead('decided', note: '${s.decisions.length}'),
            for (final d in s.decisions) PointRow(d),
          ],
          if (s.points.isNotEmpty) ...[
            const SizedBox(height: 16),
            const SectionHead('key points'),
            for (final p in s.points) PointRow(p),
          ],
          const SizedBox(height: 16),
          SectionHead('to-dos', note: s.todos.isEmpty ? 'none said' : '${s.todos.where((x) => !x.done).length} open'),
          for (final todo in s.todos) TodoRow(todo: todo, onTick: (v) => data.tick(t, todo, v)),
        ],
        if (t.speakers.isNotEmpty) ...[
          const HandDivider(seed: 5),
          SectionHead('who was there', note: 'tap to name a voice'),
          for (final sp in t.speakers) _speakerRow(context, sp),
        ],
        if (t.lines.isNotEmpty) ...[
          const HandDivider(seed: 7),
          SectionHead('transcript', note: '${t.lines.length} lines'),
          for (final l in t.lines) _line(context, l),
        ],
        const SizedBox(height: 24),
        Center(
          child: HandLink(
            'delete this talk',
            color: c.redPen,
            onPressed: () async {
              final ok = await confirmSheet(
                context,
                title: 'delete this talk?',
                body: 'Its audio, transcript and notes are deleted from this device. This cannot be undone.',
                confirm: 'delete it',
                danger: true,
              );
              if (!ok) return;
              await data.deleteTalk(t);
              if (context.mounted && !embedded) Navigator.of(context).pop();
            },
          ),
        ),
      ],
    );
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
          child: Door(
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
                    Flexible(child: Text(data.speakerName(talk, l.speaker), style: context.type.small)),
                    const SizedBox(width: 8),
                    Text(clock(l.at), style: context.type.mono),
                  ],
                ),
                Body(l.text),
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
          Text('rename this talk', style: context.type.headline.copyWith(fontSize: 34)),
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
        Text('who is speaker ${index + 1}?', style: context.type.headline.copyWith(fontSize: 34)),
        const SizedBox(height: 8),
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
        InkButton('save', onPressed: () => Navigator.pop(context, (controller.text, false))),
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
