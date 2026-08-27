import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:reem/core/design_system/design_system.dart';
import 'package:reem/core/localization/l10n_extension.dart';
import 'package:reem/core/router/route_paths.dart';
import 'package:reem/features/auth/presentation/providers/auth_provider.dart';

/// Pinned, glassy home app bar: the Reem wordmark, notifications and the
/// current user's avatar.
///
/// The wordmark comes from `appTitle`, so it reads «ريم» in Arabic and "Reem"
/// in English — the two-script logo the client asked for in Q74.
class HomeTopBar extends ConsumerWidget {
  const HomeTopBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authNotifierProvider.select((s) => s.user));
    final colors = context.dsColors;

    return SliverAppBar(
      pinned: true,
      floating: true,
      elevation: 0,
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      titleSpacing: DsSpacing.lg,
      toolbarHeight: 70,
      flexibleSpace: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: DsBlur.medium, sigmaY: DsBlur.medium),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  colors.background.withValues(alpha: 0.96),
                  colors.background.withValues(alpha: 0.42),
                ],
              ),
            ),
          ),
        ),
      ),
      title: ShaderMask(
        blendMode: BlendMode.srcIn,
        shaderCallback: (bounds) =>
            CustomerExperience.signatureGradient.createShader(bounds),
        child: Text(
          context.l10n.appTitle,
          style: const TextStyle(
            fontFamily: DsTypography.fontFamilyDisplay,
            fontFamilyFallback: DsTypography.displayFallback,
            fontSize: 32,
            fontWeight: DsTypography.bold,
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
          padding: const EdgeInsetsDirectional.only(end: DsSpacing.lg),
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
    final colors = context.dsColors;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: colors.surfaceElevated.withValues(alpha: 0.76),
            shape: BoxShape.circle,
            border: Border.all(color: colors.border),
          ),
          child: IconButton(
            tooltip: context.l10n.notifications,
            icon: Icon(
              Icons.notifications_none_rounded,
              color: colors.onSurface,
              size: 21,
            ),
            onPressed: onTap,
          ),
        ),
        PositionedDirectional(
          top: 8,
          end: 9,
          child: Container(
            width: 9,
            height: 9,
            decoration: BoxDecoration(
              color: colors.primary,
              shape: BoxShape.circle,
              border: Border.all(color: colors.surfaceElevated, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }
}
