import 'package:base_core/base_core.dart';

import 'pages/ask_page.dart';
import 'pages/today_page.dart';

const appConfig = BaseAppConfig(
  appId: 'com.showcase.burrow',
  name: 'Burrow',
  wordmark: 'burrow.',
  tagline: 'Record a talk and get its notes, to-dos and people, written on this device.',
  welcomeMark: 'this device',
  tabs: [BaseTab('today', TodayPage.new), BaseTab('ask', AskPage.new)],
  nativeAi: true,
  optionalModels: ['gemma-4-e2b'],
);

abstract final class AppModels {
  static const ask = 'gemma-4-e2b';
}

abstract final class AppLedger {
  static const questions = LedgerEntry('burrow.questions', 'answered 1 question', 'answered %d questions');
}
