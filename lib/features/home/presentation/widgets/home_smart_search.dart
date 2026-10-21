import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:reem/core/design_system/design_system.dart';
import 'package:reem/core/localization/l10n_extension.dart';
import 'package:reem/core/router/route_paths.dart';
import 'package:reem/features/home/domain/entities/search_suggestions.dart';
import 'package:reem/features/home/presentation/providers/home_content_provider.dart';

class HomeSmartSearch extends ConsumerWidget {
  const HomeSmartSearch({super.key});

  void _search(BuildContext context, [String? query]) =>
      context.push(RoutePaths.keywordSearchFor(query));

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final suggestions = ref.watch(
      homeContentNotifierProvider.select(
        (s) => s.content?.searchSuggestions ?? const SearchSuggestions(),
      ),
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        DsSpacing.lg,
        DsSpacing.xxxs,
        DsSpacing.lg,
        DsSpacing.xxxs,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CustomerPanel(
            padding: const EdgeInsets.symmetric(
              horizontal: DsSpacing.md,
              vertical: DsSpacing.sm,
            ),
            onTap: () => _search(context),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: CustomerExperience.signatureGradient,
                  ),
                  child: const Icon(
                    Icons.search_rounded,
                    color: DsColors.onMedia,
                  ),
                ),
                const SizedBox(width: DsSpacing.sm),
                Expanded(
                  child: Text(
                    context.l10n.homeSearchHint,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.dsText.body.medium.tint(
                      context.dsColors.onSurfaceVariant,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: context.l10n.filters,
                  onPressed: () => _search(context),
                  icon: Icon(
                    Icons.tune_rounded,
                    color: context.dsColors.onSurface,
                  ),
                ),
              ],
            ),
          ),
          if (suggestions.trending.isNotEmpty ||
              suggestions.suggested.isNotEmpty) ...[
            const SizedBox(height: DsSpacing.sm),
            _SuggestionRail(
              label: context.l10n.trending,
              icon: Icons.local_fire_department_rounded,
              children: [
                for (final term in suggestions.trending)
                  _SuggestionChip(
                    label: term,
                    onTap: () => _search(context, term),
                  ),
                for (final term in suggestions.suggested)
                  _SuggestionChip(
                    label: term,
                    tonal: true,
                    onTap: () => _search(context, term),
                  ),
              ],
            ),
          ],
          if (suggestions.recent.isNotEmpty) ...[
            const SizedBox(height: DsSpacing.xs),
            _SuggestionRail(
              label: context.l10n.recent,
              icon: Icons.history_rounded,
              children: [
                for (final term in suggestions.recent)
                  _SuggestionChip(
                    label: term,
                    ghost: true,
                    icon: Icons.north_west_rounded,
                    onTap: () => _search(context, term),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _SuggestionRail extends StatelessWidget {
  const _SuggestionRail({
    required this.label,
    required this.icon,
    required this.children,
  });

  final String label;
  final IconData icon;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final colors = context.dsColors;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          Icon(icon, size: 16, color: colors.primary),
          const SizedBox(width: DsSpacing.xxs),
          Text(
            label,
            style: context.dsText.caption.bold.tint(colors.onSurfaceVariant),
          ),
          const SizedBox(width: DsSpacing.xs),
          ...children,
        ],
      ),
    );
  }
}

class _SuggestionChip extends StatelessWidget {
  const _SuggestionChip({
    required this.label,
    required this.onTap,
    this.tonal = false,
    this.ghost = false,
    this.icon,
  });

  final String label;
  final VoidCallback onTap;
  final bool tonal;
  final bool ghost;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final colors = context.dsColors;
    final Color bg;
    final Color fg;
    final Border? border;
    if (ghost) {
      bg = Colors.transparent;
      fg = colors.onSurfaceVariant;
      border = Border.all(color: colors.border);
    } else if (tonal) {
      bg = colors.secondaryContainer;
      fg = colors.onSecondaryContainer;
      border = null;
    } else {
      bg = colors.primaryContainer;
      fg = colors.onPrimaryContainer;
      border = null;
    }

    return Padding(
      padding: const EdgeInsetsDirectional.only(end: DsSpacing.xs),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: DsSpacing.sm,
            vertical: DsSpacing.xs,
          ),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: DsRadius.borderFull,
            border: border,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 13, color: fg),
                const SizedBox(width: DsSpacing.xxs),
              ],
              Text(label, style: context.dsText.labelMedium.semibold.tint(fg)),
            ],
          ),
        ),
      ),
    );
  }
}
