import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ohara/core/design_system/design_system.dart';
import 'package:ohara/core/localization/l10n_extension.dart';
import 'package:ohara/core/utils/damascus_time.dart';
import 'package:ohara/features/auth/presentation/providers/auth_provider.dart';
import 'package:ohara/features/home/presentation/providers/home_provider.dart';
import 'package:ohara/l10n/app_localizations.dart';

/// The opening lines of the home screen.
///
/// Deliberately unboxed — the old panel spent a full card on a hello and
/// pushed the merchandise below the fold. Set straight on the silk backdrop,
/// her name is the one line on the page painted in the brand gradient, so the
/// greeting reads personal without a card around it.
///
/// Kept short because the feed now starts right under it: a section-sized
/// hello rather than a display-sized one, and in place of the standing
/// tagline a line of news — how many boutiques have a story up today — so
/// the second line says something that is true this morning and was not
/// yesterday. The tagline comes back on a day with no stories.
class HomeGreeting extends ConsumerWidget {
  const HomeGreeting({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authNotifierProvider.select((s) => s.user));
    final boutiquesWithStories = ref.watch(
      homeNotifierProvider.select(
        (s) => {
          for (final story in s.stories)
            if (story.user.id != user?.id) story.user.id,
        }.length,
      ),
    );
    final colors = context.dsColors;
    final l10n = context.l10n;

    final firstName = _firstName(user?.name);
    final headline = firstName == null
        ? l10n.homeGreetingGuest
        : l10n.homeGreetingNamed(firstName);

    final headlineStyle = context.dsText.sectionTitle
        .tint(colors.onBackground)
        .copyWith(height: 1.2);

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
            boutiquesWithStories > 0
                ? l10n.homeStoriesToday(boutiquesWithStories)
                : l10n.homeGreetingSubtitle,
            style: context.dsText.body
                .tint(colors.onSurfaceVariant)
                .copyWith(height: 1.45),
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

  /// The hello above her name — Damascus's hour, and never the same wording
  /// two days running.
  static String _timeOfDay(BuildContext context) =>
      HomeGreetingCopy.of(context.l10n);
}

/// Which part of a Damascus day it is, and what one says in it.
///
/// Two things were wrong with the line this replaces. It read the handset's
/// clock, so a phone still set to a European timezone wished a Damascus
/// shopper «مساء الخير» over her breakfast; and it had exactly one phrase per
/// slot — the same «صباح الخير» every single morning, which is the register of
/// a utility, not of the boutique this is meant to be.
///
/// Now every slot carries a small bouquet of Levantine openings — صباح
/// الياسمين، صباحك ورد، مساء النور — and the day's date picks one. Deterministic
/// on purpose: the phrase must not shuffle underneath her while the page
/// rebuilds, but it should be a different welcome tomorrow.
enum HomeGreetingSlot {
  /// 05:00–11:59 — صباح.
  morning,

  /// 12:00–16:59 — نهار.
  midday,

  /// 17:00–21:59 — مساء.
  evening,

  /// 22:00–04:59 — سهرة.
  night;

  /// The slot [when] (Damascus wall clock) falls in.
  static HomeGreetingSlot at(DateTime when) {
    final hour = when.hour;
    if (hour >= 22 || hour < 5) return HomeGreetingSlot.night;
    if (hour < 12) return HomeGreetingSlot.morning;
    if (hour < 17) return HomeGreetingSlot.midday;
    return HomeGreetingSlot.evening;
  }

  List<String> phrases(AppLocalizations l10n) => switch (this) {
    HomeGreetingSlot.morning => [
      l10n.greetingMorningKhair,
      l10n.greetingMorningNour,
      l10n.greetingMorningWard,
      l10n.greetingMorningYasmine,
      l10n.greetingMorningFull,
    ],
    HomeGreetingSlot.midday => [
      l10n.greetingMiddaySaeed,
      l10n.greetingMiddayTab,
      l10n.greetingMiddayWard,
    ],
    HomeGreetingSlot.evening => [
      l10n.greetingEveningNour,
      l10n.greetingEveningKhair,
      l10n.greetingEveningYasmine,
      l10n.greetingEveningWard,
    ],
    HomeGreetingSlot.night => [l10n.greetingNightSahra, l10n.greetingNightFull],
  };
}

/// Picks today's greeting. Exposed (and injectable) so a test can stand at any
/// hour of any day without touching the system clock.
abstract final class HomeGreetingCopy {
  static String of(AppLocalizations l10n, {DateTime? clock}) {
    final now = damascusNow(clock: clock);
    final slot = HomeGreetingSlot.at(now);
    final phrases = slot.phrases(l10n);

    // The day number carries the rotation, offset by the slot so a morning and
    // the evening that follows it never land on the same wording by accident.
    final day = now.difference(DateTime.utc(2020)).inDays;
    return phrases[(day + slot.index * 3) % phrases.length];
  }
}
