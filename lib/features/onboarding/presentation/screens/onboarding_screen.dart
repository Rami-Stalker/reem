import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design_system/design_system.dart';
import '../../../../core/router/route_paths.dart';
import '../providers/onboarding_provider.dart';
import 'onboarding_data.dart';

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
    if (_index >= onboardingItems.length - 1) {
      await ref.read(onboardingNotifierProvider.notifier).complete();
      if (mounted) context.go(RoutePaths.login);
      return;
    }
    _controller.nextPage(
      duration: DsMotion.moderate,
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.dsColors;
    return Scaffold(
      body: Stack(
        children: [
          PageView.builder(
            controller: _controller,
            itemCount: onboardingItems.length,
            onPageChanged: (i) => setState(() => _index = i),
            itemBuilder: (context, index) {
              final item = onboardingItems[index];
              return Stack(
                fit: StackFit.expand,
                children: [
                  Image.network(item.image, fit: BoxFit.cover),
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
                        Text(item.emoji, style: const TextStyle(fontSize: 48)),
                        const SizedBox(height: DsSpacing.md),
                        Text(
                          item.title,
                          style: TextStyle(
                            fontFamily: DsTypography.fontFamily,
                            color: colors.onPrimary,
                            fontSize: 36,
                            fontWeight: DsTypography.bold,
                          ),
                        ),
                        const SizedBox(height: DsSpacing.sm),
                        Text(
                          item.subtitle,
                          style: TextStyle(
                            color: colors.onPrimary.withValues(alpha: 0.92),
                            fontSize: DsTypography.bodyLarge,
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 100),
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
                      onboardingItems.length,
                      (i) => AnimatedContainer(
                        duration: DsMotion.fast,
                        margin: const EdgeInsets.symmetric(horizontal: 4),
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
                    label: _index == onboardingItems.length - 1
                        ? 'Start shopping'
                        : 'Continue',
                    onPressed: _next,
                  ),
                  const SizedBox(height: DsSpacing.md),
                  if (_index < onboardingItems.length - 1)
                    TextButton(
                      onPressed: () => context.go(RoutePaths.home),
                      child: Text(
                        'Skip',
                        style: TextStyle(color: colors.onPrimary),
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
