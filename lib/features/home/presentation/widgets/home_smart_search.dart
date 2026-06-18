import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design_system/design_system.dart';
import '../../../../core/router/route_paths.dart';
import '../../domain/entities/search_suggestions.dart';
import '../providers/home_content_provider.dart';

/// The smart search entry: a tappable search field plus trending, suggested and
/// recent queries as quick chips. Tapping anything routes into full search.
class HomeSmartSearch extends ConsumerWidget {
  const HomeSmartSearch({super.key});

  void _search(BuildContext context, [String? query]) {
    final q = (query == null || query.isEmpty)
        ? ''
        : '?q=${Uri.encodeQueryComponent(query)}';
    context.push('${RoutePaths.search}$q');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final suggestions = ref.watch(
      homeContentNotifierProvider
          .select((s) => s.content?.searchSuggestions ?? const SearchSuggestions()),
    );
    final c = context.dsColors;

    return Padding(
      padding: const EdgeInsets.fromLTRB(DsSpacing.lg, 0, DsSpacing.lg, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DsSearchBar(
            hint: 'Search dresses, perfume, gifts…',
            readOnly: true,
            onTap: () => _search(context),
            onFilter: () => _search(context),
          ),
          if (suggestions.trending.isNotEmpty ||
              suggestions.suggested.isNotEmpty) ...[
            const SizedBox(height: DsSpacing.sm),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                children: [
                  Icon(Icons.local_fire_department_rounded,
                      size: 16, color: c.discount),
                  const SizedBox(width: DsSpacing.xxs),
                  Text('Trending', style: DsTypography.overline(c.onSurfaceVariant)),
                  const SizedBox(width: DsSpacing.xs),
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
            ),
          ],
          if (suggestions.recent.isNotEmpty) ...[
            const SizedBox(height: DsSpacing.xs),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                children: [
                  Icon(Icons.history_rounded,
                      size: 16, color: c.onSurfaceVariant),
                  const SizedBox(width: DsSpacing.xxs),
                  Text('Recent', style: DsTypography.overline(c.onSurfaceVariant)),
                  const SizedBox(width: DsSpacing.xs),
                  for (final term in suggestions.recent)
                    _SuggestionChip(
                      label: term,
                      ghost: true,
                      icon: Icons.north_west_rounded,
                      onTap: () => _search(context, term),
                    ),
                ],
              ),
            ),
          ],
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
    final c = context.dsColors;
    final Color bg;
    final Color fg;
    final Border? border;
    if (ghost) {
      bg = Colors.transparent;
      fg = c.onSurfaceVariant;
      border = Border.all(color: c.border);
    } else if (tonal) {
      bg = c.secondaryContainer;
      fg = c.onSecondaryContainer;
      border = null;
    } else {
      bg = c.primaryContainer;
      fg = c.onPrimaryContainer;
      border = null;
    }

    return Padding(
      padding: const EdgeInsets.only(right: DsSpacing.xs),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(
              horizontal: DsSpacing.sm, vertical: DsSpacing.xs),
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
              Text(
                label,
                style: TextStyle(
                  color: fg,
                  fontSize: DsTypography.labelMedium,
                  fontWeight: DsTypography.semiBold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
