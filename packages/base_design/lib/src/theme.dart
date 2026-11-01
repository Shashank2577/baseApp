import 'package:flutter/material.dart';

import 'generated/tokens.g.dart';

const _pkg = 'base_design';

/// The nine colours of the notebook. Read them with `context.colors`.
@immutable
class BaseColors extends ThemeExtension<BaseColors> {
  const BaseColors({
    required this.paper,
    required this.ink,
    required this.pencil,
    required this.graphite,
    required this.rule,
    required this.smudge,
    required this.marker,
    required this.markerInk,
    required this.redPen,
    required this.isDark,
  });

  static const light = BaseColors(
    paper: LightTokens.paper,
    ink: LightTokens.ink,
    pencil: LightTokens.pencil,
    graphite: LightTokens.graphite,
    rule: LightTokens.rule,
    smudge: LightTokens.smudge,
    marker: LightTokens.marker,
    markerInk: LightTokens.markerInk,
    redPen: LightTokens.redPen,
    isDark: false,
  );

  static const dark = BaseColors(
    paper: DarkTokens.paper,
    ink: DarkTokens.ink,
    pencil: DarkTokens.pencil,
    graphite: DarkTokens.graphite,
    rule: DarkTokens.rule,
    smudge: DarkTokens.smudge,
    marker: DarkTokens.marker,
    markerInk: DarkTokens.markerInk,
    redPen: DarkTokens.redPen,
    isDark: true,
  );

  /// Page background. Content sits straight on it: no cards.
  final Color paper;

  /// Text, doodles and the one primary button.
  final Color ink;

  /// Secondary text and meta lines.
  final Color pencil;

  /// Disabled text and placeholders.
  final Color graphite;

  /// Sketchy hairlines.
  final Color rule;

  /// The only fill: input wells, done notes, selected rows.
  final Color smudge;

  /// The one accent: a highlighter swipe behind one word per screen.
  final Color marker;

  /// Text on the marker.
  final Color markerInk;

  /// Private or destructive things only.
  final Color redPen;

  final bool isDark;

  @override
  BaseColors copyWith({Color? paper, Color? ink, Color? marker}) => BaseColors(
    paper: paper ?? this.paper,
    ink: ink ?? this.ink,
    pencil: pencil,
    graphite: graphite,
    rule: rule,
    smudge: smudge,
    marker: marker ?? this.marker,
    markerInk: markerInk,
    redPen: redPen,
    isDark: isDark,
  );

  @override
  BaseColors lerp(BaseColors? other, double t) {
    if (other == null) return this;
    Color l(Color a, Color b) => Color.lerp(a, b, t)!;
    return BaseColors(
      paper: l(paper, other.paper),
      ink: l(ink, other.ink),
      pencil: l(pencil, other.pencil),
      graphite: l(graphite, other.graphite),
      rule: l(rule, other.rule),
      smudge: l(smudge, other.smudge),
      marker: l(marker, other.marker),
      markerInk: l(markerInk, other.markerInk),
      redPen: l(redPen, other.redPen),
      isDark: t < 0.5 ? isDark : other.isDark,
    );
  }
}

/// A muted pencil-box tone for charts, legends and person colours.
Color seriesColor(int index) => seriesTokens[index % seriesTokens.length];

/// How the quiet text under the hand-lettered headlines reads. Headlines are
/// always Caveat; the user picks this in settings, from formal to handwritten.
@immutable
class Voice {
  const Voice._(this.token);

  final VoiceToken token;

  String get id => token.id;
  String get label => token.label;
  String get note => token.note;

  static final all = [for (final t in voiceTokens) Voice._(t)];

  static Voice byId(String? id) => all.firstWhere((v) => v.id == id, orElse: () => all.firstWhere((v) => v.id == defaultVoiceId));

  static Voice get standard => byId(defaultVoiceId);

  /// A body style in this voice. [size] and [lineHeight] are scaled together.
  TextStyle style(double size, double lineHeight, {int weight = 400, Color? color}) {
    final s = size * token.scale;
    final informality = token.informality;
    return TextStyle(
      fontFamily: token.family,
      package: _pkg,
      fontSize: s,
      height: lineHeight / size,
      fontWeight: _weight(weight),
      color: color,
      fontVariations: informality == null ? null : [FontVariation('wght', weight.toDouble()), FontVariation('INFM', informality)],
    );
  }

  @override
  bool operator ==(Object other) => other is Voice && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

FontWeight _weight(int w) => FontWeight.values.firstWhere((f) => f.value == w, orElse: () => FontWeight.w400);

TextStyle _hand(TypeToken t, Color color) => TextStyle(
  fontFamily: handFontFamily,
  package: _pkg,
  fontSize: t.size,
  height: t.lineHeight / t.size,
  fontWeight: _weight(t.weight),
  letterSpacing: t.letterSpacing * t.size,
  color: color,
);

/// Every text style in the system. Read with `context.type`.
@immutable
class BaseType extends ThemeExtension<BaseType> {
  const BaseType({required this.colors, required this.voice});

  final BaseColors colors;
  final Voice voice;

  // Hand-lettered (Caveat). Not affected by the voice.
  TextStyle get display => _hand(HandTypeTokens.display, colors.ink);
  TextStyle get headline => _hand(HandTypeTokens.headline, colors.ink);
  TextStyle get title => _hand(HandTypeTokens.title, colors.ink);
  TextStyle get door => _hand(HandTypeTokens.door, colors.ink);
  TextStyle get label => _hand(HandTypeTokens.label, colors.ink);
  TextStyle get small => _hand(HandTypeTokens.small, colors.ink);

  // The user's voice.
  TextStyle get bodyLarge => body16;
  TextStyle get body => bodyStyle(BodyTypeTokens.body.size, BodyTypeTokens.body.lineHeight);
  TextStyle get body16 => bodyStyle(BodyTypeTokens.bodyLarge.size, BodyTypeTokens.bodyLarge.lineHeight);
  TextStyle get meta => bodyStyle(BodyTypeTokens.meta.size, BodyTypeTokens.meta.lineHeight, color: colors.pencil);

  /// Placeholders like [NAME_1] and timestamps.
  TextStyle get mono => TextStyle(fontFamily: 'monospace', fontSize: BodyTypeTokens.mono.size, color: colors.pencil);

  TextStyle bodyStyle(double size, double lineHeight, {int weight = 400, Color? color}) =>
      voice.style(size, lineHeight, weight: weight, color: color ?? colors.ink);

  @override
  BaseType copyWith({BaseColors? colors, Voice? voice}) => BaseType(colors: colors ?? this.colors, voice: voice ?? this.voice);

  @override
  BaseType lerp(BaseType? other, double t) => other == null || t < 0.5 ? this : other;
}

extension BaseThemeContext on BuildContext {
  BaseColors get colors => Theme.of(this).extension<BaseColors>() ?? BaseColors.light;
  BaseType get type => Theme.of(this).extension<BaseType>() ?? BaseType(colors: colors, voice: Voice.standard);

  /// Lists and details side by side (fold inner screens, tablets, desktop, landscape).
  bool get isWide => MediaQuery.sizeOf(this).width >= SpaceTokens.twoPaneBreakpoint;

  /// Animation length, or zero when the user asked for reduced motion.
  Duration motion(Duration d) => MediaQuery.maybeDisableAnimationsOf(this) == true ? Duration.zero : d;
}

/// Builds the Material theme from the tokens, so stock widgets (dialogs,
/// text selection, scrollbars) also look like the notebook.
abstract final class BaseTheme {
  static ThemeData build({required Brightness brightness, Voice? voice}) {
    final c = brightness == Brightness.dark ? BaseColors.dark : BaseColors.light;
    final v = voice ?? Voice.standard;
    final type = BaseType(colors: c, voice: v);
    final base = brightness == Brightness.dark ? const ColorScheme.dark() : const ColorScheme.light();
    final scheme = base.copyWith(
      primary: c.ink,
      onPrimary: c.paper,
      primaryContainer: c.marker,
      onPrimaryContainer: c.markerInk,
      inversePrimary: c.marker,
      secondary: c.ink,
      onSecondary: c.paper,
      secondaryContainer: c.smudge,
      onSecondaryContainer: c.ink,
      tertiary: c.pencil,
      onTertiary: c.paper,
      tertiaryContainer: c.smudge,
      onTertiaryContainer: c.ink,
      surface: c.paper,
      onSurface: c.ink,
      surfaceBright: c.paper,
      surfaceDim: c.smudge,
      surfaceContainerLowest: c.paper,
      surfaceContainerLow: c.paper,
      surfaceContainer: c.paper,
      surfaceContainerHigh: c.smudge,
      surfaceContainerHighest: c.smudge,
      onSurfaceVariant: c.pencil,
      surfaceTint: Colors.transparent,
      outline: c.ink.withValues(alpha: 0.55),
      outlineVariant: c.rule,
      error: c.redPen,
      onError: c.paper,
      errorContainer: c.redPen.withValues(alpha: 0.12),
      onErrorContainer: c.redPen,
      scrim: Colors.black.withValues(alpha: 0.32),
    );
    final textTheme = TextTheme(
      displayLarge: type.display.copyWith(fontSize: 64, height: 1),
      displayMedium: type.display,
      displaySmall: type.headline,
      headlineLarge: type.headline,
      headlineMedium: type.title.copyWith(fontSize: 34, height: 36 / 34),
      headlineSmall: type.title,
      titleLarge: type.title,
      titleMedium: type.door.copyWith(fontSize: 24, height: 27 / 24),
      titleSmall: type.label,
      bodyLarge: type.bodyStyle(16, 23),
      bodyMedium: type.bodyStyle(15, 21),
      bodySmall: type.bodyStyle(13, 18),
      labelLarge: type.label.copyWith(fontSize: 20),
      labelMedium: type.bodyStyle(12, 16, weight: 500),
      labelSmall: type.bodyStyle(11, 14, weight: 500),
    );
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: c.paper,
      canvasColor: c.paper,
      textTheme: textTheme,
      splashFactory: NoSplash.splashFactory,
      highlightColor: c.smudge,
      dividerColor: c.rule,
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: c.ink,
        selectionColor: c.marker.withValues(alpha: 0.6),
        selectionHandleColor: c.ink,
      ),
      bottomSheetTheme: BottomSheetThemeData(backgroundColor: c.paper, modalBackgroundColor: c.paper, surfaceTintColor: Colors.transparent),
      dialogTheme: DialogThemeData(backgroundColor: c.paper, surfaceTintColor: Colors.transparent),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: c.ink,
        contentTextStyle: type.label.copyWith(color: c.paper),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: c.ink, linearTrackColor: c.rule),
      extensions: [c, type],
    );
  }
}
