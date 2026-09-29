// ─────────────────────────────────────────────
// HATI – Themed Scenario: Dialogue Replay
// scenario_replay_view.dart
//
// Visual-novel style "back" for the scenario's dialogue. The rewind button
// (next to the 2x toggle) opens a full-screen replay over the live scene;
// each Back steps one line further into the past, redrawn with that line's
// own scene background, speaking NPC, and Hati. View-only — the backend
// can't undo answers, so the live scene's choices stay hidden underneath
// until the player returns to the present.
// ─────────────────────────────────────────────

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app_theme.dart';
import 'scenario_models.dart';
import 'scenario_provider.dart';
import 'shared_widgets.dart';

const _kHeaderBlue = Color(0xFF4A8FD4);
const _kBrandBlue = Color(0xFF0B28D9);
const _kCream = Color(0xFFF5F1E8);

/// Pill that enters replay, styled to sit beside [HatiSpeedToggle].
class ScenarioRewindButton extends StatelessWidget {
  const ScenarioRewindButton({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ScenarioProvider?>();
    if (provider == null) return const SizedBox.shrink();
    final enabled = provider.canReplay;

    return Semantics(
      button: true,
      label: 'Replay previous dialogue',
      child: GestureDetector(
        onTap: enabled ? provider.startReplay : null,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 200),
          opacity: enabled ? 1 : 0.4,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: _kCream.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: _kCream.withValues(alpha: 0.45),
                width: 1.2,
              ),
            ),
            child: const Icon(Icons.replay_rounded, size: 15, color: _kCream),
          ),
        ),
      ),
    );
  }
}

String _sceneLabel(SceneId scene, ScenarioConfig config) {
  switch (scene) {
    case SceneId.preScene:
      return config.title;
    case SceneId.office:
      return 'The Office';
    case SceneId.preparation:
      return 'Preparation & Intention';
    case SceneId.interaction:
      return 'The Approach';
    case SceneId.debrief:
      return 'Post-Interaction Reflection';
    case SceneId.coping:
      return 'Coping Strategy Integration';
    case SceneId.closing:
      return 'Closing';
    case SceneId.dashboard:
      return 'Wrap-up';
  }
}

/// The character a line puts on stage: the speaker for an NPC line, or —
/// for a narrator line — the one character it names, if exactly one.
NpcCharacter? _characterFor(ScenarioConfig config, ReplayLine line) {
  if (line.kind == ReplayLineKind.npc) {
    return resolveNpcCharacter(config, line.speaker ?? '');
  }
  if (line.kind == ReplayLineKind.narrator) {
    final lower = line.text.toLowerCase();
    final named = config.npcCharacters
        .where((c) => c.matchKeywords.any(lower.contains))
        .toList();
    return named.length == 1 ? named.first : null;
  }
  return null;
}

String? _spriteFor(ScenarioConfig config, ReplayLine line) {
  final angry = line.npcMood == 'angry';
  final character = _characterFor(config, line);
  if (character != null) {
    final NpcMood mood;
    if (angry) {
      mood = NpcMood.frown;
    } else if (line.kind == ReplayLineKind.npc && line.text.endsWith('?')) {
      mood = NpcMood.tilt;
    } else {
      mood = NpcMood.blink;
    }
    return character.sprites.forMood(mood);
  }
  // foa_supervisor: one implicit NPC with its own sprite pair.
  if (line.kind == ReplayLineKind.npc &&
      config.npcCharacters.isEmpty &&
      config.spriteAsset != null) {
    return angry && config.spriteAssetAngry != null
        ? config.spriteAssetAngry
        : config.spriteAsset;
  }
  return null;
}

String _npcName(ScenarioConfig config, ReplayLine line) {
  final character = resolveNpcCharacter(config, line.speaker ?? '');
  if (character != null) return character.displayName;
  return (line.speaker ?? '').replaceAll(RegExp(r'\s*\(.*\)'), '').trim();
}

class ScenarioReplayView extends StatelessWidget {
  const ScenarioReplayView({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ScenarioProvider>();
    final index = provider.replayIndex;
    final log = provider.replayLog;
    if (index == null || index >= log.length) return const SizedBox.shrink();

    final config = provider.config;
    final line = log[index];
    SceneId sceneOf(ReplayLine l) =>
        l.step != null ? sceneForStep(l.step) : provider.currentScene;
    final scene = sceneOf(line);

    // In the interaction scene the last NPC to speak stays on stage while
    // Hati or the player talks, same as the live scene.
    var sprite = _spriteFor(config, line);
    if (sprite == null &&
        scene == SceneId.interaction &&
        line.kind != ReplayLineKind.npc) {
      for (var j = index - 1; j >= 0; j--) {
        if (sceneOf(log[j]) != SceneId.interaction) break;
        final earlier = _spriteFor(config, log[j]);
        if (earlier != null) {
          sprite = earlier;
          break;
        }
      }
    }

    final blueHeader =
        scene == SceneId.preScene ||
        scene == SceneId.closing ||
        scene == SceneId.dashboard;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) provider.exitReplay();
      },
      child: Material(
        color: Colors.black,
        child: Column(
          children: [
            _ReplayHeader(
              color: blueHeader ? _kBrandBlue : _kHeaderBlue,
              sceneLabel: _sceneLabel(scene, config),
              position: index + 1,
              total: log.length,
              onClose: provider.exitReplay,
            ),
            Expanded(
              child: _ReplayStage(
                key: ValueKey(index),
                config: config,
                scene: scene,
                line: line,
                spriteAsset: sprite,
                canGoBack: index > 0,
                onBack: provider.replayBack,
                onForward: provider.replayForward,
                isLatest: index == log.length - 1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReplayHeader extends StatelessWidget {
  final Color color;
  final String sceneLabel;
  final int position;
  final int total;
  final VoidCallback onClose;

  const _ReplayHeader({
    required this.color,
    required this.sceneLabel,
    required this.position,
    required this.total,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: color,
      padding: const EdgeInsets.fromLTRB(8, 0, 20, 12),
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            IconButton(
              onPressed: onClose,
              tooltip: 'Back to present',
              icon: const Icon(Icons.close_rounded, color: _kCream),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'REPLAYING',
                    style: HatiTextStyles.caption.copyWith(
                      color: _kCream.withValues(alpha: 0.75),
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                  Text(
                    sceneLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: HatiTextStyles.bodyLarge.copyWith(
                      color: _kCream,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              '$position / $total',
              style: HatiTextStyles.caption.copyWith(
                color: _kCream,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReplayStage extends StatelessWidget {
  final ScenarioConfig config;
  final SceneId scene;
  final ReplayLine line;
  final String? spriteAsset;
  final bool canGoBack;
  final bool isLatest;
  final VoidCallback onBack;
  final VoidCallback onForward;

  const _ReplayStage({
    super.key,
    required this.config,
    required this.scene,
    required this.line,
    required this.spriteAsset,
    required this.canGoBack,
    required this.isLatest,
    required this.onBack,
    required this.onForward,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final h = constraints.maxHeight;
        final isStage = scene == SceneId.interaction;
        final floorH = isStage ? (h * 0.20).clamp(110.0, 160.0) : 0.0;
        final hatiSize = isStage ? (floorH - 24).clamp(72.0, 120.0) : 120.0;
        final hatiBottom = isStage ? 12.0 : 24.0;
        final npcH = isStage
            ? ((h - floorH) * 0.42).clamp(140.0, 210.0)
            : (h * 0.30).clamp(140.0, 210.0);
        final npcBottom = isStage ? floorH + 20 : 24.0;
        final hasNpc = spriteAsset != null;
        // Hati moves aside whenever something else needs the lower centre.
        final hatiCentered =
            !isStage && !hasNpc && line.kind != ReplayLineKind.user;
        final hatiLeft = hatiCentered ? (w - hatiSize) / 2 : 8.0;
        final bubbleMaxW = math.min(w - 32, 340.0);
        final bubbleMaxH = h * 0.4;

        return Stack(
          fit: StackFit.expand,
          children: [
            _background(h, floorH),
            if (hasNpc)
              Positioned(
                right: 12,
                bottom: npcBottom,
                child: _ReplaySprite(asset: spriteAsset!, height: npcH),
              ),
            Positioned(
              left: hatiLeft,
              bottom: hatiBottom,
              child: HatiFrogAvatar(
                size: hatiSize,
                mood: line.kind == ReplayLineKind.hati
                    ? HatiMood.thinking
                    : HatiMood.idle,
              ),
            ),
            ..._bubble(
              w: w,
              h: h,
              bubbleMaxW: bubbleMaxW,
              bubbleMaxH: bubbleMaxH,
              hatiCentered: hatiCentered,
              hatiSize: hatiSize,
              hatiBottom: hatiBottom,
              hasNpc: hasNpc,
              npcTop: npcBottom + npcH,
              floorH: floorH,
            ),
            Positioned(
              top: 10,
              left: 20,
              child: Row(
                children: [
                  _StepPill(
                    icon: Icons.chevron_left_rounded,
                    label: 'Back',
                    enabled: canGoBack,
                    onTap: onBack,
                  ),
                  const SizedBox(width: 8),
                  _StepPill(
                    icon: Icons.chevron_right_rounded,
                    label: isLatest ? 'Return' : 'Next',
                    iconAfter: true,
                    enabled: true,
                    onTap: onForward,
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _background(double h, double floorH) {
    switch (scene) {
      case SceneId.interaction:
        return Stack(
          fit: StackFit.expand,
          children: [
            Container(color: _kHeaderBlue),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: h - floorH,
              child: Image.asset(config.backgroundAsset, fit: BoxFit.cover),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: floorH,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      _kHeaderBlue.withValues(alpha: 0.55),
                      _kHeaderBlue.withValues(alpha: 0.85),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      case SceneId.preScene:
      case SceneId.closing:
      case SceneId.dashboard:
        return Container(color: _kBrandBlue);
      case SceneId.office:
      case SceneId.preparation:
      case SceneId.debrief:
      case SceneId.coping:
        return ScenarioGradientBackground(
          backgroundAsset: config.backgroundAsset,
          child: const SizedBox.expand(),
        );
    }
  }

  List<Widget> _bubble({
    required double w,
    required double h,
    required double bubbleMaxW,
    required double bubbleMaxH,
    required bool hatiCentered,
    required double hatiSize,
    required double hatiBottom,
    required bool hasNpc,
    required double npcTop,
    required double floorH,
  }) {
    final aboveHati = hatiBottom + hatiSize + 8;

    switch (line.kind) {
      case ReplayLineKind.hati:
        final maxW = hasNpc ? math.min(bubbleMaxW, w * 0.62) : bubbleMaxW;
        return [
          Positioned(
            left: 16,
            right: 16,
            bottom: aboveHati,
            child: Align(
              alignment: hatiCentered
                  ? Alignment.bottomCenter
                  : Alignment.bottomLeft,
              child: _ReplayBubble(
                text: line.text,
                name: 'Hati',
                maxWidth: maxW,
                maxHeight: bubbleMaxH,
                tail: hatiCentered ? _Tail.center : _Tail.left,
                // Bubble starts at x=16; Hati's centre sits at 8 + size/2.
                tailInset: hatiSize / 2 - 8 - 10,
              ),
            ),
          ),
        ];
      case ReplayLineKind.npc:
        final npcBubbleBottom = hasNpc ? npcTop + 8 : aboveHati;
        // Leave room above for the name tag, tail, and Back/Next pills.
        final npcBubbleMaxH = math.max(
          80.0,
          math.min(bubbleMaxH, h - npcBubbleBottom - 100),
        );
        return [
          Positioned(
            right: 16,
            bottom: npcBubbleBottom,
            child: _ReplayBubble(
              text: line.text,
              name: _npcName(config, line),
              maxWidth: bubbleMaxW,
              maxHeight: npcBubbleMaxH,
              tail: _Tail.right,
              textAlign: TextAlign.right,
            ),
          ),
        ];
      case ReplayLineKind.narrator:
        return [
          Positioned(
            top: 56,
            left: 16,
            right: 16,
            child: Container(
              constraints: BoxConstraints(maxHeight: bubbleMaxH),
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.62),
                borderRadius: BorderRadius.circular(14),
              ),
              child: SingleChildScrollView(
                child: Text(
                  line.text,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: _kCream,
                    fontSize: 15,
                    fontStyle: FontStyle.italic,
                    height: 1.4,
                  ),
                ),
              ),
            ),
          ),
        ];
      case ReplayLineKind.user:
        return [
          Positioned(
            right: 16,
            bottom: hatiBottom,
            child: _ReplayBubble(
              text: line.text,
              name: 'You',
              maxWidth: math.min(bubbleMaxW, w - hatiSize - 48),
              maxHeight: math.max(floorH - 24, bubbleMaxH * 0.6),
              color: _kBrandBlue,
              textColor: _kCream,
              textAlign: TextAlign.right,
            ),
          ),
        ];
    }
  }
}

class _ReplaySprite extends StatelessWidget {
  final String asset;
  final double height;

  const _ReplaySprite({required this.asset, required this.height});

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      child: asset.endsWith('.riv')
          ? NpcRiveSprite(key: ValueKey(asset), assetPath: asset, height: height)
          : Image.asset(
              asset,
              key: ValueKey(asset),
              height: height,
              fit: BoxFit.contain,
              alignment: Alignment.bottomRight,
            ),
    );
  }
}

enum _Tail { none, left, center, right }

class _ReplayBubble extends StatelessWidget {
  final String text;
  final String? name;
  final double maxWidth;
  final double maxHeight;
  final Color color;
  final Color textColor;
  final _Tail tail;
  final double tailInset;
  final TextAlign textAlign;

  const _ReplayBubble({
    required this.text,
    required this.maxWidth,
    required this.maxHeight,
    this.name,
    this.color = _kCream,
    this.textColor = Colors.black,
    this.tail = _Tail.none,
    this.tailInset = 16,
    this.textAlign = TextAlign.left,
  });

  @override
  Widget build(BuildContext context) {
    final alignEnd = tail == _Tail.right || textAlign == TextAlign.right;
    final crossAxis = tail == _Tail.center
        ? CrossAxisAlignment.center
        : (alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start);

    Widget tailWidget() {
      final paint = CustomPaint(
        size: const Size(20, 10),
        painter: _TailPainter(color),
      );
      switch (tail) {
        case _Tail.none:
          return const SizedBox.shrink();
        case _Tail.center:
          return paint;
        case _Tail.left:
          return Padding(
            padding: EdgeInsets.only(left: math.max(tailInset, 12)),
            child: paint,
          );
        case _Tail.right:
          return Padding(padding: const EdgeInsets.only(right: 28), child: paint);
      }
    }

    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: crossAxis,
        children: [
          if (name != null && name!.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(bottom: 4),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                name!,
                style: const TextStyle(
                  color: _kCream,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          Container(
            constraints: BoxConstraints(maxHeight: maxHeight),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.18),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: SingleChildScrollView(
              child: Text(
                text,
                textAlign: textAlign,
                style: TextStyle(
                  color: textColor,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  height: 1.4,
                ),
              ),
            ),
          ),
          tailWidget(),
        ],
      ),
    );
  }
}

class _TailPainter extends CustomPainter {
  final Color color;

  const _TailPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2, size.height)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _TailPainter oldDelegate) =>
      oldDelegate.color != color;
}

class _StepPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool enabled;
  final bool iconAfter;
  final VoidCallback onTap;

  const _StepPill({
    required this.icon,
    required this.label,
    required this.enabled,
    required this.onTap,
    this.iconAfter = false,
  });

  @override
  Widget build(BuildContext context) {
    final iconWidget = Icon(icon, size: 18, color: _kCream);
    final labelWidget = Text(
      label,
      style: const TextStyle(
        color: _kCream,
        fontSize: 13,
        fontWeight: FontWeight.w700,
      ),
    );
    return Opacity(
      opacity: enabled ? 1 : 0.4,
      child: Material(
        color: Colors.black.withValues(alpha: 0.45),
        shape: StadiumBorder(
          side: BorderSide(color: _kCream.withValues(alpha: 0.5)),
        ),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: enabled ? onTap : null,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 6, 12, 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: iconAfter
                  ? [labelWidget, iconWidget]
                  : [iconWidget, labelWidget],
            ),
          ),
        ),
      ),
    );
  }
}
