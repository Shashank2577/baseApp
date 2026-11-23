import 'package:base_core/base_core.dart';

import 'pages/ask_page.dart';
import 'pages/people_page.dart';
import 'pages/talks_page.dart';
import 'pages/today_page.dart';

/// Burrow on the base platform: talks written up on this device, the to-dos in
/// them, the people in them, and text masked before it goes to an AI.
final appConfig = BaseAppConfig(
  appId: 'com.showcase.burrow',
  name: 'Burrow',
  wordmark: 'burrow.',
  tagline: 'Record a talk and get its notes, to-dos and people, written on this device.',
  welcomeMark: 'this device',
  welcomeDoodle: Doodle.mic,
  tabs: const [
    BaseTab('today', TodayPage.new),
    BaseTab('talks', TalksPage.new),
    BaseTab('ask', AskPage.new),
    BaseTab('people', PeoplePage.new),
  ],
  // The speech models run only where base_ai_native has engines (iPhone, Mac,
  // Android). Elsewhere (web, Windows, Linux) the demo engines need nothing.
  requiredModels: AiRuntime.nativeEnginesHere ? AppModels.required : const [],
  optionalModels: const [AppModels.gemma],
  nativeAi: true,
  ledgerEntries: const [AppLedger.talks, AppLedger.questions, AppLedger.masked],
);

abstract final class AppModels {
  static const ear = 'desertant.ear';
  static const voz = 'desertant.voz';
  static const who = 'desertant.who';
  static const gist = 'desertant.gist';
  static const redact = 'desertant.redact';

  /// Summaries and ask Burrow: Gemma 4 E2B (about 2.6 GB, wants about 6 GB of RAM).
  static const gemma = 'gemma-4-e2b';

  /// What processing a talk needs.
  static const speech = [ear, voz, who];
  static const required = [ear, voz, who, gist, redact];
}

abstract final class AppLedger {
  static const talks = LedgerEntry('burrow.talks', 'wrote notes for 1 talk', 'wrote notes for %d talks');
  static const questions = LedgerEntry('burrow.questions', 'answered 1 question', 'answered %d questions');
  static const masked = LedgerEntry('burrow.masked', 'masked 1 message', 'masked %d messages');
}
