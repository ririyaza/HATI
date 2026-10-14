// ─────────────────────────────────────────────
// HATI – App-wide tap sound
// shared/audio/hati_tap_sound.dart
//
// One listener at the root of the app (see main.dart's MaterialApp.builder)
// plays the button click for every tap that lands on something tappable,
// instead of adding a sound call to each of the ~200 onTap/onPressed
// handlers across the app.
//
// Only *buttons* click — things that take you to another page or part of
// the app — not selection controls like answer options, chips, checkboxes
// or toggles. On pointer-down it hit-tests the tap position:
//   • the nearest [HatiTapSound] marker around the tap, if any, wins —
//     custom-built buttons opt in with `HatiTapSound.click`, answer options
//     / radio-style choices get the softer `.option` select sound, buttons
//     that shouldn't click (mic/record, toggles) opt out with `.silent`,
//     and Hati himself croaks;
//   • otherwise the innermost widget that declares itself to accessibility
//     as a button or tab decides: Material buttons (Elevated/Filled/
//     Outlined/Text/IconButton), bottom-nav items, tabs and popup menus
//     click while enabled; switches/checkboxes (toggled/checked) and
//     disabled buttons stay silent;
//   • plain GestureDetector/InkWell taps (option tiles, cards) are silent.
// The sound only plays on pointer-up if the finger didn't move past touch
// slop, so scrolling and dragging stay silent. Gestures themselves are
// untouched — this only listens, it never joins the gesture arena.
// ─────────────────────────────────────────────

import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/widgets.dart';

import 'hati_audio_service.dart';

/// Wrap the whole app once (MaterialApp.builder) to get the button click on
/// every tappable widget.
class HatiTapSoundScope extends StatefulWidget {
  const HatiTapSoundScope({super.key, required this.child});

  final Widget child;

  @override
  State<HatiTapSoundScope> createState() => _HatiTapSoundScopeState();
}

class _HatiTapSoundScopeState extends State<HatiTapSoundScope> {
  // Down position + sound for each active pointer, decided at pointer-down.
  final Map<int, (Offset, VoidCallback)> _pending = {};

  void _onDown(PointerDownEvent event) {
    if (event.kind == PointerDeviceKind.mouse &&
        event.buttons != kPrimaryMouseButton) {
      return;
    }
    final result = HitTestResult();
    WidgetsBinding.instance.hitTestInView(result, event.position, event.viewId);
    final sound = _soundFor(result);
    if (sound != null) _pending[event.pointer] = (event.position, sound);
  }

  void _onMove(PointerMoveEvent event) {
    final pending = _pending[event.pointer];
    if (pending == null) return;
    if ((event.position - pending.$1).distance > kTouchSlop) {
      _pending.remove(event.pointer);
    }
  }

  void _onUp(PointerUpEvent event) {
    _pending.remove(event.pointer)?.$2();
  }

  void _onCancel(PointerCancelEvent event) {
    _pending.remove(event.pointer);
  }

  static VoidCallback? _soundFor(HitTestResult result) {
    VoidCallback? semanticSound;
    var semanticDecided = false;
    // Whether an enabled tap handler sits inside the nearest marker, so a
    // `.click` marker around a currently-disabled custom button (onTap:
    // null) stays silent like a disabled Material button does.
    var sawTapHandler = false;
    for (final entry in result.path) {
      final target = entry.target;
      if (target is _RenderHatiTapSound) {
        if (target.needsTapHandler && !sawTapHandler) return null;
        return target.sound;
      }
      if ((target is RenderSemanticsGestureHandler && target.onTap != null) ||
          (target is RenderMouseRegion &&
              target.cursor == SystemMouseCursors.click)) {
        sawTapHandler = true;
      }
      if (semanticDecided || target is! RenderSemanticsAnnotations) continue;
      final props = target.properties;
      if (props.toggled != null ||
          props.checked != null ||
          props.inMutuallyExclusiveGroup == true) {
        semanticDecided = true;
      } else if (props.button == true || props.role == SemanticsRole.tab) {
        semanticDecided = true;
        if (props.enabled != false) semanticSound = _click;
      }
    }
    return semanticSound;
  }

  static void _click() => HatiAudioService.instance.playButton();

  static void _option() => HatiAudioService.instance.playOptionSelect();

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: _onDown,
      onPointerMove: _onMove,
      onPointerUp: _onUp,
      onPointerCancel: _onCancel,
      child: widget.child,
    );
  }
}

/// Sets the tap sound for everything inside [child]; the innermost marker
/// around a tap wins over any button semantics inside it.
///
/// * `HatiTapSound.click(child: ...)` — a custom-built (GestureDetector/
///   InkWell) button that navigates somewhere, which wouldn't click on its
///   own.
/// * `HatiTapSound.option(child: ...)` — an answer option, radio, checkbox
///   or chip: plays the select sound instead of the button click.
/// * `HatiTapSound.silent(child: ...)` — a real button that shouldn't
///   click, e.g. the mic button (the click would land in the recording).
/// * `HatiTapSound(sound: ..., child: ...)` — a custom sound, e.g. Hati's
///   croak when the frog itself is tapped.
class HatiTapSound extends SingleChildRenderObjectWidget {
  const HatiTapSound({super.key, required this.sound, super.child})
    : _needsTapHandler = false;

  const HatiTapSound.click({super.key, super.child})
    : sound = _HatiTapSoundScopeState._click,
      _needsTapHandler = true;

  const HatiTapSound.option({super.key, super.child})
    : sound = _HatiTapSoundScopeState._option,
      _needsTapHandler = true;

  const HatiTapSound.silent({super.key, super.child})
    : sound = null,
      _needsTapHandler = false;

  final VoidCallback? sound;
  final bool _needsTapHandler;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderHatiTapSound(sound, _needsTapHandler);

  @override
  void updateRenderObject(BuildContext context, RenderObject renderObject) {
    (renderObject as _RenderHatiTapSound)
      ..sound = sound
      ..needsTapHandler = _needsTapHandler;
  }
}

// Translucent: shows up in the hit path whenever the tap is within its
// bounds, without changing whether anything above or below it gets hit.
class _RenderHatiTapSound extends RenderProxyBoxWithHitTestBehavior {
  _RenderHatiTapSound(this.sound, this.needsTapHandler)
    : super(behavior: HitTestBehavior.translucent);

  VoidCallback? sound;
  bool needsTapHandler;
}
