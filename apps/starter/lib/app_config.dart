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
  // The smallest Gemma: enough to try the ask tab. Any other app on this device
  // that already downloaded it shares its copy, so onboarding skips it.
  requiredModels: ['gemma-3-270m'],
  optionalModels: ['gemma-4-e2b', 'embeddinggemma-2-text-270m', 'desertant.redact'],
  ledgerEntries: [AppLedger.questions],
);

abstract final class AppLedger {
  static const questions = LedgerEntry('starter.questions', 'answered 1 question', 'answered %d questions');
}
