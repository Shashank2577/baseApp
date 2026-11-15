import 'dart:io';

import 'package:base_core/base_core.dart';
import 'package:flutter/widgets.dart';
import 'package:path/path.dart' as p;

import 'models.dart';

/// Burrow's talks and people, kept in the app's JsonStore. One per
/// [BaseServices]; reach it with `BurrowData.of(context)`. Audio files live
/// under the store's files folder, so "wipe everything" removes them too.
class BurrowData extends ChangeNotifier {
  BurrowData._(this.services) {
    services.settings.addListener(_onSettings);
  }

  final BaseServices services;
  JsonStore get _store => services.store;

  static const _talksKey = 'burrow.talks';
  static const _peopleKey = 'burrow.people';

  static final _instances = Expando<BurrowData>('burrow');

  static BurrowData of(BuildContext context) => forServices(BaseScope.of(context));

  static BurrowData forServices(BaseServices s) => _instances[s] ??= BurrowData._(s).._load();

  final List<Talk> _talks = [];
  final List<Person> _people = [];
  bool loaded = false;
  late Future<void> ready;

  /// Newest first.
  List<Talk> get talks => List.unmodifiable(_talks);
  List<Person> get people => List.unmodifiable(_people);

  void _load() {
    ready = () async {
      final t = (await _store.read(_talksKey) as List?) ?? const [];
      final pp = (await _store.read(_peopleKey) as List?) ?? const [];
      _talks
        ..clear()
        ..addAll(t.cast<Map>().map(Talk.fromJson));
      _people
        ..clear()
        ..addAll(pp.cast<Map>().map(Person.fromJson));
      _talks.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      // A talk that was mid-way when the app stopped is offered again.
      for (final x in _talks.where((x) => x.status == TalkStatus.processing)) {
        x
          ..status = TalkStatus.failed
          ..error = 'Burrow was closed while this talk was being processed.'
          ..step = null;
      }
      loaded = true;
      notifyListeners();
    }();
  }

  /// After "wipe everything" the store is empty and onboarding shows again:
  /// forget what is in memory too.
  void _onSettings() {
    if (!services.settings.onboarded && (_talks.isNotEmpty || _people.isNotEmpty)) {
      _talks.clear();
      _people.clear();
      notifyListeners();
    }
  }

  Future<void> save() async {
    notifyListeners();
    await _store.write(_talksKey, [for (final t in _talks) t.toJson()]);
    await _store.write(_peopleKey, [for (final x in _people) x.toJson()]);
  }

  // ---- talks

  Talk? talk(String id) {
    for (final t in _talks) {
      if (t.id == id) return t;
    }
    return null;
  }

  /// Where a new talk's audio goes, or null where the app has no files folder (web).
  String? newAudioPath(String id, String ext) {
    final dir = _store.filesDir;
    if (dir == null) return null;
    final d = Directory(p.join(dir, 'talks'))..createSync(recursive: true);
    return p.join(d.path, '$id.$ext');
  }

  String? audioPath(Talk t) => t.audioFile == null || _store.filesDir == null ? null : p.join(_store.filesDir!, 'talks', t.audioFile);

  /// Copies an imported file into Burrow's own folder (the original stays where it was).
  Future<String?> keepCopy(String id, String source) async {
    final ext = p.extension(source).replaceFirst('.', '').toLowerCase();
    final dest = newAudioPath(id, ext.isEmpty ? 'audio' : ext);
    if (dest == null) return null;
    await File(source).copy(dest);
    return dest;
  }

  Future<Talk> addTalk({required String id, required String? audioPath, required bool imported, double durationSec = 0}) async {
    final now = DateTime.now();
    final t = Talk(
      id: id,
      title: imported ? 'an imported talk' : 'a new talk',
      createdAt: now,
      durationSec: durationSec,
      audioFile: audioPath == null ? null : p.basename(audioPath),
      imported: imported,
    );
    _talks.insert(0, t);
    await save();
    return t;
  }

  Future<void> deleteTalk(Talk t) async {
    final path = audioPath(t);
    if (path != null) {
      try {
        await File(path).delete();
      } on FileSystemException {
        // Already gone.
      }
    }
    _talks.remove(t);
    await save();
  }

  Future<void> renameTalk(Talk t, String title) async {
    final v = title.trim();
    if (v.isEmpty) return;
    t.title = v;
    await save();
  }

  Future<void> tick(Talk t, Todo todo, bool done) async {
    final s = t.summary;
    if (s == null) return;
    t.summary = s.copyWith(todos: [for (final x in s.todos) x.id == todo.id ? x.ticked(done) : x]);
    await save();
  }

  // ---- people

  Person? person(String? id) {
    for (final x in _people) {
      if (x.id == id) return x;
    }
    return null;
  }

  Person? get me => _people.where((x) => x.isMe).firstOrNull;

  /// Finds a person by name (case-insensitive), or adds them.
  Future<Person> personNamed(String name, {bool isMe = false}) async {
    final n = name.trim();
    if (isMe && me != null) return me!;
    final found = _people.where((x) => x.name.toLowerCase() == n.toLowerCase()).firstOrNull;
    if (found != null) return found;
    final x = Person(id: 'p${DateTime.now().microsecondsSinceEpoch}', name: isMe ? (n.isEmpty ? 'me' : n) : n, isMe: isMe);
    _people.add(x);
    await save();
    return x;
  }

  /// "This voice is Priya": names speaker [index] in [t].
  Future<void> nameSpeaker(Talk t, int index, Person? person) async {
    t.speakers = [for (final s in t.speakers) s.index == index ? s.withPerson(person?.id) : s];
    await save();
  }

  /// Forgets a person and unlinks them from every talk.
  Future<void> forgetPerson(Person x) async {
    for (final t in _talks) {
      t.speakers = [for (final s in t.speakers) s.personId == x.id ? s.withPerson(null) : s];
    }
    _people.remove(x);
    await save();
  }

  /// "Priya", "you", or "speaker 2" for a voice not named yet.
  String speakerName(Talk t, int? index) {
    if (index == null) return 'someone';
    final x = person(t.speaker(index)?.personId);
    if (x == null) return 'speaker ${index + 1}';
    return x.isMe ? 'you' : x.name;
  }

  List<Person> peopleIn(Talk t) => [for (final s in t.speakers) ?person(s.personId)];

  List<Talk> talksWith(Person x) => _talks.where((t) => t.speakers.any((s) => s.personId == x.id)).toList();

  /// To-dos that belong to [x]: named as theirs, or found in their lines.
  List<(Talk, Todo)> todosOf(Person x) => [
    for (final t in _talks)
      for (final todo in t.todos)
        if (_isTheirs(t, todo, x)) (t, todo),
  ];

  bool _isTheirs(Talk t, Todo todo, Person x) {
    final who = todo.who?.toLowerCase().trim();
    if (who != null && who.isNotEmpty) {
      if (x.isMe && (who == 'me' || who == 'you' || who.contains('the user'))) return true;
      return who == x.name.toLowerCase() || who.split(' ').first == x.name.toLowerCase().split(' ').first;
    }
    return false;
  }

  /// Unnamed voices in talks from the last [days] days.
  List<(Talk, Speaker)> voicesToName({int days = 14}) {
    final since = DateTime.now().subtract(Duration(days: days));
    return [
      for (final t in _talks)
        if (t.status == TalkStatus.ready && t.createdAt.isAfter(since))
          for (final s in t.speakers)
            if (s.personId == null) (t, s),
    ];
  }

  /// Every open to-do, soonest first (undated last).
  List<(Talk, Todo)> openTodos() {
    final all = [
      for (final t in _talks)
        for (final todo in t.todos)
          if (!todo.done) (t, todo),
    ];
    all.sort((a, b) {
      final x = a.$2.due, y = b.$2.due;
      if (x == null && y == null) return b.$1.createdAt.compareTo(a.$1.createdAt);
      if (x == null) return 1;
      if (y == null) return -1;
      return x.compareTo(y);
    });
    return all;
  }

  @override
  void dispose() {
    services.settings.removeListener(_onSettings);
    super.dispose();
  }
}

/// A short unique id for a new talk.
String newTalkId() => 't${DateTime.now().millisecondsSinceEpoch}';
