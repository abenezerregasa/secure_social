import 'package:flutter/material.dart';
import '../core/app_theme.dart';

class ExpandableText extends StatefulWidget {
  const ExpandableText(
    this.text, {
    super.key,
    this.trimLines = 3,
    this.style,
  });

  final String text;
  final int trimLines;
  final TextStyle? style;

  @override
  State<ExpandableText> createState() => _ExpandableTextState();
}

class _ExpandableTextState extends State<ExpandableText> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final txt = widget.text.trim();
    if (txt.isEmpty) {
      return Text(
        '(empty)', 
        style: TextStyle(color: Colors.grey.shade400, fontStyle: FontStyle.italic)
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        // We use TextPainter to check for overflow (Logic Unchanged)
        final span = TextSpan(text: txt, style: widget.style);
        final tp = TextPainter(
          text: span,
          maxLines: widget.trimLines,
          textDirection: TextDirection.ltr,
        )..layout(maxWidth: constraints.maxWidth);

        final hasOverflow = tp.didExceedMaxLines;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // AnimatedSwitcher makes the expansion feel "Serious" and smooth
            AnimatedSize(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeInOut,
              alignment: Alignment.topCenter,
              child: Text(
                txt,
                style: widget.style?.copyWith(
                  height: 1.4, // Professional line-height
                ),
                maxLines: _expanded ? null : widget.trimLines,
                overflow: _expanded ? TextOverflow.visible : TextOverflow.ellipsis,
              ),
            ),
            if (hasOverflow) ...[
              const SizedBox(height: 6),
              GestureDetector(
                onTap: () {
                  setState(() => _expanded = !_expanded);
                },
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _expanded ? 'Show less' : 'Read more',
                          style: TextStyle(
                            color: AppColors.accent,
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          _expanded 
                            ? Icons.keyboard_arrow_up_rounded 
                            : Icons.keyboard_arrow_down_rounded,
                          size: 16,
                          color: AppColors.accent,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ]
          ],
        );
      },
    );
  }
}