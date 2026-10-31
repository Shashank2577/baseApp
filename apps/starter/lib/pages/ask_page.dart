import 'package:base_core/base_core.dart';
import 'package:flutter/material.dart';

import '../app_config.dart';

/// One question, one streamed answer, from the on-device model.
class AskPage extends StatefulWidget {
  const AskPage(BuildContext context, {super.key});

  @override
  State<AskPage> createState() => _AskPageState();
}

class _AskPageState extends State<AskPage> {
  final _question = TextEditingController();
  String _answer = '';
  bool _busy = false;

  String get _modelId => AppModels.ask;

  Future<void> _ask() async {
    final s = BaseScope.of(context);
    final text = _question.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _busy = true;
      _answer = '';
    });
    try {
      final spec = s.models.spec(_modelId);
      if (!s.ai.llm.isLoaded(_modelId)) {
        await s.ai.llm.load(modelId: _modelId, path: s.models.pathOf(_modelId, spec.files.first.name));
      }
      await for (final e in s.ai.llm.generate(
        GenerationRequest(modelId: _modelId, sessionId: 'ask', history: [EngineTurn(role: TurnRole.user, text: text)]),
      )) {
        if (e is TokenEvent) setState(() => _answer += e.text);
        if (e is ErrorEvent) setState(() => _answer = e.message);
      }
      s.ledger.add(AppLedger.questions);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _question.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = BaseScope.of(context);
    return ListenableBuilder(
      listenable: s.models,
      builder: (context, _) {
        // The demo engine needs no model file; a real engine does.
        final ready = s.ai.isDemo || s.models.isReady(_modelId);
        return HandPage(
          actions: const [ShellActions()],
          bottom: InkButton('ask', busy: _busy, trailing: Doodle.arrow, onPressed: ready ? _ask : null),
          children: [
            PageIntro(
              title: 'ask',
              purpose: 'Ask the model on this device a question. Nothing you type leaves it.',
              doodle: Doodle.bubble,
            ),
            if (!ready)
              DoneNote(
                '${s.models.spec(_modelId).name} is not on this device yet.',
                action: 'get it',
                onAction: () => pushPage(context, const ModelsPage()),
              ),
            HandField(controller: _question, placeholder: 'what would you like to know?', minHeight: 96, leading: Doodle.pen),
            const SizedBox(height: 16),
            if (_answer.isNotEmpty) ...[
              const SectionHead('answer'),
              Body(_answer),
              const SizedBox(height: 8),
              OnDeviceStamp(text: s.ai.isDemo ? 'demo engine: scripted, not a model' : 'answered on this device'),
            ],
          ],
        );
      },
    );
  }
}
