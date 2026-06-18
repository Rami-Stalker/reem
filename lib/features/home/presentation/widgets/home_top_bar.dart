import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design_system/design_system.dart';
import '../../../../core/router/route_paths.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

/// Pinned, glassy home app bar: the Reem wordmark, notifications and the
/// current user's avatar.
class HomeTopBar extends ConsumerWidget {
  const HomeTopBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.dsColors;
    final user = ref.watch(authNotifierProvider.select((s) => s.user));

    return SliverAppBar(
      pinned: true,
      floating: true,
      elevation: 0,
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      titleSpacing: DsSpacing.lg,
      toolbarHeight: 64,
      flexibleSpace: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: DsBlur.medium, sigmaY: DsBlur.medium),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  c.background.withValues(alpha: 0.88),
                  c.background.withValues(alpha: 0.30),
                ],
              ),
            ),
          ),
        ),
      ),
      title: ShaderMask(
        blendMode: BlendMode.srcIn,
        shaderCallback: (bounds) =>
            context.primaryGradient.createShader(bounds),
        child: const Text(
          'Reem',
          style: TextStyle(
            fontFamily: DsTypography.fontFamilyDisplay,
            fontFamilyFallback: DsTypography.displayFallback,
            fontSize: 30,
            fontWeight: DsTypography.bold,
            letterSpacing: 0.5,
            color: Colors.white,
          ),
        ),
      ),
      actions: [
        _NotificationsBell(
          onTap: () => context.push(RoutePaths.notifications),
        ),
        const SizedBox(width: DsSpacing.xs),
        Padding(
          padding: const EdgeInsets.only(right: DsSpacing.lg),
          child: DsAvatar(
            imageUrl: user?.imageUrl,
            name: user?.name,
            size: 38,
            onTap: () => context.push(RoutePaths.profile),
          ),
        ),
      ],
    );
  }
}

class _NotificationsBell extends StatelessWidget {
  const _NotificationsBell({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        DsIconButton(
          icon: Icons.notifications_none_rounded,
          variant: DsIconButtonVariant.surface,
          size: 40,
          onPressed: onTap,
        ),
        Positioned(
          top: 8,
          right: 9,
          child: Container(
            width: 9,
            height: 9,
            decoration: BoxDecoration(
              color: c.favorite,
              shape: BoxShape.circle,
              border: Border.all(color: c.surface, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }
}
