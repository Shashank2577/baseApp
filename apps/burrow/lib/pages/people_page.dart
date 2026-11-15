import 'package:base_core/base_core.dart';
import 'package:flutter/material.dart';

import '../data/burrow_data.dart';
import '../data/models.dart';
import '../widgets/type_roles.dart';
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
          detail: open == null
              ? const HandPage(
                  children: [
                    SizedBox(height: 40),
                    HandEmpty(title: 'pick someone', body: 'Their talks and to-dos open here.', doodle: Doodle.person),
                  ],
                )
              : PersonPage(key: ValueKey(open.id), personId: open.id, embedded: true),
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
          const SectionHead('voices to name'),
          Meta('${voices.length} from the last two weeks.'),
          for (final (t, sp) in voices.take(6))
            ContentRow(
              'Speaker ${sp.index + 1}',
              meta: 'In ${t.title}, ${(sp.talkSec / 60).ceil()} min of talking',
              leading: const DoodleIcon(Doodle.wave, size: 24),
              onTap: () => nameVoice(context, data, t, sp.index),
            ),
          const HandDivider(seed: 2),
        ],
        Align(alignment: Alignment.centerLeft, child: HandLink('add someone', onPressed: () => _add(context, data))),
        const SizedBox(height: 8),
        if (people.isEmpty)
          const HandEmpty(
            title: 'no one yet',
            body: 'Open a talk and tap a voice under "who was there" to name it.',
            doodle: Doodle.person,
          )
        else ...[
          for (final p in people)
            ContentRow(
              p.isMe ? '${p.name} (you)' : p.name,
              meta: _meta(data, p),
              selected: context.isWide && p.id == _open,
              onTap: () => context.isWide ? setState(() => _open = p.id) : pushPage(context, PersonPage(personId: p.id)),
            ),
        ],
      ],
    );
  }

  Future<void> _add(BuildContext context, BurrowData data) async {
    final controller = TextEditingController();
    final name = await showHandSheet<String>(
      context,
      builder: (context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('add someone', style: context.type.title),
          const SizedBox(height: 8),
          const Meta('Then name their voice in a talk, and their to-dos gather on their page.'),
          const SizedBox(height: 14),
          HandField(controller: controller, singleLine: true, autofocus: true, placeholder: 'Their name', leading: Doodle.person),
          const SizedBox(height: 14),
          InkButton('add', onPressed: () => Navigator.pop(context, controller.text)),
        ],
      ),
    );
    if (name != null && name.trim().isNotEmpty) await data.personNamed(name);
  }

  static String _meta(BurrowData data, Person p) {
    final talks = data.talksWith(p).length;
    final open = data.todosOf(p).where((e) => !e.$2.done).length;
    return '$talks talk${talks == 1 ? '' : 's'} · $open open to-do${open == 1 ? '' : 's'}';
  }
}
