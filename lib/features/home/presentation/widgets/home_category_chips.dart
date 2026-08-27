import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design_system/design_system.dart';
import '../../../../core/router/route_paths.dart';
import '../../../../core/shared/entities/post.dart';
import '../../../../core/localization/l10n_extension.dart';

/// Quick category filters. Tapping deep-links into a category browse screen.
class HomeCategoryChips extends StatelessWidget {
  const HomeCategoryChips({super.key});

  @override
  Widget build(BuildContext context) {
    return DsFilterBar(
      options: [
        DsFilterOption(
          label: context.l10n.all,
          icon: Icons.auto_awesome_rounded,
          selected: true,
          onTap: () => context.push(RoutePaths.categories),
        ),
        for (final category in CategoryType.values)
          DsFilterOption(
            label: category.label,
            onTap: () => context.push('/category/${category.name}'),
          ),
      ],
    );
  }
}
