import 'package:flutter_test/flutter_test.dart';
import 'package:reem/core/shared/entities/story.dart';
import 'package:reem/core/shared/entities/user.dart';
import 'package:reem/features/home/presentation/widgets/home_stories_rail.dart';

/// The stories row draws one ring per boutique.
///
/// The feed lists every story on its own; a shop with three frames up used to
/// take three places in the row, so «رهف الشامي» appeared twice beside shops
/// that appeared once.
void main() {
  User shop(String id) => User(
    id: id,
    name: id,
    username: id,
    phone: '',
    createdAt: DateTime(2026),
  );
  Story story(String id, String shopId) => Story(
    id: id,
    user: shop(shopId),
    expiresAt: DateTime(2026, 10, 22),
    createdAt: DateTime(2026, 10, 21),
  );

  test('one group per shop, in the order shops first appear', () {
    final groups = HomeStoriesRail.groupStoriesByShop([
      story('1', 'rahaf'),
      story('2', 'rima'),
      story('3', 'rahaf'),
      story('4', 'jana'),
      story('5', 'rima'),
    ]);

    expect(groups.map((g) => g.first.user.id), ['rahaf', 'rima', 'jana']);
    expect(groups.first.map((s) => s.id), ['1', '3']);
    expect(groups[1].map((s) => s.id), ['2', '5']);
  });
}
