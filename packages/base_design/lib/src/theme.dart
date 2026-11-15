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

  /// Meta lines (at most two lines), captions.
  final Color pencil;

  /// Placeholders and disabled things only. Nothing that informs.
  final Color graphite;

  /// Sketchy hairlines.
  final Color rule;

  /// The only fill: input wells, done notes, selected rows.
  final Color smudge;

  /// The one accent: a highlighter swipe behind one word per screen.
  final Color marker;

  /// Text on the marker.
  final Color markerInk;

  /// Destructive actions and the ! mark. A mark, never a paragraph.
  final Color redPen;

  final bool isDark;

  /// Chart, legend and person colour [index], in the set made for this paper.
  Color series(int index) => seriesColor(index, isDark ? Brightness.dark : Brightness.light);

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

/// A muted pencil-box tone for charts, legends and person colours. In dark
/// mode the tones are lifted (`seriesDark`) so each is at least 6:1 on the paper.
/// Inside a widget, `context.colors.series(i)` picks the right set for you.
Color seriesColor(int index, [Brightness brightness = Brightness.light]) {
  final set = brightness == Brightness.dark ? seriesDarkTokens : seriesTokens;
  return set[index % set.length];
}

/// The face everything you read is set in, picked by the user in settings.
/// Headlines, buttons and nav words are always Caveat.
///
/// Voices come in two styles. With a handwriting voice ([isHand]: neat hand,
/// loose hand, all handwritten; the default) names, row titles and tags are
/// hand-lettered too. With a formal voice (friendly, formal) everything you
/// read is plain type and only headings and buttons are hand-lettered.
@immutable
class Voice {
  const Voice._(this.token);

  final VoiceToken token;

  String get id => token.id;
  String get label => token.label;
  String get note => token.note;

  static final all = [for (final t in voiceTokens) Voice._(t)];

  /// A handwriting face. See the class comment for what follows from it.
  bool get isHand => token.hand;

  /// The voices of one style: handwriting ([hand] true) or formal.
  static List<Voice> ofStyle({required bool hand}) => [for (final v in all) if (v.isHand == hand) v];

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

  /// [style] from a type token.
  TextStyle of(TypeToken t, {Color? color}) => style(t.size, t.lineHeight, weight: t.weight, color: color);

  @override
  bool operator ==(Object other) => other is Voice && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

FontWeight _weight(int w) => FontWeight.values.firstWhere((f) => f.value == w, orElse: () => FontWeight.w400);

/// Hand-lettered text grows with the OS text size only up to this factor, so a
/// heading never pushes the content off the screen. Body text follows fully.
const maxHandTextScale = 1.3;

TextStyle _hand(TypeToken t, Color color, double shrink) => TextStyle(
  fontFamily: handFontFamily,
  package: _pkg,
  fontSize: t.size * shrink,
  height: t.lineHeight / t.size,
  fontWeight: _weight(t.weight),
  letterSpacing: t.letterSpacing * t.size * shrink,
  color: color,
);

/// Every text style in the system. Read with `context.type`.
///
/// Headings, buttons and nav words are hand-lettered. What the rest looks like
/// follows the voice (design/THEME.md): with a handwriting voice, titles of
/// content, row titles and tags are hand-lettered as well; with a formal voice
/// they are in the body face. Nothing is below 13.
@immutable
class BaseType extends ThemeExtension<BaseType> {
  const BaseType({required this.colors, required this.voice, this.handShrink = 1});

  final BaseColors colors;
  final Voice voice;

  /// Applied to hand styles so that, with the OS text scale, they grow at most
  /// [maxHandTextScale]. Set by `context.type`; 1 means no correction.
  final double handShrink;

  // Hand-lettered (Caveat): the app's own short words. Not affected by the voice.

  /// Wordmark, welcome statement, record timer. 52/58.
  TextStyle get display => _hand(HandTypeTokens.display, colors.ink, handShrink);

  /// Page title. 38/42.
  TextStyle get headline => _hand(HandTypeTokens.headline, colors.ink, handShrink);

  /// Section head, sheet title, empty-state line. 30/34.
  TextStyle get title => _hand(HandTypeTokens.title, colors.ink, handShrink);

  /// A row that leads to a place in the app; switch titles. 24/28.
  TextStyle get door => _hand(HandTypeTokens.door, colors.ink, handShrink);

  /// Buttons, links, nav words, choice pills. 24/28.
  TextStyle get label => _hand(HandTypeTokens.label, colors.ink, handShrink);

  /// Small hand-lettering: 18/22. [tag] uses it with a handwriting voice.
  TextStyle get small => _hand(HandTypeTokens.small, colors.ink, handShrink);

  // The body face (the user's voice): everything you read.

  // These three follow the style of the voice.

  /// Title of a talk, article or person on its own page. Hand-lettered 30/34
  /// with a handwriting voice; the body face 22/28, 600 with a formal one.
  TextStyle get contentTitle => voice.isHand ? title : voice.of(BodyTypeTokens.contentTitle, color: colors.ink);

  /// Long-form reading: summaries, transcripts, chat answers, article text. 17/26.
  TextStyle get reading => voice.of(BodyTypeTokens.reading, color: colors.ink);

  /// Title of a content row (talk, person, model, file, saved item).
  /// Hand-lettered 24/28 with a handwriting voice; the body face 17/24, 600 with a formal one.
  TextStyle get rowTitle => voice.isHand ? door : voice.of(BodyTypeTokens.rowTitle, color: colors.ink);

  /// Sentences, intros, field text, list items. 16/24, ink.
  TextStyle get body => voice.of(BodyTypeTokens.body, color: colors.ink);

  /// Second line of a row, notes under a head. 14/20, pencil.
  TextStyle get meta => voice.of(BodyTypeTokens.meta, color: colors.pencil);

  /// Timestamps, counts, sizes, "on this device". 13/18, pencil.
  TextStyle get caption => voice.of(BodyTypeTokens.caption, color: colors.pencil);

  /// Tags, step numbers, badges. Hand-lettered 18/22 with a handwriting
  /// voice; the body face 13/18, 600 with a formal one.
  TextStyle get tag => voice.isHand ? small : voice.of(BodyTypeTokens.tag, color: colors.ink);

  /// Placeholders like [NAME_1], tool calls, logs. 13/20, ink.
  TextStyle get mono => TextStyle(
    fontFamily: monoFontFamily,
    fontFamilyFallback: monoFontFallback,
    fontSize: BodyTypeTokens.mono.size,
    height: BodyTypeTokens.mono.lineHeight / BodyTypeTokens.mono.size,
    fontWeight: _weight(BodyTypeTokens.mono.weight),
    color: colors.ink,
  );

  /// A body-face style at a size that is not a role. Prefer the named roles:
  /// after tokens 2.0.0 a font size should only appear in tokens.json.
  TextStyle bodyStyle(double size, double lineHeight, {int weight = 400, Color? color}) =>
      voice.style(size, lineHeight, weight: weight, color: color ?? colors.ink);

  /// Every named style, for tests and the design catalogue.
  Map<String, TextStyle> get hand => {'display': display, 'headline': headline, 'title': title, 'door': door, 'label': label, 'small': small};
  Map<String, TextStyle> get bodyRoles => {
    'contentTitle': contentTitle,
    'reading': reading,
    'rowTitle': rowTitle,
    'body': body,
    'meta': meta,
    'caption': caption,
    'tag': tag,
    'mono': mono,
  };

  @override
  BaseType copyWith({BaseColors? colors, Voice? voice, double? handShrink}) =>
      BaseType(colors: colors ?? this.colors, voice: voice ?? this.voice, handShrink: handShrink ?? this.handShrink);

  @override
  BaseType lerp(BaseType? other, double t) => other == null || t < 0.5 ? this : other;
}

extension BaseThemeContext on BuildContext {
  BaseColors get colors => Theme.of(this).extension<BaseColors>() ?? BaseColors.light;

  /// The text styles, with hand styles clamped so the OS text size grows them
  /// at most [maxHandTextScale] (body styles follow it fully).
  BaseType get type {
    final t = Theme.of(this).extension<BaseType>() ?? BaseType(colors: colors, voice: Voice.standard);
    final scale = (MediaQuery.maybeTextScalerOf(this) ?? TextScaler.noScaling).scale(100) / 100;
    return scale <= maxHandTextScale ? t : t.copyWith(handShrink: maxHandTextScale / scale);
  }

  /// Lists and details side by side (fold inner screens, tablets, desktop, landscape). From 840.
  bool get isWide => MediaQuery.sizeOf(this).width >= SpaceTokens.twoPaneBreakpoint;

  /// Navigation as a rail on the left instead of words along the bottom. From 1000.
  bool get isRailWide => MediaQuery.sizeOf(this).width >= SpaceTokens.railBreakpoint;

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
    // Material widgets get the same roles; no style below 13.
    final textTheme = TextTheme(
      displayLarge: type.display,
      displayMedium: type.display,
      displaySmall: type.headline,
      headlineLarge: type.headline,
      headlineMedium: type.headline,
      headlineSmall: type.title,
      titleLarge: type.title,
      titleMedium: type.door,
      titleSmall: type.label,
      bodyLarge: type.reading,
      bodyMedium: type.body,
      bodySmall: type.meta,
      labelLarge: type.label,
      labelMedium: type.caption,
      labelSmall: type.caption,
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
        contentTextStyle: type.body.copyWith(color: c.paper),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: c.ink, linearTrackColor: c.rule),
      extensions: [c, type],
    );
  }
}
