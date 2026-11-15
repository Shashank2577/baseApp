import 'package:base_core/base_core.dart';
import 'package:flutter/material.dart';

import '../data/burrow_data.dart';
import '../data/models.dart';
import '../widgets/talk_bits.dart';
import 'mask_page.dart';
import 'talk_page.dart';
import 'talks_page.dart';

/// Home: what happened lately and what needs you. The brief is built from the
/// stored notes, so no model runs when the app opens.
class TodayPage extends StatelessWidget {
  const TodayPage(BuildContext context, {super.key});

  @override
  Widget build(BuildContext context) {
    final data = BurrowData.of(context);
    final s = data.services;
    return ListenableBuilder(
      listenable: Listenable.merge([data, s.models]),
      builder: (context, _) {
        final now = DateTime.now();
        final day = now.hour >= 6 && now.hour < 18;
        final missing = s.config.requiredModels.where((id) => !s.models.isReady(id)).toList();
        final brief = Brief.of(data, now);
        final busy = data.talks.where((t) => t.status == TalkStatus.processing).toList();
        final voices = data.voicesToName();
        return HandPage(
          wordmark: s.config.wordmark,
          actions: const [ShellActions()],
          bottom: InkButton(
            'record a talk',
            trailing: Doodle.mic,
            onPressed: s.store.filesDir == null ? null : () => startRecording(context),
          ),
          children: [
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Flexible(child: Text(greeting(now), style: context.type.headline.copyWith(fontSize: 44))),
                const SizedBox(width: 10),
                DoodleIcon(day ? Doodle.sun : Doodle.moon, size: 36, color: context.colors.pencil, tilt: -10),
              ],
            ),
            Meta(MaterialLocalizations.of(context).formatFullDate(now)),
            const SizedBox(height: 16),
            if (missing.isNotEmpty)
              Door(
                'get the speech models',
                mark: 'speech',
                meta: '${missing.length} of ${s.config.requiredModels.length} missing, '
                    '${formatBytes(missing.fold(0, (n, id) => n + s.models.spec(id).bytes))}, once per device',
                leading: const DoodleIcon(Doodle.spark, size: 28),
                onTap: () => pushPage(context, const ModelsPage()),
              ),
            for (final t in busy)
              Door(t.title, meta: t.step ?? 'working', leading: const DoodleIcon(Doodle.pen, size: 26), onTap: () => pushPage(context, TalkPage(talkId: t.id))),
            if (brief.isEmpty && busy.isEmpty) ...[
              const SizedBox(height: 16),
              MarkedText(
                data.talks.isEmpty ? 'nothing yet.' : 'all quiet.',
                // One marker per screen: the model download has it while models are missing.
                mark: missing.isNotEmpty ? null : (data.talks.isEmpty ? 'nothing' : 'quiet'),
                style: context.type.title,
              ),
              const SizedBox(height: 4),
              Meta(
                data.talks.isEmpty
                    ? 'Record a talk and its notes, to-dos and people show up here.'
                    : 'No talks since yesterday and nothing due this week.',
              ),
            ],
            if (!brief.isEmpty) ...[
              const SizedBox(height: 8),
              const SectionHead('your brief', note: 'from your talks'),
              if (brief.recent.isNotEmpty) ...[
                _label(context, 'since yesterday'),
                for (final t in brief.recent)
                  Door(t.title, meta: _recentMeta(t), onTap: () => pushPage(context, TalkPage(talkId: t.id))),
              ],
              if (brief.dueNow.isNotEmpty) ...[
                _label(context, 'due now'),
                for (final (t, todo) in brief.dueNow) _todo(context, data, t, todo),
              ],
              if (brief.thisWeek.isNotEmpty) ...[
                _label(context, 'this week'),
                for (final (t, todo) in brief.thisWeek.take(4)) _todo(context, data, t, todo),
                if (brief.thisWeek.length > 4) Meta('and ${brief.thisWeek.length - 4} more'),
              ],
              if (brief.undated.isNotEmpty) ...[
                _label(context, 'no date said'),
                for (final (t, todo) in brief.undated.take(3)) _todo(context, data, t, todo),
                if (brief.undated.length > 3) Meta('and ${brief.undated.length - 3} more'),
              ],
            ],
            const HandDivider(seed: 4),
            if (voices.isNotEmpty)
              Door(
                'voices to name',
                meta: '${voices.length} in recent talks',
                leading: const DoodleIcon(Doodle.wave, size: 28),
                onTap: () => nameVoice(context, data, voices.first.$1, voices.first.$2.index),
              ),
            Door(
              'mask a message',
              meta: 'swap names and numbers for placeholders before text goes to an AI',
              leading: const DoodleIcon(Doodle.mask, size: 28),
              onTap: () => pushPage(context, const MaskPage()),
            ),
            Door(
              'privacy',
              meta: '${formatBytes(s.ledger.bytesDownloaded)} downloaded, all of it AI models; nothing uploaded',
              leading: const DoodleIcon(Doodle.lock, size: 28),
              onTap: () => pushPage(context, const PrivacyPage()),
            ),
          ],
        );
      },
    );
  }

  static Widget _label(BuildContext context, String text) => Padding(
    padding: const EdgeInsets.only(top: 10, bottom: 2),
    child: Text(text, style: context.type.small.copyWith(color: context.colors.pencil)),
  );

  static String _recentMeta(Talk t) {
    final s = t.summary;
    if (s == null) return t.status == TalkStatus.ready ? 'no summary yet: open it to write one' : (t.step ?? 'not finished');
    final d = s.decisions.length, n = s.todos.length;
    return '$d decision${d == 1 ? '' : 's'} · $n to-do${n == 1 ? '' : 's'}';
  }

  static Widget _todo(BuildContext context, BurrowData data, Talk t, Todo todo) => TodoRow(
    todo: todo,
    context: t.title,
    onTick: (v) => data.tick(t, todo, v),
    onOpen: () => pushPage(context, TalkPage(talkId: t.id)),
  );
}

/// "your brief": talks since yesterday, and open to-dos by when they're due.
class Brief {
  const Brief(this.recent, this.dueNow, this.thisWeek, this.undated);
  final List<Talk> recent;
  final List<(Talk, Todo)> dueNow;
  final List<(Talk, Todo)> thisWeek;
  final List<(Talk, Todo)> undated;

  bool get isEmpty => recent.isEmpty && dueNow.isEmpty && thisWeek.isEmpty && undated.isEmpty;

  static Brief of(BurrowData data, DateTime now) {
    final today = dayOf(now);
    final yesterday = today.subtract(const Duration(days: 1));
    final recent = data.talks.where((t) => t.status == TalkStatus.ready && !t.createdAt.isBefore(yesterday)).toList();
    final open = data.openTodos();
    final dueNow = <(Talk, Todo)>[], week = <(Talk, Todo)>[], undated = <(Talk, Todo)>[];
    for (final e in open) {
      final d = e.$2.due;
      if (d == null) {
        if (!e.$1.createdAt.isBefore(today.subtract(const Duration(days: 7)))) undated.add(e);
        continue;
      }
      final diff = dayOf(d).difference(today).inDays;
      if (diff <= 1) {
        dueNow.add(e);
      } else if (diff <= 7) {
        week.add(e);
      }
    }
    return Brief(recent, dueNow, week, undated);
  }
}
