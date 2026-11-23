import 'package:base_core/base_core.dart';
import 'package:burrow/app_config.dart';
import 'package:burrow/data/burrow_data.dart';
import 'package:burrow/data/models.dart';
import 'package:burrow/logic/ask_agent.dart';
import 'package:burrow/logic/burrow_tools.dart';
import 'package:burrow/logic/due_dates.dart';
import 'package:burrow/logic/summarizer.dart';
import 'package:burrow/logic/talk_text.dart';
import 'package:flutter_test/flutter_test.dart';

/// An LLM that replies from a script, one reply per call, and records what it was sent.
class ScriptedLlm extends DemoLlmEngine {
  ScriptedLlm(this.replies, {this.native = false});
  final List<String> replies;
  final bool native;
  final requests = <GenerationRequest>[];

  @override
  bool get supportsNativeTools => native;

  @override
  Stream<GenEvent> generate(GenerationRequest request) async* {
    requests.add(request);
    yield TokenEvent(replies.removeAt(0));
    yield const DoneEvent(GenerationStats());
  }
}

class FakeText implements TextModel {
  FakeText(this.replies);
  final List<String> replies;
  int calls = 0;
  @override
  Future<String> complete(String system, String prompt) async {
    calls++;
    return replies.removeAt(0);
  }
}

void main() {
  // Thursday 12 November 2026.
  final thu = DateTime(2026, 11, 12);

  group('DueDates', () {
    test('weekdays, relative words and days of the month', () {
      expect(DueDates.resolve('by Friday', thu), DateTime(2026, 11, 13));
      expect(DueDates.resolve('next Tuesday', thu), DateTime(2026, 11, 17));
      expect(DueDates.resolve('Thursday', thu), DateTime(2026, 11, 19));
      expect(DueDates.resolve('tomorrow', thu), DateTime(2026, 11, 13));
      expect(DueDates.resolve('next week', thu), DateTime(2026, 11, 19));
      expect(DueDates.resolve('end of the month', thu), DateTime(2026, 11, 30));
      expect(DueDates.resolve('the tenth', thu), DateTime(2026, 12, 10));
      expect(DueDates.resolve('20 November', thu), DateTime(2026, 11, 20));
      expect(DueDates.resolve('March 3rd', thu), DateTime(2027, 3, 3));
      expect(DueDates.resolve('अगले मंगलवार', thu), DateTime(2026, 11, 17));
      expect(DueDates.resolve('2026-11-01', thu), isNull, reason: 'past dates are dropped');
      expect(DueDates.resolve('soon', thu), isNull);
      expect(DueDates.resolve('', thu), isNull);
    });
  });

  Talk talk() => Talk(
    id: 't1',
    title: 'launch planning',
    createdAt: thu,
    durationSec: 600,
    lines: const [
      Line(0, 20, 0, 'Okay, let us start. The launch moves to Thursday.'),
      Line(21, 40, 1, 'Priya will update the deck by Friday. Sam books the venue by Monday.'),
    ],
    speakers: const [Speaker(0, talkSec: 20), Speaker(1, talkSec: 19)],
  );

  group('TalkSummarizer', () {
    test('reads the model JSON, checks times and works out dates', () {
      final s = TalkSummarizer.parse(
        'Here you go:\n```json\n{"gist":"Launch planning.","points":["The deck needs work"],'
        '"decisions":[{"text":"Launch on Thursday","at":"0:10"}],'
        '"todos":[{"who":"Priya","what":"Update the deck","when":"by Friday","at":"0:25"},{"what":"Out of range","at":"99:00"}]}\n```',
        talk(),
      )!;
      expect(s.gist, 'Launch planning.');
      expect(s.points.single.text, 'The deck needs work');
      expect(s.decisions.single.at, 10);
      expect(s.todos.first.due, DateTime(2026, 11, 13));
      expect(s.todos.first.who, 'Priya');
      expect(s.todos.last.at, isNull, reason: 'a time outside the talk is dropped');
      expect(TalkSummarizer.parse('no json here', talk()), isNull);
    });

    test('asks once more when the answer is not JSON, and uses the prompts', () async {
      final model = FakeText(['Sorry, here are notes.', '{"gist":"Done.","todos":[{"what":"Book the venue","when":"Monday"}]}']);
      final s = await TalkSummarizer(model, 'Gemma 4 E2B').summarize(talk(), people: ['Priya', 'Sam'], who: (i) => 'speaker ${i! + 1}');
      expect(model.calls, 2);
      expect(s.byModel, isTrue);
      expect(s.model, 'Gemma 4 E2B');
      expect(s.todos.single.due, DateTime(2026, 11, 16));
    });

    test('long talks are summarised in parts, then merged', () async {
      final model = FakeText(['{"gist":"a"}', '{"gist":"b"}', '{"gist":"both"}']);
      final s = await TalkSummarizer(model, 'm', partChars: 60).summarize(talk(), people: const [], who: (_) => 'x');
      expect(model.calls, 3);
      expect(s.gist, 'both');
    });
  });

  test('lines from words and turns, and notes picked by rules', () {
    final words = wordsFor('Okay, let us start. The launch moves to Thursday. Priya will update the deck by Friday.', const [], 12);
    final lines = linesFrom(words, const [Turn(0, 0, 6), Turn(1, 6.1, 12)]);
    expect(lines.length, 2);
    expect(lines.first.speaker, 0);
    expect(lines.map((l) => l.text).join(' '), startsWith('Okay, let us start.'));
    final notes = ruleNotes(talk(), (i) => 'speaker ${(i ?? 0) + 1}', model: 'rules');
    expect(notes.decisions.single.text, 'The launch moves to Thursday.');
    expect(notes.todos.first.who, 'Priya');
    expect(notes.todos.first.due, DateTime(2026, 11, 13));
    expect(notes.todos.last.what, 'Sam books the venue by Monday.');
    expect(notes.todos.last.due, DateTime(2026, 11, 16));
  });

  group('ask Burrow', () {
    late BaseServices s;
    late BurrowData data;

    setUp(() async {
      s = await BaseServices.create(appConfig, store: MemoryJsonStore(), useNativeLocation: false, ai: AiRuntime.demo());
      data = BurrowData.forServices(s);
      await data.ready;
      final t = await data.addTalk(id: 't1', audioPath: null, imported: true);
      t
        ..title = 'launch planning'
        ..status = TalkStatus.ready
        ..lines = talk().lines
        ..speakers = talk().speakers
        ..summary = Summary(
          gist: 'The launch moved.',
          todos: [Todo(id: 'x', what: 'Update the deck', who: 'Priya', due: DateTime(2026, 11, 13))],
        );
      await data.nameSpeaker(t, 1, await data.personNamed('Priya'));
    });

    test('runs tools the model asks for in text (iOS and macOS), and cites the talk', () async {
      final llm = ScriptedLlm([
        '```tool_call\n{"name": "search_talks", "arguments": {"query": "launch"}}\n```',
        'The launch moves to Thursday, said in launch planning.',
      ]);
      final steps = <List<AskStep>>[];
      final out = await AskAgent(llm, AppModels.gemma, BurrowTools(data)).run('when is the launch?', onStep: steps.add, confirm: (_) async => true);
      expect(out.answer, 'The launch moves to Thursday, said in launch planning.');
      expect(steps.last.single.status, StepStatus.done);
      expect(steps.last.single.summary, 'launch planning');
      expect(out.sources.first.talkId, 't1');
      // The tool list was in the system prompt, and the result went back as a tool turn.
      expect(llm.requests.first.systemPrompt, contains('```tool_call'));
      expect(llm.requests.last.history.last.role, TurnRole.tool);
      expect(llm.requests.last.history.last.toolResponses.single.response['talks'], isNotEmpty);
    });

    test('a tool that changes things waits for a yes, and a no is said plainly', () async {
      final llm = ScriptedLlm([
        '```tool_call\n{"name": "rename_talk", "arguments": {"talk_id": "t1", "title": "launch"}}\n```',
        'Done, I renamed it.',
      ]);
      final out = await AskAgent(llm, AppModels.gemma, BurrowTools(data)).run('rename it', onStep: (_) {}, confirm: (_) async => false);
      expect(data.talk('t1')!.title, 'launch planning');
      expect(out.answer, startsWith("Okay, I left it as it was: I didn't rename"));
    });

    test('rounds are capped', () async {
      final call = '```tool_call\n{"name": "follow_ups", "arguments": {}}\n```';
      final llm = ScriptedLlm(List.generate(7, (_) => call));
      final out = await AskAgent(llm, AppModels.gemma, BurrowTools(data), maxRounds: 3).run('loop', onStep: (_) {}, confirm: (_) async => true);
      expect(out.answer, contains("couldn't work that out"));
      expect(llm.requests.length, 4);
    });

    test('follow-ups and people', () async {
      final tools = BurrowTools(data);
      final f = await tools.run('follow_ups', {'person': 'Priya'});
      expect((f.json['follow_ups'] as List).single['what'], 'Update the deck');
      final p = await tools.run('find_person', {'name': 'pri'});
      expect((p.json['people'] as List).single['talks'], 1);
    });
  });
}
