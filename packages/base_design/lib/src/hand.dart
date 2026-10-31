import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import 'generated/tokens.g.dart';
import 'theme.dart';

/// 32-bit multiply that gives the same bits on native and web (JS numbers
/// lose precision above 2^53, so a plain `*` would not wrap like Kotlin's Int).
int _imul(int a, int b) {
  a &= 0xFFFFFFFF;
  b &= 0xFFFFFFFF;
  final al = a & 0xFFFF, ah = (a >> 16) & 0xFFFF, bl = b & 0xFFFF, bh = (b >> 16) & 0xFFFF;
  return ((al * bl) + (((ah * bl + al * bh) & 0xFFFF) << 16)) & 0xFFFFFFFF;
}

/// A small deterministic wobble in [-amount, amount], so a stroke looks drawn
/// by hand but looks the same on every frame. Bit-for-bit the same as Burrow's
/// Kotlin `wobble`, so a line drawn by an Android app and a Flutter app match.
double wobble(int seed, int i, double amount) {
  var x = (_imul(seed, 374761393) + _imul(i, 668265263)) & 0xFFFFFFFF;
  x = _imul(x ^ (x >> 13), 1274126177);
  return ((x ^ (x >> 16)) & 0xFFFF) / 65535 * 2 * amount - amount;
}

/// A slightly uneven stroke from [start] to [end].
Path handLinePath(Offset start, Offset end, int seed) {
  const segments = 4;
  final p = Path()..moveTo(start.dx, start.dy);
  for (var i = 1; i <= segments; i++) {
    final t = i / segments;
    final x = start.dx + (end.dx - start.dx) * t;
    final y = start.dy + (end.dy - start.dy) * t + wobble(seed, i, 1.2);
    final cx = start.dx + (end.dx - start.dx) * (t - 0.5 / segments);
    p.quadraticBezierTo(cx, y + wobble(seed, i + 10, 1), x, y);
  }
  return p;
}

void drawHandLine(Canvas canvas, Offset start, Offset end, Color color, double width, int seed) {
  canvas.drawPath(
    handLinePath(start, end, seed),
    Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = width
      ..strokeCap = StrokeCap.round,
  );
}

/// A highlighter swipe across [rect]: rough ends, slightly tilted, covering
/// the lower part of the line box.
Path swipePath(Rect rect, int seed) {
  const pad = 3.0;
  final top = rect.top + rect.height * 0.38;
  final bottom = rect.bottom - rect.height * 0.04;
  final l = rect.left - pad, r = rect.right + pad;
  return Path()
    ..moveTo(l + wobble(seed, 1, pad), top + wobble(seed, 2, 2))
    ..quadraticBezierTo((l + r) / 2, top - 2 + wobble(seed, 3, 1), r, top + wobble(seed, 4, 2))
    ..lineTo(r + wobble(seed, 5, pad), bottom + wobble(seed, 6, 2))
    ..quadraticBezierTo((l + r) / 2, bottom + 2, l, bottom + wobble(seed, 7, 2))
    ..close();
}

/// A loose ring around [size] that doesn't quite close, drawn up to [progress].
Path handCirclePath(Size size, double progress, int seed) {
  final cx = size.width / 2, cy = size.height / 2;
  final rx = size.width / 2 + 9, ry = size.height / 2 + 4;
  const start = -2.2;
  final sweep = (2 * math.pi + 0.45) * progress;
  const steps = 48;
  final p = Path();
  for (var i = 0; i <= steps; i++) {
    final a = start + sweep * i / steps;
    final grow = 1 + 0.05 * i / steps + wobble(seed, i ~/ 6, 0.015);
    final x = cx + math.cos(a) * rx * grow, y = cy + math.sin(a) * ry * grow;
    i == 0 ? p.moveTo(x, y) : p.lineTo(x, y);
  }
  return p;
}

class _Behind extends CustomPainter {
  _Behind(this.draw, this.key);
  final void Function(Canvas, Size) draw;
  final Object key;
  @override
  void paint(Canvas canvas, Size size) => draw(canvas, size);
  @override
  bool shouldRepaint(_Behind old) => old.key != key;
}

/// The yellow marker swipe behind [child]. One per screen.
class Marker extends StatelessWidget {
  const Marker({super.key, required this.child, this.seed = 7, this.color});
  final Widget child;
  final int seed;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? context.colors.marker;
    return CustomPaint(
      painter: _Behind((canvas, size) => canvas.drawPath(swipePath(Offset.zero & size, seed), Paint()..color = c), (c, seed)),
      child: child,
    );
  }
}

/// A hand-drawn underline under [child] (used by links).
class HandUnderline extends StatelessWidget {
  const HandUnderline({super.key, required this.child, this.color, this.width = StrokeTokens.underline, this.seed = 3});
  final Widget child;
  final Color? color;
  final double width;
  final int seed;

  @override
  Widget build(BuildContext context) {
    final c = color ?? context.colors.ink;
    return CustomPaint(
      painter: _Behind((canvas, size) {
        final y = size.height - 1;
        drawHandLine(canvas, Offset(0, y), Offset(size.width, y + wobble(seed, 0, 1)), c, width, seed);
      }, (c, width, seed)),
      child: child,
    );
  }
}

/// A loose hand-drawn ring around [child] that draws itself in when
/// [visible] turns on (the selected word in the nav bar).
class HandCircle extends StatelessWidget {
  const HandCircle({super.key, required this.child, required this.visible, this.color, this.seed = 5, this.width = StrokeTokens.circle});
  final Widget child;
  final bool visible;
  final Color? color;
  final int seed;
  final double width;

  @override
  Widget build(BuildContext context) {
    final c = color ?? context.colors.ink;
    return TweenAnimationBuilder<double>(
      tween: Tween(end: visible ? 1 : 0),
      duration: context.motion(MotionTokens.circle),
      builder: (context, progress, child) => CustomPaint(
        painter: _Behind((canvas, size) {
          if (progress <= 0) return;
          canvas.drawPath(
            handCirclePath(size, progress, seed),
            Paint()
              ..color = c
              ..style = PaintingStyle.stroke
              ..strokeWidth = width
              ..strokeCap = StrokeCap.round,
          );
        }, (c, progress, seed)),
        child: child,
      ),
      child: child,
    );
  }
}

/// A sketchy hairline divider.
class HandDivider extends StatelessWidget {
  const HandDivider({super.key, this.seed = 1});
  final int seed;

  @override
  Widget build(BuildContext context) {
    final c = context.colors.rule;
    return SizedBox(
      height: 6,
      width: double.infinity,
      child: CustomPaint(
        painter: _Behind(
          (canvas, size) =>
              drawHandLine(canvas, Offset(0, size.height / 2), Offset(size.width, size.height / 2 + 1), c, StrokeTokens.hairline, seed),
          (c, seed),
        ),
      ),
    );
  }
}

/// A hand-drawn progress line. [fraction] null means "working, size unknown".
class HandProgress extends StatefulWidget {
  const HandProgress({super.key, required this.fraction});
  final double? fraction;

  @override
  State<HandProgress> createState() => _HandProgressState();
}

class _HandProgressState extends State<HandProgress> with SingleTickerProviderStateMixin {
  late final _spin = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(HandProgress oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  void _sync() {
    final reduce = MediaQuery.maybeDisableAnimationsOf(context) == true;
    if (widget.fraction == null && !reduce) {
      if (!_spin.isAnimating) _spin.repeat();
    } else {
      _spin.stop();
    }
  }

  @override
  void dispose() {
    _spin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    Widget paint(double from, double to) => CustomPaint(
      size: const Size(double.infinity, 10),
      painter: _Behind((canvas, size) {
        final y = size.height / 2;
        drawHandLine(canvas, Offset(0, y), Offset(size.width, y), c.rule, StrokeTokens.progressTrack, 9);
        if (to > from) {
          drawHandLine(canvas, Offset(size.width * from, y), Offset(size.width * to, y), c.ink, StrokeTokens.progressInk, 9);
        }
      }, (c.ink, from, to)),
    );
    final f = widget.fraction;
    return Semantics(
      value: f == null ? null : '${(f * 100).round()}%',
      child: f == null
          ? AnimatedBuilder(
              animation: _spin,
              builder: (_, _) {
                final t = _spin.value;
                return paint(math.max(0, t * 1.3 - 0.3), math.min(1, t * 1.3));
              },
            )
          : TweenAnimationBuilder<double>(
              tween: Tween(end: f.clamp(0, 1)),
              duration: context.motion(MotionTokens.progress),
              builder: (_, v, _) => paint(0, v),
            ),
    );
  }
}

/// Text with the marker swipe behind the first case-insensitive match of
/// [mark]. The swipe follows the words across line wraps.
class MarkedText extends StatelessWidget {
  const MarkedText(this.text, {super.key, this.mark, this.style, this.color, this.textAlign = TextAlign.start, this.maxLines});

  final String text;
  final String? mark;
  final TextStyle? style;
  final Color? color;
  final TextAlign textAlign;
  final int? maxLines;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final base = (style ?? context.type.title).copyWith(color: color ?? style?.color ?? c.ink);
    final at = mark == null || mark!.isEmpty ? -1 : text.toLowerCase().indexOf(mark!.toLowerCase());
    final span = at < 0
        ? TextSpan(text: text, style: base)
        : TextSpan(
            style: base,
            children: [
              TextSpan(text: text.substring(0, at)),
              TextSpan(
                text: text.substring(at, at + mark!.length),
                style: TextStyle(color: c.markerInk),
              ),
              TextSpan(text: text.substring(at + mark!.length)),
            ],
          );
    final textScaler = MediaQuery.textScalerOf(context);
    final rendered = Text.rich(span, textAlign: textAlign, maxLines: maxLines, overflow: maxLines == null ? null : TextOverflow.ellipsis);
    if (at < 0) return rendered;
    return LayoutBuilder(
      builder: (context, box) {
        // Lay the text out the same way the Text below will, to find where the
        // marked words fall on each line.
        final tp = TextPainter(
          text: span,
          textAlign: textAlign,
          textDirection: Directionality.of(context),
          textScaler: textScaler,
          maxLines: maxLines,
          ellipsis: maxLines == null ? null : '\u2026',
        )..layout(maxWidth: box.maxWidth.isFinite ? box.maxWidth : double.infinity);
        final boxes = tp.getBoxesForSelection(TextSelection(baseOffset: at, extentOffset: at + mark!.length));
        tp.dispose();
        return CustomPaint(painter: _MarkedPainter(boxes, c.marker), child: rendered);
      },
    );
  }
}

class _MarkedPainter extends CustomPainter {
  _MarkedPainter(this.boxes, this.color);
  final List<TextBox> boxes;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    for (var line = 0; line < boxes.length; line++) {
      canvas.drawPath(swipePath(boxes[line].toRect(), line + 11), Paint()..color = color);
    }
  }

  @override
  bool shouldRepaint(_MarkedPainter old) => old.color != color || old.boxes.length != boxes.length || !_same(old.boxes, boxes);

  static bool _same(List<TextBox> a, List<TextBox> b) {
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
