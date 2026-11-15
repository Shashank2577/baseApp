/// Turns the words people use for "when" ("by Friday", "next Tuesday", "the
/// tenth", "20 November", "अगले मंगलवार") into a date, counted from the day of
/// the talk. Small models get this arithmetic wrong, so Burrow does it itself;
/// anything it can't place stays as the words. Ported from Burrow's DueDates.kt.
abstract final class DueDates {
  static const _weekdays = {
    'monday': DateTime.monday, 'tuesday': DateTime.tuesday, 'wednesday': DateTime.wednesday, 'thursday': DateTime.thursday,
    'friday': DateTime.friday, 'saturday': DateTime.saturday, 'sunday': DateTime.sunday,
    'mon': DateTime.monday, 'tue': DateTime.tuesday, 'wed': DateTime.wednesday, 'thu': DateTime.thursday, 'fri': DateTime.friday,
    'सोमवार': DateTime.monday, 'मंगलवार': DateTime.tuesday, 'बुधवार': DateTime.wednesday, 'गुरुवार': DateTime.thursday,
    'बृहस्पतिवार': DateTime.thursday, 'शुक्रवार': DateTime.friday, 'शनिवार': DateTime.saturday, 'रविवार': DateTime.sunday,
  };

  static const _monthNames = [
    'january', 'february', 'march', 'april', 'may', 'june', 'july', 'august', 'september', 'october', 'november', 'december',
  ];

  static const _ordinals = {
    'first': 1, 'second': 2, 'third': 3, 'fourth': 4, 'fifth': 5, 'sixth': 6, 'seventh': 7, 'eighth': 8, 'ninth': 9,
    'tenth': 10, 'eleventh': 11, 'twelfth': 12, 'thirteenth': 13, 'fourteenth': 14, 'fifteenth': 15, 'sixteenth': 16,
    'seventeenth': 17, 'eighteenth': 18, 'nineteenth': 19, 'twentieth': 20, 'thirtieth': 30,
  };

  static int? _month(String t) {
    for (var i = 0; i < 12; i++) {
      if (t == _monthNames[i] || t == _monthNames[i].substring(0, 3)) return i + 1;
    }
    return null;
  }

  static DateTime _plusDays(DateTime d, int n) => DateTime(d.year, d.month, d.day + n);

  /// The next [weekday] strictly after [d].
  static DateTime _next(DateTime d, int weekday) {
    var diff = (weekday - d.weekday) % 7;
    if (diff == 0) diff = 7;
    return _plusDays(d, diff);
  }

  static DateTime? resolve(String? words, DateTime talkDay) {
    final talk = DateTime(talkDay.year, talkDay.month, talkDay.day);
    final w = words?.toLowerCase().trim() ?? '';
    if (w.isEmpty) return null;
    if (w.length >= 10) {
      final iso = DateTime.tryParse(w.substring(0, 10));
      if (iso != null && RegExp(r'^\d{4}-\d{2}-\d{2}').hasMatch(w)) return iso.isBefore(talk) ? null : iso;
    }
    final tokens = w.split(RegExp(r'[^\p{L}\p{M}\p{N}]+', unicode: true)).where((t) => t.isNotEmpty).toList();
    bool has(String t) => tokens.contains(t);
    if (has('परसों') || w.contains('day after tomorrow')) return _plusDays(talk, 2);
    if (has('tomorrow') || has('कल')) return _plusDays(talk, 1);
    if (has('today') || has('tonight') || has('आज')) return talk;
    if (has('end') && has('month')) return DateTime(talk.year, talk.month + 1, 0);
    if ((has('next') || has('अगले') || has('अगला')) && (has('week') || has('हफ्ते') || has('सप्ताह'))) return _plusDays(talk, 7);
    if (has('end') && has('week')) return talk.weekday == DateTime.friday ? talk : _next(talk, DateTime.friday);
    for (final t in tokens) {
      final day = _weekdays[t];
      if (day != null) return _next(talk, day);
    }
    // A day of the month, maybe with a month: "the tenth", "13th", "20 November", "November 20".
    int? day;
    for (final t in tokens) {
      final n = _ordinals[t] ?? int.tryParse(t.replaceFirst(RegExp(r'(st|nd|rd|th)$'), ''));
      if (n != null && n >= 1 && n <= 31) {
        day = n;
        break;
      }
    }
    if (day == null) {
      for (var i = 0; i + 1 < tokens.length; i++) {
        if (tokens[i] == 'twenty' || tokens[i] == 'thirty') {
          day = (tokens[i] == 'twenty' ? 20 : 30) + (_ordinals[tokens[i + 1]] ?? 0);
          break;
        }
      }
    }
    if (day == null) return null;
    int? month;
    for (final t in tokens) {
      month ??= _month(t);
    }
    DateTime? valid(int y, int m, int d) {
      final dt = DateTime(y, m, d);
      return dt.month == ((m - 1) % 12) + 1 ? dt : null;
    }

    if (month != null) {
      final d = valid(talk.year, month, day);
      if (d == null) return null;
      return d.isBefore(talk) ? valid(talk.year + 1, month, day) : d;
    }
    final d = valid(talk.year, talk.month, day);
    if (d != null && !d.isBefore(talk)) return d;
    return valid(talk.year, talk.month + 1, day);
  }
}
