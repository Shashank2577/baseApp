import 'package:base_core/base_core.dart';
import 'package:flutter/material.dart';

import '../app_config.dart';
import '../data/burrow_data.dart';
import '../data/models.dart';
import '../logic/ask_agent.dart';
import 'talk_page.dart';

/// "ask Burrow": a small model on this device looks things up in your talks
/// with Burrow's own tools, shows every step, and cites the talks it used.
class AskPage extends StatefulWidget {
  const AskPage(BuildContext context, {super.key});

  @override
  State<AskPage> createState() => _AskPageState();
}

class _AskPageState extends State<AskPage> {
  final _question = TextEditingController();
  bool _confirming = false;
  bool _trace = false;

  @override
  void dispose() {
    _question.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final data = BurrowData.of(context);
    final s = data.services;
    final ask = AskSession.of(data);
    return ListenableBuilder(
      listenable: Listenable.merge([ask, s.models]),
      builder: (context, _) {
        final ready = s.ai.isDemo || s.models.isReady(AppModels.gemma);
        if (ask.pending != null && !_confirming) {
          _confirming = true;
          WidgetsBinding.instance.addPostFrameCallback((_) => _confirm(ask));
        }
        return HandPage(
          wordmark: s.config.wordmark,
          actions: const [ShellActions()],
          bottom: InkButton(
            'ask',
            busy: ask.busy,
            trailing: Doodle.arrow,
            onPressed: ready && !ask.busy ? () => ask.ask(_question.text) : null,
          ),
          children: [
            PageIntro(
              title: 'ask Burrow',
              purpose: ask.phase == AskPhase.idle
                  ? 'Ask about your talks, people and to-dos. A small model on this device looks it up with Burrow\'s own tools. Nothing leaves the device.'
                  : 'Answered from your talks, on this device.',
              doodle: Doodle.bubble,
            ),
            if (!ready)
              DoneNote(
                '${s.models.spec(AppModels.gemma).name} is not on this device yet (${formatBytes(s.models.spec(AppModels.gemma).bytes)}, once).',
                action: 'get it',
                onAction: () => pushPage(context, const ModelsPage()),
              ),
            const SizedBox(height: 8),
            HandField(
              controller: _question,
              placeholder: 'What did we decide about the launch?',
              minHeight: 80,
              leading: Doodle.pen,
              onSubmitted: (q) {
                if (ready) ask.ask(q);
              },
            ),
            const SizedBox(height: 12),
            if (ask.phase == AskPhase.idle)
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final q in const ['what is due this week?', 'what did we decide?', 'what did I promise?'])
                    ChoicePill(
                      q,
                      selected: false,
                      onPressed: () {
                        if (!ready) return;
                        _question.text = q;
                        ask.ask(q);
                      },
                    ),
                ],
              ),
            if (ask.phase == AskPhase.loading) const Meta('Getting the model ready…'),
            if (ask.busy && ask.phase != AskPhase.loading) ...[
              const SizedBox(height: 8),
              const HandProgress(fraction: null),
              const SizedBox(height: 4),
              Meta(ask.steps.isEmpty ? 'Reading your question…' : 'Looking it up: ${ask.steps.last.label}…'),
            ],
            if (ask.answer != null) ...[
              const SizedBox(height: 24),
              Align(
                alignment: Alignment.centerRight,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(color: context.colors.smudge, borderRadius: BorderRadius.circular(14)),
                  child: Text(ask.question, style: context.type.body),
                ),
              ),
              const SizedBox(height: 12),
              const SizedBox(height: 8),
              Prose(ask.answer!),
              const SizedBox(height: 8),
              OnDeviceStamp(text: ask.demo ? 'demo engine: Burrow\'s tools, not a model' : 'answered on this device'),
              if (ask.sources.isNotEmpty) ...[
                const SizedBox(height: 24),
                const SectionHead('from'),
                for (final src in ask.sources)
                  ItemRow(
                    src.title,
                    meta: [if (src.at != null) 'at ${clock(src.at!)}', if (src.quote != null) '"${src.quote}"'].join(' · '),
                    onTap: data.talk(src.talkId) == null ? null : () => pushPage(context, TalkPage(talkId: src.talkId)),
                  ),
              ],
            ],
            if (ask.steps.isNotEmpty && !ask.busy) ...[
              const SizedBox(height: 8),
              HandLink(
                _trace ? 'hide the steps' : '${ask.steps.length} step${ask.steps.length == 1 ? '' : 's'}, all on this device',
                onPressed: () => setState(() => _trace = !_trace),
              ),
              if (_trace) for (final st in ask.steps) _step(context, st),
            ],
            if (ask.answer != null)
              HandLink(
                'ask something else',
                onPressed: () {
                  _question.clear();
                  ask.clear();
                  setState(() => _trace = false);
                },
              ),
            if (ask.error != null) DoneNote('Could not answer: ${ask.error}', action: 'try again', onAction: () => ask.ask(ask.question)),
          ],
        );
      },
    );
  }

  Widget _step(BuildContext context, AskStep st) {
    final c = context.colors;
    final doodle = switch (st.status) {
      StepStatus.running => Doodle.squiggle,
      StepStatus.done => Doodle.tick,
      StepStatus.declined || StepStatus.failed => Doodle.cross,
    };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DoodleIcon(doodle, size: 18, color: st.status == StepStatus.failed ? c.redPen : c.pencil),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(st.label, style: context.type.rowTitle),
                if (st.args.isNotEmpty) Text(st.args, style: context.type.mono),
                if (st.summary != null) Meta(st.summary!),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirm(AskSession ask) async {
    final sentence = ask.pending;
    if (sentence == null) {
      _confirming = false;
      return;
    }
    final yes = await confirmSheet(
      context,
      title: 'Burrow wants to $sentence',
      body: 'Nothing changes unless you say yes.',
      confirm: 'do it',
      cancel: 'no',
    );
    ask.decide(yes);
    _confirming = false;
  }
}
