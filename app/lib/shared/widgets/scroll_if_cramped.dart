import 'package:flutter/material.dart';

/// Lays [child] out to fill the available height — so a `Spacer`/`Expanded`
/// inside a [Column] still pins content to the bottom on roomy screens — but
/// lets it scroll instead of overflowing when the viewport is too short
/// (small phones, landscape, large system text). Content is centered and
/// capped at [maxWidth] so it doesn't stretch edge-to-edge on tablets.
class ScrollIfCramped extends StatelessWidget {
  const ScrollIfCramped({super.key, required this.child, this.maxWidth = 560});

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: IntrinsicHeight(
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxWidth),
                child: child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
