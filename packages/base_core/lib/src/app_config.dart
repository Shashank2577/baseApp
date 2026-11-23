import 'package:base_design/base_design.dart';
import 'package:base_models/base_models.dart';
import 'package:flutter/widgets.dart';

import 'ledger.dart';

/// One word in the bottom bar, and the page it opens.
class BaseTab {
  const BaseTab(this.word, this.builder);

  /// Lowercase, hand-lettered ("today", "notes", "talks").
  final String word;
  final WidgetBuilder builder;
}

/// Everything that makes an app different from the starter. Each app has
/// exactly one, in lib/app_config.dart.
class BaseAppConfig {
  const BaseAppConfig({
    required this.appId,
    required this.name,
    required this.tagline,
    required this.tabs,
    this.wordmark,
    this.requiredModels = const [],
    this.optionalModels = const [],
    this.extraModels = const [],
    this.nativeAi = false,
    this.ledgerEntries = const [],
    this.welcomeDoodle = Doodle.spark,
    this.welcomeMark,
  });

  /// The bundle / application id (com.showcase.notes). Recorded in the shared
  /// model store as a user of the models this app claims.
  final String appId;

  /// The app's name as people say it.
  final String name;

  /// One sentence on the welcome page.
  final String tagline;

  /// The word in [tagline] that gets the marker.
  final String? welcomeMark;
  final Doodle welcomeDoodle;

  /// Hand-lettered name in the top-left of home pages ("notes.").
  final String? wordmark;

  /// Two to four words. More than four means the app is doing too much.
  final List<BaseTab> tabs;

  /// Models the app cannot work without. Offered during onboarding.
  final List<String> requiredModels;

  /// Models the app can use when they are on the device (often because
  /// another app already downloaded them).
  final List<String> optionalModels;

  /// Private catalog entries. Prefer adding to catalog/models.json so other
  /// apps can share the download.
  final List<ModelSpec> extraModels;

  /// True once the app depends on base_ai_native and should use real engines.
  final bool nativeAi;

  /// The app's own ledger sentences, shown on the privacy page.
  final List<LedgerEntry> ledgerEntries;

  List<String> get allModels => [...requiredModels, ...optionalModels];
}
