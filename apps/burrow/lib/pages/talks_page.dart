import 'dart:async';

import 'package:base_core/base_core.dart';
import 'package:flutter/material.dart';

import '../data/burrow_data.dart';
import '../data/models.dart';
import '../logic/audio_io.dart';
import '../logic/processor.dart';
import '../widgets/talk_bits.dart';
import 'record_page.dart';
import 'talk_page.dart';

/// Every talk, newest first. On wide screens the open talk sits beside the list.
class TalksPage extends StatefulWidget {
  const TalksPage(BuildContext context, {super.key});

  @override
  State<TalksPage> createState() => _TalksPageState();
}

class _TalksPageState extends State<TalksPage> {
  String? _open;
  bool _importing = false;

  void _show(Talk t) {
    if (context.isWide) {
      setState(() => _open = t.id);
    } else {
      pushPage(context, TalkPage(talkId: t.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = BurrowData.of(context);
    return ListenableBuilder(
      listenable: data,
      builder: (context, _) {
        final open = _open == null ? null : data.talk(_open!);
        return TwoPane(
          list: _list(context, data),
          detail: open == null ? null : TalkPage(key: ValueKey(open.id), talkId: open.id, embedded: true),
        );
      },
    );
  }

  Widget _list(BuildContext context, BurrowData data) {
    final talks = data.talks;
    final canRecord = data.services.store.filesDir != null;
    return HandPage(
      wordmark: context.isWide ? null : data.services.config.wordmark,
      actions: const [ShellActions()],
      bottom: InkButton(
        'record a talk',
        trailing: Doodle.mic,
        onPressed: canRecord ? () => startRecording(context, onDone: _show) : null,
      ),
      children: [
        const PageIntro(
          title: 'talks',
          purpose: 'Record a meeting, a lecture or a call. Burrow writes the notes (who said what, the decisions, the to-dos) on this device.',
          doodle: Doodle.mic,
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: PillButton(
            _importing ? 'bringing it in…' : 'import a recording',
            leading: Doodle.plus,
            onPressed: canRecord && !_importing ? () => _import(context, data) : null,
          ),
        ),
        if (!canRecord) ...[
          const SizedBox(height: 12),
          const DoneNote('Recording and importing need the app on a phone or computer; this browser preview has no files folder.'),
        ],
        const SizedBox(height: 16),
        if (talks.isEmpty)
          const HandEmpty(
            title: 'no talks yet',
            body: 'Record one, or import a recording you already have. The audio stays on this device.',
            doodle: Doodle.mic,
          )
        else ...[
          SectionHead('every talk', note: '${talks.length}'),
          for (final t in talks)
            Door(
              t.title,
              meta: talkMeta(data, t),
              alert: t.status == TalkStatus.failed,
              leading: DoodleIcon(t.imported ? Doodle.plus : Doodle.mic, size: 24, color: context.colors.pencil),
              onTap: () => _show(t),
            ),
        ],
      ],
    );
  }

  Future<void> _import(BuildContext context, BurrowData data) async {
    setState(() => _importing = true);
    try {
      final path = await AudioIo.pickAudio();
      if (path == null) return;
      final id = newTalkId();
      final copy = await data.keepCopy(id, path);
      final t = await data.addTalk(id: id, audioPath: copy, imported: true);
      unawaited(TalkProcessor(data).process(t));
      if (context.mounted) _show(t);
    } on Object catch (e) {
      data.services.log.add('burrow', 'import failed: $e');
      if (context.mounted) {
        await confirmSheet(context, title: 'that file could not be read', body: '$e', confirm: 'okay', cancel: 'close');
      }
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }
}

/// Opens the recorder; when it is stopped, the new talk is processed and shown.
Future<void> startRecording(BuildContext context, {void Function(Talk)? onDone}) async {
  final t = await Navigator.of(context).push<Talk>(MaterialPageRoute(builder: (_) => const RecordPage()));
  if (t == null || !context.mounted) return;
  if (onDone != null) {
    onDone(t);
  } else {
    await pushPage(context, TalkPage(talkId: t.id));
  }
}
