import 'package:base_core/base_core.dart';

import 'pages/ask_page.dart';
import 'pages/design_page.dart';
import 'pages/today_page.dart';

/// Everything that makes this app this app. `./base new` copies the starter,
/// so a new app starts by editing this file.
const appConfig = BaseAppConfig(
  appId: 'com.showcase.starter',
  name: 'Starter',
  wordmark: 'starter.',
  tagline: 'The template every new app begins from. Everything here runs on this device.',
  welcomeMark: 'this device',
  tabs: [
    BaseTab('today', TodayPage.new),
    BaseTab('ask', AskPage.new),
    BaseTab('design', DesignPage.new),
  ],
  // Nothing is required while this app runs the demo engine. With real engines
  // (nativeAi: true) move 'gemma-3-270m' here so onboarding fetches it; any
  // other app that already downloaded it shares its copy.
  requiredModels: [],
  optionalModels: [AppModels.ask, 'gemma-4-e2b', 'embeddinggemma-2-text-270m', 'desertant.redact'],
  ledgerEntries: [AppLedger.questions],
);

abstract final class AppModels {
  /// The smallest Gemma: what the ask tab runs on a real engine.
  static const ask = 'gemma-3-270m';
}

abstract final class AppLedger {
  static const questions = LedgerEntry('starter.questions', 'answered 1 question', 'answered %d questions');
}
