import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

import 'sprites.dart';

const paper = Color(0xFFEEEED6);

/// Thin canvas helper with pixel-art primitives: integer-aligned
/// rectangles, half-pixel lines and monospace labels.
class Draw {
  final Canvas c;
  final Sprites sprites;
  final Paint _fill = Paint()..style = PaintingStyle.fill;
  final Paint _stroke = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;
  final Paint _image = Paint()..filterQuality = FilterQuality.none;
  double alpha = 1;

  /// Visible stage height in logical pixels; the classic 640 band is centred
  /// inside it, so taller phones reveal more world above and below.
  final double h;
  double get m => (h - 640) / 2;
  Draw(this.c, this.sprites, {this.h = 640});

  Color _a(Color color) =>
      alpha >= 1 ? color : color.withValues(alpha: color.a * alpha);

  void rect(double x, double y, double w, double h, Color color) {
    _fill.color = _a(color);
    c.drawRect(
      Rect.fromLTWH(
        x.roundToDouble(),
        y.roundToDouble(),
        w.roundToDouble(),
        h.roundToDouble(),
      ),
      _fill,
    );
  }

  void rectF(double x, double y, double w, double h, Color color) {
    _fill.color = _a(color);
    c.drawRect(Rect.fromLTWH(x, y, w, h), _fill);
  }

  void line(
    List<List<double>> pts,
    Color color, [
    double width = 1,
    bool snap = true,
  ]) {
    _stroke
      ..color = _a(color)
      ..strokeWidth = width;
    final path = Path();
    for (var i = 0; i < pts.length; i++) {
      final x = snap ? pts[i][0].roundToDouble() + 0.5 : pts[i][0];
      final y = snap ? pts[i][1].roundToDouble() + 0.5 : pts[i][1];
      i == 0 ? path.moveTo(x, y) : path.lineTo(x, y);
    }
    c.drawPath(path, _stroke);
  }

  void poly(List<List<double>> pts, Color color) {
    _fill.color = _a(color);
    final path = Path();
    for (var i = 0; i < pts.length; i++) {
      i == 0
          ? path.moveTo(pts[i][0], pts[i][1])
          : path.lineTo(pts[i][0], pts[i][1]);
    }
    path.close();
    c.drawPath(path, _fill);
  }

  void circle(double x, double y, double r, Color color, {double? stroke}) {
    if (stroke != null) {
      _stroke
        ..color = _a(color)
        ..strokeWidth = stroke;
      c.drawCircle(Offset(x, y), r, _stroke);
    } else {
      _fill.color = _a(color);
      c.drawCircle(Offset(x, y), r, _fill);
    }
  }

  void dashedCircle(
    double x,
    double y,
    double r,
    Color color,
    double on,
    double off,
    double width,
    double rot,
  ) {
    _stroke
      ..color = _a(color)
      ..strokeWidth = width;
    final circumference = 2 * 3.141592653589793 * r;
    var d = 0.0;
    while (d < circumference) {
      final a0 = d / r + rot, a1 = (d + on) / r + rot;
      c.drawArc(
        Rect.fromCircle(center: Offset(x, y), radius: r),
        a0,
        a1 - a0,
        false,
        _stroke,
      );
      d += on + off;
    }
  }

  void gradientRect(
    double x,
    double y,
    double w,
    double h,
    Color from,
    Color to, {
    bool vertical = true,
  }) {
    final p = Paint()
      ..shader = ui.Gradient.linear(
        Offset(x, y),
        vertical ? Offset(x, y + h) : Offset(x + w, y),
        [_a(from), _a(to)],
      );
    c.drawRect(Rect.fromLTWH(x, y, w, h), p);
  }

  void label(
    String text,
    double x,
    double y,
    Color color, {
    double size = 8,
    TextAlign align = TextAlign.center,
    Color? outline,
    double outlineWidth = 3,
    bool bold = true,
  }) {
    final style = TextStyle(
      fontFamily: 'DotGothic16',
      fontFamilyFallback: const ['Silkscreen', 'monospace'],
      fontSize: size,
      fontWeight: bold ? FontWeight.bold : FontWeight.normal,
      height: 1,
    );
    if (outline != null) {
      final tp = TextPainter(
        text: TextSpan(
          text: text,
          style: style.copyWith(
            foreground: Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = outlineWidth
              ..color = _a(outline),
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      _place(tp, x, y, align);
    }
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: style.copyWith(color: _a(color)),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    _place(tp, x, y, align);
  }

  void _place(TextPainter tp, double x, double y, TextAlign align) {
    final dx = align == TextAlign.center
        ? x - tp.width / 2
        : align == TextAlign.right
        ? x - tp.width
        : x;
    // Text baselines sit at y; approximate with the ascent.
    tp.paint(
      c,
      Offset(dx.roundToDouble(), (y - tp.height * 0.82).roundToDouble()),
    );
  }

  /// Draws a sprite frame; `w`/`h` select a frame cell within a horizontal sheet.
  void sprite(
    String name,
    double x,
    double y, {
    double scale = 1,
    int frame = 0,
    double? w,
    double? h,
    Color? tint,
  }) {
    final im = sprites[name];
    if (im == null) return;
    final fw = w ?? im.width.toDouble(), fh = h ?? im.height.toDouble();
    final paint = tint == null
        ? _image
        : (Paint()
            ..filterQuality = FilterQuality.none
            ..colorFilter = ColorFilter.mode(_a(tint), BlendMode.srcIn));
    if (alpha < 1 && tint == null) {
      paint.color = Color.fromRGBO(255, 255, 255, alpha);
    } else if (tint == null) {
      paint.color = const Color(0xFFFFFFFF);
    }
    c.drawImageRect(
      im,
      Rect.fromLTWH(frame * fw, 0, fw, fh),
      Rect.fromLTWH(
        x.roundToDouble(),
        y.roundToDouble(),
        (fw * scale).roundToDouble(),
        (fh * scale).roundToDouble(),
      ),
      paint,
    );
  }
}
