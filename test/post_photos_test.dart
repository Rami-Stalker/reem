// A post shows the photographs its author posted; the tagged piece's gallery
// is only the fallback for a post with none. The home feed used to show the
// catalogue shots even under a shopper's own photo.
//
//   flutter test test/post_photos_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:ohara/core/shared/models/post_model.dart';

Map<String, dynamic> _json({List<Map<String, dynamic>>? media}) => {
  'id': 'p1',
  'author': {
    'id': 'u1',
    'name': 'ريم',
    'username': 'reem',
    'created_at': '2026-01-01T00:00:00.000Z',
  },
  'product': {
    'id': 'pr1',
    'slug': 'dress',
    'title': 'فستان',
    'description': '',
    'category': {'id': 'c', 'slug': 'dresses', 'name_ar': 'فساتين'},
    'media': [
      {'url': 'https://cdn/catalogue.jpg', 'type': 'image'},
    ],
    'created_at': '2026-10-01T00:00:00.000Z',
  },
  'caption': 'لبستو بالعرس',
  'created_at': '2026-10-01T00:00:00.000Z',
  'media': ?media,
};

void main() {
  test('her own photo is what the post shows', () {
    final post = PostModel.fromJson(
      _json(
        media: [
          {'url': 'https://cdn/her-photo.jpg', 'type': 'image'},
        ],
      ),
    );
    expect(post.media.single.url, 'https://cdn/her-photo.jpg');
    expect(post.cover?.url, 'https://cdn/her-photo.jpg');
    // The piece is still tagged under it.
    expect(post.product?.id, 'pr1');
  });

  test('without photos, the piece is shown', () {
    final post = PostModel.fromJson(_json());
    expect(post.media.single.url, 'https://cdn/catalogue.jpg');
  });

  test('photos survive a round trip through the cache', () {
    final post = PostModel.fromJson(
      _json(
        media: [
          {'url': 'https://cdn/her-photo.jpg', 'type': 'image'},
        ],
      ),
    );
    final again = PostModel.fromJson(post.toJson());
    expect(again.photos.single.url, 'https://cdn/her-photo.jpg');
  });
}
