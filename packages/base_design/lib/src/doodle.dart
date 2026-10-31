import 'package:flutter/widgets.dart';

import 'generated/doodles.g.dart';
import 'theme.dart';

final _cache = <Doodle, Path>{};

/// The path for [doodle] on its 24x24 grid.
Path doodlePath(Doodle doodle) => _cache.putIfAbsent(doodle, () => parseSvgPath(doodle.d));

/// A small SVG path parser for the commands the doodles use
/// (M L H V C Q Z, absolute or relative).
Path parseSvgPath(String d) {
  final path = Path();
  final tokens = RegExp(r'[MmLlHhVvCcQqZz]|-?\d*\.?\d+(?:e-?\d+)?').allMatches(d).map((m) => m[0]!).toList();
  var i = 0;
  var cmd = 'M';
  var x = 0.0, y = 0.0, sx = 0.0, sy = 0.0;
  bool isCmd(String t) => RegExp(r'^[A-Za-z]$').hasMatch(t);
  double n() => double.parse(tokens[i++]);
  while (i < tokens.length) {
    if (isCmd(tokens[i])) cmd = tokens[i++];
    final rel = cmd == cmd.toLowerCase();
    final ox = rel ? x : 0.0, oy = rel ? y : 0.0;
    switch (cmd.toUpperCase()) {
      case 'M':
        x = ox + n();
        y = oy + n();
        path.moveTo(x, y);
        sx = x;
        sy = y;
        cmd = rel ? 'l' : 'L'; // Further pairs after M are line-tos.
      case 'L':
        x = ox + n();
        y = oy + n();
        path.lineTo(x, y);
      case 'H':
        x = ox + n();
        path.lineTo(x, y);
      case 'V':
        y = oy + n();
        path.lineTo(x, y);
      case 'C':
        final x1 = ox + n(), y1 = oy + n(), x2 = ox + n(), y2 = oy + n();
        x = ox + n();
        y = oy + n();
        path.cubicTo(x1, y1, x2, y2, x, y);
      case 'Q':
        final x1 = ox + n(), y1 = oy + n();
        x = ox + n();
        y = oy + n();
        path.quadraticBezierTo(x1, y1, x, y);
      case 'Z':
        path.close();
        x = sx;
        y = sy;
      default:
        throw FormatException('Unsupported path command $cmd in $d');
    }
  }
  return path;
}

/// A hand-drawn icon. Use these instead of Material icons.
class DoodleIcon extends StatelessWidget {
  const DoodleIcon(
    this.doodle, {
    super.key,
    this.size = 24,
    this.color,
    this.stroke = 2,
    this.fill = false,
    this.semanticLabel,
    this.tilt = 0,
  });

  final Doodle doodle;
  final double size;
  final Color? color;
  final double stroke;
  final bool fill;
  final String? semanticLabel;

  /// Rotation in degrees (page doodles sit at about -8).
  final double tilt;

  @override
  Widget build(BuildContext context) {
    final c = color ?? context.colors.ink;
    Widget icon = CustomPaint(size: Size.square(size), painter: _DoodlePainter(doodle, c, stroke, fill));
    if (tilt != 0) icon = Transform.rotate(angle: tilt * 3.141592653589793 / 180, child: icon);
    return Semantics(label: semanticLabel, excludeSemantics: semanticLabel == null, child: icon);
  }
}

class _DoodlePainter extends CustomPainter {
  _DoodlePainter(this.doodle, this.color, this.stroke, this.fill);
  final Doodle doodle;
  final Color color;
  final double stroke;
  final bool fill;

  @override
  void paint(Canvas canvas, Size size) {
    final k = size.shortestSide / 24;
    final w = stroke / k;
    canvas.save();
    canvas.scale(k);
    final path = doodlePath(doodle);
    if (fill) canvas.drawPath(path, Paint()..color = color);
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = w
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
    for (final (dx, dy) in doodle.dots) {
      canvas.drawCircle(Offset(dx, dy), w * 0.75, Paint()..color = color);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_DoodlePainter old) => old.doodle != doodle || old.color != color || old.stroke != stroke || old.fill != fill;
}
