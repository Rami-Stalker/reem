import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:reem/core/design_system/design_system.dart';
import 'package:reem/core/errors/failure_exception.dart';
import 'package:reem/core/localization/l10n_extension.dart';
import 'package:reem/core/router/route_paths.dart';
import 'package:reem/features/catalog/domain/entities/category_node.dart';
import 'package:reem/features/catalog/presentation/providers/categories_provider.dart';

/// The shop's departments, from the catalogue's own tree.
///
/// This page used to hold a hand-written list of eight departments, on the
/// stated grounds that "the client has no categories endpoint yet". It does —
/// `GET /categories` is public and `categoryTreeProvider` has been reading it
/// for the search screen all along. So the grid named departments the shop
/// might not stock, in a fixed order, and could never show a ninth.
///
/// Worse than the list was where a tile went: it pushed the department's
/// *display name* into free-text search, while `home_categories_showcase` and
/// the search screen both push `categoryOf(slug)`. The same tap meant two
/// different things depending on where she made it, and one of them was a
/// keyword guess against a translated label.
///
/// The palette stays local. A colour per department is presentation, and the
/// catalogue has no opinion about it; it is assigned by position so the grid
/// looks deliberate however many departments come back.
class CategoriesScreen extends ConsumerWidget {
  const CategoriesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tree = ref.watch(categoryTreeProvider);

    return ReemScrollPage(
      slivers: [
        PremiumAppBar(title: context.l10n.categories, showBack: true),
        switch (tree) {
          AsyncData(:final value) => _grid(_departmentsOf(value)),
          AsyncError(:final error) => SliverFillRemaining(
            hasScrollBody: false,
            child: DsErrorState(
              message: messageOf(error),
              onRetry: () => ref.invalidate(categoryTreeProvider),
            ),
          ),
          _ => const SliverFillRemaining(
            hasScrollBody: false,
            child: Center(child: DsLoadingIndicator()),
          ),
        },
        DsGaps.sliverBottomSafe,
      ],
    );
  }

  /// Level one, or the roots themselves where a root has no children — the
  /// same reading the search screen's chips take, so the two never disagree
  /// about what a department is.
  List<CategoryNode> _departmentsOf(List<CategoryNode> roots) => [
    for (final root in roots) ...root.children.isEmpty ? [root] : root.children,
  ];

  Widget _grid(List<CategoryNode> departments) {
    if (departments.isEmpty) {
      return const SliverFillRemaining(
        hasScrollBody: false,
        child: _EmptyDepartments(),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.all(DsSpacing.lg),
      sliver: SliverGrid.builder(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: DsSpacing.md,
          crossAxisSpacing: DsSpacing.md,
          childAspectRatio: 0.95,
        ),
        itemCount: departments.length,
        itemBuilder: (context, index) =>
            _DepartmentCard(department: departments[index], index: index),
      ),
    );
  }
}

/// Colour and icon by position, cycled so the grid never runs out.
const _palette = <Gradient>[
  DsGradients.primarySoft,
  DsGradients.lavenderBlush,
  DsGradients.sunset,
  DsGradients.champagne,
  DsGradients.rewards,
  DsGradients.accent,
  DsGradients.primary,
  DsGradients.soft,
];

const _icons = <IconData>[
  Icons.checkroom_rounded,
  Icons.face_retouching_natural,
  Icons.shopping_bag_rounded,
  Icons.diamond_outlined,
  Icons.card_giftcard_rounded,
  Icons.roller_skating_rounded,
  Icons.shopping_basket_rounded,
  Icons.spa_rounded,
];

class _DepartmentCard extends StatelessWidget {
  const _DepartmentCard({required this.department, required this.index});

  final CategoryNode department;
  final int index;

  @override
  Widget build(BuildContext context) {
    final text = context.dsText;
    final gradient = _palette[index % _palette.length];
    final icon = _icons[index % _icons.length];
    // What sits under a department: its own children, or the pieces in it.
    final subtitle = department.children.isEmpty
        ? department.crumb
        : department.children.map((child) => child.name).take(3).join(' · ');

    return DsStaggerAnimations.item(
      index: index,
      child: SurfaceCard(
        // The slug, like everywhere else that opens a category. The display
        // name went to free-text search and matched whatever it happened to.
        onTap: () =>
            context.push(RoutePaths.categoryOf(department.category.slug)),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: DsSizes.avatarXl,
              height: DsSizes.avatarXl,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: gradient,
                boxShadow: [
                  BoxShadow(
                    color: gradient.colors.first.withValues(alpha: 0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Icon(icon, size: DsSizes.iconLg, color: DsColors.onMedia),
            ),
            DsGaps.vMd,
            Text(
              department.name,
              textAlign: TextAlign.center,
              style: text.tileTitle.bold,
            ),
            DsGaps.vXxs,
            Text(
              subtitle,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: text.caption,
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyDepartments extends StatelessWidget {
  const _EmptyDepartments();

  @override
  Widget build(BuildContext context) => DsEmptyState(
    icon: Icons.category_outlined,
    title: context.l10n.emptyFeed,
  );
}
