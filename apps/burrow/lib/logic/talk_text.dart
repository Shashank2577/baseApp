import '../data/models.dart';
import 'due_dates.dart';

/// A word with its timing, as the speech model returns it.
class Word {
  const Word(this.text, this.start, this.end);
  final String text;
  final double start;
  final double end;
}

/// Who spoke from [start] to [end].
class Turn {
  const Turn(this.speaker, this.start, this.end);
  final int speaker;
  final double start;
  final double end;
}

/// Speaker of the turn that contains [t], else of the nearest turn; null without turns.
int? speakerAt(List<Turn> turns, double t) {
  if (turns.isEmpty) return null;
  for (final u in turns) {
    if (t >= u.start && t <= u.end) return u.speaker;
  }
  Turn best = turns.first;
  double dist(Turn u) => [(u.start - t).abs(), (u.end - t).abs()].reduce((a, b) => a < b ? a : b);
  for (final u in turns) {
    if (dist(u) < dist(best)) best = u;
  }
  return best.speaker;
}

/// When the speech model gives the text but not every word's timing, spread
/// the words evenly over the talk, so lines still get rough times.
List<Word> wordsFor(String text, List<Word> timed, double duration) {
  final words = text.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
  if (timed.length >= words.length * 0.8 || words.isEmpty) return timed;
  final span = (duration > 0 ? duration : words.length * 0.4) / words.length;
  return [for (var i = 0; i < words.length; i++) Word(words[i], i * span, (i + 1) * span)];
}

/// Groups words into lines: a new one starts on a speaker change or a pause
/// over [gap] seconds. Ported from Burrow's MeetingText.kt.
List<Line> linesFrom(List<Word> words, List<Turn> turns, {double gap = 1.6}) {
  if (words.isEmpty) return const [];
  final out = <Line>[];
  var speaker = speakerAt(turns, (words[0].start + words[0].end) / 2);
  var start = words[0].start;
  var end = words[0].end;
  final text = StringBuffer();
  for (final w in words) {
    final s = speakerAt(turns, (w.start + w.end) / 2);
    final pause = w.start - end;
    final t = text.toString().trimRight();
    final endsSentence = t.isNotEmpty && '.?!'.contains(t[t.length - 1]);
    if (text.isNotEmpty && (s != speaker || (pause > gap && endsSentence) || pause > gap * 2)) {
      out.add(Line(start, end, speaker, text.toString().trim()));
      text.clear();
      start = w.start;
      speaker = s;
    }
    text
      ..write(w.text)
      ..write(' ');
    end = w.end;
  }
  if (text.isNotEmpty) out.add(Line(start, end, speaker, text.toString().trim()));
  return out;
}

/// Sentences with an estimated start time, interpolated across their line.
List<Line> sentencesOf(List<Line> lines) {
  final out = <Line>[];
  for (final u in lines) {
    final parts = u.text.split(RegExp(r'(?<=[.?!])\s+')).map((p) => p.trim()).where((p) => p.isNotEmpty);
    var offset = 0;
    final len = u.text.isEmpty ? 1 : u.text.length;
    for (final part in parts) {
      final at = u.at + (u.end - u.at) * offset / len;
      offset += part.length + 1;
      out.add(Line(at, u.end, u.speaker, part));
    }
  }
  return out;
}

final _followUp = RegExp(
  r"\b(i'll|i will|we'll|we will|you'll|let's|let us|need to|needs to|have to|has to|going to|should|must|"
  r'follow up|action item|next step|deadline|by (monday|tuesday|wednesday|thursday|friday|tomorrow|tonight|next week|end of)|'
  r'remind|send (you|me|it|the)|schedule|book|books|todo|to-do|will update|updates)\b',
  caseSensitive: false,
);

/// Openers that sound like plans but aren't ("let's start").
final _notFollowUp = RegExp(r"\blet(?:'s| us) (?:start|begin|go|see|get started)\b", caseSensitive: false);

/// Commitments and next steps, by phrasing (English).
List<Line> followUpsOf(List<Line> sentences, {int limit = 8}) => sentences
    .where((m) {
      final n = m.text.split(' ').length;
      return n >= 4 && n <= 40 && _followUp.hasMatch(m.text) && !_notFollowUp.hasMatch(m.text) && !m.text.trimRight().endsWith('?');
    })
    .take(limit)
    .toList();

final _decision = RegExp(
  r"\b(decided|agreed|we'll go with|let's go with|moves? to|settled|approved|final answer|the plan is|we're going with)\b",
  caseSensitive: false,
);

final _when = RegExp(
  r'\b(by|on|before|until)?\s*(today|tonight|tomorrow|next week|end of (the )?(week|month)|monday|tuesday|wednesday|thursday|friday|saturday|sunday|'
  r'the \w+(st|nd|rd|th)|\d{1,2}(st|nd|rd|th)?( (of )?(january|february|march|april|may|june|july|august|september|october|november|december))?)\b',
  caseSensitive: false,
);

/// Notes picked from the transcript by rules, for when no model is on the
/// device (and on the demo engine): the opening as the gist, decisions and
/// to-dos by phrasing, dates worked out in code. Says plainly what it is.
Summary ruleNotes(Talk talk, String Function(int? speaker) who, {required String model}) {
  final sentences = sentencesOf(talk.lines);
  final gist = sentences.take(2).map((s) => s.text).join(' ');
  final decisions = [
    for (final s in sentences)
      if (_decision.hasMatch(s.text)) Point(s.text, s.at),
  ].take(5).toList();
  final todos = <Todo>[];
  for (final f in followUpsOf(sentences)) {
    final words = _when.firstMatch(f.text)?.group(0)?.trim();
    todos.add(
      Todo(
        id: '${talk.id}-t${todos.length}',
        what: f.text,
        who: _namedIn(f.text) ?? who(f.speaker),
        dueWords: words,
        due: DueDates.resolve(words, talk.createdAt),
        at: f.at,
      ),
    );
  }
  final usedAt = {...decisions.map((d) => d.at), ...todos.map((t) => t.at)};
  final points = [
    for (final s in sentences.skip(2))
      if (!usedAt.contains(s.at) && s.text.split(' ').length >= 5) Point(s.text, s.at),
  ].take(4).toList();
  return Summary(gist: gist, points: points, decisions: decisions, todos: todos, model: model, writtenAt: DateTime.now());
}

/// "Priya will update the deck" → "Priya": a capitalised name right before a commitment.
String? _namedIn(String text) {
  final m = RegExp(r"\b([A-Z][a-z]+)\s+(will|'ll|books|sends|updates|needs to|has to|should)\b").firstMatch(text);
  final n = m?.group(1);
  const notNames = {'We', 'I', 'You', 'They', 'He', 'She', 'It', 'This', 'That', 'Okay', 'And', 'So', 'Then'};
  return n == null || notNames.contains(n) ? null : n;
}

/// A talk's title from its topics, else from the day.
String titleFor(List<Topic> topics, DateTime when) {
  const days = ['monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday'];
  final part = when.hour < 12
      ? 'morning'
      : when.hour < 18
      ? 'afternoon'
      : 'evening';
  if (topics.isNotEmpty) {
    final name = topics.first.name.toLowerCase();
    return '${name.split('&').first.trim()} talk';
  }
  return '${days[when.weekday - 1]} $part talk';
}
