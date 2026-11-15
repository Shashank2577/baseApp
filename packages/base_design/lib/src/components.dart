import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'doodle.dart';
import 'generated/doodles.g.dart';
import 'generated/tokens.g.dart';
import 'hand.dart';
import 'theme.dart';

// ------------------------------------------------------------------- text

/// A meta line: the second line of a row, a note under a head. 14/20 pencil,
/// at most two lines of it.
class Meta extends StatelessWidget {
  const Meta(this.text, {super.key, this.color, this.textAlign, this.maxLines});
  final String text;
  final Color? color;
  final TextAlign? textAlign;
  final int? maxLines;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: context.type.meta.copyWith(color: color ?? context.colors.pencil),
    textAlign: textAlign,
    maxLines: maxLines,
    overflow: maxLines == null ? null : TextOverflow.ellipsis,
  );
}

/// A sentence in the body face: 16/24, ink. Sentences are ink; pencil is for
/// meta lines.
class Body extends StatelessWidget {
  const Body(this.text, {super.key, this.color, this.textAlign});
  final String text;

  /// Only for the centred line of an empty state; paragraphs stay ink.
  final Color? color;
  final TextAlign? textAlign;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: context.type.body.copyWith(color: color ?? context.colors.ink),
    textAlign: textAlign,
  );
}

/// Long-form text (summaries, transcripts, chat answers, article text):
/// reading 17/26, at most `readingColumn` wide, 12 between paragraphs.
///
/// Renders the little markdown models write: `**bold**`, `-` and `1.` lists,
/// `>` quotes, `` `code` `` and fenced code (mono), and `#` headings, which are
/// set as row titles (one level of heading inside an answer, never Caveat).
class Prose extends StatelessWidget {
  const Prose(this.source, {super.key, this.selectable = true});
  final String source;
  final bool selectable;

  @override
  Widget build(BuildContext context) {
    final t = context.type;
    final c = context.colors;
    final blocks = <Widget>[];
    void gap() {
      if (blocks.isNotEmpty) blocks.add(const SizedBox(height: SpaceTokens.sm));
    }

    final lines = source.replaceAll('\r\n', '\n').split('\n');
    final para = <String>[];
    void flush() {
      if (para.isEmpty) return;
      gap();
      blocks.add(Text.rich(_inline(para.join('\n'), t.reading, t, c)));
      para.clear();
    }

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      final trimmed = line.trimLeft();
      if (trimmed.startsWith('```')) {
        flush();
        final code = <String>[];
        i++;
        while (i < lines.length && !lines[i].trimLeft().startsWith('```')) {
          code.add(lines[i++]);
        }
        gap();
        blocks.add(
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(SpaceTokens.sm),
            decoration: BoxDecoration(color: c.smudge, borderRadius: BorderRadius.circular(RadiusTokens.row)),
            child: Text(code.join('\n'), style: t.mono),
          ),
        );
        continue;
      }
      if (trimmed.isEmpty) {
        flush();
        continue;
      }
      final heading = RegExp(r'^#{1,6}\s+(.*)').firstMatch(trimmed);
      if (heading != null) {
        flush();
        gap();
        blocks.add(Text.rich(_inline(heading.group(1)!.replaceAll(RegExp(r'\s*#+$'), ''), t.rowTitle, t, c)));
        continue;
      }
      final item = RegExp(r'^([-*•]|\d+[.)])\s+(.*)').firstMatch(trimmed);
      if (item != null) {
        flush();
        final ordered = RegExp(r'\d').hasMatch(item.group(1)!);
        // Consecutive items sit 4 apart; a list is one paragraph.
        final previousWasItem = blocks.isNotEmpty && blocks.last is _ProseItem;
        if (previousWasItem) {
          blocks.add(const SizedBox(height: SpaceTokens.xs));
        } else {
          gap();
        }
        blocks.add(_ProseItem(ordered ? item.group(1)! : '•', _inline(item.group(2)!, t.reading, t, c), indent: line.length - trimmed.length >= 2));
        continue;
      }
      if (trimmed.startsWith('>')) {
        flush();
        final quote = <String>[trimmed.replaceFirst(RegExp(r'^>\s?'), '')];
        while (i + 1 < lines.length && lines[i + 1].trimLeft().startsWith('>')) {
          quote.add(lines[++i].trimLeft().replaceFirst(RegExp(r'^>\s?'), ''));
        }
        gap();
        blocks.add(
          Container(
            padding: const EdgeInsets.only(left: SpaceTokens.sm),
            decoration: BoxDecoration(
              border: Border(left: BorderSide(color: c.rule, width: StrokeTokens.progressInk)),
            ),
            child: Text.rich(_inline(quote.join('\n'), t.reading, t, c)),
          ),
        );
        continue;
      }
      para.add(line.trimRight());
    }
    flush();
    final column = Align(
      alignment: AlignmentDirectional.topStart,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: SpaceTokens.readingColumn),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: blocks),
      ),
    );
    return selectable ? SelectionArea(child: column) : column;
  }

  static TextSpan _inline(String text, TextStyle base, BaseType t, BaseColors c) {
    final spans = <InlineSpan>[];
    final re = RegExp(r'\*\*(.+?)\*\*|__(.+?)__|`([^`]+)`');
    var last = 0;
    for (final m in re.allMatches(text)) {
      if (m.start > last) spans.add(TextSpan(text: text.substring(last, m.start)));
      final bold = m.group(1) ?? m.group(2);
      if (bold != null) {
        spans.add(TextSpan(text: bold, style: base.copyWith(fontWeight: FontWeight.w600, fontVariations: _w600(base))));
      } else {
        spans.add(TextSpan(text: m.group(3), style: t.mono.copyWith(color: base.color, backgroundColor: c.smudge)));
      }
      last = m.end;
    }
    if (last < text.length) spans.add(TextSpan(text: text.substring(last)));
    return TextSpan(style: base, children: spans);
  }

  /// Shantell Sans is a variable font: bold needs its axis too.
  static List<FontVariation>? _w600(TextStyle base) =>
      base.fontVariations?.map((v) => v.axis == 'wght' ? const FontVariation('wght', 600) : v).toList();
}

class _ProseItem extends StatelessWidget {
  const _ProseItem(this.bullet, this.span, {this.indent = false});
  final String bullet;
  final TextSpan span;
  final bool indent;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(left: indent ? SpaceTokens.l : 0),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: SpaceTokens.l,
          child: Text(bullet, style: context.type.reading.copyWith(color: context.colors.pencil)),
        ),
        Expanded(child: Text.rich(span)),
      ],
    ),
  );
}

// ------------------------------------------------------------------- page

/// How the pages under it lay out their column. `BaseShell` puts one around
/// the tabs when the nav is a rail, and `TwoPane` around its detail pane.
class HandLayout extends InheritedWidget {
  const HandLayout({super.key, required super.child, this.rail = false, this.start = false, this.maxWidth = SpaceTokens.maxColumn});

  /// A `HandNav.rail` is showing: pages leave the wordmark and the shell's
  /// gear and padlock to it.
  final bool rail;

  /// Columns are left-aligned with `xl` padding instead of centred.
  final bool start;

  /// The widest a page's column may be.
  final double maxWidth;

  static HandLayout? maybeOf(BuildContext context) => context.dependOnInheritedWidgetOfExactType<HandLayout>();

  @override
  bool updateShouldNotify(HandLayout old) => old.rail != rail || old.start != start || old.maxWidth != maxWidth;
}

/// The page frame: paper, a top row (back, wordmark, actions), one column at
/// most `maxColumn` wide, and an optional sticky bottom (usually the ink
/// button, full width up to 400). Centred on its own; left-aligned after a
/// rail or in a detail pane ([HandLayout]).
class HandPage extends StatelessWidget {
  const HandPage({
    super.key,
    required this.children,
    this.onBack,
    this.wordmark,
    this.actions = const [],
    this.bottom,
    this.scroll = true,
    this.controller,
  });

  final List<Widget> children;
  final VoidCallback? onBack;

  /// The app's name, hand-lettered, on home pages ("burrow."). Left to the
  /// rail when there is one.
  final String? wordmark;
  final List<Widget> actions;
  final Widget? bottom;
  final bool scroll;
  final ScrollController? controller;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final layout = HandLayout.maybeOf(context);
    final max = layout?.maxWidth ?? SpaceTokens.maxColumn;
    final start = layout?.start ?? false;
    final wordmark = layout?.rail == true ? null : this.wordmark;
    // Left-aligned columns start `xl` from the edge; the gutter is part of that.
    final lead = start ? SpaceTokens.xl - SpaceTokens.gutter : 0.0;
    Widget place(double maxWidth, Widget child) => start
        ? Align(
            alignment: Alignment.topLeft,
            child: Padding(
              padding: EdgeInsets.only(left: lead),
              child: ConstrainedBox(constraints: BoxConstraints(maxWidth: maxWidth), child: child),
            ),
          )
        : Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(constraints: BoxConstraints(maxWidth: maxWidth), child: child),
          );
    final column = Padding(
      padding: const EdgeInsets.fromLTRB(SpaceTokens.gutter, 0, SpaceTokens.gutter, SpaceTokens.xl),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
    );
    return Material(
      color: c.paper,
      child: SafeArea(
        bottom: bottom == null,
        child: Column(
          children: [
            place(
                max + SpaceTokens.l * 2,
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: SpaceTokens.sm, vertical: SpaceTokens.xs),
                  child: SizedBox(
                    height: SizeTokens.minTap, // with the padding, a 56 top row
                    child: Row(
                      children: [
                        if (onBack != null) DoodleButton(Doodle.back, label: 'back', onPressed: onBack),
                        if (wordmark != null)
                          Flexible(
                            child: Padding(
                              padding: EdgeInsets.only(left: onBack == null ? SpaceTokens.sm : 0),
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerLeft,
                                child: Text(wordmark, maxLines: 1, style: context.type.title),
                              ),
                            ),
                          ),
                        const Spacer(),
                        ...actions,
                      ],
                    ),
                  ),
                ),
              ),
            Expanded(
              child: place(max, scroll ? SingleChildScrollView(controller: controller, child: column) : column),
            ),
            if (bottom != null)
              ColoredBox(
                color: c.paper,
                child: SafeArea(
                  top: false,
                  child: place(
                    400 + SpaceTokens.gutter * 2,
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: SpaceTokens.gutter, vertical: SpaceTokens.sm),
                      child: SizedBox(width: double.infinity, child: bottom),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Every page says what it is for: the name and one or two plain sentences,
/// in ink. [mark] exists for a fact in the title, never the whole title.
class PageIntro extends StatelessWidget {
  const PageIntro({super.key, required this.title, required this.purpose, this.mark, this.doodle});
  final String title;
  final String purpose;
  final String? mark;
  final Doodle? doodle;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.only(bottom: SpaceTokens.l),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Flexible(
                child: MarkedText(title, mark: mark, style: context.type.headline),
              ),
              if (doodle != null)
                Padding(
                  padding: const EdgeInsets.only(left: SpaceTokens.sm, bottom: SpaceTokens.s),
                  child: DoodleIcon(doodle!, size: 32, color: c.pencil, stroke: 1.8, tilt: -8),
                ),
            ],
          ),
          const SizedBox(height: SpaceTokens.s),
          Body(purpose),
        ],
      ),
    );
  }
}

/// A section heading: title 30/34 with 40 above (16 when it is the [first]
/// thing on the page) and 12 below. The [note] sits on its own line under it.
class SectionHead extends StatelessWidget {
  const SectionHead(this.text, {super.key, this.note, this.mark = false, this.first = false});
  final String text;
  final String? note;
  final bool mark;
  final bool first;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(top: first ? SpaceTokens.m : SpaceTokens.xl, bottom: SpaceTokens.sm),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(header: true, child: MarkedText(text, mark: mark ? text : null, style: context.type.title)),
        if (note != null) Padding(padding: const EdgeInsets.only(top: SpaceTokens.xs), child: Meta(note!)),
      ],
    ),
  );
}

// ------------------------------------------------------------------- buttons

class _Press extends StatefulWidget {
  const _Press({required this.child, required this.onTap, required this.label, this.shape = const StadiumBorder()});
  final Widget child;
  final VoidCallback? onTap;
  final String label;
  final ShapeBorder shape;

  @override
  State<_Press> createState() => _PressState();
}

/// Squish on press, a light haptic tick on tap. Keyboard and screen-reader friendly.
class _PressState extends State<_Press> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    return Semantics(
      button: true,
      enabled: enabled,
      label: widget.label,
      excludeSemantics: true,
      child: AnimatedScale(
        scale: _down ? 0.96 : 1,
        duration: context.motion(MotionTokens.quick),
        child: InkWell(
          customBorder: widget.shape,
          onHighlightChanged: enabled ? (v) => setState(() => _down = v) : null,
          onTap: enabled
              ? () {
                  HapticFeedback.selectionClick();
                  widget.onTap!();
                }
              : null,
          child: widget.child,
        ),
      ),
    );
  }
}

/// The one primary action on a screen: a black ink pill. Disabled, it is a
/// smudge pill with a graphite outline and label (never a faded ink pill).
class InkButton extends StatelessWidget {
  const InkButton(this.text, {super.key, required this.onPressed, this.busy = false, this.trailing, this.danger = false});
  final String text;
  final VoidCallback? onPressed;
  final bool busy;
  final Doodle? trailing;

  /// Red pen: only for destructive actions.
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final enabled = onPressed != null && !busy;
    final off = !enabled && !busy;
    final fill = off ? c.smudge : (danger ? c.redPen : c.ink);
    final fg = off ? c.graphite : c.paper;
    return Material(
      color: fill,
      shape: StadiumBorder(side: off ? BorderSide(color: c.graphite, width: StrokeTokens.pill) : BorderSide.none),
      child: _Press(
        onTap: enabled ? onPressed : null,
        label: text,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: SizeTokens.inkButton),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: SpaceTokens.s),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (busy) ...[
                  SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2, color: c.paper)),
                  const SizedBox(width: SpaceTokens.sm),
                ],
                Flexible(
                  child: Text(
                    text,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.type.label.copyWith(color: fg),
                  ),
                ),
                if (trailing != null && !off) ...[
                  const SizedBox(width: 10),
                  DoodleIcon(trailing!, size: SizeTokens.iconSmall, color: fg),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A secondary action: an outlined pill, 48 high.
class PillButton extends StatelessWidget {
  const PillButton(this.text, {super.key, required this.onPressed, this.leading, this.color});
  final String text;
  final VoidCallback? onPressed;
  final Doodle? leading;

  /// `redPen` for a destructive action; ink otherwise.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final ink = onPressed == null ? context.colors.graphite : (color ?? context.colors.ink);
    return Material(
      type: MaterialType.transparency,
      shape: StadiumBorder(
        side: BorderSide(color: ink, width: StrokeTokens.pill),
      ),
      child: _Press(
        onTap: onPressed,
        label: text,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: SizeTokens.pill, minWidth: SizeTokens.minTap),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: SpaceTokens.xs),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (leading != null) ...[DoodleIcon(leading!, size: SizeTokens.iconSmall, color: ink), const SizedBox(width: SpaceTokens.s)],
                Flexible(
                  child: Text(text, style: context.type.label.copyWith(color: ink)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// One choice of several (radio-style): filled ink when selected, 48 high.
class ChoicePill extends StatelessWidget {
  const ChoicePill(this.text, {super.key, required this.selected, required this.onPressed, this.leading});
  final String text;
  final bool selected;
  final VoidCallback? onPressed;
  final Doodle? leading;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final line = onPressed == null ? c.graphite : c.ink;
    final fg = selected ? c.paper : line;
    return Semantics(
      selected: selected,
      inMutuallyExclusiveGroup: true,
      child: Material(
        color: selected ? line : Colors.transparent,
        shape: StadiumBorder(
          side: BorderSide(color: line, width: StrokeTokens.pill),
        ),
        child: _Press(
          onTap: onPressed,
          label: text,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: SizeTokens.pill, minWidth: SizeTokens.minTap),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: SpaceTokens.xs),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (leading != null) ...[DoodleIcon(leading!, size: SizeTokens.iconSmall, color: fg), const SizedBox(width: SpaceTokens.s)],
                  Flexible(child: Text(text, style: context.type.label.copyWith(color: fg))),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A minor, tertiary action: hand-underlined words with a 48 target.
class HandLink extends StatelessWidget {
  const HandLink(this.text, {super.key, required this.onPressed, this.color});
  final String text;
  final VoidCallback? onPressed;

  /// `redPen` for a destructive link; ink otherwise.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = onPressed == null ? context.colors.graphite : (color ?? context.colors.ink);
    return _Press(
      onTap: onPressed,
      label: text,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: SizeTokens.minTap, minHeight: SizeTokens.minTap),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: SpaceTokens.s, vertical: 10),
          child: Align(
            widthFactor: 1,
            heightFactor: 1,
            child: HandUnderline(
              color: c.withValues(alpha: 0.8),
              seed: text.length,
              child: Text(text, style: context.type.label.copyWith(color: c)),
            ),
          ),
        ),
      ),
    );
  }
}

/// An icon-only button with a 48dp touch target.
class DoodleButton extends StatelessWidget {
  const DoodleButton(this.doodle, {super.key, required this.label, required this.onPressed, this.color, this.size = 26});
  final Doodle doodle;
  final String label;
  final VoidCallback? onPressed;
  final Color? color;
  final double size;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: label,
    child: _Press(
      onTap: onPressed,
      label: label,
      shape: const CircleBorder(),
      child: SizedBox.square(
        dimension: 48,
        child: Center(
          child: DoodleIcon(doodle, size: size, color: color),
        ),
      ),
    ),
  );
}

// ------------------------------------------------------------------- switches

/// A hand-drawn switch. Never use it for something that can't be switched back.
class HandSwitch extends StatelessWidget {
  const HandSwitch({super.key, required this.value, required this.onChanged});
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      toggled: value,
      enabled: onChanged != null,
      child: GestureDetector(
        onTap: onChanged == null ? null : () => onChanged!(!value),
        // A 48 high target around the 52 x 30 drawing; graphite when it cannot be switched.
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 9),
          child: TweenAnimationBuilder<double>(
            tween: Tween(end: value ? 1 : 0),
            duration: context.motion(MotionTokens.toggle),
            curve: Curves.easeOutBack,
            builder: (context, t, _) => CustomPaint(
              size: const Size(52, 30),
              painter: _SwitchPainter(t, c, onChanged == null ? c.graphite : c.ink),
            ),
          ),
        ),
      ),
    );
  }
}

class _SwitchPainter extends CustomPainter {
  _SwitchPainter(this.t, this.c, this.ink);
  final double t;
  final BaseColors c;
  final Color ink;

  @override
  void paint(Canvas canvas, Size size) {
    final rr = RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(size.height / 2));
    canvas.drawRRect(rr, Paint()..color = ink.withValues(alpha: t.clamp(0, 1)));
    canvas.drawRRect(
      rr.deflate(0.9),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8
        ..color = ink,
    );
    final r = size.height / 2 - 4;
    final cx = r + 4 + (size.width - 2 * r - 8) * t;
    canvas.drawCircle(Offset(cx, size.height / 2), r, Paint()..color = c.paper);
    canvas.drawCircle(
      Offset(cx, size.height / 2),
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..color = ink,
    );
    if (t > 0.6) {
      // A small tick on the knob once it is on.
      canvas.save();
      canvas.translate(cx - 7, size.height / 2 - 7);
      canvas.scale(14 / 24);
      canvas.drawPath(
        doodlePath(Doodle.tick),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3.4
          ..strokeCap = StrokeCap.round
          ..color = ink.withValues(alpha: ((t - 0.6) / 0.4).clamp(0, 1)),
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_SwitchPainter old) => old.t != t || old.c != c || old.ink != ink;
}

/// A whole-row toggle: title (door 24/28), an explanation (meta), and the switch.
/// The title says what the switch does.
class SwitchRow extends StatelessWidget {
  const SwitchRow({super.key, required this.title, required this.value, required this.onChanged, this.body, this.doodle});
  final String title;
  final bool value;
  final ValueChanged<bool>? onChanged;
  final String? body;
  final Doodle? doodle;

  @override
  Widget build(BuildContext context) => MergeSemantics(
    child: InkWell(
      onTap: onChanged == null ? null : () => onChanged!(!value),
      borderRadius: BorderRadius.circular(RadiusTokens.row),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: SpaceTokens.s),
        child: Row(
          children: [
            if (doodle != null) ...[DoodleIcon(doodle!, size: SizeTokens.icon), const SizedBox(width: SpaceTokens.sm)],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: context.type.door.copyWith(color: onChanged == null ? context.colors.graphite : null)),
                  if (body != null) Meta(body!),
                ],
              ),
            ),
            const SizedBox(width: SpaceTokens.sm),
            HandSwitch(value: value, onChanged: onChanged),
          ],
        ),
      ),
    ),
  );
}

// ------------------------------------------------------------------- rows

/// A row that leads to a place in the app ("models", "privacy"): the place in
/// hand-lettering (door 24/28, at most two lines) and a circled arrow. Rows
/// that lead nowhere are drawn in pencil with no arrow. For content (talks,
/// people, models, files) use [ItemRow].
class Door extends StatelessWidget {
  const Door(this.text, {super.key, this.onTap, this.mark, this.meta, this.alert = false, this.leading});
  final String text;
  final VoidCallback? onTap;
  final String? mark;
  final String? meta;

  /// A red exclamation: something private or wrong needs a look.
  final bool alert;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final live = onTap != null;
    return MergeSemantics(
      child: Semantics(
        button: live,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(RadiusTokens.row),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 64),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: SpaceTokens.sm),
              child: Row(
                children: [
                  if (leading != null) ...[leading!, const SizedBox(width: SpaceTokens.sm)],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Flexible(
                              child: MarkedText(text, mark: mark, style: context.type.door, color: live ? c.ink : c.pencil, maxLines: 2),
                            ),
                            if (alert)
                              Padding(
                                padding: const EdgeInsets.only(left: 2, top: 2),
                                child: DoodleIcon(Doodle.exclaim, size: SizeTokens.iconSmall, color: c.redPen, stroke: 2.6, semanticLabel: 'needs a look'),
                              ),
                          ],
                        ),
                        if (meta != null) Padding(padding: const EdgeInsets.only(top: 2), child: Meta(meta!, maxLines: 2)),
                      ],
                    ),
                  ),
                  if (live) ...[
                    const SizedBox(width: SpaceTokens.sm),
                    Container(
                      width: 40,
                      height: 40,
                      decoration: ShapeDecoration(
                        shape: CircleBorder(
                          side: BorderSide(color: c.ink, width: StrokeTokens.pill),
                        ),
                      ),
                      child: const Center(child: DoodleIcon(Doodle.arrow, size: SizeTokens.iconSmall)),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A row of content (a talk, a person, a model, a file, a saved item, a memory
/// fact): the title in the body face (row title 17/24, two lines), an optional
/// meta (two lines) and caption, an optional leading doodle or initial, and a
/// trailing arrow when it opens something (or one [trailing] widget).
class ItemRow extends StatelessWidget {
  const ItemRow(
    this.title, {
    super.key,
    this.meta,
    this.caption,
    this.aside,
    this.doodle,
    this.initial,
    this.initialColor,
    this.leading,
    this.trailing,
    this.below,
    this.onTap,
    this.selected = false,
    this.titleStyle,
  });

  final String title;

  /// Pencil, 14/20, up to two lines.
  final String? meta;

  /// Pencil, 13/18: timestamps, counts, "on this device".
  final String? caption;

  /// A short caption on the right of the title, such as a size ("2.6 GB").
  final String? aside;

  /// A 24 doodle in front.
  final Doodle? doodle;

  /// One letter in a 40 circle in front (people).
  final String? initial;
  final Color? initialColor;

  /// Anything else in front (overrides [doodle] and [initial]).
  final Widget? leading;

  /// One widget at the end: a switch, a link, a caption. Without it, a row
  /// with [onTap] ends in a pencil arrow.
  final Widget? trailing;

  /// Full width under the text: a pill, a progress line, a state line.
  final Widget? below;
  final VoidCallback? onTap;

  /// In a list beside its detail: smudge background and an ink bar on the left.
  final bool selected;

  /// The body style for [title], for rows whose title is the user's own words
  /// (a memory fact reads as `body`). Defaults to `rowTitle`.
  final TextStyle? titleStyle;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.type;
    Widget? lead = leading;
    if (lead == null && initial != null) {
      final color = initialColor ?? c.ink;
      lead = Container(
        width: 40,
        height: 40,
        alignment: Alignment.center,
        decoration: ShapeDecoration(shape: CircleBorder(side: BorderSide(color: color, width: StrokeTokens.pill))),
        child: Text(initial!.characters.take(1).toString().toUpperCase(), style: t.rowTitle.copyWith(color: color)),
      );
    }
    lead ??= doodle == null ? null : DoodleIcon(doodle!, size: SizeTokens.icon, color: c.ink);
    final end = trailing ?? (onTap != null ? DoodleIcon(Doodle.arrow, size: SizeTokens.iconSmall, color: c.pencil) : null);
    final row = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: SizeTokens.row),
      child: Padding(
        padding: EdgeInsets.fromLTRB(selected ? SpaceTokens.sm : 0, SpaceTokens.sm, selected ? SpaceTokens.s : 0, SpaceTokens.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (lead != null) ...[lead, const SizedBox(width: SpaceTokens.sm)],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, style: titleStyle ?? t.rowTitle),
                          ),
                          if (aside != null)
                            Padding(
                              // Sits on the title's first line.
                              padding: const EdgeInsets.only(left: SpaceTokens.sm, top: 3),
                              child: Text(aside!, style: t.caption, textAlign: TextAlign.end),
                            ),
                        ],
                      ),
                      if (meta != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(meta!, maxLines: 2, overflow: TextOverflow.ellipsis, style: t.meta),
                        ),
                      if (caption != null) Padding(padding: const EdgeInsets.only(top: 2), child: Text(caption!, style: t.caption)),
                    ],
                  ),
                ),
                if (end != null) ...[
                  const SizedBox(width: SpaceTokens.sm),
                  ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 24),
                    child: Center(widthFactor: 1, heightFactor: 1, child: end),
                  ),
                ],
              ],
            ),
            if (below != null) Padding(padding: const EdgeInsets.only(top: SpaceTokens.s), child: below),
          ],
        ),
      ),
    );
    final content = selected
        ? DecoratedBox(
            decoration: BoxDecoration(
              color: c.smudge,
              border: Border(left: BorderSide(color: c.ink, width: 3)),
            ),
            child: row,
          )
        : row;
    if (onTap == null) return MergeSemantics(child: Semantics(selected: selected, child: content));
    return MergeSemantics(
      child: Semantics(
        button: true,
        selected: selected,
        child: InkWell(onTap: onTap, borderRadius: BorderRadius.circular(RadiusTokens.row), child: content),
      ),
    );
  }
}

/// A small label in the body face (13/18, 600) on a smudge fill; marked
/// (yellow) for the one that matters. With [onTap] the target is 48 high.
class HandTag extends StatelessWidget {
  const HandTag(this.text, {super.key, this.marked = false, this.onTap});
  final String text;
  final bool marked;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final tag = DecoratedBox(
      decoration: ShapeDecoration(color: marked ? c.marker : c.smudge, shape: const StadiumBorder()),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: SpaceTokens.sm, vertical: 5),
        child: Text(text, style: context.type.tag.copyWith(color: marked ? c.markerInk : c.ink)),
      ),
    );
    if (onTap == null) return tag;
    return Semantics(
      button: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          HapticFeedback.selectionClick();
          onTap!();
        },
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: SizeTokens.minTap),
          child: Center(widthFactor: 1, child: tag),
        ),
      ),
    );
  }
}

/// "on this device": a lock doodle and a caption.
class OnDeviceStamp extends StatelessWidget {
  const OnDeviceStamp({super.key, this.text = 'on this device'});
  final String text;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      DoodleIcon(Doodle.lock, size: 16, color: context.colors.pencil, stroke: 1.6),
      const SizedBox(width: 6),
      Flexible(child: Text(text, style: context.type.caption)),
    ],
  );
}

// ------------------------------------------------------------------- inputs

/// A text input: a pale smudge well, no outline. Text is body 16/24 in ink,
/// the placeholder graphite.
class HandField extends StatelessWidget {
  const HandField({
    super.key,
    this.controller,
    this.onChanged,
    this.onSubmitted,
    this.placeholder = '',
    this.singleLine = false,
    this.minHeight = 0,
    this.leading,
    this.keyboardType,
    this.autofocus = false,
    this.obscure = false,
  });
  final TextEditingController? controller;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final String placeholder;
  final bool singleLine;
  final double minHeight;
  final Doodle? leading;
  final TextInputType? keyboardType;
  final bool autofocus;

  /// Hides what is typed (tokens, passwords).
  final bool obscure;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final style = context.type.body;
    return Container(
      constraints: BoxConstraints(minHeight: minHeight < SizeTokens.field ? SizeTokens.field : minHeight),
      decoration: BoxDecoration(color: c.smudge, borderRadius: BorderRadius.circular(RadiusTokens.well)),
      padding: const EdgeInsets.symmetric(horizontal: SpaceTokens.m, vertical: 14),
      child: Row(
        crossAxisAlignment: singleLine ? CrossAxisAlignment.center : CrossAxisAlignment.start,
        children: [
          if (leading != null) ...[
            Padding(
              padding: EdgeInsets.only(top: singleLine ? 0 : 2),
              child: DoodleIcon(leading!, size: SizeTokens.iconSmall, color: c.pencil),
            ),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              onSubmitted: onSubmitted,
              autofocus: autofocus,
              obscureText: obscure,
              autocorrect: !obscure,
              enableSuggestions: !obscure,
              keyboardType: keyboardType,
              maxLines: singleLine ? 1 : null,
              style: style,
              cursorColor: c.ink,
              decoration: InputDecoration.collapsed(
                hintText: placeholder,
                hintStyle: style.copyWith(color: c.graphite),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------------- flows

/// A flow says its steps up front. [current] is the step in progress, or -1.
class Steps extends StatelessWidget {
  const Steps(this.steps, {super.key, this.current = -1});
  final List<String> steps;
  final int current;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.type;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < steps.length; i++)
          Padding(
            padding: EdgeInsets.only(bottom: i == steps.length - 1 ? 0 : SpaceTokens.s),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 24,
                  height: 24,
                  alignment: Alignment.center,
                  decoration: ShapeDecoration(
                    color: i == current ? c.ink : null,
                    shape: CircleBorder(side: BorderSide(color: c.ink, width: 1.4)),
                  ),
                  child: Text('${i + 1}', style: t.tag.copyWith(color: i == current ? c.paper : c.ink)),
                ),
                const SizedBox(width: SpaceTokens.sm),
                Expanded(
                  child: Text(steps[i], style: t.body.copyWith(color: current >= 0 && i != current ? c.pencil : c.ink)),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// A numbered stage of a page; ticked once done.
class StepHead extends StatelessWidget {
  const StepHead(this.number, this.text, {super.key, this.done = false});
  final int number;
  final String text;
  final bool done;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.only(top: SpaceTokens.s, bottom: SpaceTokens.s),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: ShapeDecoration(
              color: done ? c.ink : c.paper,
              shape: CircleBorder(
                side: BorderSide(color: c.ink, width: StrokeTokens.pill),
              ),
            ),
            child: done ? DoodleIcon(Doodle.tick, size: 18, color: c.paper, stroke: 2.4) : Text('$number', style: context.type.tag),
          ),
          const SizedBox(width: SpaceTokens.sm),
          Expanded(child: Text(text, style: context.type.door)),
        ],
      ),
    );
  }
}

/// After something happens, say so (an ink sentence on smudge) and offer the
/// next step as a link.
class DoneNote extends StatelessWidget {
  const DoneNote(this.text, {super.key, this.action, this.onAction});
  final String text;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(color: context.colors.smudge, borderRadius: BorderRadius.circular(RadiusTokens.well)),
    padding: EdgeInsets.fromLTRB(SpaceTokens.m, action == null ? SpaceTokens.sm : SpaceTokens.xs, SpaceTokens.s, action == null ? SpaceTokens.sm : SpaceTokens.xs),
    child: Row(
      children: [
        const DoodleIcon(Doodle.tick, size: SizeTokens.iconSmall),
        const SizedBox(width: 10),
        Expanded(child: Text(text, style: context.type.body)),
        if (action != null) HandLink(action!, onPressed: onAction),
      ],
    ),
  );
}

/// An empty state: a doodle, a title and one plain sentence of what will
/// appear here, and how.
class HandEmpty extends StatelessWidget {
  const HandEmpty({super.key, required this.title, required this.body, this.doodle = Doodle.spark, this.action});
  final String title;
  final String body;
  final Doodle doodle;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 28),
    child: Column(
      children: [
        DoodleIcon(doodle, size: 40, color: context.colors.pencil),
        const SizedBox(height: SpaceTokens.sm),
        Text(title, style: context.type.title, textAlign: TextAlign.center),
        const SizedBox(height: SpaceTokens.s),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 280),
          child: Body(body, color: context.colors.pencil, textAlign: TextAlign.center),
        ),
        if (action != null) ...[const SizedBox(height: SpaceTokens.sm), action!],
      ],
    ),
  );
}

/// A choice drawn on a photo or row: filled ink with a tick when picked.
class PickMark extends StatelessWidget {
  const PickMark({super.key, required this.picked});
  final bool picked;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      width: 28,
      height: 28,
      decoration: ShapeDecoration(
        color: picked ? c.ink : c.paper.withValues(alpha: 0.85),
        shape: CircleBorder(side: BorderSide(color: picked ? c.paper : c.ink, width: 1.8)),
      ),
      child: picked ? Center(child: DoodleIcon(Doodle.tick, size: 18, color: c.paper, stroke: 2.6)) : null,
    );
  }
}

/// A photo as a snapshot: small, white border, slightly tilted, 2dp lift.
class Snapshot extends StatelessWidget {
  const Snapshot({super.key, required this.child, this.tilt = 0, this.faded = false});
  final Widget child;

  /// Degrees. Grids use [-2.5, 1.8, -1.2, 2.6, -1.8, 1.2].
  final double tilt;
  final bool faded;

  @override
  Widget build(BuildContext context) => Opacity(
    opacity: faded ? AlphaTokens.faded : 1,
    child: Transform.rotate(
      angle: tilt * 3.141592653589793 / 180,
      child: Material(
        color: context.colors.paper,
        elevation: ElevationTokens.snapshot,
        borderRadius: BorderRadius.circular(RadiusTokens.snapshot),
        child: Padding(padding: const EdgeInsets.all(4), child: child),
      ),
    ),
  );
}

// ------------------------------------------------------------------- sheets

/// A bottom sheet on paper with a squiggle handle.
Future<T?> showHandSheet<T>(BuildContext context, {required WidgetBuilder builder}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    showDragHandle: false,
    useSafeArea: true,
    backgroundColor: context.colors.paper,
    builder: (context) => SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 10, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(child: DoodleIcon(Doodle.squiggle, size: 34, color: context.colors.graphite)),
            const SizedBox(height: 14),
            builder(context),
          ],
        ),
      ),
    ),
  );
}

/// Ask before doing something that matters. Returns true when confirmed.
Future<bool> confirmSheet(
  BuildContext context, {
  required String title,
  required String body,
  required String confirm,
  bool danger = false,
  String cancel = 'not now',
}) async {
  final ok = await showHandSheet<bool>(
    context,
    builder: (context) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(title, style: context.type.title),
        const SizedBox(height: SpaceTokens.sm),
        Body(body),
        const SizedBox(height: SpaceTokens.l),
        InkButton(confirm, danger: danger, onPressed: () => Navigator.pop(context, true)),
        Center(child: HandLink(cancel, onPressed: () => Navigator.pop(context, false))),
      ],
    ),
  );
  return ok ?? false;
}

// ------------------------------------------------------------------- navigation

/// Words do the navigation: two to four hand-lettered words, the current one
/// circled. Along the bottom on phones; from `railBreakpoint` the same words
/// stand in a rail on the left ([HandNav.rail]), with the wordmark at the top
/// and [footer] (the gear and padlock) at the bottom.
class HandNav extends StatelessWidget {
  const HandNav({super.key, required this.words, required this.selected, required this.onSelect})
    : rail = false,
      wordmark = null,
      footer = const [],
      assert(words.length <= 4, 'At most four nav words: more means the app is doing too much.');

  const HandNav.rail({super.key, required this.words, required this.selected, required this.onSelect, this.wordmark, this.footer = const []})
    : rail = true,
      assert(words.length <= 4, 'At most four nav words: more means the app is doing too much.');

  final List<String> words;
  final int? selected;
  final ValueChanged<int> onSelect;
  final bool rail;

  /// Rail only: the app's name at the top.
  final String? wordmark;

  /// Rail only: doodle buttons at the bottom.
  final List<Widget> footer;

  /// Words never shrink below this on a narrow screen.
  static const minWordSize = 20.0;

  Widget _word(BuildContext context, int i, {required bool fit}) {
    final c = context.colors;
    final on = i == selected;
    final style = context.type.label.copyWith(color: on ? c.ink : c.pencil, fontWeight: on ? FontWeight.w700 : FontWeight.w600);
    Widget text = Text(words[i], maxLines: 1, softWrap: false, overflow: TextOverflow.ellipsis, style: style);
    if (fit) {
      // Shrinks rather than overflows on narrow screens or large text, but not below 20.
      text = LayoutBuilder(
        builder: (context, box) {
          final scaler = MediaQuery.textScalerOf(context);
          final tp = TextPainter(text: TextSpan(text: words[i], style: style), textDirection: TextDirection.ltr, textScaler: scaler, maxLines: 1)
            ..layout();
          final room = box.maxWidth - 20; // the circle reaches 9 past each side
          final shrink = tp.width <= room || tp.width == 0 ? 1.0 : (room / tp.width).clamp(minWordSize / style.fontSize!, 1.0);
          tp.dispose();
          return Text(
            words[i],
            maxLines: 1,
            softWrap: false,
            overflow: TextOverflow.ellipsis,
            style: style,
            textScaler: TextScaler.linear(scaler.scale(1) * shrink),
          );
        },
      );
    }
    return Semantics(
      selected: on,
      button: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          HapticFeedback.selectionClick();
          onSelect(i);
        },
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: SizeTokens.minTap, minWidth: SizeTokens.minTap),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: fit ? 4 : SpaceTokens.sm, vertical: SpaceTokens.s),
            child: Align(
              alignment: fit ? Alignment.center : Alignment.centerLeft,
              widthFactor: fit ? null : 1,
              child: HandCircle(visible: on, seed: i + 2, child: text),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    if (rail) {
      return Material(
        color: c.paper,
        child: SafeArea(
          right: false,
          child: SizedBox(
            width: SpaceTokens.railWidth,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(SpaceTokens.l, SpaceTokens.l, SpaceTokens.s, SpaceTokens.m),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (wordmark != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: SpaceTokens.xl),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(wordmark!, maxLines: 1, style: context.type.title),
                      ),
                    ),
                  for (var i = 0; i < words.length; i++) ...[
                    if (i > 0) const SizedBox(height: SpaceTokens.sm),
                    _word(context, i, fit: false),
                  ],
                  const Spacer(),
                  if (footer.isNotEmpty) Wrap(children: footer),
                ],
              ),
            ),
          ),
        ),
      );
    }
    return ColoredBox(
      color: c.paper,
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(padding: EdgeInsets.symmetric(horizontal: SpaceTokens.l), child: HandDivider()),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: SpaceTokens.sm, vertical: SpaceTokens.xs),
              child: Row(
                children: [for (var i = 0; i < words.length; i++) Expanded(child: _word(context, i, fit: true))],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// On wide screens (fold inner, tablet, desktop; from 840) a list and its
/// detail sit side by side. The detail's page is left-aligned with 40 padding
/// and its text capped at `readingColumn`; extra width stays empty paper.
class TwoPane extends StatelessWidget {
  const TwoPane({super.key, required this.list, required this.detail, this.listWidth = SpaceTokens.listPane});
  final Widget list;
  final Widget? detail;
  final double listWidth;

  @override
  Widget build(BuildContext context) {
    if (!context.isWide || detail == null) return list;
    final outer = HandLayout.maybeOf(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          width: listWidth,
          child: HandLayout(rail: outer?.rail ?? false, maxWidth: listWidth, child: list),
        ),
        SizedBox(width: 1, child: ColoredBox(color: context.colors.rule)),
        Expanded(
          child: HandLayout(rail: outer?.rail ?? false, start: true, maxWidth: SpaceTokens.readingColumn, child: detail!),
        ),
      ],
    );
  }
}
