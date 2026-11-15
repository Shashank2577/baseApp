import 'dart:convert';

import 'package:base_core/base_core.dart';

import '../data/models.dart';
import 'due_dates.dart';

/// One prompt in, one answer out, no tools: what summaries need from a model.
abstract class TextModel {
  Future<String> complete(String system, String prompt);
}

/// [TextModel] over the platform's LLM engine (Gemma on LiteRT-LM). A fresh
/// conversation each time, so parts never leak into each other.
class EngineText implements TextModel {
  EngineText(this.llm, this.modelId);
  final LlmEngine llm;
  final String modelId;
  int _n = 0;

  @override
  Future<String> complete(String system, String prompt) async {
    final session = 'notes-${_n++}';
    final out = StringBuffer();
    try {
      await for (final e in llm.generate(
        GenerationRequest(
          modelId: modelId,
          sessionId: session,
          systemPrompt: system,
          history: [EngineTurn(role: TurnRole.user, text: prompt)],
          sampler: const SamplerSettings(temperature: 0.2, topK: 20, topP: 0.9, maxTokens: 1536),
        ),
      )) {
        if (e is TokenEvent) out.write(e.text);
        if (e is ErrorEvent) throw StateError(e.message);
      }
    } finally {
      await llm.resetSession(session);
    }
    return out.toString();
  }
}

/// Writes a talk's notes with the on-device model: a short gist, key points,
/// decisions and to-dos (who, what, by when), each tied to the moment it was
/// said. Ported from Burrow's TalkSummarizer.kt, prompts unchanged.
///
/// Long talks don't fit the model's window, so they're summarised in parts
/// first and the parts are then merged. Every line the model returns is
/// checked: times must fall inside the talk, dates are worked out in code.
class TalkSummarizer {
  TalkSummarizer(this.model, this.modelName, {this.partChars = 16000});
  final TextModel model;
  final String modelName;
  final int partChars;

  static const system =
      'You write short, accurate notes of recorded conversations. You only use what is in the transcript. You reply with JSON only.';

  static const _shape =
      '{"gist":"…","points":[{"text":"…","at":"12:30"}],"decisions":[{"text":"…","at":"23:10"}],"todos":[{"who":"…","what":"…","when":"…","at":"28:20"}]}';

  /// [people] names everyone, with "(the user)" after the user; [who] names a line's speaker.
  Future<Summary> summarize(
    Talk talk, {
    required List<String> people,
    required String Function(int? speaker) who,
    String writeIn = 'English',
    void Function(String step)? progress,
  }) async {
    if (talk.lines.isEmpty) throw StateError("there's no transcript to summarise");
    final chars = talk.lines.fold<int>(0, (n, l) => n + l.text.length);
    final wide = talk.lines.fold<int>(0, (n, l) => n + l.text.runes.where((r) => r > 0x2FF).length);
    // Scripts like Devanagari take more of the model's window per character.
    final budget = wide > chars / 3 ? partChars * 2 ~/ 3 : partChars;
    final parts = _split(talk.lines, who, budget);
    Summary notes;
    if (parts.length == 1) {
      progress?.call('writing the summary');
      notes = await _ask(_prompt(talk, people, parts[0], who, writeIn, null), talk);
    } else {
      final partial = <Summary>[];
      for (var i = 0; i < parts.length; i++) {
        progress?.call('summarising part ${i + 1} of ${parts.length}');
        partial.add(await _ask(_prompt(talk, people, parts[i], who, writeIn, (i, parts.length)), talk));
      }
      progress?.call('putting the parts together');
      notes = await _ask(_mergePrompt(talk, people, partial, writeIn), talk);
    }
    final tidy = _tidy(notes);
    return Summary(
      gist: tidy.gist,
      points: tidy.points,
      decisions: tidy.decisions,
      todos: tidy.todos,
      model: modelName,
      language: writeIn,
      writtenAt: DateTime.now(),
      byModel: true,
    );
  }

  /// Drop lines that repeat an earlier one (merging parts, and recaps at the end, make repeats).
  static Summary _tidy(Summary s) {
    Set<String> words(String t) =>
        t.toLowerCase().split(RegExp(r'[^\p{L}\p{M}\p{N}]+', unicode: true)).where((w) => w.length > 2).toSet();
    List<T> unique<T>(List<T> items, String Function(T) text) {
      final kept = <(T, Set<String>)>[];
      for (final item in items) {
        final w = words(text(item));
        final repeat = kept.any((k) {
          final ks = k.$2;
          if (w.isEmpty || ks.isEmpty) return false;
          final small = w.length < ks.length ? w.length : ks.length;
          return w.intersection(ks).length >= 0.7 * small;
        });
        if (!repeat) kept.add((item, w));
      }
      return [for (final k in kept) k.$1];
    }

    final decisions = unique(s.decisions, (p) => p.text);
    // A point that only restates a decision goes; the decision says it.
    final points = unique([...decisions, ...s.points], (p) => p.text).skip(decisions.length).toList();
    return Summary(gist: s.gist, points: points, decisions: decisions, todos: unique(s.todos, (t) => t.what));
  }

  static List<List<Line>> _split(List<Line> lines, String Function(int?) who, int budget) {
    final out = <List<Line>>[[]];
    var size = 0;
    for (final l in lines) {
      final n = l.text.length + who(l.speaker).length + 10;
      if (size + n > budget && out.last.isNotEmpty) {
        out.add([]);
        size = 0;
      }
      out.last.add(l);
      size += n;
    }
    return out;
  }

  static const _days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
  static const _months = [
    'January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December',
  ];

  /// "Thursday 13 November 2026".
  static String longDay(DateTime d) => '${_days[d.weekday - 1]} ${d.day} ${_months[d.month - 1]} ${d.year}';

  String _header(Talk talk, List<String> people) {
    final minutes = (talk.durationSec / 60).floor();
    final b = StringBuffer(
      'Talk: "${talk.title}", recorded on ${longDay(talk.createdAt)} (${dayKey(talk.createdAt)}), ${minutes < 1 ? 1 : minutes} minutes long.',
    );
    final lang = languageName(talk.language);
    if (lang != null) b.write(' It was spoken in $lang.');
    if (people.isNotEmpty) b.write('\nPeople in it: ${people.join(', ')}.');
    return b.toString();
  }

  static String _rules(String writeIn) =>
      '''
Rules:
- Write every text value in $writeIn, even if the talk was in another language. Keep people's names as they are.
- "gist": two or three sentences on what the talk was about and how it ended.
- "points": up to 5 objects, the most important facts or updates from the talk.
- "decisions": up to 5 objects, things the people agreed or settled (a date chosen, an option picked, a plan approved).
- "todos": up to 8 objects, things someone said they or someone else will do.
- Every list item is an object with "text" (or "what" for todos) and "at". Fill "points" and "decisions" whenever the talk has any.
- Only include what was actually said.
- "at" is the [minutes:seconds] of the line it comes from.
- "when" copies the words the talk used for when it's due ("by Friday", "the tenth", "next Tuesday"), or "" if none. Don't turn it into a date.
- "who" is the person's name as listed above, or "" if it's unclear.
Reply with the JSON only.''';

  String _prompt(Talk talk, List<String> people, List<Line> part, String Function(int?) who, String writeIn, (int, int)? which) {
    final b = StringBuffer()..writeln(_header(talk, people));
    if (which != null) {
      b.writeln('This is part ${which.$1 + 1} of ${which.$2} of the transcript (${clock(part.first.at)} to ${clock(part.last.at)}).');
    }
    b.writeln('Transcript, each line starting with [minutes:seconds] and who spoke:');
    for (final l in part) {
      b.writeln('[${clock(l.at)}] ${who(l.speaker)}: ${l.text}');
    }
    b
      ..writeln()
      ..writeln('Write notes for ${which != null ? 'this part' : 'this talk'} as JSON exactly in this shape:')
      ..writeln(_shape)
      ..write(_rules(writeIn));
    return b.toString();
  }

  String _mergePrompt(Talk talk, List<String> people, List<Summary> parts, String writeIn) {
    final b = StringBuffer()
      ..writeln(_header(talk, people))
      ..writeln('Here are notes for each part of the talk, in order:');
    for (var i = 0; i < parts.length; i++) {
      b.writeln('Part ${i + 1}: ${encode(parts[i])}');
    }
    b
      ..writeln()
      ..writeln('Combine them into notes for the whole talk, as JSON exactly in this shape (drop repeats, keep the times):')
      ..writeln(_shape)
      ..write(_rules(writeIn));
    return b.toString();
  }

  /// Ask, and ask once more if the answer wasn't usable JSON.
  Future<Summary> _ask(String prompt, Talk talk) async {
    final first = parse(await model.complete(system, prompt), talk);
    if (first != null) return first;
    final second = parse(
      await model.complete(system, "$prompt\n\nYour last answer wasn't valid JSON. Reply with only the JSON object."),
      talk,
    );
    if (second != null) return second;
    throw StateError("the model's notes couldn't be read");
  }

  /// Read the model's JSON, tolerating code fences and chatter around it; null if it isn't usable.
  static Summary? parse(String text, Talk talk) {
    final start = text.indexOf('{');
    final end = text.lastIndexOf('}');
    if (start < 0 || end <= start) return null;
    Map o;
    try {
      final v = jsonDecode(text.substring(start, end + 1));
      if (v is! Map) return null;
      o = v;
    } on FormatException {
      return null;
    }
    final gist = _str(o, 'gist');
    if (gist == null) return null;
    double? at(Map e) {
      final s = _str(e, 'at');
      final v = s == null ? null : parseClock(s);
      return v != null && v <= talk.durationSec + 5 ? v : null;
    }

    List<Point> points(String key) => [
      for (final e in _items(o, key))
        if ((_str(e, 'text') ?? _str(e, 'what')) case final t?) Point(t, at(e)),
    ].take(6).toList();
    final todos = <Todo>[];
    for (final e in _items(o, 'todos')) {
      final what = _str(e, 'what') ?? _str(e, 'text');
      if (what == null) continue;
      final words = _str(e, 'when') ?? _str(e, 'due');
      todos.add(
        Todo(
          id: '${talk.id}-t${todos.length}',
          what: what,
          who: _str(e, 'who'),
          dueWords: words,
          due: DueDates.resolve(words, talk.createdAt),
          at: at(e),
        ),
      );
      if (todos.length == 10) break;
    }
    return Summary(gist: gist, points: points('points'), decisions: points('decisions'), todos: todos);
  }

  static String? _str(Map m, String k) {
    final v = m[k];
    if (v == null || v is Map || v is List) return null;
    final s = '$v'.trim();
    return s.isEmpty || s == 'null' ? null : s;
  }

  /// A list's items as objects; a plain string becomes {"text": it} (small models do that).
  static List<Map> _items(Map o, String k) => [
    for (final e in (o[k] is List ? o[k] as List : const []))
      if (e is Map)
        e
      else if (e is String && e.trim().isNotEmpty)
        {'text': e},
  ];

  static String encode(Summary s) => jsonEncode({
    'gist': s.gist,
    'points': [
      for (final p in s.points) {'text': p.text, 'at': p.at == null ? '' : clock(p.at!)},
    ],
    'decisions': [
      for (final p in s.decisions) {'text': p.text, 'at': p.at == null ? '' : clock(p.at!)},
    ],
    'todos': [
      for (final t in s.todos)
        {'who': t.who ?? '', 'what': t.what, 'when': t.dueWords ?? (t.due == null ? '' : dayKey(t.due!)), 'at': t.at == null ? '' : clock(t.at!)},
    ],
  });
}

/// "en" → "English". Null for an unknown or empty code.
String? languageName(String? code) {
  const names = {
    'en': 'English', 'de': 'German', 'fr': 'French', 'es': 'Spanish', 'it': 'Italian', 'pt': 'Portuguese', 'nl': 'Dutch',
    'sv': 'Swedish', 'da': 'Danish', 'no': 'Norwegian', 'fi': 'Finnish', 'pl': 'Polish', 'cs': 'Czech', 'sk': 'Slovak',
    'hu': 'Hungarian', 'ro': 'Romanian', 'bg': 'Bulgarian', 'el': 'Greek', 'hr': 'Croatian', 'sl': 'Slovenian', 'et': 'Estonian',
    'lv': 'Latvian', 'lt': 'Lithuanian', 'uk': 'Ukrainian', 'ru': 'Russian', 'hi': 'Hindi', 'bn': 'Bengali', 'ta': 'Tamil',
    'te': 'Telugu', 'mr': 'Marathi', 'ja': 'Japanese', 'zh': 'Chinese', 'ko': 'Korean', 'ar': 'Arabic', 'tr': 'Turkish',
  };
  if (code == null || code.isEmpty) return null;
  return names[code.toLowerCase().split(RegExp('[-_]')).first];
}
