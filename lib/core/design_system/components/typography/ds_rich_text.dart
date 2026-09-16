import 'package:flutter/material.dart';

import 'package:reem/core/design_system/foundation/theme/extensions/color_extension.dart';
import 'package:reem/core/design_system/foundation/theme/extensions/typography_extension.dart';
import 'package:reem/core/design_system/foundation/tokens/ds_radius.dart';
import 'package:reem/core/design_system/foundation/tokens/ds_spacing.dart';

/// A long, admin-authored document, rendered.
///
/// **Why this exists rather than a Markdown package.** The body of a policy is
/// text an administrator types into a console and every customer then reads, so
/// the renderer is a trust boundary: whatever it can express, somebody with
/// console access can put on a hundred thousand screens. A general Markdown
/// renderer expresses raw HTML, images from arbitrary hosts and links — a
/// tracking pixel, an off-platform payment link, a spoofed sign-in form. This
/// one expresses headings, paragraphs, lists, tables, rules and bold. Nothing
/// it can draw fetches anything or goes anywhere.
///
/// The grammar, in full:
///
/// ```
/// ## Heading            a section title
/// ### Heading           a sub-heading
/// - item                a bullet
/// 1. item                a numbered item
/// | a | b |             a table row; a row of dashes is the header rule
/// ---                   a horizontal rule
/// **bold**              bold, inline, anywhere
/// (blank line)          a paragraph break
/// ```
///
/// Anything else is a paragraph, which is the right failure: an editor who
/// types a `>` quote gets her text, not an error and not a missing clause.
class DsRichText extends StatelessWidget {
  const DsRichText({super.key, required this.text, this.textAlign});

  final String text;
  final TextAlign? textAlign;

  @override
  Widget build(BuildContext context) {
    final blocks = _parse(text);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < blocks.length; i++)
          Padding(
            padding: EdgeInsets.only(
              top: i == 0 ? 0 : blocks[i].spacingAbove,
            ),
            child: blocks[i].build(context, textAlign),
          ),
      ],
    );
  }

  // ── Parsing ─────────────────────────────────────────────────────────────

  static List<_Block> _parse(String source) {
    final lines = source.replaceAll('\r\n', '\n').split('\n');
    final blocks = <_Block>[];

    // A paragraph is accumulated across lines until a blank one or a line that
    // is unmistakably something else. Soft-wrapping a long clause in the
    // console must not produce six one-line paragraphs on the phone.
    final paragraph = <String>[];
    void flush() {
      if (paragraph.isEmpty) return;
      blocks.add(_Paragraph(paragraph.join(' ').trim()));
      paragraph.clear();
    }

    final table = <List<String>>[];
    void flushTable() {
      if (table.isEmpty) return;
      blocks.add(_Table(List.of(table)));
      table.clear();
    }

    for (final raw in lines) {
      final line = raw.trimRight();
      final trimmed = line.trim();

      if (trimmed.startsWith('|') && trimmed.endsWith('|')) {
        flush();
        final cells = trimmed
            .substring(1, trimmed.length - 1)
            .split('|')
            .map((cell) => cell.trim())
            .toList(growable: false);
        // The `| --- | --- |` separator carries no content; it only says the
        // row above it was a header, which `_Table` assumes of its first row.
        final isRule = cells.every(
          (cell) => cell.isNotEmpty && RegExp(r'^:?-{2,}:?$').hasMatch(cell),
        );
        if (!isRule) table.add(cells);
        continue;
      }
      flushTable();

      if (trimmed.isEmpty) {
        flush();
        continue;
      }

      if (trimmed == '---' || trimmed == '***' || trimmed == '___') {
        flush();
        blocks.add(const _Rule());
        continue;
      }

      if (trimmed.startsWith('### ')) {
        flush();
        blocks.add(_Heading(trimmed.substring(4).trim(), level: 3));
        continue;
      }
      if (trimmed.startsWith('## ')) {
        flush();
        blocks.add(_Heading(trimmed.substring(3).trim(), level: 2));
        continue;
      }
      if (trimmed.startsWith('# ')) {
        flush();
        blocks.add(_Heading(trimmed.substring(2).trim(), level: 1));
        continue;
      }

      if (trimmed.startsWith('- ') || trimmed.startsWith('* ')) {
        flush();
        blocks.add(_Bullet(trimmed.substring(2).trim()));
        continue;
      }

      final numbered = RegExp(r'^(\d+)[.)]\s+(.*)$').firstMatch(trimmed);
      if (numbered != null) {
        flush();
        blocks.add(
          _Bullet(numbered.group(2)!.trim(), marker: '${numbered.group(1)}.'),
        );
        continue;
      }

      paragraph.add(trimmed);
    }

    flush();
    flushTable();
    return blocks;
  }

  /// Splits a line into runs, alternating plain and `**bold**`.
  ///
  /// Kept here rather than in each block so a heading, a bullet and a table
  /// cell all emphasise the same way — an inconsistency a reader notices
  /// immediately in a document this long.
  static List<TextSpan> spansFor(String text, TextStyle base) {
    final spans = <TextSpan>[];
    final pattern = RegExp(r'\*\*(.+?)\*\*', dotAll: true);
    var index = 0;

    for (final match in pattern.allMatches(text)) {
      if (match.start > index) {
        spans.add(TextSpan(text: text.substring(index, match.start)));
      }
      spans.add(
        TextSpan(
          text: match.group(1),
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      );
      index = match.end;
    }
    if (index < text.length) spans.add(TextSpan(text: text.substring(index)));

    return spans.isEmpty ? [TextSpan(text: text)] : spans;
  }
}

// ── Blocks ────────────────────────────────────────────────────────────────

abstract class _Block {
  const _Block();

  double get spacingAbove => DsSpacing.sm;

  Widget build(BuildContext context, TextAlign? align);
}

class _Heading extends _Block {
  const _Heading(this.text, {required this.level});

  final String text;
  final int level;

  @override
  double get spacingAbove => level >= 3 ? DsSpacing.md : DsSpacing.lg;

  @override
  Widget build(BuildContext context, TextAlign? align) {
    final style = switch (level) {
      1 => context.dsText.screenTitle.bold,
      2 => context.dsText.sectionTitle.bold,
      _ => context.dsText.cardTitle.semibold,
    };
    return Text.rich(
      TextSpan(children: DsRichText.spansFor(text, style)),
      style: style.copyWith(height: 1.35),
      textAlign: align,
    );
  }
}

class _Paragraph extends _Block {
  const _Paragraph(this.text);

  final String text;

  @override
  double get spacingAbove => DsSpacing.md;

  @override
  Widget build(BuildContext context, TextAlign? align) {
    // 1.7 rather than the design system's default: a page of Arabic legal
    // prose at the body line height is a wall, and the diacritics need the
    // room.
    final style = context.dsText.body.copyWith(height: 1.7);
    return Text.rich(
      TextSpan(children: DsRichText.spansFor(text, style)),
      style: style,
      textAlign: align,
    );
  }
}

class _Bullet extends _Block {
  const _Bullet(this.text, {this.marker});

  final String text;

  /// `1.` for a numbered item; null draws a dot.
  final String? marker;

  @override
  double get spacingAbove => DsSpacing.xs;

  @override
  Widget build(BuildContext context, TextAlign? align) {
    final colors = context.dsColors;
    final style = context.dsText.body.copyWith(height: 1.6);

    return Padding(
      padding: const EdgeInsetsDirectional.only(start: DsSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // `EdgeInsetsDirectional` and a Row: the marker has to sit on the
          // right of the text in Arabic and on the left in English, and doing
          // that with a hardcoded prefix character is how a bullet ends up
          // stranded mid-sentence when the language flips.
          Padding(
            padding: const EdgeInsets.only(top: 7),
            child: marker == null
                ? Container(
                    width: 5,
                    height: 5,
                    decoration: BoxDecoration(
                      color: colors.primary,
                      shape: BoxShape.circle,
                    ),
                  )
                : Text(
                    marker!,
                    style: context.dsText.caption.semibold.tint(colors.primary),
                  ),
          ),
          const SizedBox(width: DsSpacing.sm),
          Expanded(
            child: Text.rich(
              TextSpan(children: DsRichText.spansFor(text, style)),
              style: style,
            ),
          ),
        ],
      ),
    );
  }
}

class _Rule extends _Block {
  const _Rule();

  @override
  double get spacingAbove => DsSpacing.lg;

  @override
  Widget build(BuildContext context, TextAlign? align) =>
      Divider(height: 1, color: context.dsColors.divider);
}

class _Table extends _Block {
  const _Table(this.rows);

  final List<List<String>> rows;

  @override
  double get spacingAbove => DsSpacing.md;

  @override
  Widget build(BuildContext context, TextAlign? align) {
    final colors = context.dsColors;
    if (rows.isEmpty) return const SizedBox.shrink();

    return Container(
      decoration: BoxDecoration(
        color: colors.surfaceVariant,
        borderRadius: BorderRadius.circular(DsRadius.md),
        border: Border.all(color: colors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var r = 0; r < rows.length; r++)
            Container(
              decoration: BoxDecoration(
                border: r == 0
                    ? Border(bottom: BorderSide(color: colors.border))
                    : null,
              ),
              padding: const EdgeInsets.symmetric(
                horizontal: DsSpacing.md,
                vertical: DsSpacing.sm,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var c = 0; c < rows[r].length; c++)
                    Expanded(
                      // The first column carries the label — «ردّ البائعة على
                      // الشكوى» — and the rest carry a short value, so it gets
                      // the room rather than an even split that wraps every
                      // label onto three lines.
                      flex: c == 0 ? 3 : 2,
                      child: Padding(
                        padding: const EdgeInsetsDirectional.only(
                          end: DsSpacing.sm,
                        ),
                        child: Text.rich(
                          TextSpan(
                            children: DsRichText.spansFor(
                              rows[r][c],
                              r == 0
                                  ? context.dsText.label.semibold
                                  : context.dsText.bodySmall,
                            ),
                          ),
                          style: r == 0
                              ? context.dsText.label.semibold
                              : context.dsText.bodySmall.copyWith(height: 1.5),
                        ),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
