/// The app shell every app on the platform is built on.
///
/// ```dart
/// void main() => runBaseApp(appConfig); // appConfig lives in lib/app_config.dart
/// ```
///
/// You get: the theme (light/dark + handwriting, saved), onboarding that
/// fetches the app's models from the shared store, settings, models and
/// privacy pages, a privacy ledger, and `BaseScope.of(context)` for the
/// services (models, AI engines, storage, settings).
library;

export 'package:base_ai/base_ai.dart';
export 'package:base_design/base_design.dart';
export 'package:base_models/base_models.dart';

export 'src/app_config.dart';
export 'src/app_log.dart';
export 'src/format.dart';
export 'src/ledger.dart';
export 'src/pages/logs_page.dart';
export 'src/pages/models_page.dart';
export 'src/pages/onboarding_page.dart';
export 'src/pages/privacy_page.dart';
export 'src/pages/settings_page.dart';
export 'src/services.dart';
export 'src/settings.dart';
export 'src/shell.dart';
export 'src/storage/json_store.dart';
export 'src/storage/memory_json_store.dart';
