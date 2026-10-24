import 'package:flutter_test/flutter_test.dart';
import 'package:ohara/features/social/data/models/social_models.dart';

void main() {
  test('«شوهدت من قبل» reads the owner-only viewers payload', () {
    final audience = ContentAudienceModel.fromJson({
      'content_id': 'c1',
      'views_count': 9,
      'viewers_count': 2,
      'reactions_count': 1,
      'reaction_breakdown': {'😍': 1},
      'viewers': [
        {
          'user': {
            'id': 'u1',
            'name': 'لينا',
            'username': 'lina',
            'created_at': '2026-01-01T00:00:00.000Z',
          },
          'viewed_at': '2026-10-24T08:00:00.000Z',
          'reaction': '😍',
        },
        // A row without a person is skipped, not drawn as a blank face.
        {'viewed_at': '2026-10-24T08:00:00.000Z'},
      ],
    });

    expect(audience.contentId, 'c1');
    expect(audience.views, 9);
    expect(audience.viewersCount, 2);
    expect(audience.reactionBreakdown, {'😍': 1});
    expect(audience.viewers, hasLength(1));
    expect(audience.viewers.single.user.id, 'u1');
    expect(audience.viewers.single.reaction, '😍');
  });
}
