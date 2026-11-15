/// Burrow's records: talks (with their transcript, speakers and notes) and the
/// people named in them. Plain JSON, kept in the app's JsonStore.
library;

enum TalkStatus { waiting, processing, ready, failed }

/// One line of transcript: when, who (speaker index), what.
class Line {
  const Line(this.at, this.end, this.speaker, this.text);
  final double at;
  final double end;
  final int? speaker;
  final String text;

  Map<String, Object?> toJson() => {'at': at, 'end': end, 'sp': speaker, 'text': text};
  static Line fromJson(Map m) => Line(_d(m['at']), _d(m['end']), m['sp'] as int?, m['text'] as String? ?? '');
}

/// A voice in one talk, and the person it was named as (if any).
class Speaker {
  const Speaker(this.index, {this.personId, this.talkSec = 0});
  final int index;
  final String? personId;
  final double talkSec;

  Speaker withPerson(String? id) => Speaker(index, personId: id, talkSec: talkSec);

  Map<String, Object?> toJson() => {'i': index, 'p': personId, 'sec': talkSec};
  static Speaker fromJson(Map m) => Speaker(m['i'] as int, personId: m['p'] as String?, talkSec: _d(m['sec']));
}

class Topic {
  const Topic(this.name, this.score);
  final String name;
  final double score;
  Map<String, Object?> toJson() => {'name': name, 'score': score};
  static Topic fromJson(Map m) => Topic(m['name'] as String, _d(m['score']));
}

/// A line of the notes, tied to the moment it was said ([at], seconds).
class Point {
  const Point(this.text, [this.at]);
  final String text;
  final double? at;
  Map<String, Object?> toJson() => {'text': text, 'at': at};
  static Point fromJson(Map m) => Point(m['text'] as String, (m['at'] as num?)?.toDouble());
}

/// Who does what, and by when. [due] is worked out in code from [dueWords]
/// and the day of the talk; the model only copies the words.
class Todo {
  const Todo({required this.id, required this.what, this.who, this.due, this.dueWords, this.at, this.done = false});
  final String id;
  final String what;
  final String? who;
  final DateTime? due;
  final String? dueWords;
  final double? at;
  final bool done;

  Todo ticked(bool value) => Todo(id: id, what: what, who: who, due: due, dueWords: dueWords, at: at, done: value);

  Map<String, Object?> toJson() => {
    'id': id,
    'what': what,
    'who': who,
    'due': due == null ? null : dayKey(due!),
    'words': dueWords,
    'at': at,
    'done': done,
  };
  static Todo fromJson(Map m) => Todo(
    id: m['id'] as String,
    what: m['what'] as String,
    who: m['who'] as String?,
    due: m['due'] == null ? null : DateTime.tryParse(m['due'] as String),
    dueWords: m['words'] as String?,
    at: (m['at'] as num?)?.toDouble(),
    done: m['done'] as bool? ?? false,
  );
}

/// A talk's notes: the gist, key points, decisions and to-dos.
class Summary {
  const Summary({
    required this.gist,
    this.points = const [],
    this.decisions = const [],
    this.todos = const [],
    this.model = '',
    this.language = 'English',
    this.writtenAt,
    this.byModel = false,
  });
  final String gist;
  final List<Point> points;
  final List<Point> decisions;
  final List<Todo> todos;

  /// Who wrote it: a model's name, or "rules" when picked from the transcript.
  final String model;
  final String language;
  final DateTime? writtenAt;

  /// True when an on-device model (not the demo engine, not rules) wrote it.
  final bool byModel;

  Summary copyWith({List<Todo>? todos}) => Summary(
    gist: gist,
    points: points,
    decisions: decisions,
    todos: todos ?? this.todos,
    model: model,
    language: language,
    writtenAt: writtenAt,
    byModel: byModel,
  );

  Map<String, Object?> toJson() => {
    'gist': gist,
    'points': [for (final p in points) p.toJson()],
    'decisions': [for (final p in decisions) p.toJson()],
    'todos': [for (final t in todos) t.toJson()],
    'model': model,
    'language': language,
    'writtenAt': writtenAt?.toIso8601String(),
    'byModel': byModel,
  };
  static Summary fromJson(Map m) => Summary(
    gist: m['gist'] as String? ?? '',
    points: _list(m['points']).map(Point.fromJson).toList(),
    decisions: _list(m['decisions']).map(Point.fromJson).toList(),
    todos: _list(m['todos']).map(Todo.fromJson).toList(),
    model: m['model'] as String? ?? '',
    language: m['language'] as String? ?? 'English',
    writtenAt: DateTime.tryParse(m['writtenAt'] as String? ?? ''),
    byModel: m['byModel'] as bool? ?? false,
  );
}

class Talk {
  Talk({
    required this.id,
    required this.title,
    required this.createdAt,
    this.durationSec = 0,
    this.audioFile,
    this.imported = false,
    this.status = TalkStatus.waiting,
    this.step,
    this.error,
    this.language,
    this.lines = const [],
    this.speakers = const [],
    this.topics = const [],
    this.followUps = const [],
    this.summary,
    this.demo = false,
  });

  final String id;
  String title;
  final DateTime createdAt;
  double durationSec;

  /// File name under the app's files folder (wiped with everything else).
  String? audioFile;
  final bool imported;
  TalkStatus status;

  /// What processing is doing now ("writing the transcript").
  String? step;
  String? error;

  /// The spoken language, as Ear reported it ("en").
  String? language;
  List<Line> lines;
  List<Speaker> speakers;
  List<Topic> topics;

  /// Commitments found by phrasing ("I'll send…"), kept even without a model.
  List<Line> followUps;
  Summary? summary;

  /// True when the demo engines produced this talk's transcript.
  bool demo;

  List<Todo> get todos => summary?.todos ?? const [];

  Speaker? speaker(int? index) {
    for (final s in speakers) {
      if (s.index == index) return s;
    }
    return null;
  }

  Map<String, Object?> toJson() => {
    'id': id,
    'title': title,
    'createdAt': createdAt.toIso8601String(),
    'duration': durationSec,
    'audio': audioFile,
    'imported': imported,
    'status': status.name,
    'step': step,
    'error': error,
    'language': language,
    'lines': [for (final l in lines) l.toJson()],
    'speakers': [for (final s in speakers) s.toJson()],
    'topics': [for (final t in topics) t.toJson()],
    'followUps': [for (final l in followUps) l.toJson()],
    'summary': summary?.toJson(),
    'demo': demo,
  };

  static Talk fromJson(Map m) => Talk(
    id: m['id'] as String,
    title: m['title'] as String? ?? 'a talk',
    createdAt: DateTime.tryParse(m['createdAt'] as String? ?? '') ?? DateTime.now(),
    durationSec: _d(m['duration']),
    audioFile: m['audio'] as String?,
    imported: m['imported'] as bool? ?? false,
    status: TalkStatus.values.asNameMap()[m['status']] ?? TalkStatus.waiting,
    step: m['step'] as String?,
    error: m['error'] as String?,
    language: m['language'] as String?,
    lines: _list(m['lines']).map(Line.fromJson).toList(),
    speakers: _list(m['speakers']).map(Speaker.fromJson).toList(),
    topics: _list(m['topics']).map(Topic.fromJson).toList(),
    followUps: _list(m['followUps']).map(Line.fromJson).toList(),
    summary: m['summary'] == null ? null : Summary.fromJson(m['summary'] as Map),
    demo: m['demo'] as bool? ?? false,
  );
}

class Person {
  const Person({required this.id, required this.name, this.isMe = false});
  final String id;
  final String name;
  final bool isMe;

  Map<String, Object?> toJson() => {'id': id, 'name': name, 'me': isMe};
  static Person fromJson(Map m) => Person(id: m['id'] as String, name: m['name'] as String, isMe: m['me'] as bool? ?? false);
}

double _d(Object? v) => (v as num?)?.toDouble() ?? 0;
List<Map> _list(Object? v) => ((v as List?) ?? const []).cast<Map>();

/// "2026-11-15".
String dayKey(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// The date part only, at local midnight.
DateTime dayOf(DateTime d) => DateTime(d.year, d.month, d.day);

/// "12:30" or "1:02:03".
String clock(double seconds) {
  final s = seconds.round();
  String two(int n) => n.toString().padLeft(2, '0');
  final h = s ~/ 3600, m = (s % 3600) ~/ 60, sec = s % 60;
  return h > 0 ? '$h:${two(m)}:${two(sec)}' : '$m:${two(sec)}';
}

/// "12:30", "1:02:03", "750", "[4:05]" → seconds.
double? parseClock(String s) {
  final parts = s.trim().replaceAll('[', '').replaceAll(']', '').split(':').map((p) => double.tryParse(p.trim())).toList();
  if (parts.any((p) => p == null)) return null;
  return switch (parts.length) {
    1 => parts[0],
    2 => parts[0]! * 60 + parts[1]!,
    3 => parts[0]! * 3600 + parts[1]! * 60 + parts[2]!,
    _ => null,
  };
}
