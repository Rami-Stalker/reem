import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:ohara/core/design_system/design_system.dart';
import 'package:ohara/core/localization/l10n_extension.dart';
import 'package:ohara/core/media/authorized_media_image.dart';
import 'package:ohara/core/router/route_paths.dart';
import 'package:ohara/features/onboarding/presentation/providers/onboarding_provider.dart';
import 'package:ohara/features/onboarding/presentation/screens/onboarding_data.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _controller = PageController();
  int _index = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _next() async {
    if (_index >= onboardingItemCount - 1) {
      await ref.read(onboardingNotifierProvider.notifier).complete();
      if (mounted) context.go(RoutePaths.login);
      return;
    }
    unawaited(
      _controller.nextPage(
        duration: DsMotion.moderate,
        curve: Curves.easeOutCubic,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.dsColors;
    final items = onboardingItems(context);
    return Scaffold(
      body: Stack(
        children: [
          PageView.builder(
            controller: _controller,
            itemCount: items.length,
            onPageChanged: (i) => setState(() => _index = i),
            itemBuilder: (context, index) {
              final item = items[index];
              return Stack(
                fit: StackFit.expand,
                children: [
                  AuthorizedMediaImage(
                    url: item.image,
                    // The first screen of a first run, on a Syrian mobile
                    // connection, is the worst possible moment for a picture
                    // to be missing — and these three are still fetched from
                    // a third-party CDN (see `onboardingItems`). A brand
                    // gradient behind the scrim reads as a designed panel
                    // rather than as the grey box a failed fetch used to
                    // leave.
                    fallback: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: context.primaryGradient,
                      ),
                    ),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          colors.onSurface.withValues(alpha: 0.1),
                          colors.onSurface.withValues(alpha: 0.72),
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(DsSpacing.xl),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ds-ignore: no-hand-rolled-text-styles -- an emoji
                        // rendered as an illustration, not as text in a role.
                        // ds-ignore: no-literal-font-sizes -- same
                        Text(item.emoji, style: const TextStyle(fontSize: 48)),
                        const SizedBox(height: DsSpacing.md),
                        Text(
                          item.title,
                          style: context.dsText.hero.tint(colors.onPrimary),
                        ),
                        const SizedBox(height: DsSpacing.sm),
                        Text(
                          item.subtitle,
                          style: context.dsText.bodyLarge
                              .tint(colors.onPrimary.withValues(alpha: 0.92))
                              .copyWith(height: 1.5),
                        ),
                        // Clears the pager dots and the primary action.
                        const SizedBox(height: DsSizes.bottomSafeGap),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(DsSpacing.lg),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      items.length,
                      (i) => AnimatedContainer(
                        duration: DsMotion.fast,
                        margin: const EdgeInsets.symmetric(
                          horizontal: DsSpacing.xxs,
                        ),
                        width: _index == i ? 28 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          borderRadius: DsRadius.borderFull,
                          color: _index == i
                              ? colors.onPrimary
                              : colors.onPrimary.withValues(alpha: 0.4),
                        ),
                      ),
                    ),
                  ),
                  const Spacer(),
                  PrimaryButton(
                    label: _index == items.length - 1
                        ? context.l10n.onboardStart
                        : context.l10n.onboardContinue,
                    onPressed: _next,
                  ),
                  const SizedBox(height: DsSpacing.md),
                  if (_index < items.length - 1)
                    TextButton(
                      onPressed: () => context.go(RoutePaths.home),
                      child: Text(
                        context.l10n.onboardSkip,
                        style: context.dsText.body.tint(colors.onPrimary),
                      ),
                    ),
                  const SizedBox(height: DsSpacing.lg),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
