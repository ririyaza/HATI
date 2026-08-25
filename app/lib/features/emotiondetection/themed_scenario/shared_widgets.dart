// ─────────────────────────────────────────────
// HATI – Shared Widgets
// widgets/shared_widgets.dart
//
// Ported from testing_env/lib/shared_widgets.dart. Presentation-only:
// bubbles, chips, buttons, frog coach, progress bar. No scenario branching
// logic lives here — scenes source all labels/options/dialogue from
// ScenarioProvider.
//
// Change from the prototype: hatiFrogSpriteAsset now points at the copied
// asset under assets/professor_signature/. A new TextResponseCard widget
// was added (not present in the prototype) as a small reusable
// text-input-plus-send-button card, used by scenes that render a
// `text_input` backend turn.
// ─────────────────────────────────────────────

import 'dart:async';

import 'package:flutter/material.dart';
import 'app_theme.dart';

// ── Hati Dialogue Bubble ─────────────────────────────────────────────────────
class HatiBubble extends StatefulWidget {
  final String text;
  final bool animate;
  final VoidCallback? onComplete;

  const HatiBubble({
    super.key,
    required this.text,
    this.animate = true,
    this.onComplete,
  });

  @override
  State<HatiBubble> createState() => _HatiBubbleState();
}

class _HatiBubbleState extends State<HatiBubble> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeIn;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 50),
    );
    _fadeIn = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    if (widget.animate) {
      _controller.forward().then((_) => widget.onComplete?.call());
    } else {
      _controller.value = 1.0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeIn,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          HatiFrogSprite(size: 44),
          const SizedBox(width: 10),
          // Speech bubble
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: HatiColors.hatiSpeech,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(4),
                  topRight: Radius.circular(16),
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                ),
                border: Border.all(
                  color: HatiColors.mossGreen.withValues(alpha: 0.2),
                  width: 1,
                ),
              ),
              child: Text(
                widget.text,
                style: HatiTextStyles.hatiSpeech,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── NPC Dialogue Bubble ───────────────────────────────────────────────────────
class NPCBubble extends StatelessWidget {
  final String npcName;
  final String text;
  final Color? color;

  const NPCBubble({
    super.key,
    required this.npcName,
    required this.text,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: color ?? HatiColors.npcSpeech,
            shape: BoxShape.circle,
            border: Border.all(color: HatiColors.divider),
          ),
          child: const Center(
            child: Text('👤', style: TextStyle(fontSize: 20)),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                npcName,
                style: HatiTextStyles.caption.copyWith(
                  color: HatiColors.mossGreen,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: color ?? HatiColors.npcSpeech,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(4),
                    topRight: Radius.circular(16),
                    bottomLeft: Radius.circular(16),
                    bottomRight: Radius.circular(16),
                  ),
                ),
                child: Text(text, style: HatiTextStyles.bodyLarge),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── User Response Bubble ──────────────────────────────────────────────────────
class UserBubble extends StatelessWidget {
  final String text;

  const UserBubble({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Flexible(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: HatiColors.mossGreen,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(4),
                bottomLeft: Radius.circular(16),
                bottomRight: Radius.circular(16),
              ),
            ),
            child: Text(
              text,
              style: HatiTextStyles.bodyLarge.copyWith(color: Colors.white),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Container(
          width: 36,
          height: 36,
          decoration: const BoxDecoration(
            color: HatiColors.mossGreen,
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.person, color: Colors.white, size: 18),
        ),
      ],
    );
  }
}

// ── PIES Selection Chip ───────────────────────────────────────────────────────
class PIESChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color? selectedColor;

  const PIESChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.selectedColor,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: selected
              ? (selectedColor ?? HatiColors.mossGreen)
              : HatiColors.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: selected
                ? (selectedColor ?? HatiColors.mossGreen)
                : HatiColors.divider,
            width: 1.5,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: (selectedColor ?? HatiColors.mossGreen).withValues(alpha: 0.25),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  )
                ]
              : [],
        ),
        child: Text(
          label,
          style: HatiTextStyles.buttonSmall.copyWith(
            color: selected ? Colors.white : HatiColors.textMedium,
          ),
        ),
      ),
    );
  }
}

// ── Script Option Card ────────────────────────────────────────────────────────
class ScriptOptionCard extends StatelessWidget {
  final String label;
  final String script;
  final bool selected;
  final VoidCallback onTap;

  const ScriptOptionCard({
    super.key,
    required this.label,
    required this.script,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selected ? HatiColors.mossGreen.withValues(alpha: 0.08) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? HatiColors.mossGreen : HatiColors.divider,
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: selected ? HatiColors.mossGreen : HatiColors.surface,
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected ? HatiColors.mossGreen : HatiColors.divider,
                ),
              ),
              child: Center(
                child: Text(
                  label,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: selected ? Colors.white : HatiColors.textMedium,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                script,
                style: HatiTextStyles.bodyMedium.copyWith(
                  color: selected ? HatiColors.textDark : HatiColors.textMedium,
                ),
              ),
            ),
            if (selected)
              const Icon(Icons.check_circle, color: HatiColors.mossGreen, size: 20),
          ],
        ),
      ),
    );
  }
}

// ── Primary CTA Button ────────────────────────────────────────────────────────
class HatiButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final Color? color;
  final IconData? icon;
  final bool fullWidth;

  const HatiButton({
    super.key,
    required this.label,
    this.onTap,
    this.color,
    this.icon,
    this.fullWidth = true,
  });

  @override
  Widget build(BuildContext context) {
    final bg = color ?? HatiColors.mossGreen;
    Widget content = Row(
      mainAxisSize: fullWidth ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (icon != null) ...[Icon(icon, size: 20, color: Colors.white), const SizedBox(width: 8)],
        Flexible(
          child: Text(
            label,
            style: HatiTextStyles.button,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: fullWidth ? double.infinity : null,
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
        decoration: BoxDecoration(
          color: onTap != null ? bg : bg.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(14),
          boxShadow: onTap != null
              ? [
                  BoxShadow(
                    color: bg.withValues(alpha: 0.35),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  )
                ]
              : [],
        ),
        child: content,
      ),
    );
  }
}

// ── Secondary/Ghost Button ────────────────────────────────────────────────────
class HatiOutlineButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final Color? borderColor;

  const HatiOutlineButton({
    super.key,
    required this.label,
    required this.onTap,
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: borderColor ?? HatiColors.mossGreen,
            width: 1.5,
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: HatiTextStyles.button.copyWith(
              color: borderColor ?? HatiColors.mossGreen,
            ),
          ),
        ),
      ),
    );
  }
}

// ── Section Header ────────────────────────────────────────────────────────────
class SectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;

  const SectionHeader({super.key, required this.title, this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: HatiTextStyles.heading3),
        if (subtitle != null) ...[
          const SizedBox(height: 4),
          Text(subtitle!, style: HatiTextStyles.bodyMedium),
        ],
      ],
    );
  }
}

// ── Slider Question ───────────────────────────────────────────────────────────
class SliderQuestion extends StatefulWidget {
  final String question;
  final ValueChanged<int> onChanged;
  final int initial;

  const SliderQuestion({
    super.key,
    required this.question,
    required this.onChanged,
    this.initial = 5,
  });

  @override
  State<SliderQuestion> createState() => _SliderQuestionState();
}

class _SliderQuestionState extends State<SliderQuestion> {
  late double _value;

  @override
  void initState() {
    super.initState();
    _value = widget.initial.toDouble();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.question, style: HatiTextStyles.bodyLarge),
        const SizedBox(height: 8),
        Row(
          children: [
            Text('0', style: HatiTextStyles.caption),
            Expanded(
              child: Slider(
                value: _value,
                min: 0,
                max: 10,
                divisions: 10,
                label: _value.toInt().toString(),
                onChanged: (v) {
                  setState(() => _value = v);
                  widget.onChanged(v.toInt());
                },
              ),
            ),
            Text('10', style: HatiTextStyles.caption),
          ],
        ),
        Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: HatiColors.mossGreen.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '${_value.toInt()} / 10',
              style: HatiTextStyles.heading3.copyWith(color: HatiColors.mossGreen),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Scene Progress Bar ────────────────────────────────────────────────────────
class SceneProgressBar extends StatelessWidget {
  final int currentStep;
  final int totalSteps;
  final String sceneLabel;

  const SceneProgressBar({
    super.key,
    required this.currentStep,
    required this.totalSteps,
    required this.sceneLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(sceneLabel, style: HatiTextStyles.caption),
            Text('$currentStep / $totalSteps', style: HatiTextStyles.caption),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: currentStep / totalSteps,
            backgroundColor: HatiColors.divider,
            color: HatiColors.mossGreen,
            minHeight: 6,
          ),
        ),
      ],
    );
  }
}

// ── PIES Section ──────────────────────────────────────────────────────────────
class PIESSection extends StatelessWidget {
  final String label;
  final String emoji;
  final List<String> options;
  final String? selected;
  final Function(String) onSelect;
  final Color? selectedColor;

  const PIESSection({
    super.key,
    required this.label,
    required this.emoji,
    required this.options,
    required this.selected,
    required this.onSelect,
    this.selectedColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 18)),
            const SizedBox(width: 8),
            Text(label, style: HatiTextStyles.heading3),
          ],
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: options.map((opt) => PIESChip(
            label: opt,
            selected: selected == opt,
            selectedColor: selectedColor,
            onTap: () => onSelect(opt),
          )).toList(),
        ),
      ],
    );
  }
}

// ── Text response card (new) ───────────────────────────────────────────────
/// Reusable text-input + send-button card for any `text_input` backend
/// turn. Not present in the prototype (which never needed to submit
/// free text to a server) — added here so every text_input step across
/// the scenes shares one implementation.
class TextResponseCard extends StatefulWidget {
  final String hintText;
  final String buttonLabel;
  final bool isLoading;
  final int maxLines;
  final ValueChanged<String> onSubmit;

  const TextResponseCard({
    super.key,
    this.hintText = 'Type your response...',
    this.buttonLabel = 'Send',
    this.isLoading = false,
    this.maxLines = 3,
    required this.onSubmit,
  });

  @override
  State<TextResponseCard> createState() => _TextResponseCardState();
}

class _TextResponseCardState extends State<TextResponseCard> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final canSubmit = !widget.isLoading && _controller.text.trim().isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _controller,
          maxLines: widget.maxLines,
          enabled: !widget.isLoading,
          onChanged: (_) => setState(() {}),
          onSubmitted: (_) {
            if (canSubmit) widget.onSubmit(_controller.text.trim());
          },
          decoration: InputDecoration(
            hintText: widget.hintText,
            hintStyle: HatiTextStyles.bodyMedium,
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: HatiColors.divider),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: HatiColors.mossGreen,
                width: 2,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        HatiButton(
          label: widget.buttonLabel,
          icon: Icons.send_rounded,
          onTap: canSubmit ? () => widget.onSubmit(_controller.text.trim()) : null,
        ),
      ],
    );
  }
}

// ── Animated speech bubble (scene0-style) ─────────────────────────────────────

/// Intro message dissolves after typing; [persistentMessage] stays on screen.
class HatiSpeechSequence extends StatefulWidget {
  final String introMessage;
  final String persistentMessage;
  final VoidCallback? onSequenceComplete;

  const HatiSpeechSequence({
    super.key,
    required this.introMessage,
    required this.persistentMessage,
    this.onSequenceComplete,
  });

  @override
  State<HatiSpeechSequence> createState() => _HatiSpeechSequenceState();
}

class _HatiSpeechSequenceState extends State<HatiSpeechSequence> {
  bool _introFinished = false;

  bool get _hasIntro => widget.introMessage.trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    if (!_hasIntro || _introFinished) {
      return _AnimatedHatiSpeechBubble(
        key: const ValueKey('persistent'),
        message: widget.persistentMessage,
        dissolves: false,
        maxWidth: HatiLayout.bubbleMaxWidth,
        maxHeight: HatiLayout.bubbleMaxHeight,
        onTypingComplete: widget.onSequenceComplete,
      );
    }

    return _AnimatedHatiSpeechBubble(
      key: const ValueKey('intro'),
      message: widget.introMessage,
      dissolves: true,
      maxWidth: HatiLayout.bubbleMaxWidth,
      maxHeight: HatiLayout.bubbleMaxHeight,
      onDismissed: () => setState(() => _introFinished = true),
    );
  }
}

/// Largest font size (down to [HatiLayout.bubbleMinFontSize]) at which
/// [content] fits within [innerMaxH]; `fits: false` means even the
/// smallest size overflows, so the caller should paginate instead of
/// letting the bubble clip it.
(double fontSize, bool fits) _fitBubbleFontSize(
  String content,
  double innerMaxW,
  double innerMaxH,
) {
  if (content.isEmpty) return (HatiLayout.bubbleBaseFontSize, true);

  for (var size = HatiLayout.bubbleBaseFontSize;
      size >= HatiLayout.bubbleMinFontSize;
      size -= 0.5) {
    if (_measureBubbleTextHeight(content, size, innerMaxW) <= innerMaxH) {
      return (size, true);
    }
  }
  return (HatiLayout.bubbleMinFontSize, false);
}

double _measureBubbleTextHeight(String content, double fontSize, double innerMaxW) {
  final painter = TextPainter(
    text: TextSpan(
      text: content,
      style: TextStyle(
        fontSize: fontSize,
        fontWeight: FontWeight.bold,
        height: _ScaledBubbleText._lineHeight,
      ),
    ),
    textAlign: TextAlign.center,
    textDirection: TextDirection.ltr,
    maxLines: null,
  )..layout(maxWidth: innerMaxW);
  return painter.height;
}

/// Greedily packs [text] into word-wrapped chunks that each fit within
/// [innerMaxH] at [fontSize], so a chunk too long for one bubble can be
/// shown as a sequence of bubbles (like separate dialogue lines) instead
/// of overflowing or scrolling a single one.
List<String> _paginateBubbleText(
  String text,
  double fontSize,
  double innerMaxW,
  double innerMaxH,
) {
  final words = text.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
  if (words.isEmpty) return const [];

  final pages = <String>[];
  var current = '';
  for (final word in words) {
    final candidate = current.isEmpty ? word : '$current $word';
    if (current.isEmpty ||
        _measureBubbleTextHeight(candidate, fontSize, innerMaxW) <= innerMaxH) {
      current = candidate;
    } else {
      pages.add(current);
      current = word;
    }
  }
  if (current.isNotEmpty) pages.add(current);
  return pages;
}

/// Speech-bubble text that shrinks to fit [maxWidth] × [maxHeight]. Assumes
/// the caller (see [_AnimatedHatiSpeechBubbleState]'s pagination) already
/// guarantees [text] fits — this only picks the font size.
class _ScaledBubbleText extends StatelessWidget {
  static const _padding = EdgeInsets.fromLTRB(24, 22, 24, 34);
  static const double _lineHeight = 1.45;

  /// Visible typewriter text.
  final String text;
  /// Full message used to pick a stable font size (avoids resize jumps while typing).
  final String layoutReference;
  final double maxWidth;
  final double maxHeight;

  const _ScaledBubbleText({
    super.key,
    required this.text,
    required this.layoutReference,
    required this.maxWidth,
    required this.maxHeight,
  });

  @override
  Widget build(BuildContext context) {
    final innerMaxW = (maxWidth - _padding.horizontal).clamp(0.0, maxWidth);
    final innerMaxH = (maxHeight - _padding.vertical).clamp(0.0, maxHeight);
    final reference = layoutReference.isNotEmpty ? layoutReference : text;
    final (fontSize, _) = _fitBubbleFontSize(reference, innerMaxW, innerMaxH);

    return SizedBox(
      width: innerMaxW,
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: Colors.black,
          fontSize: fontSize,
          fontWeight: FontWeight.bold,
          height: _lineHeight,
        ),
      ),
    );
  }
}

/// Splits a message into sentence-sized chunks so a speech bubble can
/// reveal one at a time instead of typing (and overflowing on) the whole
/// block at once. Splits on sentence-ending punctuation and blank lines;
/// falls back to the whole trimmed message when no boundary is found.
List<String> _splitIntoSentences(String text) {
  final trimmed = text.trim();
  if (trimmed.isEmpty) return const [];

  final boundary = RegExp(r'(?<=[.!?])\s+|\n{2,}');
  final parts = trimmed
      .split(boundary)
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .toList();

  return parts.isEmpty ? [trimmed] : parts;
}

class _AnimatedHatiSpeechBubble extends StatefulWidget {
  final String message;
  final bool dissolves;
  final Duration holdAfterTyping;
  final double maxWidth;
  final double maxHeight;
  final VoidCallback? onDismissed;
  final VoidCallback? onTypingComplete;

  const _AnimatedHatiSpeechBubble({
    super.key,
    required this.message,
    this.dissolves = true,
    this.holdAfterTyping = const Duration(seconds: 2),
    this.maxWidth = HatiLayout.bubbleMaxWidth,
    this.maxHeight = HatiLayout.bubbleMaxHeight,
    this.onDismissed,
    this.onTypingComplete,
  });

  @override
  State<_AnimatedHatiSpeechBubble> createState() => _AnimatedHatiSpeechBubbleState();
}

class _AnimatedHatiSpeechBubbleState extends State<_AnimatedHatiSpeechBubble>
    with TickerProviderStateMixin {
  static const _charInterval = Duration(milliseconds: 20);
  static const _sentenceHold = Duration(seconds: 2);

  late final AnimationController _entranceController;
  late final AnimationController _dissolveController;
  late final Animation<double> _entranceScale;
  late final Animation<double> _entranceOpacity;
  late final Animation<Offset> _entranceSlide;
  late final Animation<double> _dissolveOpacity;

  late final List<String> _sentences;
  late final String _layoutReference;

  Timer? _typewriterTimer;
  Timer? _sentenceHoldTimer;
  Timer? _dissolveDelayTimer;
  int _sentenceIndex = 0;
  int _visibleChars = 0;
  bool _dissolved = false;

  @override
  void initState() {
    super.initState();
    final rawSentences = _splitIntoSentences(widget.message);
    _layoutReference = rawSentences.isEmpty
        ? widget.message
        : rawSentences.reduce((a, b) => a.length >= b.length ? a : b);

    final innerMaxW = (widget.maxWidth - _ScaledBubbleText._padding.horizontal)
        .clamp(0.0, widget.maxWidth);
    final innerMaxH = (widget.maxHeight - _ScaledBubbleText._padding.vertical)
        .clamp(0.0, widget.maxHeight);
    final (fontSize, _) = _fitBubbleFontSize(_layoutReference, innerMaxW, innerMaxH);

    // A sentence that alone still doesn't fit at that font size gets
    // paginated further, so it pages like separate dialogue lines instead
    // of overflowing the bubble.
    _sentences = rawSentences.expand((s) {
      if (_measureBubbleTextHeight(s, fontSize, innerMaxW) <= innerMaxH) return [s];
      return _paginateBubbleText(s, fontSize, innerMaxW, innerMaxH);
    }).toList();

    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _dissolveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    final entranceCurve = CurvedAnimation(
      parent: _entranceController,
      curve: Curves.easeOutCubic,
    );
    _entranceScale = Tween<double>(begin: 0.82, end: 1).animate(entranceCurve);
    _entranceOpacity = Tween<double>(begin: 0, end: 1).animate(entranceCurve);
    _entranceSlide = Tween<Offset>(
      begin: const Offset(0, 0.12),
      end: Offset.zero,
    ).animate(entranceCurve);
    _dissolveOpacity = Tween<double>(begin: 1, end: 0).animate(
      CurvedAnimation(parent: _dissolveController, curve: Curves.easeIn),
    );

    _entranceController.forward().then((_) {
      if (mounted) _startTypewriter();
    });
  }

  void _startTypewriter() {
    if (_sentences.isEmpty) {
      _scheduleDissolve();
      return;
    }
    _typeCurrentSentence();
  }

  void _typeCurrentSentence() {
    final sentence = _sentences[_sentenceIndex];
    if (sentence.isEmpty) {
      _holdThenAdvance();
      return;
    }

    _typewriterTimer = Timer.periodic(_charInterval, (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_visibleChars >= sentence.length) {
        timer.cancel();
        _holdThenAdvance();
        return;
      }
      setState(() => _visibleChars++);
    });
  }

  void _holdThenAdvance() {
    final isLast = _sentenceIndex >= _sentences.length - 1;
    if (isLast) {
      _scheduleDissolve();
      return;
    }

    _sentenceHoldTimer = Timer(_sentenceHold, () {
      if (!mounted) return;
      setState(() {
        _sentenceIndex++;
        _visibleChars = 0;
      });
      _typeCurrentSentence();
    });
  }

  void _scheduleDissolve() {
    if (!widget.dissolves) {
      widget.onTypingComplete?.call();
      return;
    }

    _dissolveDelayTimer = Timer(widget.holdAfterTyping, () {
      if (!mounted) return;
      _dissolveController.forward().then((_) {
        if (!mounted) return;
        if (widget.onDismissed != null) {
          widget.onDismissed!();
        } else {
          setState(() => _dissolved = true);
        }
      });
    });
  }

  @override
  void dispose() {
    _typewriterTimer?.cancel();
    _sentenceHoldTimer?.cancel();
    _dissolveDelayTimer?.cancel();
    _entranceController.dispose();
    _dissolveController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_dissolved) {
      return const SizedBox.shrink();
    }

    final sentence = _sentences.isNotEmpty
        ? _sentences[_sentenceIndex.clamp(0, _sentences.length - 1)]
        : '';
    final displayed = sentence.substring(
      0,
      _visibleChars.clamp(0, sentence.length),
    );
    final isTyping = _visibleChars < sentence.length;

    return Align(
      alignment: Alignment.bottomCenter,
      child: AnimatedBuilder(
        animation: Listenable.merge([
          _entranceController,
          _dissolveController,
          _entranceSlide,
        ]),
        builder: (context, child) {
          final dissolving = _dissolveController.isAnimating ||
              _dissolveController.status == AnimationStatus.completed;
          final opacity = dissolving
              ? _dissolveOpacity.value
              : _entranceOpacity.value;
          final scale = dissolving
              ? 1 - (_dissolveController.value * 0.05)
              : _entranceScale.value;

          return Opacity(
            opacity: opacity.clamp(0, 1),
            child: Transform.scale(
              scale: scale,
              alignment: Alignment.bottomCenter,
              child: SlideTransition(
                position: _entranceSlide,
                child: child,
              ),
            ),
          );
        },
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: widget.maxWidth,
            maxHeight: widget.maxHeight,
          ),
          child: AnimatedSize(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            alignment: Alignment.topCenter,
            clipBehavior: Clip.none,
            child: CustomPaint(
              painter: const _HatiSpeechBubblePainter(),
              child: Padding(
                padding: _ScaledBubbleText._padding,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  switchInCurve: Curves.easeOut,
                  switchOutCurve: Curves.easeIn,
                  child: _ScaledBubbleText(
                    key: ValueKey(_sentenceIndex),
                    text: isTyping ? '$displayed|' : displayed,
                    layoutReference: _layoutReference,
                    maxWidth: widget.maxWidth,
                    maxHeight: widget.maxHeight,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HatiSpeechBubblePainter extends CustomPainter {
  const _HatiSpeechBubblePainter();

  @override
  void paint(Canvas canvas, Size size) {
    const radius = 20.0;
    const tailWidth = 22.0;
    const tailHeight = 14.0;
    final bubbleBottom = size.height - tailHeight;

    final bubblePath = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(0, 0, size.width, bubbleBottom),
          const Radius.circular(radius),
        ),
      );

    final tailCenter = size.width / 2;
    final tailPath = Path()
      ..moveTo(tailCenter - tailWidth / 2, bubbleBottom - 1)
      ..lineTo(tailCenter, size.height)
      ..lineTo(tailCenter + tailWidth / 2, bubbleBottom - 1)
      ..close();

    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    canvas.drawPath(Path.combine(PathOperation.union, bubblePath, tailPath), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ── Hati Frog Character ───────────────────────────────────────────────────────

const int hatiFrogFrameCount = 12;
const String hatiFrogSpriteAsset = 'assets/professor_signature/frog_sprite_sheet.png';

/// Shared layout metrics for Hati-guided scenes (matches Scene 1).
class HatiLayout {
  HatiLayout._();

  static const double frogSize = 210;
  static const double bubbleMaxWidth = 328;
  static const double bubbleMaxHeight = 220;
  static const double bubbleBaseFontSize = 16;
  /// Smallest font used in speech bubbles; text never scales below this.
  static const double bubbleMinFontSize = 12;
  static const double coachZoneHeight = frogSize + bubbleMaxHeight + 28;
  static const double horizontalPadding = 20;
}

class HatiFrogSprite extends StatelessWidget {
  final int frameIndex;
  final double size;
  final double widthScale;

  const HatiFrogSprite({
    super.key,
    this.frameIndex = 0,
    required this.size,
    this.widthScale = 1,
  });

  @override
  Widget build(BuildContext context) {
    final alignmentX = hatiFrogFrameCount <= 1
        ? 0.0
        : -1 + (2 * frameIndex / (hatiFrogFrameCount - 1));

    final width = size * widthScale;

    return SizedBox(
      width: width,
      height: size,
      child: ClipRect(
        child: OverflowBox(
          maxWidth: width * hatiFrogFrameCount,
          alignment: Alignment(alignmentX, 0),
          child: Image.asset(
            hatiFrogSpriteAsset,
            width: widthScale == 1 ? null : width * hatiFrogFrameCount,
            height: size,
            fit: widthScale == 1 ? BoxFit.fitHeight : BoxFit.fill,
            filterQuality: FilterQuality.medium,
          ),
        ),
      ),
    );
  }
}

class HatiFrogAvatar extends StatefulWidget {
  final double size;
  final double widthScale;
  final bool animate;

  const HatiFrogAvatar({
    super.key,
    this.size = HatiLayout.frogSize,
    this.widthScale = 1,
    this.animate = true,
  });

  @override
  State<HatiFrogAvatar> createState() => _HatiFrogAvatarState();
}

/// Animated speech bubble + frog avatar — use wherever Hati is talking.
/// When [replacementMessage] is set, the bubble text is swapped in place
/// (same frog; no second avatar).
class HatiSpeakingBlock extends StatelessWidget {
  final String introMessage;
  final String persistentMessage;
  final String? replacementMessage;
  final VoidCallback? onSequenceComplete;
  final VoidCallback? onBubbleDismissed;
  final double frogSize;
  final bool dissolveBubble;
  final Duration holdAfterTyping;

  const HatiSpeakingBlock({
    super.key,
    this.introMessage = '',
    required this.persistentMessage,
    this.replacementMessage,
    this.onSequenceComplete,
    this.onBubbleDismissed,
    this.frogSize = HatiLayout.frogSize,
    this.dissolveBubble = false,
    this.holdAfterTyping = const Duration(seconds: 2),
  });

  @override
  Widget build(BuildContext context) {
    final Widget bubble;
    if (replacementMessage != null) {
      bubble = _AnimatedHatiSpeechBubble(
        key: ValueKey(replacementMessage),
        message: replacementMessage!,
        dissolves: dissolveBubble,
        holdAfterTyping: holdAfterTyping,
        maxWidth: HatiLayout.bubbleMaxWidth,
        maxHeight: HatiLayout.bubbleMaxHeight,
        onTypingComplete: dissolveBubble ? null : onSequenceComplete,
        onDismissed: dissolveBubble
            ? () {
                onBubbleDismissed?.call();
                onSequenceComplete?.call();
              }
            : null,
      );
    } else if (dissolveBubble) {
      bubble = _AnimatedHatiSpeechBubble(
        key: ValueKey(persistentMessage),
        message: persistentMessage,
        dissolves: true,
        holdAfterTyping: holdAfterTyping,
        maxWidth: HatiLayout.bubbleMaxWidth,
        maxHeight: HatiLayout.bubbleMaxHeight,
        onDismissed: () {
          onBubbleDismissed?.call();
          onSequenceComplete?.call();
        },
      );
    } else {
      bubble = HatiSpeechSequence(
        introMessage: introMessage,
        persistentMessage: persistentMessage,
        onSequenceComplete: onSequenceComplete,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        bubble,
        const SizedBox(height: 8),
        HatiFrogAvatar(size: frogSize),
      ],
    );
  }
}

/// Speech bubble only (no frog) — for use in [HatiCoachZone].
class HatiCoachSpeech extends StatelessWidget {
  final String introMessage;
  final String persistentMessage;
  final String? replacementMessage;
  final VoidCallback? onSequenceComplete;
  final VoidCallback? onBubbleDismissed;
  final bool dissolveBubble;
  final Duration holdAfterTyping;

  const HatiCoachSpeech({
    super.key,
    this.introMessage = '',
    this.persistentMessage = '',
    this.replacementMessage,
    this.onSequenceComplete,
    this.onBubbleDismissed,
    this.dissolveBubble = false,
    this.holdAfterTyping = const Duration(seconds: 2),
  });

  @override
  Widget build(BuildContext context) {
    if (replacementMessage != null) {
      return _AnimatedHatiSpeechBubble(
        key: ValueKey(replacementMessage),
        message: replacementMessage!,
        dissolves: dissolveBubble,
        holdAfterTyping: holdAfterTyping,
        maxWidth: HatiLayout.bubbleMaxWidth,
        maxHeight: HatiLayout.bubbleMaxHeight,
        onTypingComplete: dissolveBubble ? null : onSequenceComplete,
        onDismissed: dissolveBubble
            ? () {
                onBubbleDismissed?.call();
                onSequenceComplete?.call();
              }
            : null,
      );
    }
    if (dissolveBubble) {
      return _AnimatedHatiSpeechBubble(
        key: ValueKey(persistentMessage),
        message: persistentMessage,
        dissolves: true,
        holdAfterTyping: holdAfterTyping,
        maxWidth: HatiLayout.bubbleMaxWidth,
        maxHeight: HatiLayout.bubbleMaxHeight,
        onDismissed: () {
          onBubbleDismissed?.call();
          onSequenceComplete?.call();
        },
      );
    }
    return HatiSpeechSequence(
      introMessage: introMessage,
      persistentMessage: persistentMessage,
      onSequenceComplete: onSequenceComplete,
    );
  }
}

/// Frog fixed in the center band; bubble floats above (separate layer).
class HatiCoachZone extends StatelessWidget {
  final String introMessage;
  final String persistentMessage;
  final String? replacementMessage;
  final VoidCallback? onSequenceComplete;
  final VoidCallback? onBubbleDismissed;
  final bool dissolveBubble;
  final Duration holdAfterTyping;
  final bool showBubble;
  final double frogWidthScale;

  const HatiCoachZone({
    super.key,
    this.introMessage = '',
    this.persistentMessage = '',
    this.replacementMessage,
    this.onSequenceComplete,
    this.onBubbleDismissed,
    this.dissolveBubble = false,
    this.holdAfterTyping = const Duration(seconds: 2),
    this.showBubble = true,
    this.frogWidthScale = 1,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: HatiLayout.coachZoneHeight,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.bottomCenter,
        children: [
          if (showBubble)
            Positioned(
              bottom: HatiLayout.frogSize + 10,
              left: HatiLayout.horizontalPadding,
              right: HatiLayout.horizontalPadding,
              child: Align(
                alignment: Alignment.bottomCenter,
                child: HatiCoachSpeech(
                  key: ValueKey(replacementMessage ?? persistentMessage),
                  introMessage: introMessage,
                  persistentMessage: persistentMessage,
                  replacementMessage: replacementMessage,
                  onSequenceComplete: onSequenceComplete,
                  onBubbleDismissed: onBubbleDismissed,
                  dissolveBubble: dissolveBubble,
                  holdAfterTyping: holdAfterTyping,
                ),
              ),
            ),
          HatiFrogAvatar(
            size: HatiLayout.frogSize,
            widthScale: frogWidthScale,
          ),
        ],
      ),
    );
  }
}

/// Fixed bottom bar for primary actions (does not move with the frog).
class HatiFixedBottomBar extends StatelessWidget {
  final Widget child;

  const HatiFixedBottomBar({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: HatiColors.divider)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(top: false, child: child),
    );
  }
}

/// Coach zone (center) + scrollable body + pinned bottom actions.
class HatiSceneShell extends StatelessWidget {
  final bool showCoach;
  final String introMessage;
  final String persistentMessage;
  final String? replacementMessage;
  final VoidCallback? onSequenceComplete;
  final bool showBubble;
  final double frogWidthScale;
  final Widget? body;
  final Widget? bottomBar;

  const HatiSceneShell({
    super.key,
    this.showCoach = true,
    this.introMessage = '',
    this.persistentMessage = '',
    this.replacementMessage,
    this.onSequenceComplete,
    this.showBubble = true,
    this.frogWidthScale = 1,
    this.body,
    this.bottomBar,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: Column(
            children: [
              if (showCoach)
                HatiCoachZone(
                  introMessage: introMessage,
                  persistentMessage: persistentMessage,
                  replacementMessage: replacementMessage,
                  onSequenceComplete: onSequenceComplete,
                  showBubble: showBubble,
                  frogWidthScale: frogWidthScale,
                ),
              Expanded(
                child: _ScrollHintArea(
                  padding: const EdgeInsets.fromLTRB(
                    HatiLayout.horizontalPadding,
                    8,
                    HatiLayout.horizontalPadding,
                    16,
                  ),
                  child: body ?? const SizedBox.shrink(),
                ),
              ),
            ],
          ),
        ),
        if (bottomBar != null) HatiFixedBottomBar(child: bottomBar!),
      ],
    );
  }
}

/// A scrollable region that shows a fading edge + a gently bouncing
/// chevron at the bottom whenever there's more content below the fold —
/// e.g. a long list of choice chips/cards that the fixed coach zone above
/// pushes past the visible area. Hides itself once there's nothing left
/// to scroll to (including when the content already fits with no
/// scrolling needed at all).
class _ScrollHintArea extends StatefulWidget {
  final EdgeInsetsGeometry padding;
  final Widget child;

  const _ScrollHintArea({required this.padding, required this.child});

  @override
  State<_ScrollHintArea> createState() => _ScrollHintAreaState();
}

class _ScrollHintAreaState extends State<_ScrollHintArea> {
  final ScrollController _controller = ScrollController();
  bool _hasMoreBelow = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_updateHint);
    WidgetsBinding.instance.addPostFrameCallback((_) => _updateHint());
  }

  void _updateHint() {
    if (!_controller.hasClients) return;
    final position = _controller.position;
    // A few px of slack so rounding at the very bottom doesn't leave the
    // hint flickering on/off.
    final hasMore = position.maxScrollExtent - position.pixels > 4;
    if (hasMore != _hasMoreBelow) {
      setState(() => _hasMoreBelow = hasMore);
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_updateHint);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        NotificationListener<ScrollMetricsNotification>(
          onNotification: (_) {
            // Fires when content size/viewport changes (e.g. options load
            // in), after the frame that produced it — safe to check now.
            WidgetsBinding.instance.addPostFrameCallback((_) => _updateHint());
            return false;
          },
          child: SingleChildScrollView(
            controller: _controller,
            padding: widget.padding,
            child: widget.child,
          ),
        ),
        if (_hasMoreBelow)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: IgnorePointer(
              child: Container(
                height: 40,
                alignment: Alignment.bottomCenter,
                padding: const EdgeInsets.only(bottom: 4),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.white.withValues(alpha: 0),
                      Colors.white.withValues(alpha: 0.95),
                    ],
                  ),
                ),
                child: const _BouncingChevron(),
              ),
            ),
          ),
      ],
    );
  }
}

class _BouncingChevron extends StatefulWidget {
  const _BouncingChevron();

  @override
  State<_BouncingChevron> createState() => _BouncingChevronState();
}

class _BouncingChevronState extends State<_BouncingChevron>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _offset;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..repeat(reverse: true);
    _offset = Tween<double>(begin: 0, end: 5).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _offset,
      builder: (context, child) => Transform.translate(
        offset: Offset(0, _offset.value),
        child: child,
      ),
      child: Icon(
        Icons.keyboard_arrow_down_rounded,
        color: HatiColors.mossGreen.withValues(alpha: 0.6),
        size: 24,
      ),
    );
  }
}

class _HatiFrogAvatarState extends State<HatiFrogAvatar>
    with SingleTickerProviderStateMixin {
  AnimationController? _controller;

  @override
  void initState() {
    super.initState();
    if (widget.animate) {
      _controller = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 1200),
      )..repeat();
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.animate || _controller == null) {
      return HatiFrogSprite(
        size: widget.size,
        widthScale: widget.widthScale,
      );
    }

    return AnimatedBuilder(
      animation: _controller!,
      builder: (context, _) {
        final frame = (_controller!.value * hatiFrogFrameCount)
            .floor()
            .clamp(0, hatiFrogFrameCount - 1);
        return HatiFrogSprite(
          frameIndex: frame,
          size: widget.size,
          widthScale: widget.widthScale,
        );
      },
    );
  }
}
