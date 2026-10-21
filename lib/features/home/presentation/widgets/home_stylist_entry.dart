import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:reem/core/design_system/design_system.dart';
import 'package:reem/core/router/route_paths.dart';

/// The way into Reem AI Stylist, sitting directly under the search bar.
///
/// It goes here rather than in the shell because the buyer's bottom bar
/// deliberately carries no floating action — see `_CustomerProductShell` — and
/// because this is the honest place for it: the search bar answers "I know what
/// I want", and this answers the other half, "I know the occasion but not the
/// piece". Putting the two next to each other is the whole pitch.
class HomeStylistEntry extends StatelessWidget {
  const HomeStylistEntry({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.dsColors;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: DsSpacing.md,
        vertical: DsSpacing.xs,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(DsRadius.field),
        child: InkWell(
          borderRadius: BorderRadius.circular(DsRadius.field),
          onTap: () => context.push(RoutePaths.stylist),
          child: Ink(
            decoration: BoxDecoration(
              gradient: context.ds.primaryGradient,
              borderRadius: BorderRadius.circular(DsRadius.field),
              boxShadow: context.ds.softShadow,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: DsSpacing.md,
                vertical: DsSpacing.sm,
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.auto_awesome_rounded,
                    color: colors.onPrimary,
                    size: 20,
                  ),
                  const SizedBox(width: DsSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'اسألي مساعِدة أوهارا',
                          style: context.dsText.tileTitle.bold.tint(
                            colors.onPrimary,
                          ),
                        ),
                        Text(
                          'احكيلي عن المناسبة وميزانيتك، وبرتّبلك خيارات متوفرة',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.dsText.caption.tint(
                            colors.onPrimary.withValues(alpha: 0.85),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.chevron_left_rounded,
                    color: colors.onPrimary,
                    size: 22,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
