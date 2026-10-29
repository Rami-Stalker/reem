import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:ohara/core/design_system/design_system.dart';
import 'package:ohara/core/localization/l10n_extension.dart';
import 'package:ohara/core/router/route_paths.dart';
import 'package:ohara/features/auth/presentation/providers/auth_provider.dart';
import 'package:ohara/features/onboarding/presentation/providers/onboarding_provider.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Timer(const Duration(seconds: 3), _navigateNext);
  }

  Future<void> _navigateNext() async {
    if (!mounted) return;

    final auth = ref.read(authNotifierProvider);
    if (!auth.isInitialized) {
      await ref.read(authNotifierProvider.notifier).restoreSession();
    }

    final onboarding = ref.read(onboardingNotifierProvider);
    if (!onboarding.isComplete) {
      final isComplete = await ref
          .read(onboardingNotifierProvider.notifier)
          .checkComplete();
      if (!mounted) return;
      if (!isComplete) {
        context.go(RoutePaths.onboarding);
        return;
      }
    }

    if (!mounted) return;
    context.go(RoutePaths.home);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.dsColors;
    return Scaffold(
      body: Stack(
        children: [
          const FeminineMeshBackground(),
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                      width: 130,
                      height: 130,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: DsGradients.storyRing,
                        boxShadow: context.luxuryShadow,
                      ),
                      child: Center(
                        child: Container(
                          width: 118,
                          height: 118,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: context.primaryGradient,
                          ),
                          child: Icon(
                            Icons.favorite_rounded,
                            size: 56,
                            color: colors.onPrimary,
                          ),
                        ),
                      ),
                    )
                    .animate()
                    .scale(duration: 900.ms, curve: Curves.easeOutExpo)
                    .fadeIn(),
                DsGaps.vXxxl,
                OharaWordmark(
                      semanticLabel: l10n.appTitle,
                      size: OharaWordmarkSize.hero,
                    )
                    .animate()
                    .fadeIn(delay: 300.ms, duration: 700.ms)
                    .slideY(begin: 0.2, curve: Curves.easeOutCubic)
                    .then(delay: 200.ms)
                    .shimmer(
                      duration: 1400.ms,
                      color: colors.onPrimary.withValues(alpha: 0.55),
                    ),
                DsGaps.vSm,
                Text(
                  l10n.splashTagline,
                  style: context.dsText.bodyLarge.copyWith(
                    color: colors.onSurfaceVariant,
                    letterSpacing: 1.2,
                  ),
                ).animate().fadeIn(delay: 500.ms),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
