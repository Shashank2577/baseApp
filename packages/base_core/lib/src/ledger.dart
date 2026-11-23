import 'package:flutter/foundation.dart';

import 'storage/json_store.dart';

/// One kind of thing the app did, with its sentence ("checked 312 photos").
class LedgerEntry {
  const LedgerEntry(this.key, this.one, this.many);
  final String key;

  /// "checked 1 photo"
  final String one;

  /// "checked %d photos"
  final String many;

  String phrase(int n) => n == 1 ? one : many.replaceFirst('%d', '$n');

  static const modelsDownloaded = LedgerEntry('models.downloaded', 'downloaded 1 model', 'downloaded %d models');
  static const modelsShared = LedgerEntry('models.shared', 'reused 1 model another app had', 'reused %d models other apps had');
}

/// A recent event, newest first in [Ledger.events].
class LedgerEvent {
  const LedgerEvent(this.time, this.kind, this.detail, {this.network = false});
  final DateTime time;
  final String kind;
  final String detail;

  /// True for the only network traffic the platform makes: model downloads.
  final bool network;

  Map<String, Object?> toJson() => {'t': time.toIso8601String(), 'k': kind, 'd': detail, 'n': network};

  static LedgerEvent fromJson(Map m) =>
      LedgerEvent(DateTime.parse(m['t'] as String), m['k'] as String, m['d'] as String, network: m['n'] as bool? ?? false);
}

/// Privacy you can check: counts of what the app did today and since setup,
/// recent events, and the bytes it downloaded. Kept on the device only.
class Ledger extends ChangeNotifier {
  Ledger._(this._store);

  static const _key = 'base.ledger';
  static const _maxEvents = 500;

  final JsonStore _store;
  final Map<String, int> _counts = {};
  final List<LedgerEvent> _events = [];
  DateTime since = DateTime.now();
  int bytesDownloaded = 0;

  List<LedgerEvent> get events => List.unmodifiable(_events);

  static Future<Ledger> load(JsonStore store) async {
    final l = Ledger._(store);
    final raw = (await store.read(_key) as Map?) ?? const {};
    l._counts.addAll(((raw['counts'] as Map?) ?? const {}).cast<String, int>());
    l._events.addAll(((raw['events'] as List?) ?? const []).cast<Map>().map(LedgerEvent.fromJson));
    l.since = DateTime.tryParse(raw['since'] as String? ?? '') ?? DateTime.now();
    l.bytesDownloaded = raw['bytes'] as int? ?? 0;
    return l;
  }

  static String _day(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  int today(LedgerEntry e) => _counts['${e.key}@${_day(DateTime.now())}'] ?? 0;

  int total(LedgerEntry e) => _counts['${e.key}@total'] ?? 0;

  /// Count [n] more of [entry].
  void add(LedgerEntry entry, [int n = 1]) {
    _counts.update('${entry.key}@${_day(DateTime.now())}', (v) => v + n, ifAbsent: () => n);
    _counts.update('${entry.key}@total', (v) => v + n, ifAbsent: () => n);
    _changed();
  }

  void record(String kind, String detail, {bool network = false}) {
    _events.insert(0, LedgerEvent(DateTime.now(), kind, detail, network: network));
    if (_events.length > _maxEvents) _events.removeRange(_maxEvents, _events.length);
    _changed();
  }

  void addBytes(int n) {
    bytesDownloaded += n;
    _saveSoon();
  }

  /// Sentences for every entry with a count today (or in total).
  List<String> summary(List<LedgerEntry> entries, {bool totals = false}) => [
    for (final e in entries)
      if ((totals ? total(e) : today(e)) > 0) e.phrase(totals ? total(e) : today(e)),
  ];

  Future<void> clear() async {
    _counts.clear();
    _events.clear();
    bytesDownloaded = 0;
    since = DateTime.now();
    _changed();
  }

  void _changed() {
    notifyListeners();
    _save();
  }

  bool _pending = false;
  void _saveSoon() {
    if (_pending) return;
    _pending = true;
    Future<void>.delayed(const Duration(seconds: 1), () {
      _pending = false;
      _save();
      notifyListeners();
    });
  }

  Future<void> _save() => _store.write(_key, {
    'counts': _counts,
    'events': [for (final e in _events) e.toJson()],
    'since': since.toIso8601String(),
    'bytes': bytesDownloaded,
  });
}
