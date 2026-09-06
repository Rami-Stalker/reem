import 'package:flutter/material.dart';

import 'package:reem/core/design_system/design_system.dart';
import 'package:reem/core/localization/l10n_extension.dart';

/// Pill follow/unfollow control with an in-place loading state.
class FollowButton extends StatelessWidget {
  const FollowButton({
    super.key,
    required this.isFollowing,
    required this.isLoading,
    required this.onPressed,
  });

  final bool isFollowing;
  final bool isLoading;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = context.dsColors;
    final following = isFollowing;
    final fg = following ? colors.onSurface : colors.onPrimary;

    return GestureDetector(
      onTap: isLoading ? null : onPressed,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: DsSpacing.xl),
        decoration: BoxDecoration(
          gradient: following ? null : context.primaryGradient,
          color: following ? colors.surfaceVariant : null,
          borderRadius: BorderRadius.circular(DsRadius.full),
          border: Border.all(
            color: following ? colors.border : Colors.transparent,
          ),
        ),
        child: Center(
          child: isLoading
              ? SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2.2, color: fg),
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      following
                          ? Icons.check_rounded
                          : Icons.person_add_alt_1_rounded,
                      size: 18,
                      color: fg,
                    ),
                    const SizedBox(width: DsSpacing.xs),
                    Text(
                      following
                          ? context.l10n.followingState
                          : context.l10n.followAction,
                      style: context.dsText.body.semibold.tint(fg),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
