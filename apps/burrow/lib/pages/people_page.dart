import 'package:base_core/base_core.dart';
import 'package:flutter/material.dart';

import '../data/burrow_data.dart';
import '../data/models.dart';
import 'person_page.dart';
import 'talk_page.dart';

/// Everyone named in a talk, and the voices still waiting for a name.
class PeoplePage extends StatefulWidget {
  const PeoplePage(BuildContext context, {super.key});

  @override
  State<PeoplePage> createState() => _PeoplePageState();
}

class _PeoplePageState extends State<PeoplePage> {
  String? _open;

  @override
  Widget build(BuildContext context) {
    final data = BurrowData.of(context);
    return ListenableBuilder(
      listenable: data,
      builder: (context, _) {
        final open = data.person(_open);
        return TwoPane(
          list: _list(context, data),
          detail: open == null ? null : PersonPage(key: ValueKey(open.id), personId: open.id, embedded: true),
        );
      },
    );
  }

  Widget _list(BuildContext context, BurrowData data) {
    final people = [...data.people]..sort((a, b) => a.isMe ? -1 : (b.isMe ? 1 : a.name.compareTo(b.name)));
    final voices = data.voicesToName();
    return HandPage(
      wordmark: context.isWide ? null : data.services.config.wordmark,
      actions: const [ShellActions()],
      children: [
        const PageIntro(
          title: 'people',
          purpose: 'Everyone you have named in a talk: their talks and their to-dos. Burrow only knows a voice once you name it.',
          doodle: Doodle.people,
        ),
        if (voices.isNotEmpty) ...[
          SectionHead('voices to name', note: '${voices.length} from the last two weeks'),
          for (final (t, sp) in voices.take(6))
            Door(
              'speaker ${sp.index + 1}',
              mark: voices.first == (t, sp) ? 'speaker' : null,
              meta: 'in ${t.title}',
              leading: const DoodleIcon(Doodle.wave, size: 26),
              onTap: () => nameVoice(context, data, t, sp.index),
            ),
          const HandDivider(seed: 2),
        ],
        if (people.isEmpty)
          const HandEmpty(
            title: 'no one yet',
            body: 'Open a talk and tap a voice under "who was there" to name it.',
            doodle: Doodle.person,
          )
        else ...[
          SectionHead('named', note: '${people.length}'),
          for (final p in people)
            Door(
              p.isMe ? '${p.name} (you)' : p.name,
              meta: _meta(data, p),
              leading: const DoodleIcon(Doodle.person, size: 26),
              onTap: () => context.isWide ? setState(() => _open = p.id) : pushPage(context, PersonPage(personId: p.id)),
            ),
        ],
      ],
    );
  }

  static String _meta(BurrowData data, Person p) {
    final talks = data.talksWith(p).length;
    final open = data.todosOf(p).where((e) => !e.$2.done).length;
    return '$talks talk${talks == 1 ? '' : 's'} · $open open to-do${open == 1 ? '' : 's'}';
  }
}
