import 'package:flutter/material.dart';

import 'help_center_sheet.dart';
import '../../../shared/audio/hati_tap_sound.dart';

/// Floating "?" help button that can be dragged anywhere within its parent
/// [Stack]. Meant to be used as `Positioned.fill(child: DraggableHelpButton())`
/// so it has the full area to roam in; a plain tap (no meaningful movement
/// between pointer down/up) still opens the help sheet.
class DraggableHelpButton extends StatefulWidget {
  const DraggableHelpButton({
    super.key,
    this.buttonKey,
    this.onReplayTour,
    this.topOffset = 16,
  });

  /// Default distance of the button's top edge below the status bar (can be
  /// negative to start partly over it). Scenario play passes a negative
  /// value so the button starts above SceneTopHeader's progress bar instead
  /// of covering its right end.
  final double topOffset;

  /// Spotlight target for the dashboard tour's final "Need Help?" step.
  final Key? buttonKey;

  /// When provided, the help sheet offers a "Replay Tutorial" option that
  /// invokes this. Left null on screens without a dashboard tour (e.g.
  /// scenario play).
  final VoidCallback? onReplayTour;

  @override
  State<DraggableHelpButton> createState() => _DraggableHelpButtonState();
}

class _DraggableHelpButtonState extends State<DraggableHelpButton> {
  static const double _size = 50;
  static const double _margin = 16;

  Offset? _topLeft;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxX = (constraints.maxWidth - _size).clamp(0.0, double.infinity);
        final maxY = (constraints.maxHeight - _size).clamp(
          0.0,
          double.infinity,
        );
        final topInset = MediaQuery.paddingOf(context).top;

        // Default starting spot: top-right, [DraggableHelpButton.topOffset]
        // below the status bar/notch (never above the screen's top edge).
        _topLeft ??= Offset(
          maxX - _margin,
          (topInset + widget.topOffset).clamp(4.0, maxY),
        );
        final clamped = Offset(
          _topLeft!.dx.clamp(0.0, maxX),
          _topLeft!.dy.clamp(1.0, maxY),
        );

        return Stack(
          children: [
            Positioned(
              left: clamped.dx,
              top: clamped.dy,
              child: HatiTapSound.click(
                child: GestureDetector(
                  onPanUpdate: (details) {
                    setState(() {
                      _topLeft = Offset(
                        (clamped.dx + details.delta.dx).clamp(0.0, maxX),
                        (clamped.dy + details.delta.dy).clamp(0.0, maxY),
                      );
                    });
                  },
                  onTap: () => showHelpCenterSheet(
                    context,
                    onReplayTour: widget.onReplayTour,
                  ),
                  child: Container(
                    key: widget.buttonKey,
                    width: _size,
                    height: _size,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFF0B28D9),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.25),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.support_agent_rounded,
                      color: const Color(0xFFF5F1E8),
                      size: 28,
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
