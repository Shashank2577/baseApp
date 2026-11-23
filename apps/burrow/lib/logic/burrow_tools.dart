import 'dart:convert';

import 'package:base_core/base_core.dart';

import '../data/burrow_data.dart';
import '../data/models.dart';

/// Something an answer can point back to: a talk, maybe a moment in it.
class AskSource {
  const AskSource(this.talkId, this.title, {this.at, this.quote});
  final String talkId;
  final String title;
  final double? at;
  final String? quote;
  String get key => '$talkId/${at ?? ''}';
}

/// Result of running one tool: [json] goes back to the model; the rest is for the screen.
class ToolResult {
  const ToolResult(this.json, this.summary, [this.sources = const []]);
  final Map<String, dynamic> json;
  final String summary;
  final List<AskSource> sources;
}

/// A tool as the model and the screen see it. Tools that [changesThings]
/// never run without the user saying yes.
class BurrowTool {
  const BurrowTool(this.spec, this.label, {this.changesThings = false});
  final ToolSpec spec;
  final String label;
  final bool changesThings;
  String get name => spec.name;
}

/// Burrow's own data as tools a small on-device model can call. Results are
/// kept small (a 2B model's window is precious) and use plain words rather
/// than ids where they can. Ported from Burrow's BurrowTools.kt; the photo and
/// chat tools are left out (no photo sweep or chat import here).
class BurrowTools {
  BurrowTools(this.data, {DateTime Function()? now}) : now = now ?? DateTime.now;
  final BurrowData data;
  final DateTime Function() now;

  static Map<String, dynamic> _schema(Map<String, (String, String)> props, {List<String> required = const []}) => {
    'type': 'object',
    'properties': {
      for (final e in props.entries) e.key: {'type': e.value.$1, 'description': e.value.$2},
    },
    if (required.isNotEmpty) 'required': required,
  };

  static final all = <BurrowTool>[
    BurrowTool(
      ToolSpec(
        name: 'find_person',
        description: 'Look up people the user has named in their talks. Use it first when a question names someone.',
        parameters: _schema({'name': ('string', 'The person\'s name or first name, or "me" for the user.')}, required: ['name']),
      ),
      'find a person',
    ),
    BurrowTool(
      ToolSpec(
        name: 'search_talks',
        description: 'Search the user\'s recorded talks (meetings and calls). Returns matching talks with the lines that match.',
        parameters: _schema({
          'query': ('string', 'Words to look for in what was said, the title or the topics. Leave out to list recent talks.'),
          'person': ('string', 'Only talks this person spoke in.'),
          'days': ('integer', 'Only talks from the last this many days.'),
        }),
      ),
      'search talks',
    ),
    BurrowTool(
      ToolSpec(
        name: 'follow_ups',
        description: 'Promises and to-dos said in talks, like "I\'ll send the budget by Friday", with their due dates.',
        parameters: _schema({
          'person': ('string', 'Only things this person said or has to do.'),
          'talk_id': ('string', 'Only this talk.'),
          'days': ('integer', 'Only talks from the last this many days.'),
        }),
      ),
      'find follow-ups',
    ),
    BurrowTool(
      ToolSpec(
        name: 'talk_details',
        description: 'Everything about one talk: who was there, topics, the summary, decisions, to-dos and the start of the transcript.',
        parameters: _schema({'talk_id': ('string', 'The talk\'s id from search_talks.')}, required: ['talk_id']),
      ),
      'open a talk',
    ),
    BurrowTool(
      ToolSpec(
        name: 'rename_talk',
        description: 'Give a talk a new title. Only when the user asks to rename it.',
        parameters: _schema({'talk_id': ('string', 'The talk\'s id.'), 'title': ('string', 'The new title.')}, required: ['talk_id', 'title']),
      ),
      'rename a talk',
      changesThings: true,
    ),
  ];

  static BurrowTool? byName(String name) => all.where((t) => t.name == name).firstOrNull;

  /// The sentence the user confirms before a tool that changes something runs.
  String describe(String name, Map<String, dynamic> args) => switch (name) {
    'rename_talk' => 'rename "${data.talk('${args['talk_id']}')?.title ?? 'this talk'}" to "${args['title']}"',
    _ => name,
  };

  Future<ToolResult> run(String name, Map<String, dynamic> args) async => switch (name) {
    'find_person' => _findPerson(_str(args, 'name') ?? (throw ArgumentError('which name?'))),
    'search_talks' => _searchTalks(_str(args, 'query'), _str(args, 'person'), _int(args, 'days')),
    'follow_ups' => _followUps(_str(args, 'person'), _str(args, 'talk_id'), _int(args, 'days')),
    'talk_details' => _talkDetails(_str(args, 'talk_id') ?? (throw ArgumentError('which talk?'))),
    'rename_talk' => await _rename(
      _str(args, 'talk_id') ?? (throw ArgumentError('which talk?')),
      _str(args, 'title') ?? (throw ArgumentError('what title?')),
    ),
    _ => throw ArgumentError('there is no tool called $name'),
  };

  static String? _str(Map<String, dynamic> a, String k) {
    final v = a[k];
    if (v == null) return null;
    final s = '$v'.trim();
    return s.isEmpty ? null : s;
  }

  static int? _int(Map<String, dynamic> a, String k) {
    final v = a[k];
    return v is num ? v.toInt() : int.tryParse('${v ?? ''}');
  }

  static const _wd = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  static const _mo = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

  /// "Thu 13 Nov".
  static String day(DateTime d) => '${_wd[d.weekday - 1]} ${d.day} ${_mo[d.month - 1]}';

  List<Talk> get _ready => data.talks.where((t) => t.status == TalkStatus.ready).toList();

  List<Person> _match(String name) {
    final q = name.trim().toLowerCase();
    if (const {'me', 'i', 'myself', 'my', 'you'}.contains(q)) return data.people.where((x) => x.isMe).toList();
    final exact = data.people.where((x) => x.name.toLowerCase() == q).toList();
    if (exact.isNotEmpty) return exact;
    final words = q.split(' ').where((w) => w.isNotEmpty);
    return data.people.where((x) {
      final n = x.name.toLowerCase().split(' ');
      return words.every((w) => n.any((p) => p.startsWith(w)));
    }).toList();
  }

  ToolResult _findPerson(String name) {
    final people = _match(name);
    if (people.isEmpty) {
      final known = data.people.map((x) => x.name).join(', ');
      return ToolResult({
        'people': [],
        'note': 'No one called $name. People Burrow knows: ${known.isEmpty ? 'none yet' : known}.',
      }, 'no one called $name');
    }
    final out = [
      for (final x in people)
        {
          'name': x.name,
          'is_me': x.isMe,
          'talks': data.talksWith(x).length,
          'last_talk': data.talksWith(x).map((t) => '${t.title}, ${day(t.createdAt)}').firstOrNull,
          'open_todos': data.todosOf(x).where((e) => !e.$2.done).length,
        },
    ];
    return ToolResult(
      {'people': out},
      people.map((x) => '${x.name} · ${data.talksWith(x).length} talk${data.talksWith(x).length == 1 ? '' : 's'}').join(', '),
    );
  }

  (List<Talk>, List<Person>?) _scope(String? person, int? days) {
    final who = person == null ? null : _match(person);
    final since = days != null && days > 0 ? now().subtract(Duration(days: days)) : null;
    final talks = _ready.where((t) {
      if (since != null && t.createdAt.isBefore(since)) return false;
      if (who != null && !t.speakers.any((s) => who.any((x) => x.id == s.personId))) return false;
      return true;
    }).toList();
    return (talks, who);
  }

  static List<String> _words(String? q) {
    const stop = {'the', 'a', 'an', 'and', 'or', 'of', 'to', 'in', 'on', 'about', 'what', 'did', 'we', 'i', 'my', 'is', 'was', 'for', 'with'};
    return (q ?? '').toLowerCase().split(RegExp(r'[^\p{L}\p{N}]+', unicode: true)).where((w) => w.length > 1 && !stop.contains(w)).toList();
  }

  ToolResult _searchTalks(String? query, String? person, int? days) {
    final (scope, who) = _scope(person, days);
    if (who != null && who.isEmpty) return ToolResult({'talks': [], 'note': 'No one called $person.'}, 'no one called $person');
    final words = _words(query);
    final hits = <(Talk, List<Line>, int)>[];
    for (final t in scope) {
      final matching = words.isEmpty ? <Line>[] : t.lines.where((l) => words.any((w) => l.text.toLowerCase().contains(w))).toList();
      final summaryText = [t.summary?.gist ?? '', ...t.topics.map((x) => x.name)].join(' ').toLowerCase();
      final titleHit = words.any((w) => t.title.toLowerCase().contains(w) || summaryText.contains(w));
      if (words.isNotEmpty && matching.isEmpty && !titleHit) continue;
      hits.add((t, matching, matching.length + (titleHit ? 2 : 0)));
    }
    hits.sort((a, b) => b.$3 != a.$3 ? b.$3.compareTo(a.$3) : b.$1.createdAt.compareTo(a.$1.createdAt));
    final top = hits.take(5).toList();
    final sources = <AskSource>[];
    final out = [
      for (final (t, matching, _) in top)
        {
          'talk_id': t.id,
          'title': t.title,
          'date': day(t.createdAt),
          'minutes': (t.durationSec / 60).round(),
          'people': data.peopleIn(t).map((x) => x.name).join(', '),
          'gist': t.summary?.gist ?? '',
          'lines': [for (final l in matching.take(3)) '[${clock(l.at)}] ${data.speakerName(t, l.speaker)}: ${l.text}'],
        },
    ];
    for (final (t, matching, _) in top) {
      sources.add(AskSource(t.id, t.title));
      for (final l in matching.take(3)) {
        sources.add(AskSource(t.id, t.title, at: l.at, quote: l.text));
      }
    }
    final summary = switch (top.length) {
      0 => 'no talks found',
      1 => top[0].$1.title,
      _ => '${top.length} talks: ${top.take(2).map((h) => h.$1.title).join(', ')}${top.length > 2 ? '…' : ''}',
    };
    return ToolResult({'talks': out}, summary, sources);
  }

  ToolResult _followUps(String? person, String? talkId, int? days) {
    final (scope, who) = _scope(null, days);
    final items = <(Talk, Todo)>[];
    for (final t in scope.where((t) => talkId == null || t.id == talkId)) {
      for (final todo in t.todos) {
        if (person != null) {
          final people = _match(person);
          if (people.isEmpty || !people.any((x) => data.todosOf(x).any((e) => e.$2.id == todo.id))) continue;
        }
        items.add((t, todo));
      }
    }
    final out = [
      for (final (t, todo) in items.take(8))
        {
          'talk_id': t.id,
          'talk': '${t.title}, ${day(t.createdAt)}',
          'who': todo.who ?? 'not said',
          'what': todo.what,
          'due': todo.due == null ? (todo.dueWords ?? 'no date') : day(todo.due!),
          'done': todo.done,
        },
    ];
    if (who != null && who.isEmpty) return ToolResult({'follow_ups': [], 'note': 'No one called $person.'}, 'no one called $person');
    return ToolResult(
      {'follow_ups': out},
      out.length == 1 ? '1 follow-up' : '${out.length} follow-ups',
      [for (final (t, todo) in items.take(8)) AskSource(t.id, t.title, at: todo.at, quote: todo.what)],
    );
  }

  ToolResult _talkDetails(String id) {
    final t = data.talk(id) ?? (throw ArgumentError("there's no talk $id"));
    if (t.status != TalkStatus.ready) {
      return ToolResult({'title': t.title, 'note': "This talk's notes aren't ready yet."}, 'notes not ready', [AskSource(t.id, t.title)]);
    }
    final total = t.speakers.fold<double>(0, (a, s) => a + s.talkSec);
    final s = t.summary;
    return ToolResult(
      {
        'talk_id': t.id,
        'title': t.title,
        'date': day(t.createdAt),
        'minutes': (t.durationSec / 60).round(),
        'people': [for (final sp in t.speakers) '${data.speakerName(t, sp.index)} ${total == 0 ? 0 : (sp.talkSec * 100 / total).round()}%'],
        'topics': t.topics.take(4).map((x) => x.name.toLowerCase()).join(', '),
        'gist': s?.gist ?? '',
        'decisions': [for (final d in s?.decisions ?? const <Point>[]) d.text],
        'todos': [for (final x in t.todos) '${x.who ?? 'someone'}: ${x.what}${x.due == null ? '' : ' (due ${day(x.due!)})'}'],
        'start': [for (final l in t.lines.take(6)) '[${clock(l.at)}] ${data.speakerName(t, l.speaker)}: ${l.text}'],
      },
      t.title,
      [AskSource(t.id, t.title)],
    );
  }

  Future<ToolResult> _rename(String id, String title) async {
    final t = data.talk(id) ?? (throw ArgumentError("there's no talk $id"));
    final old = t.title;
    await data.renameTalk(t, title);
    return ToolResult({'done': true, 'old_title': old, 'new_title': title}, 'renamed to "$title"', [AskSource(t.id, title)]);
  }

  static String encode(Map<String, dynamic> json) => jsonEncode(json);
}
