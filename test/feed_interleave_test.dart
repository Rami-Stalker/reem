import 'package:flutter_test/flutter_test.dart';

import 'package:ohara/features/home/presentation/feed_interleave.dart';

/// The home page stopped being a stack of shelves with a feed at the bottom;
/// the shelves are set between the posts instead. These pin the rhythm that
/// promise depends on: she meets a post first, never two shelves in a row,
/// and no shelf goes missing because the feed was short.
void main() {
  /// Renders slots as a string — `p` for a post, `m` for a module — so a
  /// failure reads as the page it would have drawn.
  String shape(List<FeedSlot<int, String>> slots) => slots
      .map(
        (slot) => switch (slot) {
          FeedPost() => 'p',
          FeedModule() => 'm',
        },
      )
      .join();

  List<int> posts(int n) => List.generate(n, (i) => i);
  List<String> modules(int n) => List.generate(n, (i) => 'm$i');

  test('the first module comes after the second post, then every third', () {
    expect(shape(interleaveFeed(posts(9), modules(5))), 'ppmpppmpppmp' 'mm');
  });

  test('a post always opens the feed', () {
    final slots = interleaveFeed(posts(5), modules(3));
    expect(slots.first, isA<FeedPost<int, String>>());
  });

  test('no two modules sit together while posts remain', () {
    final drawn = shape(interleaveFeed(posts(12), modules(10)));
    final lastPost = drawn.lastIndexOf('p');
    expect(drawn.substring(0, lastPost).contains('mm'), isFalse);
  });

  test('a short feed ends in the modules it had no room for', () {
    expect(shape(interleaveFeed(posts(2), modules(3))), 'ppmmm');
  });

  test('modules keep the order they were handed in', () {
    final slots = interleaveFeed(posts(9), modules(5));
    final order = [
      for (final slot in slots)
        if (slot case FeedModule(:final module)) module,
    ];
    expect(order, modules(5));
  });

  test('an empty feed still leaves the modules to shop', () {
    expect(shape(interleaveFeed(posts(0), modules(3))), 'mmm');
  });

  test('no modules is just the feed', () {
    expect(shape(interleaveFeed(posts(4), modules(0))), 'pppp');
  });
}
