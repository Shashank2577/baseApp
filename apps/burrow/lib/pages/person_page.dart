import 'package:base_core/base_core.dart';
import 'package:flutter/material.dart';

import '../data/burrow_data.dart';
import '../widgets/talk_bits.dart';
import 'talk_page.dart';

/// One person: the talks they were in and the to-dos that are theirs.
class PersonPage extends StatelessWidget {
  const PersonPage({super.key, required this.personId, this.embedded = false});
  final String personId;
  final bool embedded;

  @override
  Widget build(BuildContext context) {
    final data = BurrowData.of(context);
    return ListenableBuilder(
      listenable: data,
      builder: (context, _) {
        final p = data.person(personId);
        final back = embedded ? null : () => Navigator.of(context).pop();
        if (p == null) {
          return HandPage(onBack: back, children: const [HandEmpty(title: 'forgotten', body: 'This person is no longer in Burrow.')]);
        }
        final talks = data.talksWith(p);
        final todos = data.todosOf(p);
        final open = todos.where((e) => !e.$2.done).toList();
        final done = todos.where((e) => e.$2.done).toList();
        return HandPage(
          onBack: back,
          children: [
            Text(p.isMe ? '${p.name} (you)' : p.name, style: context.type.contentTitle),
            Text(
              '${talks.length} talk${talks.length == 1 ? '' : 's'} together · ${open.length} open to-do${open.length == 1 ? '' : 's'}',
              style: context.type.caption,
            ),
            const SizedBox(height: 24),
            const SectionHead('to-dos'),
            if (todos.isEmpty) Meta('No to-dos are ${p.isMe ? 'yours' : 'theirs'} yet.'),
            for (final (t, todo) in [...open, ...done])
              TodoRow(
                todo: todo,
                context: t.title,
                onTick: (v) => data.tick(t, todo, v),
                onOpen: () => pushPage(context, TalkPage(talkId: t.id)),
              ),
            const SizedBox(height: 24),
            const SectionHead('talks together'),
            if (talks.isEmpty) const Meta('Not in any talk now.'),
            for (final t in talks) ItemRow(t.title, meta: talkMeta(data, t), onTap: () => pushPage(context, TalkPage(talkId: t.id))),
            const SizedBox(height: 24),
            Center(
              child: HandLink(
                'forget ${p.isMe ? 'me' : p.name}',
                color: context.colors.redPen,
                onPressed: () async {
                  final ok = await confirmSheet(
                    context,
                    title: 'forget ${p.isMe ? 'me' : p.name}?',
                    body: 'Their name comes off every talk. The talks themselves stay.',
                    confirm: 'forget',
                    danger: true,
                  );
                  if (!ok) return;
                  await data.forgetPerson(p);
                  if (context.mounted && !embedded) Navigator.of(context).pop();
                },
              ),
            ),
          ],
        );
      },
    );
  }
}
