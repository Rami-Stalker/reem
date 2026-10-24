// Guards the feed's decode path against the two shapes that have silently
// emptied the home feed before: a post that tags no product, and a product
// whose `category` arrives as an object rather than a bare slug. Either one
// used to throw inside `PostModel.fromJson`, and because the repository wraps
// the call in `guard()`, the whole feed came back as one swallowed Error —
// an empty "your feed is warming up" screen with nothing in the logs.
//
// The fixture is a trimmed capture of a live `GET /posts/feed` response.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ohara/core/shared/entities/post.dart';
import 'package:ohara/core/shared/models/post_model.dart';

void main() {
  late List<PostModel> posts;

  setUpAll(() {
    final raw = File('test/fixtures/posts_feed.json').readAsStringSync();
    final data = (jsonDecode(raw) as Map<String, dynamic>)['data'] as List;
    posts = [
      for (final item in data)
        PostModel.fromJson(Map<String, dynamic>.from(item as Map)),
    ];
  });

  test('decodes every post in a live feed payload', () {
    expect(posts, isNotEmpty);
  });

  test('keeps a post that tags no product', () {
    final untagged = posts.where((p) => !p.hasProduct);
    expect(untagged, isNotEmpty, reason: 'fixture must cover the null case');
    for (final post in untagged) {
      expect(post.product, isNull);
      expect(post.media, isEmpty);
      expect(post.cover, isNull);
      // It is still a post: author and caption survive.
      expect(post.author.name, isNotEmpty);
    }
  });

  test('reads the category off the product object, not a bare string', () {
    final tagged = posts.firstWhere((p) => p.hasProduct);
    // The regression: `category` arrives as an object. Decoding must survive
    // it and land the slug on the product entity.
    expect(tagged.product!.category.slug, isNotEmpty);
    expect(tagged.product!.category.nameAr, isNotEmpty);
    // The coarse bucket is derived from that slug; it may legitimately fall
    // back to `gifts` for a slug outside the nine display types.
    expect(tagged.category, isA<CategoryType>());
  });

  test('exposes the product gallery as the post media', () {
    final gallery = posts.firstWhere(
      (p) => p.media.length > 1,
      orElse: () => posts.firstWhere((p) => p.hasProduct),
    );
    expect(gallery.media, equals(gallery.product!.media));
    expect(gallery.cover, equals(gallery.product!.cover));
  });
}
