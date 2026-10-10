# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

Rope Escape: a Flutter (Dart 3.11, Flutter ≥ 3.41) iOS/Android game. Swing on soft Verlet ropes, jump between anchors and outrun a rising death platform. README.md is written in Traditional Chinese; code and comments are English.

## Commands

```sh
flutter pub get
flutter analyze                               # flutter_lints, must stay clean
flutter test                                  # 11 physics tests + 1 screenshot test
flutter test test/rope_core_test.dart         # physics only (fast, pure Dart)
flutter test --plain-name "milestones fire"   # single test by name substring
flutter run                                   # device or simulator
flutter build ios --simulator
flutter build ipa                             # needs signing set up in Xcode
flutter build appbundle
tool/store_capture.sh <udid> output/store/iphone-6.9 886x1920   # App Store shots + 30 s preview
```

`tool/store_capture.sh` boots a simulator, runs `integration_test/store_capture_test.dart` (an autoplay that uses `predictClimb` with a short lookahead, `_jumpWait`, to decide pump/lower/jump), screenshots each phase the test writes to its Documents dir, and trims the `simctl recordVideo` into an App Preview with ffmpeg. Use the iPhone 17 Pro Max (1320×2868) and iPad Pro 13-inch (2064×2752, preview 1200x1600) simulators for store sizes.

`test/screens_test.dart` drives the real widget tree with real sprites and fonts and writes PNGs to `output/screens/` (menu, play, pause, countdown, result, player-zoom). The README embeds copies from `docs/screens/`; after a visual change, re-run tests and copy the PNGs over.

## Architecture

Three layers with a strict dependency direction: `lib/game` (simulation, pure Dart apart from `controller.dart`) ← `lib/render` (CustomPainter) ← `lib/ui` (widgets). `lib/audio` is used only by the controller.

**Simulation is deterministic and fixed-step.** `ClimbState` (`types.dart`) is a plain mutable object holding everything: player, ropes, traps, pickups, particles, camera, rng. `createClimb(seed)` seeds an LCG stored in the state; `stepClimb(s, 1/60)` advances it. Never read `DateTime`, `Random` or Flutter APIs inside `lib/game/rope_core.dart`, `soft_rope.dart`, `particles.dart` or `weather.dart`. The tests depend on `createClimb()` (seed 17) replaying identically.

**Prediction reuses the production integrator.** `predictClimb` clones the state (`ClimbState.clone()`) and runs `ropeAction` + `stepClimb` on the copy, so the dotted trajectory on screen is always the real outcome. Any new field added to `ClimbState` (or `Rope`, `Trap`, `Pickup`, `RunStats`) must be copied in `clone()` or prediction silently diverges from play.

**Events are strings.** `rope_core.dart` appends names to `s.events` (`catch`, `snap`, `pump`, `lower`, `jump`, `pickup`, `block`, `graze`, `milestone`, `death`). `GameController.update` drains the list each step and maps each name to `GameAudio.effect(name)` and a haptic. Effect names must exist as keys returned by `renderEffects()` in `lib/audio/synth.dart`; UI cues are separate and looked up as `ui_<name>` via `GameAudio.ui`.

**Controller loop and two update channels.** `GameController` runs a `Ticker` with a fixed 1/60 s accumulator (frame dt capped at 0.05 s). Each tick bumps the `frame` `ValueNotifier`, which only repaints the `CustomPaint`; the painter reads the live `game.s` directly. Separately, an immutable `GameView` snapshot is emitted via `notifyListeners` roughly 10×/s or on mode change, and that is what the widget layer (`GameScreen`, HUD, panels) rebuilds from. Keep expensive widget rebuilds out of the per-frame path.

**Stage geometry.** Logical stage width is fixed at 360; `stageHeightFor` extends height from 640 up to 960 to match the device aspect, and `GameScreen` scales it with `FittedBox(fit: cover)`. Viewports wider than the stage (iPad) switch to `contain` and are pillarboxed, otherwise the HUD and controls get cropped away. All render and gesture code works in stage pixels. Safe-area insets are passed into panels as `inset` already divided by the scale.

**The climber is procedural.** `_drawFigure` in `lib/render/climber.dart` draws the pixel figure with rects and strokes in local space (origin at the hips, cord along local −y while held, rotated by `-theta`); `assets/sprites/player.png` is no longer used for the player. A halo pass draws the same figure in pale ink at four offsets first.

**Audio is synthesized at startup.** `GameAudio.init` renders every cue, the music loop and the wind loop into WAV bytes in a `compute` isolate (recipes in `synth.dart`), writes them to the temp directory and plays them with `audioplayers` in low-latency mode. Until rendering finishes every play call is a no-op, so tests and early frames are silent by design. Music tempo follows tension via playback rate. Playback futures swallow errors (`catchError`) and `dispose` is idempotent: audioplayers throws a 30 s `TimeoutException` on a seek before the source loads, which would fail an integration test if left unhandled. iOS uses the `ambient` category without `mixWithOthers` (that combination trips an audioplayers assertion in debug builds).

**Gestures and jump assist.** `stageGesture` in `lib/ui/game_screen.dart` classifies a pointer down/up pair: tap → `GameController.jump()` (assisted), downward swipe → lower, any other swipe → `jump(assist: false)`. Holding still for `holdPumpDelay` pumps repeatedly (a timer in the screen state; the PUMP button does the same). `jump()` releases at once when `predictClimb` says a higher rope will be caught, otherwise queues for `jumpAssistWindow` and fires on the first frame a catch appears, or posts a "NOT YET" notice. `GameView.jumpReady` drives the green JUMP button and a selection-click haptic.

**Launch intro.** `IntroOverlay` (`lib/ui/intro.dart`) sits on top of the menu for `introDuration` (2 s, tap to skip) and paints its own staged `ClimbState` with `drawScenery`/`drawClimber`: camera plunging from -2600 to 0 for parallax, a rebuilt `Rope` with straight cord nodes so the climber hangs on it, hazard rails, a stamped title and a global fade via `saveLayer`. `GameScreen(showIntro: false)` disables it; the screenshot and integration tests do that. Native launch colours (iOS storyboard, Android `launch_background`) match `Pal.shell` so the first intro frame is seamless.

**Pause and lifecycle.** Resuming from pause sets `s.countdown = resumeCountdown` (1.5 s) during which `stepClimb` freezes the whole world (only the countdown and screen shake decay); the app auto-pauses when it leaves the foreground. `Mode` has five states (`menu`, `playing`, `paused`, `dying`, `over`); `dying` still animates.

**Persistence.** `Records` (`lib/ui/records.dart`) is the only `shared_preferences` user; `_commitRun` in `GameScreen` updates it once per transition into `Mode.over`.

## Tests

`test/rope_core_test.dart` exports `planRope`, a brute-force search over real control sequences (lowers × pumps × wait → jump) that finds an input plan which catches the next rope using the real stepper. `screens_test.dart` imports it to get a believable mid-run state for the play screenshot. Prefer driving tests through `ropeAction`/`stepClimb` rather than poking state fields.

## Notes

- All sprite PNGs are generated by `tool/gen_sprites.py` (run it after changing the art code); they are original and MIT-licensed. `assets/sprites/LICENSE.md` documents this.
- iOS bundle ID is `com.ivan9527945.ropeEscape` (App Store Connect app 6821199045); Android keeps `com.ivan9527945.ropeEscape`.
- `output/` is untracked but not git-ignored; it is regenerated on every `flutter test`.
