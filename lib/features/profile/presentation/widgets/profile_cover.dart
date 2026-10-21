import 'package:flutter/material.dart';

import 'package:reem/core/design_system/design_system.dart';
import 'package:reem/core/router/open_route.dart';
import 'package:reem/core/shared/entities/user.dart';

/// Branded gradient cover with the user's avatar — the profile's hero.
class ProfileCover extends StatelessWidget {
  const ProfileCover({super.key, required this.user});

  final User user;

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    final canPop = Navigator.of(context).canPop();

    return SliverAppBar(
      expandedHeight: 208,
      pinned: true,
      stretch: true,
      elevation: 0,
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      automaticallyImplyLeading: false,
      leading: canPop
          ? Padding(
              padding: const EdgeInsetsDirectional.only(start: DsSpacing.sm),
              child: Center(
                child: DsIconButton(
                  tooltip: 'رجوع',
                  icon: Icons.arrow_back_ios_new_rounded,
                  variant: DsIconButtonVariant.glass,
                  size: 40,
                  iconSize: 18,
                  color: DsColors.onMedia,
                  onPressed: () => popOrHome(context),
                ),
              ),
            )
          : null,
      flexibleSpace: FlexibleSpaceBar(
        stretchModes: const [StretchMode.zoomBackground],
        background: Stack(
          fit: StackFit.expand,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(gradient: context.primaryGradient),
            ),
            // Soft sheen for depth.
            DecoratedBox(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topRight,
                  end: Alignment.bottomLeft,
                  colors: [DsColors.onMediaFaint, Colors.transparent],
                ),
              ),
            ),
            // Fade the bottom into the page background to seat the avatar.
            Align(
              alignment: Alignment.bottomCenter,
              child: Container(
                height: 90,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [c.background.withValues(alpha: 0), c.background],
                  ),
                ),
              ),
            ),
            Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.only(bottom: DsSpacing.xs),
                child: Container(
                  padding: const EdgeInsets.all(DsSpacing.xxs),
                  decoration: BoxDecoration(
                    color: c.surface,
                    shape: BoxShape.circle,
                    boxShadow: context.shadowMedium,
                  ),
                  child: DsAvatar(
                    imageUrl: user.imageUrl,
                    name: user.name,
                    size: 104,
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
