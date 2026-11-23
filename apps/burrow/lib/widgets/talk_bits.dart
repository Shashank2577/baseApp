import 'package:base_core/base_core.dart';
import 'package:flutter/material.dart';

import '../data/burrow_data.dart';
import '../data/models.dart';
import '../logic/burrow_tools.dart';
import '../logic/processor.dart';

/// "Thu 13 Nov · 12 min · 3 voices".
String talkMeta(BurrowData data, Talk t) {
  final parts = <String>[BurrowTools.day(t.createdAt)];
  if (t.durationSec > 0) parts.add(t.durationSec < 60 ? '${t.durationSec.round()} s' : '${(t.durationSec / 60).round()} min');
  switch (t.status) {
    case TalkStatus.processing:
      parts.add(t.step ?? 'working');
    case TalkStatus.failed:
      parts.add('stopped: open it to try again');
    case TalkStatus.waiting:
      parts.add('waiting');
    case TalkStatus.ready:
      if (t.speakers.isNotEmpty) parts.add('${t.speakers.length} voice${t.speakers.length == 1 ? '' : 's'}');
      final open = t.todos.where((x) => !x.done).length;
      if (open > 0) parts.add('$open to-do${open == 1 ? '' : 's'}');
  }
  return parts.join(' · ');
}

/// "due today", "due Fri 14 Nov", "overdue since Mon 10 Nov", or the words.
String dueText(Todo t, {DateTime? now}) {
  final today = dayOf(now ?? DateTime.now());
  final d = t.due;
  if (d == null) return t.dueWords == null ? 'no date said' : '"${t.dueWords}"';
  final diff = dayOf(d).difference(today).inDays;
  if (diff < 0) return 'overdue since ${BurrowTools.day(d)}';
  if (diff == 0) return 'due today';
  if (diff == 1) return 'due tomorrow';
  return 'due ${BurrowTools.day(d)}';
}

/// A to-do with a drawn tick box. Tapping the box ticks it; tapping the text opens [onOpen].
class TodoRow extends StatelessWidget {
  const TodoRow({super.key, required this.todo, required this.onTick, this.context, this.onOpen});
  final Todo todo;
  final ValueChanged<bool> onTick;

  /// Where it came from ("budget talk"), shown under the text.
  final String? context;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final meta = [
      if (todo.who != null && todo.who!.isNotEmpty) todo.who!,
      dueText(todo),
      if (todo.at != null) 'at ${clock(todo.at!)}',
      if (this.context != null) this.context!,
    ].join(' · ');
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            checked: todo.done,
            label: todo.done ? 'done: ${todo.what}' : 'to do: ${todo.what}',
            button: true,
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: () => onTick(!todo.done),
              child: SizedBox(width: 48, height: 48, child: Center(child: PickMark(picked: todo.done))),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: InkWell(
              onTap: onOpen,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      todo.what,
                      style: context.type.body.copyWith(
                        color: todo.done ? c.pencil : c.ink,
                        decoration: todo.done ? TextDecoration.lineThrough : null,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Meta(meta, color: todo.due != null && !todo.done && dueText(todo).startsWith('overdue') ? c.redPen : null),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A talk being processed: the step it is on, and how far along.
class ProcessingNote extends StatelessWidget {
  const ProcessingNote(this.talk, {super.key});
  final Talk talk;

  @override
  Widget build(BuildContext context) {
    final i = processingSteps.indexOf(talk.step ?? '');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Steps(processingSteps, current: i),
        const SizedBox(height: 12),
        HandProgress(fraction: i < 0 ? 0 : (i + 0.5) / processingSteps.length),
        const SizedBox(height: 8),
        const Meta('This stays on the device. Burrow keeps the screen awake until it is done.'),
      ],
    );
  }
}

/// A notes line tied to a moment in the talk.
class PointRow extends StatelessWidget {
  const PointRow(this.point, {super.key});
  final Point point;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(padding: const EdgeInsets.only(top: 3), child: DoodleIcon(Doodle.curl, size: 16, color: context.colors.pencil)),
        const SizedBox(width: 10),
        Expanded(child: Body(point.text)),
        if (point.at != null) ...[const SizedBox(width: 8), Text(clock(point.at!), style: context.type.mono.copyWith(color: context.colors.pencil))],
      ],
    ),
  );
}
