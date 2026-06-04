import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../flow/dataleon_flow_controller.dart';
import '../widgets/dataleon_step_header.dart';

/// Mirrors React's ChainedDocumentIntroStep + Footer CTA for step 6 intro.
///
/// Shows the `intro_custom_document` markdown content from webviewConfig,
/// then lets the user proceed to the actual chained document capture.
class ChainedDocumentIntroStepPage extends StatelessWidget {
  const ChainedDocumentIntroStepPage({
    super.key,
    required this.controller,
  });

  final DataleonFlowController controller;

  String get _lang => controller.languageCode;

  @override
  Widget build(BuildContext context) {
    final dashboardConfiguration = controller.dashboardConfiguration;
    final adConfig = controller.advancedDesignConfiguration;
    final uniformColor = adConfig['uniformPrincipalColor'] == true;

    final buttonColor = _parseColor(
      dashboardConfiguration['buttonColor'] as String?,
      const Color(0xFF111827),
    );
    final effectiveButtonColor = uniformColor
        ? _parseColor(dashboardConfiguration['buttonColor'] as String?,
            const Color(0xFF111827))
        : buttonColor;
    final buttonTextColor = _parseColor(
      dashboardConfiguration['buttonTextColor'] as String?,
      Colors.white,
    );

    final wc = controller.webviewConfig;
    final rawContent = wc['intro_custom_document'] as String? ?? '';
    final ctaLabel = (wc['intro_custom_document_cta'] as String?)?.trim() ??
        (_lang.startsWith('fr') ? 'Démarrer la vérification' : 'Start verification');

    return Container(
      color: Colors.white,
      child: SafeArea(
        child: Column(
          children: [
            DataleonStepHeader(
              controller: controller,
              onBack: controller.exitChainedDocumentFlow,
            ),

            // Content area
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                child: _SimpleMarkdown(content: rawContent, lang: _lang),
              ),
            ),

            // CTA button
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: controller.chainedDocumentIntroComplete,
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size.fromHeight(54),
                    backgroundColor: effectiveButtonColor,
                    foregroundColor: buttonTextColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          ctaLabel,
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Icon(Icons.arrow_forward, size: 18),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Minimal inline Markdown renderer — no external packages required.
// Handles paragraphs, headings, bold, italic, links, images, lists,
// and the special ❔ bullet pattern from ChainedDocumentIntroStep.tsx.
// ---------------------------------------------------------------------------

class _SimpleMarkdown extends StatelessWidget {
  const _SimpleMarkdown({required this.content, required this.lang});

  final String content;
  final String lang;

  @override
  Widget build(BuildContext context) {
    if (content.trim().isEmpty) return const SizedBox.shrink();

    final blocks = _parseBlocks(content);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: blocks.map((block) => _buildBlock(block)).toList(),
    );
  }

  // ---- block-level parsing -----------------------------------------------

  List<_Block> _parseBlocks(String text) {
    final lines = text.split('\n');
    final blocks = <_Block>[];
    final paragraphLines = <String>[];

    void flushParagraph() {
      if (paragraphLines.isEmpty) return;
      final joined = paragraphLines.join('\n').trim();
      if (joined.isNotEmpty) blocks.add(_Block.paragraph(joined));
      paragraphLines.clear();
    }

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];

      // Blank line → flush pending paragraph
      if (line.trim().isEmpty) {
        flushParagraph();
        continue;
      }

      // Heading
      final headingMatch = RegExp(r'^(#{1,3})\s+(.+)$').firstMatch(line);
      if (headingMatch != null) {
        flushParagraph();
        final level = headingMatch.group(1)!.length;
        blocks.add(_Block.heading(headingMatch.group(2)!.trim(), level));
        continue;
      }

      // List item
      final listMatch = RegExp(r'^[\-\*]\s+(.+)$').firstMatch(line);
      if (listMatch != null) {
        flushParagraph();
        blocks.add(_Block.listItem(listMatch.group(1)!.trim()));
        continue;
      }

      // Image  ![alt](url)
      final imageMatch =
          RegExp(r'^!\[([^\]]*)\]\(([^)]+)\)$').firstMatch(line.trim());
      if (imageMatch != null) {
        flushParagraph();
        blocks.add(_Block.image(
          imageMatch.group(1) ?? '',
          imageMatch.group(2)!,
        ));
        continue;
      }

      paragraphLines.add(line);
    }

    flushParagraph();
    return blocks;
  }

  // ---- widget per block --------------------------------------------------

  Widget _buildBlock(_Block block) {
    switch (block.type) {
      case _BlockType.heading:
        return Padding(
          padding: const EdgeInsets.only(top: 14, bottom: 4),
          child: Text(
            block.text,
            style: TextStyle(
              fontSize: block.level == 1
                  ? 22
                  : block.level == 2
                      ? 18
                      : 15,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF111827),
              height: 1.3,
            ),
          ),
        );

      case _BlockType.listItem:
        return Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(top: 7, right: 8),
                child: CircleAvatar(
                  radius: 3,
                  backgroundColor: Color(0xFF6B7280),
                ),
              ),
              Expanded(child: _inlineText(block.text)),
            ],
          ),
        );

      case _BlockType.image:
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 112),
              child: Image.network(
                block.text,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              ),
            ),
          ),
        );

      case _BlockType.paragraph:
        final emojiMatch =
            RegExp(r'^\*\*❔\s*(.+)\*\*$').firstMatch(block.text.trim());
        if (emojiMatch != null) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 6, top: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 20,
                  height: 20,
                  decoration: const BoxDecoration(
                    color: Color(0xFFDC2626),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.lightbulb_outline,
                    size: 12,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    emojiMatch.group(1)!.trim(),
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: Color(0xFFDC2626),
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
          );
        }
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _inlineText(block.text),
        );
    }
  }

  // ---- inline spans (bold, italic, links, ❔ bullet) ----------------------

  Widget _inlineText(String text) {
    return Text.rich(
      TextSpan(children: _parseInline(text)),
      style: const TextStyle(
        fontSize: 14,
        color: Color(0xFF374151),
        height: 1.6,
      ),
    );
  }

  List<InlineSpan> _parseInline(String text) {
    final spans = <InlineSpan>[];

    // Regex that matches: **bold**, *italic*, [link](url), bare text
    final pattern = RegExp(
      r'\*\*([^*]+)\*\*'   // **bold**
      r'|\*([^*]+)\*'       // *italic*
      r'|\[([^\]]+)\]\(([^)]+)\)', // [text](url)
    );

    var cursor = 0;
    for (final match in pattern.allMatches(text)) {
      if (match.start > cursor) {
        spans.add(TextSpan(text: text.substring(cursor, match.start)));
      }

      if (match.group(1) != null) {
        // **bold** — check for ❔ special pattern
        final boldText = match.group(1)!;
        if (boldText.contains('❔')) {
          final clean = boldText.replaceAll(RegExp(r'❔\s*'), '').trim();
          spans.add(
            WidgetSpan(
              alignment: PlaceholderAlignment.middle,
              child: Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 4,
                children: [
                  Container(
                    width: 18,
                    height: 18,
                    decoration: const BoxDecoration(
                      color: Color(0xFFDC2626),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.lightbulb_outline,
                      size: 11,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    clean,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: Color(0xFFDC2626),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          );
        } else {
          spans.add(TextSpan(
            text: boldText,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ));
        }
      } else if (match.group(2) != null) {
        // *italic*
        spans.add(TextSpan(
          text: match.group(2)!,
          style: const TextStyle(fontStyle: FontStyle.italic),
        ));
      } else if (match.group(3) != null && match.group(4) != null) {
        // [text](url)
        final label = match.group(3)!;
        final href = match.group(4)!;
        spans.add(TextSpan(
          text: label,
          style: const TextStyle(
            color: Color(0xFF2563EB),
            decoration: TextDecoration.underline,
          ),
          recognizer: TapGestureRecognizer()
            ..onTap = () {
              final uri = Uri.tryParse(href);
              if (uri != null) {
                launchUrl(uri, mode: LaunchMode.externalApplication);
              }
            },
        ));
      }

      cursor = match.end;
    }

    if (cursor < text.length) {
      spans.add(TextSpan(text: text.substring(cursor)));
    }

    return spans;
  }
}

// ---------------------------------------------------------------------------
// Block model
// ---------------------------------------------------------------------------

enum _BlockType { heading, paragraph, listItem, image }

class _Block {
  const _Block._({
    required this.type,
    required this.text,
    this.level = 1,
  });

  factory _Block.heading(String text, int level) =>
      _Block._(type: _BlockType.heading, text: text, level: level);
  factory _Block.paragraph(String text) =>
      _Block._(type: _BlockType.paragraph, text: text);
  factory _Block.listItem(String text) =>
      _Block._(type: _BlockType.listItem, text: text);
  factory _Block.image(String alt, String url) =>
      _Block._(type: _BlockType.image, text: url);

  final _BlockType type;
  final String text;
  final int level;
}

Color _parseColor(String? rawColor, Color fallback) {
  if (rawColor == null || rawColor.isEmpty) return fallback;
  final normalized = rawColor.replaceAll('#', '');
  final hex = normalized.length == 6 ? 'FF$normalized' : normalized;
  final value = int.tryParse(hex, radix: 16);
  return value == null ? fallback : Color(value);
}
