import 'dart:async';

import 'package:flutter/material.dart';

import '../game/controller.dart';
import '../game/types.dart';
import 'records.dart';
import 'theme.dart';

const instructions = [
  (
    '01 / SWING',
    'Hold a finger on the screen (or hold PUMP) to swing harder, at the cost of rope wear. Rope positions and lengths are random; moving anchors slide sideways and frayed ropes wear faster. Wall saws are lethal; fans warn before they blow.',
  ),
  (
    '02 / REACH',
    'Tap anywhere (or press JUMP) to fly off along your current tangent and auto-grab the next rope you touch. The JUMP button and the target ring turn green when a release would reach a higher rope; tap a little early and the jump waits for that moment. Swipe up to release immediately without the assist. Swipe down or press LOWER to lengthen the rope and adjust your swing and landing. Faint dots predict the swing, bright dots predict the release path. SHIELD crates block one saw hit; SLOW crates brake the platform for five seconds.',
  ),
  (
    '03 / ESCAPE',
    'Once you start, the death platform below keeps rising and speeds up over time; the further you climb, the faster it chases. Touching it ends the run. Ropes keep generating upward, so there is no top floor.',
  ),
];

class MenuPanel extends StatelessWidget {
  final GameView view;
  final Records records;
  final VoidCallback onStart, onHelp;
  final EdgeInsets inset;
  const MenuPanel({
    super.key,
    required this.view,
    required this.records,
    required this.onStart,
    required this.onHelp,
    this.inset = EdgeInsets.zero,
  });
  @override
  Widget build(BuildContext context) => Container(
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0x771B1B26), Color(0x00000000), Color(0xDD1B1B26)],
        stops: [0, 0.55, 1],
      ),
    ),
    padding: EdgeInsets.fromLTRB(28, 56 + inset.top, 28, 28 + inset.bottom),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'STAY ABOVE THE LINE',
          style: mono(10, color: const Color(0xFFAAB9A3), spacing: 2),
        ),
        const SizedBox(height: 12),
        Text(
          'ROPE ESCAPE',
          style: mono(39, color: Pal.plate, spacing: 4, weight: FontWeight.bold)
              .copyWith(
                shadows: const [Shadow(color: Pal.dark, offset: Offset(2, 2))],
              ),
        ),
        const SizedBox(height: 10),
        Text(
          'The line beneath you is rising.',
          style: mono(12, color: const Color(0xFFC0CAB0)),
        ),
        const Spacer(),
        SteelButton(
          view.assetError != null
              ? 'Asset load failed'
              : view.assetsLoaded
              ? 'START CLIMB'
              : 'Loading scene…',
          kind: SteelKind.primary,
          fontSize: 15,
          icon: view.assetsLoaded && view.assetError == null
              ? PixelGlyphs.launch
              : null,
          onTap: view.assetsLoaded ? onStart : null,
        ),
        const SizedBox(height: 10),
        SteelButton('HOW TO PLAY  +', onTap: onHelp),
        const SizedBox(height: 12),
        Center(
          child: Text(
            'BEST ${records.best} m · MAX COMBO ×${records.bestCombo} · ${records.runs} RUNS',
            style: mono(10, color: const Color(0xFF9EAE99)),
          ),
        ),
      ],
    ),
  );
}

class Hud extends StatelessWidget {
  final GameView view;
  final bool sound;
  final VoidCallback onPause, onSound;
  final EdgeInsets inset;
  const Hud({
    super.key,
    required this.view,
    required this.sound,
    required this.onPause,
    required this.onSound,
    this.inset = EdgeInsets.zero,
  });
  @override
  Widget build(BuildContext context) {
    final danger = view.wear < 25;
    return Padding(
      padding: EdgeInsets.only(top: inset.top),
      child: Stack(
        children: [
          Positioned(
            left: 8,
            top: 8,
            child: GestureDetector(
              onTap: onSound,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xDD35353D),
                  border: Border.all(color: const Color(0xFF858592)),
                ),
                child: Text(
                  sound ? 'SOUND ON' : 'SOUND OFF',
                  style: mono(10, color: Pal.plate),
                ),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            top: 18,
            child: Column(
              children: [
                Text('HEIGHT', style: mono(8, color: Pal.steel, spacing: 1)),
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: '${view.score}',
                        style: mono(
                          31,
                          color: const Color(0xFFF0F0DA),
                          weight: FontWeight.bold,
                        ),
                      ),
                      TextSpan(
                        text: ' m',
                        style: mono(11, color: Pal.steel),
                      ),
                    ],
                  ),
                  style: const TextStyle(
                    shadows: [
                      Shadow(color: Colors.black, offset: Offset(0, 2)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            right: 10,
            top: 10,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onPause,
              // Padding widens the hit target well beyond the drawn circle.
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Container(
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: const Color(0xE635353D),
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFF777786)),
                  ),
                  child: Text('Ⅱ', style: mono(16, color: Colors.white)),
                ),
              ),
            ),
          ),
          Positioned(
            left: 22,
            right: 22,
            top: 86,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'ROPE ${view.wear}%',
                  style: mono(8, color: danger ? Pal.red : Pal.ink),
                ),
                Text('FLOOR ${view.gap} m', style: mono(8, color: Pal.ink)),
              ],
            ),
          ),
          Positioned(
            left: 22,
            right: 22,
            top: 100,
            child: Container(
              height: 2,
              color: const Color(0x3335353D),
              alignment: Alignment.centerLeft,
              child: FractionallySizedBox(
                widthFactor: (view.wear / 100).clamp(0.0, 1.0),
                child: Container(
                  color: danger ? const Color(0xFFD78258) : Pal.mid,
                ),
              ),
            ),
          ),
          Positioned(
            left: 22,
            right: 22,
            top: 112,
            child: Text(
              view.notice,
              textAlign: TextAlign.center,
              style: mono(8, color: Pal.ink),
            ),
          ),
          Positioned(
            left: 18,
            right: 18,
            top: 128,
            child: Wrap(
              alignment: WrapAlignment.center,
              spacing: 6,
              children: [
                if (view.combo > 1)
                  _pill(
                    '×${view.combo} COMBO',
                    view.combo >= 5 ? Pal.hazard : const Color(0xFFC9E8CF),
                    hot: view.combo >= 5,
                  ),
                if (view.shield) _pill('⬡ SHIELD', const Color(0xFF5FB7A0)),
                if (view.brake > 0)
                  _pill('◷ SLOW ${view.brake.toStringAsFixed(1)}s', Pal.hazard),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _pill(String text, Color color, {bool hot = false}) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
    decoration: BoxDecoration(
      color: hot ? const Color(0xEE3A2F12) : const Color(0xE61F1F26),
      border: Border.all(color: color),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Text(text, style: mono(9, color: color, spacing: 1)),
  );
}

/// Thumb buttons: LOWER, hold-to-PUMP and a large JUMP that lights up while a
/// release would catch a higher rope.
class Controls extends StatefulWidget {
  final void Function(RopeAction) onAction;
  final VoidCallback onJump;
  final bool jumpReady, jumpQueued;
  const Controls({
    super.key,
    required this.onAction,
    required this.onJump,
    this.jumpReady = false,
    this.jumpQueued = false,
  });
  @override
  State<Controls> createState() => _ControlsState();
}

class _ControlsState extends State<Controls> {
  Timer? _pump;

  void _startPump() {
    widget.onAction(RopeAction.pump);
    _pump?.cancel();
    _pump = Timer.periodic(
      const Duration(milliseconds: 320),
      (_) => widget.onAction(RopeAction.pump),
    );
  }

  void _stopPump() {
    _pump?.cancel();
    _pump = null;
  }

  @override
  void dispose() {
    _stopPump();
    super.dispose();
  }

  Widget _button({
    required String label,
    String? sub,
    required Color fill,
    required Color ink,
    required Color edge,
    double fontSize = 12,
    bool bold = false,
    List<BoxShadow>? glow,
  }) => Container(
    height: 46,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: fill,
      borderRadius: BorderRadius.circular(23),
      border: Border.all(color: edge, width: 1.5),
      boxShadow: glow,
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: mono(
            fontSize,
            color: ink,
            weight: bold ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        if (sub != null)
          Text(sub, style: mono(7, color: ink.withValues(alpha: 0.8))),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final ready = widget.jumpReady, queued = widget.jumpQueued;
    return Row(
      children: [
        Expanded(
          flex: 5,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (_) => widget.onAction(RopeAction.lower),
            child: _button(
              label: 'LOWER ↓',
              fill: const Color(0xF035353D),
              ink: Pal.plate,
              edge: const Color(0xFF888896),
            ),
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          flex: 6,
          child: Listener(
            behavior: HitTestBehavior.opaque,
            onPointerDown: (_) => _startPump(),
            onPointerUp: (_) => _stopPump(),
            onPointerCancel: (_) => _stopPump(),
            child: _button(
              label: 'PUMP',
              sub: 'HOLD',
              fill: const Color(0xF035353D),
              ink: Pal.plate,
              edge: const Color(0xFF888896),
            ),
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          flex: 8,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (_) => widget.onJump(),
            child: _button(
              label: 'JUMP ↑',
              sub: ready
                  ? 'NOW'
                  : queued
                  ? 'WAITING…'
                  : null,
              fill: ready ? const Color(0xFFCCE493) : Pal.plate,
              ink: Pal.ink,
              edge: ready ? const Color(0xFF29665C) : const Color(0xFF888896),
              fontSize: 14,
              bold: true,
              glow: ready
                  ? const [
                      BoxShadow(
                        color: Color(0x9929665C),
                        blurRadius: 14,
                        spreadRadius: 2,
                      ),
                    ]
                  : null,
            ),
          ),
        ),
      ],
    );
  }
}

class CountdownOverlay extends StatelessWidget {
  final double countdown;
  const CountdownOverlay({super.key, required this.countdown});
  @override
  Widget build(BuildContext context) {
    final step = (countdown / (resumeCountdown / 3)).ceil();
    return IgnorePointer(
      child: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0, -0.1),
            radius: 0.9,
            colors: [Color(0xCC1B1B26), Color(0x661B1B26), Color(0x221B1B26)],
            stops: [0, 0.5, 1],
          ),
        ),
        alignment: Alignment.center,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TweenAnimationBuilder<double>(
              key: ValueKey(step),
              tween: Tween(begin: 1.5, end: 1),
              duration: const Duration(milliseconds: 450),
              curve: Curves.easeOutBack,
              builder: (_, v, child) => Transform.scale(scale: v, child: child),
              child: Text(
                '$step',
                style: mono(96, color: Colors.white, weight: FontWeight.bold)
                    .copyWith(
                      shadows: const [
                        Shadow(color: Pal.dark, offset: Offset(0, 3)),
                        Shadow(color: Colors.black, blurRadius: 28),
                      ],
                    ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'GET READY',
              style: mono(10, color: Pal.plate, spacing: 3).copyWith(
                shadows: const [Shadow(color: Pal.dark, offset: Offset(0, 1))],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class HelpPanel extends StatelessWidget {
  final bool paused;
  final VoidCallback onStart, onClose;
  const HelpPanel({
    super.key,
    required this.paused,
    required this.onStart,
    required this.onClose,
  });
  @override
  Widget build(BuildContext context) => SteelPanel(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Eyebrow('FIELD MANUAL'),
        const SizedBox(height: 6),
        Text(
          'Before you climb.',
          textAlign: TextAlign.center,
          style: mono(24, weight: FontWeight.bold).copyWith(
            shadows: const [Shadow(color: Pal.stage, offset: Offset(2, 2))],
          ),
        ),
        const SizedBox(height: 8),
        for (final (n, t) in instructions) ...[
          Text(n, style: mono(9, color: const Color(0xFF7A5A14), spacing: 1)),
          const SizedBox(height: 4),
          Text(t, style: mono(11, color: Pal.steel, height: 1.8)),
          const SizedBox(height: 10),
        ],
        SteelButton(
          paused ? 'Back to pause' : 'I am ready',
          kind: SteelKind.primary,
          onTap: paused ? onClose : onStart,
        ),
        const SizedBox(height: 8),
        SteelButton('Close guide', onTap: onClose),
      ],
    ),
  );
}

class PausePanel extends StatelessWidget {
  final GameView view;
  final bool sound;
  final VoidCallback onResume, onRestart, onHelp, onMenu, onSound;
  const PausePanel({
    super.key,
    required this.view,
    required this.sound,
    required this.onResume,
    required this.onRestart,
    required this.onHelp,
    required this.onMenu,
    required this.onSound,
  });
  @override
  Widget build(BuildContext context) => SteelPanel(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Eyebrow('TAKE A BREATH'),
        const SizedBox(height: 6),
        Text(
          'Take a breath.',
          textAlign: TextAlign.center,
          style: mono(24, weight: FontWeight.bold).copyWith(
            shadows: const [Shadow(color: Pal.stage, offset: Offset(2, 2))],
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: StatTile('HEIGHT', '${view.score} m', valueSize: 13),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: StatTile('TIME', fmtTime(view.time), valueSize: 13),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: StatTile(
                'COMBO',
                '×${view.stats.maxCombo}',
                valueSize: 13,
              ),
            ),
            const SizedBox(width: 6),
            Expanded(child: StatTile('FLOOR', '${view.gap} m', valueSize: 13)),
          ],
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: Pal.light,
            border: Border.all(color: Pal.grey, width: 2),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _key('TAP', 'Jump', 'waits for the green ring'),
              _key('HOLD', 'Pump', 'swing harder, wears the rope'),
              _key('SWIPE DOWN', 'Lower', 'adjust the landing'),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: SteelButton(
                sound ? '♪ SOUND ON' : '♪ SOUND OFF',
                fontSize: 10,
                pressed: sound,
                onTap: onSound,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SteelButton(
          'RESUME',
          kind: SteelKind.primary,
          fontSize: 15,
          onTap: onResume,
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: SteelButton('Restart', fontSize: 11, onTap: onRestart),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: SteelButton('How to play', fontSize: 11, onTap: onHelp),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SteelButton(
          'Main menu',
          kind: SteelKind.ghost,
          fontSize: 10,
          padding: const EdgeInsets.symmetric(vertical: 8),
          onTap: onMenu,
        ),
      ],
    ),
  );

  Widget _key(String k, String name, String hint) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
          decoration: BoxDecoration(
            color: Pal.steel,
            border: Border.all(color: Pal.dark),
            borderRadius: BorderRadius.circular(3),
          ),
          child: Text(k, style: mono(9, color: Pal.plate)),
        ),
        const SizedBox(width: 6),
        Text(name, style: mono(10, color: Pal.steel)),
        const SizedBox(width: 6),
        Text(hint, style: mono(9, color: const Color(0xFF777786))),
      ],
    ),
  );
}

class ResultPanel extends StatelessWidget {
  final GameView view;
  final bool isRecord;
  final VoidCallback onAgain, onMenu;
  const ResultPanel({
    super.key,
    required this.view,
    required this.isRecord,
    required this.onAgain,
    required this.onMenu,
  });

  @override
  Widget build(BuildContext context) => SteelPanel(
    padding: const EdgeInsets.fromLTRB(16, 22, 16, 16),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (isRecord)
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                color: Pal.steel,
                border: Border.all(color: Pal.hazard),
              ),
              child: Text(
                '★ NEW RECORD ★',
                style: mono(10, color: Pal.hazard, spacing: 2),
              ),
            ),
          )
        else
          const Eyebrow('RUN COMPLETE'),
        const SizedBox(height: 6),
        Text(
          isRecord ? 'New height record!' : 'So close. Climb higher.',
          textAlign: TextAlign.center,
          style: mono(24, weight: FontWeight.bold).copyWith(
            shadows: const [Shadow(color: Pal.stage, offset: Offset(2, 2))],
          ),
        ),
        const SizedBox(height: 14),
        Center(
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: view.score.toDouble()),
            duration: const Duration(milliseconds: 1100),
            curve: Curves.easeOutCubic,
            builder: (_, v, _) => Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: '${v.round()}',
                    style: mono(64, weight: FontWeight.bold, height: 1)
                        .copyWith(
                          shadows: const [
                            Shadow(color: Pal.stage, offset: Offset(3, 3)),
                          ],
                        ),
                  ),
                  TextSpan(
                    text: ' m',
                    style: mono(14, color: Pal.mid),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 22),
        SteelButton(
          'PLAY AGAIN',
          kind: SteelKind.primary,
          fontSize: 15,
          icon: PixelGlyphs.retry,
          onTap: onAgain,
        ),
        const SizedBox(height: 8),
        SteelButton(
          'Main menu',
          fontSize: 12,
          icon: PixelGlyphs.home,
          onTap: onMenu,
        ),
      ],
    ),
  );
}

/// On-screen gesture primer shown at the start of a run until the first action.
class StartHint extends StatelessWidget {
  final bool visible;
  const StartHint({super.key, required this.visible});
  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: AnimatedOpacity(
      opacity: visible ? 1 : 0,
      duration: const Duration(milliseconds: 350),
      child: Align(
        // Sits between the HUD and the hanging climber so neither is covered.
        alignment: const Alignment(0, -0.38),
        child: Container(
          width: 236,
          decoration: const BoxDecoration(
            color: Color(0xE61F1F26),
            border: Border.fromBorderSide(
              BorderSide(color: Pal.plate, width: 2),
            ),
            boxShadow: [
              BoxShadow(color: Color(0x80000000), offset: Offset(3, 3)),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const HazardStripes(height: 6, period: 12),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'HOW TO CLIMB',
                      textAlign: TextAlign.center,
                      style: mono(9, color: Pal.hazard, spacing: 2),
                    ),
                    const SizedBox(height: 8),
                    _row(
                      PixelGlyphs.hold,
                      'Hold',
                      'PUMP',
                      'swing harder, wears the rope',
                    ),
                    _row(
                      PixelGlyphs.tap,
                      'Tap',
                      'JUMP',
                      'fly off when the ring is green',
                    ),
                    _row(
                      PixelGlyphs.down,
                      'Swipe down',
                      'LOWER',
                      'lengthen the rope, adjust landing',
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Hold to pump and start · the floor waits for you',
                      textAlign: TextAlign.center,
                      style: mono(8, color: Pal.grey, spacing: 1),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  Widget _row(List<String> glyph, String gesture, String name, String hint) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Container(
              width: 26,
              height: 26,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Pal.steel,
                border: Border.all(color: Pal.grey),
              ),
              child: PixelIcon(glyph, size: 16, color: Pal.plate),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: gesture,
                          style: mono(11, color: Pal.plate),
                        ),
                        TextSpan(
                          text: '  →  ',
                          style: mono(9, color: Pal.grey),
                        ),
                        TextSpan(
                          text: name,
                          style: mono(
                            11,
                            color: Pal.hazard,
                            weight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(hint, style: mono(8, color: Pal.grey)),
                ],
              ),
            ),
          ],
        ),
      );
}
