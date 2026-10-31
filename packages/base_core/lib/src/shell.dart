import 'package:base_design/base_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_config.dart';
import 'pages/onboarding_page.dart';
import 'pages/privacy_page.dart';
import 'pages/settings_page.dart';
import 'services.dart';

/// Starts an app on the platform. This is all `main()` needs:
/// `void main() => runBaseApp(appConfig);`
void runBaseApp(BaseAppConfig config) {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(BaseApp(config: config));
}

/// Boots the services, applies the theme the user picked, and shows
/// onboarding once, then the shell.
class BaseApp extends StatefulWidget {
  const BaseApp({super.key, required this.config, this.services});

  final BaseAppConfig config;

  /// Ready-made services (tests).
  final Future<BaseServices>? services;

  @override
  State<BaseApp> createState() => _BaseAppState();
}

class _BaseAppState extends State<BaseApp> {
  late final Future<BaseServices> _boot = widget.services ?? BaseServices.create(widget.config);

  @override
  Widget build(BuildContext context) => FutureBuilder<BaseServices>(
    future: _boot,
    builder: (context, snap) {
      final services = snap.data;
      if (services == null) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: BaseTheme.build(brightness: Brightness.light),
          darkTheme: BaseTheme.build(brightness: Brightness.dark),
          home: Builder(
            builder: (context) => ColoredBox(
              color: context.colors.paper,
              child: snap.hasError
                  ? Center(
                      child: Padding(padding: const EdgeInsets.all(24), child: Body('Could not start: ${snap.error}')),
                    )
                  : const SizedBox.expand(),
            ),
          ),
        );
      }
      return BaseScope(
        services: services,
        child: ListenableBuilder(
          listenable: services.settings,
          builder: (context, _) {
            final s = services.settings;
            return MaterialApp(
              title: widget.config.name,
              debugShowCheckedModeBanner: false,
              theme: BaseTheme.build(brightness: Brightness.light, voice: s.voice),
              darkTheme: BaseTheme.build(brightness: Brightness.dark, voice: s.voice),
              themeMode: s.themeMode,
              home: s.onboarded ? const BaseShell() : const OnboardingPage(),
            );
          },
        ),
      );
    },
  );
}

/// The words along the bottom and one page per word.
class BaseShell extends StatefulWidget {
  const BaseShell({super.key});

  @override
  State<BaseShell> createState() => _BaseShellState();
}

class _BaseShellState extends State<BaseShell> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final tabs = BaseScope.of(context).config.tabs;
    final c = context.colors;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      // Status-bar icons follow the app's light/dark choice, not the phone's.
      value: (c.isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark).copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: c.paper,
      ),
      child: Scaffold(
        backgroundColor: c.paper,
        body: IndexedStack(
          index: _tab,
          children: [for (final t in tabs) Builder(builder: t.builder)],
        ),
        bottomNavigationBar: tabs.length < 2
            ? null
            : HandNav(words: [for (final t in tabs) t.word], selected: _tab, onSelect: (i) => setState(() => _tab = i)),
      ),
    );
  }
}

/// The gear (settings) and padlock (privacy) every home page has top-right.
class ShellActions extends StatelessWidget {
  const ShellActions({super.key});

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      DoodleButton(Doodle.gear, label: 'settings', onPressed: () => pushPage(context, const SettingsPage())),
      DoodleButton(Doodle.lock, label: 'privacy', onPressed: () => pushPage(context, const PrivacyPage())),
    ],
  );
}

/// Opens [page] with the platform's page transition.
Future<T?> pushPage<T>(BuildContext context, Widget page) => Navigator.of(context).push<T>(MaterialPageRoute(builder: (_) => page));
