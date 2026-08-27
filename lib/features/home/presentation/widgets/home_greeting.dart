import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:reem/core/design_system/design_system.dart';
import 'package:reem/core/localization/l10n_extension.dart';
import 'package:reem/features/auth/presentation/providers/auth_provider.dart';

/// The opening line of the home screen.
///
/// Deliberately unboxed — the old panel spent a full card on a hello and
/// pushed the merchandise below the fold. Set straight on the silk backdrop,
/// the display serif does the welcoming and the products start higher. Her
/// name is the one word on the page painted in the brand gradient, so the
/// greeting reads personal without a card around it.
class HomeGreeting extends ConsumerWidget {
  const HomeGreeting({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authNotifierProvider.select((s) => s.user));
    final colors = context.dsColors;
    final l10n = context.l10n;

    final firstName = _firstName(user?.name);
    final headline = firstName == null
        ? l10n.homeGreetingGuest
        : l10n.homeGreetingNamed(firstName);

    final headlineStyle = TextStyle(
      color: colors.onBackground,
      fontFamily: DsTypography.fontFamilyDisplay,
      fontFamilyFallback: DsTypography.displayFallback,
      fontSize: 34,
      fontWeight: DsTypography.bold,
      height: 1.15,
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        DsSpacing.lg,
        DsSpacing.xs,
        DsSpacing.lg,
        DsSpacing.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              DsSparkle(size: 11, color: colors.accent),
              const SizedBox(width: DsSpacing.xxs),
              Text(
                _timeOfDay(context),
                style: DsTypography.overline(colors.primary),
              ),
            ],
          ),
          const SizedBox(height: DsSpacing.xxs),
          // The greeting sentence is one string from the ARB (word order is not
          // ours to assume across ar/en), so the gradient is applied to the
          // whole line rather than surgically to the name.
          DsGradientText(
            headline,
            style: headlineStyle,
            gradient: context.rewardsGradient,
          ),
          const SizedBox(height: DsSpacing.xs),
          Text(
            l10n.homeGreetingSubtitle,
            style: TextStyle(
              color: colors.onSurfaceVariant,
              fontSize: DsTypography.bodyMedium,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }

  /// The shopper's first name, or `null` when we have nothing to greet by —
  /// in which case the copy switches to «أهلاً فيكِ» rather than a placeholder.
  static String? _firstName(String? fullName) {
    final trimmed = fullName?.trim() ?? '';
    if (trimmed.isEmpty) return null;
    return trimmed.split(RegExp(r'\s+')).first;
  }

  String _timeOfDay(BuildContext context) {
    final hour = DateTime.now().hour;
    if (hour < 12) return context.l10n.goodMorning;
    if (hour < 17) return context.l10n.goodAfternoon;
    return context.l10n.goodEvening;
  }
}
