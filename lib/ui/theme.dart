import 'package:flutter/material.dart';

/// Industrial sprite palette shared with the canvas renderer.
class Pal {
  static const plate = Color(0xFFEDEDF0);
  static const light = Color(0xFFDEDEE7);
  static const ink = Color(0xFF292932);
  static const steel = Color(0xFF35353D);
  static const mid = Color(0xFF53535E);
  static const grey = Color(0xFF8E8E9C);
  static const dark = Color(0xFF1F1F26);
  static const hazard = Color(0xFFE3C15A);
  static const hazardDeep = Color(0xFFC9A24A);
  static const red = Color(0xFFB94B4C);
  static const green = Color(0xFF367064);
  static const blue = Color(0xFF4C6A8C);
  static const shell = Color(0xFF15151C);
  static const stage = Color(0xFFB0B0BF);
}

ThemeData buildTheme() => ThemeData(
  useMaterial3: true,
  brightness: Brightness.dark,
  scaffoldBackgroundColor: Pal.shell,
  fontFamily: 'DotGothic16',
  colorScheme: const ColorScheme.dark(primary: Pal.hazard, surface: Pal.shell),
  textTheme: const TextTheme(
    bodyMedium: TextStyle(color: Pal.plate, fontSize: 11),
  ),
);

TextStyle mono(
  double size, {
  Color color = Pal.ink,
  FontWeight weight = FontWeight.normal,
  double spacing = 0,
  double height = 1.2,
}) => TextStyle(
  fontFamily: 'DotGothic16',
  fontSize: size,
  color: color,
  fontWeight: weight,
  letterSpacing: spacing,
  height: height,
);

/// Paints the hazard stripe rail used on panel headers and tip boxes.
class HazardStripes extends StatelessWidget {
  final double height;
  final double period;
  final double? width;
  const HazardStripes({
    super.key,
    this.height = 8,
    this.period = 16,
    this.width,
  });
  @override
  Widget build(BuildContext context) => SizedBox(
    height: width == null ? height : double.infinity,
    width: width ?? double.infinity,
    child: CustomPaint(painter: _StripePainter(period)),
  );
}

class _StripePainter extends CustomPainter {
  final double period;
  const _StripePainter(this.period);
  @override
  void paint(Canvas canvas, Size size) {
    canvas.clipRect(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, Paint()..color = Pal.steel);
    final p = Paint()..color = Pal.hazard;
    for (var x = -size.height; x < size.width + period; x += period) {
      final path = Path()
        ..moveTo(x, size.height)
        ..lineTo(x + size.height, 0)
        ..lineTo(x + size.height + period / 2, 0)
        ..lineTo(x + period / 2, size.height)
        ..close();
      canvas.drawPath(path, p);
    }
  }

  @override
  bool shouldRepaint(covariant _StripePainter old) => old.period != period;
}

/// Steel plate: light face, hard dark border, offset pixel shadow, hazard rail
/// on top and four corner rivets.
class SteelPanel extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  const SteelPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(14, 18, 14, 14),
  });
  @override
  Widget build(BuildContext context) => Container(
    decoration: const BoxDecoration(
      color: Pal.plate,
      border: Border.fromBorderSide(BorderSide(color: Pal.steel, width: 2)),
      boxShadow: [BoxShadow(color: Pal.steel, offset: Offset(4, 4))],
    ),
    child: Stack(
      children: [
        const Positioned(left: 0, right: 0, top: 0, child: HazardStripes()),
        for (final a in const [
          Alignment.topLeft,
          Alignment.topRight,
          Alignment.bottomLeft,
          Alignment.bottomRight,
        ])
          Positioned.fill(
            child: Align(
              alignment: a,
              child: Padding(
                padding: EdgeInsets.only(
                  top: a.y < 0 ? 12 : 5,
                  bottom: a.y > 0 ? 5 : 0,
                  left: 5,
                  right: 5,
                ),
                child: Container(
                  width: 3,
                  height: 3,
                  decoration: const BoxDecoration(
                    color: Pal.grey,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
          ),
        Padding(padding: padding, child: child),
      ],
    ),
  );
}

enum SteelKind { normal, primary, ghost }

/// 8×8 pixel glyphs drawn in the sprite palette, so buttons never fall back to
/// platform emoji for arrows.
class PixelGlyphs {
  static const retry = [
    '..####.#',
    '.#....##',
    '#....###',
    '#.......',
    '#.......',
    '#......#',
    '.#....#.',
    '..####..',
  ];
  static const home = [
    '...##...',
    '..####..',
    '.######.',
    '########',
    '.######.',
    '.##..##.',
    '.##..##.',
    '.######.',
  ];
  static const hold = [
    '..####..',
    '.######.',
    '.######.',
    '..####..',
    '........',
    '########',
    '........',
    '########',
  ];
  static const tap = [
    '..####..',
    '.######.',
    '.######.',
    '..####..',
    '........',
    '.#....#.',
    '#......#',
    '........',
  ];
  static const up = [
    '...##...',
    '..####..',
    '.######.',
    '##.##.##',
    '...##...',
    '...##...',
    '...##...',
    '...##...',
  ];
  static const down = [
    '...##...',
    '...##...',
    '...##...',
    '...##...',
    '##.##.##',
    '.######.',
    '..####..',
    '...##...',
  ];
  static const launch = [
    '..######',
    '....####',
    '...#.###',
    '..#...##',
    '.#.....#',
    '#.......',
    '........',
    '........',
  ];
}

class PixelIcon extends StatelessWidget {
  final List<String> rows;
  final double size;
  final Color color;
  const PixelIcon(this.rows, {super.key, this.size = 14, this.color = Pal.ink});
  @override
  Widget build(BuildContext context) =>
      CustomPaint(size: Size(size, size), painter: _PixelPainter(rows, color));
}

class _PixelPainter extends CustomPainter {
  final List<String> rows;
  final Color color;
  const _PixelPainter(this.rows, this.color);
  @override
  void paint(Canvas canvas, Size size) {
    final cell = size.width / rows.length;
    final p = Paint()..color = color;
    for (var y = 0; y < rows.length; y++) {
      for (var x = 0; x < rows[y].length; x++) {
        if (rows[y][x] != '#') continue;
        canvas.drawRect(
          Rect.fromLTWH(x * cell, y * cell, cell + 0.2, cell + 0.2),
          p,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _PixelPainter old) =>
      old.rows != rows || old.color != color;
}

class SteelButton extends StatefulWidget {
  final String label;
  final VoidCallback? onTap;
  final SteelKind kind;
  final double fontSize;
  final EdgeInsets padding;
  final bool pressed;
  final List<String>? icon;
  const SteelButton(
    this.label, {
    super.key,
    this.onTap,
    this.kind = SteelKind.normal,
    this.fontSize = 13,
    this.padding = const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
    this.pressed = false,
    this.icon,
  });
  @override
  State<SteelButton> createState() => _SteelButtonState();
}

class _SteelButtonState extends State<SteelButton> {
  bool _down = false;
  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    final primary = widget.kind == SteelKind.primary,
        ghost = widget.kind == SteelKind.ghost;
    final bg = ghost
        ? Colors.transparent
        : primary
        ? Pal.hazard
        : widget.pressed
        ? Pal.mid
        : Pal.steel;
    final fg = ghost
        ? Pal.mid
        : primary
        ? Pal.ink
        : Pal.plate;
    final shadow = ghost
        ? null
        : primary
        ? Pal.steel
        : Pal.dark;
    final offset = _down ? 2.0 : 0.0;
    return Semantics(
      button: true,
      enabled: enabled,
      label: widget.label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: enabled ? (_) => setState(() => _down = true) : null,
        onTapUp: enabled ? (_) => setState(() => _down = false) : null,
        onTapCancel: enabled ? () => setState(() => _down = false) : null,
        onTap: widget.onTap,
        child: Opacity(
          opacity: enabled ? 1 : 0.45,
          child: Transform.translate(
            offset: Offset(offset, offset),
            child: Container(
              padding: widget.padding,
              decoration: BoxDecoration(
                color: bg,
                border: ghost
                    ? Border.all(color: Pal.grey, width: 1)
                    : Border.all(color: Pal.steel, width: 2),
                boxShadow: shadow == null
                    ? null
                    : [
                        BoxShadow(
                          color: shadow,
                          offset: Offset(3 - offset, 3 - offset),
                        ),
                      ],
              ),
              child: Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      widget.label,
                      style: mono(
                        widget.fontSize,
                        color: fg,
                        weight: primary ? FontWeight.bold : FontWeight.normal,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    if (widget.icon != null) ...[
                      const SizedBox(width: 8),
                      PixelIcon(
                        widget.icon!,
                        size: widget.fontSize + 1,
                        color: fg,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Small plate tile for a label + value pair.
class StatTile extends StatelessWidget {
  final String label, value;
  final double valueSize;
  const StatTile(this.label, this.value, {super.key, this.valueSize = 12});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 3),
    decoration: const BoxDecoration(
      color: Pal.light,
      border: Border.fromBorderSide(BorderSide(color: Pal.steel, width: 2)),
      boxShadow: [BoxShadow(color: Pal.grey, offset: Offset(2, 2))],
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: mono(7, color: Pal.mid, spacing: 1),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 3),
        Text(
          value,
          style: mono(valueSize, color: Pal.ink),
          textAlign: TextAlign.center,
        ),
      ],
    ),
  );
}

class Eyebrow extends StatelessWidget {
  final String text;
  final Color color;
  const Eyebrow(this.text, {super.key, this.color = Pal.mid});
  @override
  Widget build(BuildContext context) => Text(
    text,
    style: mono(10, color: color, spacing: 2),
    textAlign: TextAlign.center,
  );
}
