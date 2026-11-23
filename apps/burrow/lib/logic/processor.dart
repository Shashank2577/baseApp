import 'package:base_core/base_core.dart';

import '../app_config.dart';
import '../data/burrow_data.dart';
import '../data/models.dart';
import 'summarizer.dart';
import 'talk_text.dart';

/// The steps a talk goes through on the device, in order.
const processingSteps = [
  'getting the speech models',
  'finding the language',
  'writing the transcript',
  'telling the voices apart',
  'finding the topics',
  'writing the summary',
];

/// Turns a recording into notes, on the device: Ear finds the language, Voz
/// writes the transcript, Who tells the voices apart, Gist finds the topics,
/// then Gemma writes the summary (or, without it, rules pick the notes from
/// the transcript). Ported from Burrow's MeetingProcessor and SummaryWorker.
class TalkProcessor {
  TalkProcessor(this.data);
  final BurrowData data;
  BaseServices get s => data.services;

  static final _running = <String>{};

  static bool isRunning(String id) => _running.contains(id);

  Future<void> process(Talk t) async {
    if (!_running.add(t.id)) return;
    try {
      // Long work: keep the app awake meanwhile (iOS keeps the screen on; macOS doesn't nap).
      await KeepAwake.during('talk-${t.id}', 'writing notes for a talk', () => _run(t), ai: true);
    } finally {
      _running.remove(t.id);
    }
  }

  Future<void> _step(Talk t, String step) async {
    t
      ..status = TalkStatus.processing
      ..step = step
      ..error = null;
    await data.save();
  }

  Future<Map<String, dynamic>> _special(String model, Map<String, dynamic> input) async {
    final r = await s.ai.specialists.run(model, 'run', input);
    if (r['error'] != null) throw StateError('${s.models.spec(model).name}: ${r['error']}');
    return r;
  }

  Future<void> _run(Talk t) async {
    final demo = s.ai.isDemo;
    final audio = data.audioPath(t) ?? '';
    try {
      await _step(t, processingSteps[0]);
      if (!demo) {
        for (final id in AppModels.speech) {
          if (!s.models.isReady(id)) await s.ensureModel(id);
        }
      }

      await _step(t, processingSteps[1]);
      final ear = await _special(AppModels.ear, {'audioPath': audio});
      t.language = (ear['language'] as String?)?.trim();

      await _step(t, processingSteps[2]);
      final voz = await _special(AppModels.voz, {'audioPath': audio});
      final text = (voz['text'] as String? ?? '').trim();
      final duration = (voz['duration'] as num?)?.toDouble() ?? t.durationSec;
      if (duration > 0) t.durationSec = duration;
      final timed = [
        for (final w in (voz['words'] as List? ?? const []).cast<Map>())
          Word('${w['text']}', (w['start'] as num).toDouble(), (w['end'] as num).toDouble()),
      ];

      await _step(t, processingSteps[3]);
      final who = await _special(AppModels.who, {'audioPath': audio});
      final turns = [
        for (final u in (who['turns'] as List? ?? const []).cast<Map>())
          Turn((u['speaker'] as num).toInt(), (u['start'] as num).toDouble(), (u['end'] as num).toDouble()),
      ];
      final lines = linesFrom(wordsFor(text, timed, t.durationSec), turns);
      if (lines.isEmpty) throw StateError('No speech was found in this recording.');
      final talkSec = <int, double>{};
      for (final l in lines) {
        if (l.speaker != null) talkSec.update(l.speaker!, (v) => v + (l.end - l.at), ifAbsent: () => l.end - l.at);
      }
      final previous = {for (final sp in t.speakers) sp.index: sp.personId};
      t
        ..lines = lines
        ..speakers = [for (final e in talkSec.entries) Speaker(e.key, personId: previous[e.key], talkSec: e.value)]
        ..followUps = followUpsOf(sentencesOf(lines))
        ..demo = demo;

      await _step(t, processingSteps[4]);
      if (demo || s.models.isReady(AppModels.gist)) {
        try {
          final g = await _special(AppModels.gist, {'text': text});
          t.topics = [
            for (final x in (g['topics'] as List? ?? const []).cast<Map>()) Topic('${x['name']}', (x['score'] as num?)?.toDouble() ?? 0),
          ];
        } on Object catch (e) {
          s.log.add('burrow', 'topics skipped: $e');
        }
      }
      if (t.title == 'a new talk' || t.title == 'an imported talk') t.title = titleFor(t.topics, t.createdAt);

      await _step(t, processingSteps[5]);
      t.summary = await summarize(t);
      t
        ..status = TalkStatus.ready
        ..step = null;
      s.ledger.add(AppLedger.talks);
      await data.save();
    } on OfflineException catch (e) {
      await _fail(t, '${e.modelName} is not on this device, and "never go online" is on. Turn it off on the privacy page to get it.');
    } on Object catch (e) {
      s.log.add('burrow', 'talk ${t.id} failed: $e');
      await _fail(t, '$e');
    }
  }

  Future<void> _fail(Talk t, String message) async {
    t
      ..status = TalkStatus.failed
      ..step = null
      ..error = message;
    await data.save();
  }

  /// Gemma's notes when it is on the device; otherwise notes picked by rules,
  /// which say so. Also used by "summarise again".
  Future<Summary> summarize(Talk t, {void Function(String)? progress}) async {
    String who(int? sp) => data.speakerName(t, sp);
    final people = [
      for (final x in data.peopleIn(t)) x.isMe ? '${x.name} (the user)' : x.name,
    ];
    if (s.ai.isDemo) return ruleNotes(t, who, model: 'demo engine: picked from the transcript by rules, not written by a model');
    if (!s.models.isReady(AppModels.gemma)) {
      return ruleNotes(t, who, model: 'picked from the transcript by rules (get Gemma 4 E2B for written notes)');
    }
    try {
      final spec = s.models.spec(AppModels.gemma);
      if (!s.ai.llm.isLoaded(AppModels.gemma)) {
        await s.ai.llm.load(modelId: AppModels.gemma, path: s.models.pathOf(AppModels.gemma, spec.files.first.name), maxTokens: 8192);
      }
      return await TalkSummarizer(EngineText(s.ai.llm, AppModels.gemma), spec.name).summarize(
        t,
        people: people,
        who: who,
        progress: progress,
      );
    } on Object catch (e) {
      s.log.add('burrow', 'summary by Gemma failed, notes picked by rules instead: $e');
      return ruleNotes(t, who, model: 'picked from the transcript by rules (Gemma could not write them: $e)');
    }
  }

  /// Writes the summary again, e.g. after naming the speakers.
  Future<void> resummarize(Talk t) async {
    if (!_running.add(t.id)) return;
    try {
      await KeepAwake.during('talk-${t.id}', 'writing a summary', () async {
        final ticked = {for (final x in t.todos.where((x) => x.done)) x.what.toLowerCase()};
        await _step(t, processingSteps[5]);
        final s = await summarize(t);
        // Ticks survive a rewrite when the to-do is still there.
        t.summary = s.copyWith(todos: [for (final x in s.todos) ticked.contains(x.what.toLowerCase()) ? x.ticked(true) : x]);
        t
          ..status = TalkStatus.ready
          ..step = null;
        await data.save();
      }, ai: true);
    } finally {
      _running.remove(t.id);
    }
  }
}
