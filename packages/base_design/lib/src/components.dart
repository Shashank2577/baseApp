import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'doodle.dart';
import 'generated/doodles.g.dart';
import 'generated/tokens.g.dart';
import 'hand.dart';
import 'theme.dart';

// ------------------------------------------------------------------- text

/// Quiet secondary text (dates, sizes, counts) in pencil.
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

/// An explanation in the user's chosen voice.
class Body extends StatelessWidget {
  const Body(this.text, {super.key, this.color, this.textAlign});
  final String text;
  final Color? color;
  final TextAlign? textAlign;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: context.type.body.copyWith(color: color ?? context.colors.ink),
    textAlign: textAlign,
  );
}

// ------------------------------------------------------------------- page

/// The page frame: paper, a top row (back, wordmark, actions), one centred
/// column at most 560 wide, and an optional sticky bottom (usually the ink button).
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

  /// The app's name, hand-lettered, on home pages ("burrow.").
  final String? wordmark;
  final List<Widget> actions;
  final Widget? bottom;
  final bool scroll;
  final ScrollController? controller;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    const max = SpaceTokens.maxColumn;
    final column = Padding(
      padding: const EdgeInsets.fromLTRB(SpaceTokens.gutter, 0, SpaceTokens.gutter, 32),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
    );
    return Material(
      color: c.paper,
      child: SafeArea(
        bottom: bottom == null,
        child: Column(
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: max + 48),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  child: SizedBox(
                    height: 48,
                    child: Row(
                      children: [
                        if (onBack != null) DoodleButton(Doodle.back, label: 'back', onPressed: onBack),
                        if (wordmark != null)
                          Flexible(
                            child: Padding(
                              padding: EdgeInsets.only(left: onBack == null ? 12 : 0),
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerLeft,
                                child: Text(wordmark!, maxLines: 1, style: context.type.title),
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
            ),
            Expanded(
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: max),
                  child: scroll ? SingleChildScrollView(controller: controller, child: column) : column,
                ),
              ),
            ),
            if (bottom != null)
              ColoredBox(
                color: c.paper,
                child: SafeArea(
                  top: false,
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: max),
                      child: Padding(padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12), child: bottom),
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

/// Every page says what it is for: the name, one plain sentence, and a doodle.
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
      padding: const EdgeInsets.only(bottom: 18),
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
                  padding: const EdgeInsets.only(left: 12, bottom: 6),
                  child: DoodleIcon(doodle!, size: 40, color: c.pencil, stroke: 1.8, tilt: -8),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Body(purpose, color: c.pencil),
        ],
      ),
    );
  }
}

/// A section heading in the page, with an optional quiet note on the right.
class SectionHead extends StatelessWidget {
  const SectionHead(this.text, {super.key, this.note, this.mark = false});
  final String text;
  final String? note;
  final bool mark;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 8),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: MarkedText(text, mark: mark ? text : null, style: context.type.title.copyWith(fontSize: 27)),
        ),
        if (note != null)
          Flexible(
            child: Padding(padding: const EdgeInsets.only(left: 12, bottom: 4), child: Meta(note!, textAlign: TextAlign.end)),
          ),
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

/// The one primary action on a screen: a black ink pill.
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
    return Opacity(
      opacity: enabled || busy ? 1 : AlphaTokens.disabledButton,
      child: Material(
        color: danger ? c.redPen : c.ink,
        shape: const StadiumBorder(),
        child: _Press(
          onTap: enabled ? onPressed : null,
          label: text,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 56),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (busy) ...[
                    SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2, color: c.paper)),
                    const SizedBox(width: 12),
                  ],
                  Flexible(
                    child: Text(
                      text,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.type.label.copyWith(fontSize: 23, color: c.paper),
                    ),
                  ),
                  if (trailing != null) ...[const SizedBox(width: 10), DoodleIcon(trailing!, size: 20, color: c.paper)],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A secondary action: an outlined pill.
class PillButton extends StatelessWidget {
  const PillButton(this.text, {super.key, required this.onPressed, this.leading, this.color});
  final String text;
  final VoidCallback? onPressed;
  final Doodle? leading;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final ink = color ?? context.colors.ink;
    return Opacity(
      opacity: onPressed == null ? AlphaTokens.disabledLink : 1,
      child: Material(
        type: MaterialType.transparency,
        shape: StadiumBorder(
          side: BorderSide(color: ink, width: StrokeTokens.pill),
        ),
        child: _Press(
          onTap: onPressed,
          label: text,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 44),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (leading != null) ...[DoodleIcon(leading!, size: 18, color: ink), const SizedBox(width: 8)],
                  Flexible(
                    child: Text(text, style: context.type.label.copyWith(color: ink)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// One choice of several (radio-style): filled ink when selected.
class ChoicePill extends StatelessWidget {
  const ChoicePill(this.text, {super.key, required this.selected, required this.onPressed, this.leading});
  final String text;
  final bool selected;
  final VoidCallback onPressed;
  final Doodle? leading;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final fg = selected ? c.paper : c.ink;
    return Semantics(
      selected: selected,
      inMutuallyExclusiveGroup: true,
      child: Material(
        color: selected ? c.ink : Colors.transparent,
        shape: StadiumBorder(
          side: BorderSide(color: c.ink, width: StrokeTokens.pill),
        ),
        child: _Press(
          onTap: onPressed,
          label: text,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 44),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (leading != null) ...[DoodleIcon(leading!, size: 18, color: fg), const SizedBox(width: 8)],
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

/// A minor, tertiary action: hand-underlined words.
class HandLink extends StatelessWidget {
  const HandLink(this.text, {super.key, required this.onPressed, this.color, this.style});
  final String text;
  final VoidCallback? onPressed;
  final Color? color;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final c = color ?? context.colors.ink;
    return Opacity(
      opacity: onPressed == null ? AlphaTokens.disabledLink : 1,
      child: _Press(
        onTap: onPressed,
        label: text,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          child: HandUnderline(
            color: c.withValues(alpha: 0.8),
            seed: text.length,
            child: Text(text, style: (style ?? context.type.label).copyWith(color: c)),
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
        child: Opacity(
          opacity: onChanged == null ? AlphaTokens.disabledLink : 1,
          child: TweenAnimationBuilder<double>(
            tween: Tween(end: value ? 1 : 0),
            duration: context.motion(MotionTokens.toggle),
            curve: Curves.easeOutBack,
            builder: (context, t, _) => CustomPaint(size: const Size(52, 30), painter: _SwitchPainter(t, c)),
          ),
        ),
      ),
    );
  }
}

class _SwitchPainter extends CustomPainter {
  _SwitchPainter(this.t, this.c);
  final double t;
  final BaseColors c;

  @override
  void paint(Canvas canvas, Size size) {
    final rr = RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(size.height / 2));
    canvas.drawRRect(rr, Paint()..color = c.ink.withValues(alpha: t.clamp(0, 1)));
    canvas.drawRRect(
      rr.deflate(0.9),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8
        ..color = c.ink,
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
        ..color = c.ink,
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
          ..color = c.ink.withValues(alpha: ((t - 0.6) / 0.4).clamp(0, 1)),
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_SwitchPainter old) => old.t != t || old.c != c;
}

/// A whole-row toggle: title, an explanation, and the switch.
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
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            if (doodle != null) ...[DoodleIcon(doodle!, size: 26), const SizedBox(width: 14)],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: context.type.door.copyWith(fontSize: 24)),
                  if (body != null) Meta(body!),
                ],
              ),
            ),
            const SizedBox(width: 12),
            HandSwitch(value: value, onChanged: onChanged),
          ],
        ),
      ),
    ),
  );
}

// ------------------------------------------------------------------- rows

/// A list row. Live rows end in a circled arrow; rows that lead nowhere are
/// drawn in pencil with no arrow.
class Door extends StatelessWidget {
  const Door(this.text, {super.key, this.onTap, this.mark, this.meta, this.alert = false, this.leading, this.style});
  final String text;
  final VoidCallback? onTap;
  final String? mark;
  final String? meta;

  /// A red exclamation: something private or wrong needs a look.
  final bool alert;
  final Widget? leading;
  final TextStyle? style;

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
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(
              children: [
                if (leading != null) ...[leading!, const SizedBox(width: 14)],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Flexible(
                            child: MarkedText(
                              text,
                              mark: mark,
                              style: style ?? context.type.door.copyWith(fontSize: 28, height: 32 / 28),
                              color: live ? c.ink : c.pencil,
                            ),
                          ),
                          if (alert)
                            Padding(
                              padding: const EdgeInsets.only(left: 2, top: 4),
                              child: DoodleIcon(Doodle.exclaim, size: 22, color: c.redPen, stroke: 2.6, semanticLabel: 'needs a look'),
                            ),
                        ],
                      ),
                      if (meta != null) Padding(padding: const EdgeInsets.only(top: 2), child: Meta(meta!)),
                    ],
                  ),
                ),
                if (live) ...[
                  const SizedBox(width: 12),
                  Container(
                    width: 40,
                    height: 40,
                    decoration: ShapeDecoration(
                      shape: CircleBorder(
                        side: BorderSide(color: c.ink, width: StrokeTokens.pill),
                      ),
                    ),
                    child: const Center(child: DoodleIcon(Doodle.arrow, size: 22)),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A small label: outlined in rule, or marked (yellow) for the one that matters.
class HandTag extends StatelessWidget {
  const HandTag(this.text, {super.key, this.marked = false, this.onTap});
  final String text;
  final bool marked;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Material(
      color: marked ? c.marker : Colors.transparent,
      shape: StadiumBorder(
        side: marked ? BorderSide.none : BorderSide(color: c.rule, width: StrokeTokens.hairline),
      ),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
          child: Text(text, style: context.type.small.copyWith(color: marked ? c.markerInk : c.ink)),
        ),
      ),
    );
  }
}

/// "on this device": a lock doodle and a meta line.
class OnDeviceStamp extends StatelessWidget {
  const OnDeviceStamp({super.key, this.text = 'on this device'});
  final String text;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      DoodleIcon(Doodle.lock, size: 14, color: context.colors.pencil, stroke: 1.6),
      const SizedBox(width: 5),
      Flexible(child: Meta(text)),
    ],
  );
}

// ------------------------------------------------------------------- inputs

/// A text input: a pale smudge well, no outline.
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

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final style = context.type.bodyStyle(16, 23);
    return Container(
      constraints: BoxConstraints(minHeight: minHeight < 52 ? 52 : minHeight),
      decoration: BoxDecoration(color: c.smudge, borderRadius: BorderRadius.circular(RadiusTokens.well)),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        crossAxisAlignment: singleLine ? CrossAxisAlignment.center : CrossAxisAlignment.start,
        children: [
          if (leading != null) ...[DoodleIcon(leading!, size: 20, color: c.pencil), const SizedBox(width: 10)],
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              onSubmitted: onSubmitted,
              autofocus: autofocus,
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < steps.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: [
                Container(
                  width: 24,
                  height: 24,
                  alignment: Alignment.center,
                  decoration: ShapeDecoration(
                    color: i == current ? c.ink : null,
                    shape: CircleBorder(side: BorderSide(color: c.ink, width: 1.4)),
                  ),
                  child: Text('${i + 1}', style: context.type.small.copyWith(fontSize: 15, color: i == current ? c.paper : c.ink)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(steps[i], style: context.type.bodyStyle(14, 19, color: current >= 0 && i != current ? c.pencil : c.ink)),
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
      padding: const EdgeInsets.only(top: 8, bottom: 6),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            alignment: Alignment.center,
            decoration: ShapeDecoration(
              color: done ? c.ink : c.paper,
              shape: CircleBorder(
                side: BorderSide(color: c.ink, width: StrokeTokens.pill),
              ),
            ),
            child: done ? DoodleIcon(Doodle.tick, size: 18, color: c.paper, stroke: 2.4) : Text('$number', style: context.type.label),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(text, style: context.type.title.copyWith(fontSize: 26))),
        ],
      ),
    );
  }
}

/// After something happens, say so and offer the next step.
class DoneNote extends StatelessWidget {
  const DoneNote(this.text, {super.key, this.action, this.onAction});
  final String text;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(color: context.colors.smudge, borderRadius: BorderRadius.circular(RadiusTokens.well)),
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    child: Row(
      children: [
        const DoodleIcon(Doodle.tick, size: 20),
        const SizedBox(width: 10),
        Expanded(child: Text(text, style: context.type.label)),
        if (action != null) HandLink(action!, onPressed: onAction, style: context.type.small),
      ],
    ),
  );
}

/// An empty state: a doodle, a title and one plain sentence.
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
        const SizedBox(height: 12),
        Text(title, style: context.type.title, textAlign: TextAlign.center),
        const SizedBox(height: 12),
        Body(body, color: context.colors.pencil, textAlign: TextAlign.center),
        if (action != null) ...[const SizedBox(height: 12), action!],
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
        Text(title, style: context.type.headline.copyWith(fontSize: 34)),
        const SizedBox(height: 14),
        Body(body, color: context.colors.pencil),
        const SizedBox(height: 14),
        InkButton(confirm, danger: danger, onPressed: () => Navigator.pop(context, true)),
        Center(child: HandLink(cancel, onPressed: () => Navigator.pop(context, false))),
      ],
    ),
  );
  return ok ?? false;
}

// ------------------------------------------------------------------- navigation

/// Words do the navigation: hand-lettered words, the current one circled.
class HandNav extends StatelessWidget {
  const HandNav({super.key, required this.words, required this.selected, required this.onSelect});
  final List<String> words;
  final int? selected;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return ColoredBox(
      color: c.paper,
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(padding: EdgeInsets.symmetric(horizontal: 24), child: HandDivider()),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  for (var i = 0; i < words.length; i++) ...[
                    if (i > 0) Text('·', style: context.type.label.copyWith(color: c.graphite)),
                    Flexible(
                      child: Semantics(
                        selected: i == selected,
                        button: true,
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () {
                            HapticFeedback.selectionClick();
                            onSelect(i);
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                            child: HandCircle(
                              visible: i == selected,
                              seed: i + 2,
                              // Shrinks rather than overflows on narrow screens or large text.
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  words[i],
                                  maxLines: 1,
                                  style: context.type.label.copyWith(fontSize: 23, color: i == selected ? c.ink : c.pencil),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// On wide screens (fold inner, tablet, desktop) a list and its detail sit side by side.
class TwoPane extends StatelessWidget {
  const TwoPane({super.key, required this.list, required this.detail, this.listWidth = 380});
  final Widget list;
  final Widget? detail;
  final double listWidth;

  @override
  Widget build(BuildContext context) {
    if (!context.isWide || detail == null) return list;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(width: listWidth, child: list),
        SizedBox(width: 1, child: ColoredBox(color: context.colors.rule)),
        Expanded(child: detail!),
      ],
    );
  }
}
