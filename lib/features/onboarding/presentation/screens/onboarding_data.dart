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

const onboardingItems = [
  OnboardingData(
    title: 'Shop in Style',
    subtitle:
        'Discover dresses, accessories, beauty & gifts curated for the modern woman.',
    image: 'https://images.unsplash.com/photo-1529139574466-a303027c1d8b',
    emoji: '👗',
  ),
  OnboardingData(
    title: 'Stories & Posts',
    subtitle:
        'Watch stories, like posts, and shop directly from your favorite creators.',
    image: 'https://images.unsplash.com/photo-1487412720507-e7ab37603c6f',
    emoji: '✨',
  ),
  OnboardingData(
    title: 'Share Your Haul',
    subtitle:
        'Post your purchases as stories & feed posts. Earn points & unlock rewards.',
    image: 'https://images.unsplash.com/photo-1496747611176-843222e1e57c',
    emoji: '💕',
  ),
];
