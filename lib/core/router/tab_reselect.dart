import 'package:flutter_riverpod/legacy.dart';

/// A tick, per bottom-bar branch, raised each time a tab that is *already*
/// selected is tapped again.
///
/// Tapping the tab you are on is not navigation — GoRouter's `goBranch` pops
/// the branch back to its root and then, quite correctly, does nothing else.
/// What a shopper means by it is "take me back to the top", and there is no
/// way for the bar to do that itself: the scroll position belongs to the
/// screen. So the bar raises this and the screen answers, which keeps the
/// knowledge of *what the top means* where it belongs.
final tabReselectProvider = StateProvider.family<int, int>(
  (ref, branchIndex) => 0,
);
