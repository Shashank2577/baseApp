import 'dart:async';

import 'package:base_core/base_core.dart';
import 'package:flutter/foundation.dart';

import '../app_config.dart';
import '../data/burrow_data.dart';
import 'burrow_tools.dart';
import 'summarizer.dart';

enum StepStatus { running, done, declined, failed }

/// A row in "what Burrow did".
class AskStep {
  const AskStep(this.tool, this.label, this.args, this.status, [this.summary]);
  final String tool;
  final String label;
  final String args;
  final StepStatus status;
  final String? summary;
  AskStep copyWith(StepStatus status, [String? summary]) => AskStep(tool, label, args, status, summary);
}

class AskOutcome {
  const AskOutcome(this.answer, this.sources);
  final String answer;
  final List<AskSource> sources;
}

/// The system prompt, from Burrow's AskSession (photos and chats left out).
String askSystemPrompt(DateTime today) =>
    '''
You are Burrow, a private assistant that runs entirely on the user's device. You answer questions about the user's recorded talks (meetings and phone calls), the people in them, and the to-dos from them.
Today is ${TalkSummarizer.longDay(today)}.
Rules:
- Always call a tool to look things up before answering. Never make up names, dates, numbers or quotes.
- Use what people actually said, and say which talk it came from.
- If the tools find nothing, say so plainly and suggest what the user could try.
- Answer in one to three short sentences, in the user's language. No lists or headings.
- Only call rename_talk when the user asks for exactly that.''';

/// The tool loop. The model reads the question and asks for tools; Burrow runs
/// them on the device and hands back the results, until the model answers.
/// Every step shows as it happens, tools that change data wait for the user's
/// yes, and the rounds are capped so a confused small model can't loop
/// forever. Ported from Burrow's AskAgent.kt.
class AskAgent {
  AskAgent(this.llm, this.modelId, this.tools, {this.maxRounds = 5});
  final LlmEngine llm;
  final String modelId;
  final BurrowTools tools;
  final int maxRounds;

  Future<AskOutcome> run(
    String question, {
    required void Function(List<AskStep>) onStep,
    required Future<bool> Function(String sentence) confirm,
  }) async {
    final native = llm.supportsNativeTools;
    final specs = [for (final t in BurrowTools.all) t.spec];
    final system = askSystemPrompt(tools.now()) + (native ? '' : '\n${ToolCallParser.prompt(specs)}');
    final known = {for (final t in BurrowTools.all) t.name};
    final history = <EngineTurn>[EngineTurn(role: TurnRole.user, text: question)];
    final steps = <AskStep>[];
    final sources = <String, AskSource>{};
    final declined = <String>[];
    final session = 'ask-${DateTime.now().microsecondsSinceEpoch}';

    Future<(String, List<ToolCallRequest>)> turn() async {
      final text = StringBuffer();
      final calls = <ToolCallRequest>[];
      await for (final e in llm.generate(
        GenerationRequest(
          modelId: modelId,
          sessionId: session,
          history: List.of(history),
          systemPrompt: system,
          tools: native ? specs : const [],
          sampler: const SamplerSettings(temperature: 0.2, topK: 20, topP: 0.9, maxTokens: 512),
        ),
      )) {
        if (e is TokenEvent) text.write(e.text);
        if (e is ToolCallsEvent) calls.addAll(e.calls);
        if (e is ErrorEvent) throw StateError(e.message);
      }
      var reply = text.toString();
      if (!native && calls.isEmpty) {
        final parsed = ToolCallParser.parse(reply, known);
        calls.addAll(parsed.calls);
        if (parsed.calls.isNotEmpty) reply = text.toString();
      }
      history.add(EngineTurn(role: TurnRole.model, text: reply, toolCalls: calls));
      return (reply, calls);
    }

    try {
      var (reply, calls) = await turn();
      var rounds = 0;
      while (calls.isNotEmpty && rounds++ < maxRounds) {
        final responses = <ToolResponse>[];
        for (final call in calls) {
          final tool = BurrowTools.byName(call.name);
          steps.add(AskStep(call.name, tool?.label ?? call.name, argsText(call.arguments), StepStatus.running));
          onStep(List.of(steps));
          final i = steps.length - 1;
          Map<String, dynamic> json;
          if (tool == null) {
            steps[i] = steps[i].copyWith(StepStatus.failed, 'no such tool');
            json = {'error': 'there is no tool called ${call.name}'};
          } else if (tool.changesThings && !await _confirmed(tools.describe(call.name, call.arguments), confirm, declined)) {
            steps[i] = steps[i].copyWith(StepStatus.declined, 'you said no');
            json = {'declined': true, 'note': "The user said no. Don't try again; tell them it wasn't done."};
          } else {
            try {
              final r = await tools.run(call.name, call.arguments);
              for (final s in r.sources) {
                sources[s.key] = s;
              }
              steps[i] = steps[i].copyWith(StepStatus.done, r.summary);
              json = r.json;
            } on ArgumentError catch (e) {
              steps[i] = steps[i].copyWith(StepStatus.failed, '${e.message}');
              json = {'error': '${e.message}'};
            }
          }
          onStep(List.of(steps));
          responses.add(ToolResponse(callId: call.id, name: call.name, response: json));
        }
        history.add(EngineTurn(role: TurnRole.tool, toolResponses: responses));
        (reply, calls) = await turn();
      }
      final clean = ToolCallParser.parse(reply, known).text.trim();
      final answer = declined.isNotEmpty
          // Small models sometimes claim they did what the user just refused, so Burrow says this part itself.
          ? "Okay, I left it as it was: I didn't ${declined.join(' or ')}."
          : clean.isNotEmpty
          ? clean
          : calls.isNotEmpty
          ? "I couldn't work that out in a few steps. Try asking it more simply."
          : "I don't have an answer for that.";
      return AskOutcome(answer, cited(answer, sources.values.toList()));
    } finally {
      await llm.resetSession(session);
    }
  }

  static Future<bool> _confirmed(String sentence, Future<bool> Function(String) confirm, List<String> declined) async {
    final yes = await confirm(sentence);
    if (!yes) declined.add(sentence);
    return yes;
  }

  static String argsText(Map<String, dynamic> args) => args.entries
      .where((e) => e.value != null && '${e.value}'.trim().isNotEmpty)
      .map((e) => e.value is String ? '${e.key}: "${e.value}"' : '${e.key}: ${e.value is num && (e.value as num) % 1 == 0 ? (e.value as num).toInt() : e.value}')
      .join(', ');

  /// The sources worth showing under an answer: the ones it names (a talk's
  /// title, a quote's words), else the first few the tools returned. Small
  /// models cite unreliably, so Burrow does the citing.
  static List<AskSource> cited(String answer, List<AskSource> all) {
    final a = answer.toLowerCase();
    double overlap(String quote) {
      final words = quote.toLowerCase().split(RegExp(r'\W+')).where((w) => w.length > 3).toSet();
      if (words.isEmpty) return 0;
      return words.where(a.contains).length / words.length;
    }

    final named = all.where((s) => s.quote != null ? overlap(s.quote!) >= 0.5 : a.contains(s.title.toLowerCase())).toList();
    final quoted = named.where((s) => s.quote != null).map((s) => s.talkId).toSet();
    final tidy = named.where((s) => !(s.quote == null && quoted.contains(s.talkId))).toList();
    return (tidy.isEmpty ? all.take(3).toList() : tidy).take(5).toList();
  }
}

enum AskPhase { idle, loading, thinking, done, failed }

/// One question at a time. Lives with the app's data (not the screen), so the
/// answer is still there after opening a cited talk and coming back. Questions
/// and answers are held in memory only, never saved.
class AskSession extends ChangeNotifier {
  AskSession._(this.data);
  final BurrowData data;

  static final _instances = Expando<AskSession>('ask');
  static AskSession of(BurrowData data) => _instances[data] ??= AskSession._(data);

  String question = '';
  AskPhase phase = AskPhase.idle;
  List<AskStep> steps = const [];
  String? pending;
  String? answer;
  List<AskSource> sources = const [];
  String? error;
  bool demo = false;
  Completer<bool>? _decision;

  bool get busy => phase == AskPhase.loading || phase == AskPhase.thinking;

  BaseServices get _s => data.services;

  Future<void> ask(String q) async {
    q = q.trim();
    if (q.isEmpty || busy) return;
    question = q;
    phase = AskPhase.loading;
    steps = const [];
    answer = null;
    sources = const [];
    error = null;
    demo = _s.ai.isDemo;
    notifyListeners();
    try {
      // Loading Gemma and answering take a while: keep the app awake meanwhile.
      final outcome = await KeepAwake.during('answer', 'writing an answer', () async {
        await data.ready;
        final tools = BurrowTools(data);
        if (demo) return _demo(q, tools);
        final spec = _s.models.spec(AppModels.gemma);
        if (!_s.ai.llm.isLoaded(AppModels.gemma)) {
          await _s.ai.llm.load(modelId: AppModels.gemma, path: _s.models.pathOf(AppModels.gemma, spec.files.first.name), maxTokens: 8192);
        }
        phase = AskPhase.thinking;
        notifyListeners();
        return AskAgent(_s.ai.llm, AppModels.gemma, tools).run(
          q,
          onStep: (s) {
            steps = s;
            notifyListeners();
          },
          confirm: (sentence) {
            final d = Completer<bool>();
            _decision = d;
            pending = sentence;
            notifyListeners();
            return d.future.whenComplete(() {
              pending = null;
              notifyListeners();
            });
          },
        );
      }, ai: true);
      answer = outcome.answer;
      sources = outcome.sources;
      phase = AskPhase.done;
      _s.ledger.add(AppLedger.questions);
    } on Object catch (e) {
      error = '$e';
      phase = AskPhase.failed;
      _s.log.add('burrow', 'ask failed: $e');
    }
    notifyListeners();
  }

  /// The user's answer to "Burrow wants to …".
  void decide(bool yes) {
    _decision?.complete(yes);
    _decision = null;
  }

  void clear() {
    if (busy) return;
    question = '';
    phase = AskPhase.idle;
    steps = const [];
    answer = null;
    sources = const [];
    error = null;
    notifyListeners();
  }

  /// The demo engine has no model to plan with, so Burrow runs its own tools by
  /// keyword and reads out what they found, saying so.
  Future<AskOutcome> _demo(String q, BurrowTools tools) async {
    phase = AskPhase.thinking;
    notifyListeners();
    final lower = q.toLowerCase();
    final calls = <(String, Map<String, dynamic>)>[];
    for (final x in data.people) {
      if (lower.contains(x.name.toLowerCase().split(' ').first)) calls.add(('find_person', {'name': x.name}));
    }
    final wantsTodos = RegExp(r'to-?do|follow|due|promise|owe|send|deadline|week').hasMatch(lower);
    calls.add(wantsTodos ? ('follow_ups', <String, dynamic>{}) : ('search_talks', {'query': q}));
    final found = <String>[];
    final all = <String, AskSource>{};
    for (final (name, args) in calls) {
      final tool = BurrowTools.byName(name)!;
      steps = [...steps, AskStep(name, tool.label, AskAgent.argsText(args), StepStatus.running)];
      notifyListeners();
      await Future<void>.delayed(const Duration(milliseconds: 200));
      final r = await tools.run(name, args);
      for (final s in r.sources) {
        all[s.key] = s;
      }
      steps = [...steps.take(steps.length - 1), steps.last.copyWith(StepStatus.done, r.summary)];
      notifyListeners();
      found.add(r.summary);
    }
    final answer =
        'Demo engine, no model: Burrow looked this up with its own tools and found ${found.join('; ')}. '
        'With Gemma 4 E2B on an iPhone, Mac or Android phone, it writes the answer in its own words.';
    return AskOutcome(answer, all.values.take(3).toList());
  }
}
