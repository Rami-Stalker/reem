import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../../core/design_system/design_system.dart';
import '../../../../core/shared/wedgets/inputs/animated_search_bar.dart';

class HomeHeader extends StatelessWidget {
  const HomeHeader({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.dsColors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Hey gorgeous ✨',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                  ),
                  const SizedBox(height: 6),
                  DsGradientText(
                    'Discover Your Glow',
                    style: TextStyle(
                      fontFamily: DsTypography.fontFamily,
                      fontSize: 32,
                      fontWeight: DsTypography.bold,
                      height: 1.15,
                    ),
                  ),
                ],
              ),
            ),
            _ProfileAvatar(colors: colors),
          ],
        ),
        const SizedBox(height: DsSpacing.xl),
        const AnimatedSearchBar(),
      ],
    ).animate().fadeIn(duration: 500.ms).slideY(begin: 0.08);
  }
}

class _ProfileAvatar extends StatelessWidget {
  const _ProfileAvatar({required this.colors});

  final DsColorScheme colors;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: context.storyRingGradient,
        boxShadow: context.luxuryShadow,
      ),
      child: CircleAvatar(
        radius: 26,
        backgroundColor: colors.surface,
        backgroundImage: const NetworkImage(
          'https://images.unsplash.com/photo-1494790108377-be9c29b29330',
        ),
      ),
    );
  }
}
