import 'package:flutter/widgets.dart';

import 'package:reem/core/localization/l10n_extension.dart';

class OnboardingData {
  const OnboardingData({
    required this.title,
    required this.subtitle,
    required this.image,
    required this.emoji,
  });

  final String title;
  final String subtitle;
  final String image;
  final String emoji;
}

/// The three panels of the first run.
///
/// A function rather than the `const` list it used to be: the copy is
/// localised, and a localised string cannot be resolved at compile time. The
/// count is stable, so the screen builds this once per frame and reads
/// `length` off the result rather than calling back in.
List<OnboardingData> onboardingItems(BuildContext context) {
  final l10n = context.l10n;
  return [
    OnboardingData(
      title: l10n.onboardShopTitle,
      subtitle: l10n.onboardShopBody,
      image: 'https://images.unsplash.com/photo-1529139574466-a303027c1d8b',
      emoji: '👗',
    ),
    OnboardingData(
      title: l10n.onboardStoriesTitle,
      subtitle: l10n.onboardStoriesBody,
      image: 'https://images.unsplash.com/photo-1487412720507-e7ab37603c6f',
      emoji: '✨',
    ),
    OnboardingData(
      title: l10n.onboardShareTitle,
      subtitle: l10n.onboardShareBody,
      image: 'https://images.unsplash.com/photo-1496747611176-843222e1e57c',
      emoji: '💕',
    ),
  ];
}

/// How many panels there are, for code that needs the count without a context
/// — the `_next` handler deciding whether it is on the last one.
const int onboardingItemCount = 3;
