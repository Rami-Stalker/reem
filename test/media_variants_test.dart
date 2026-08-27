// Asking for a smaller copy from nothing but a URL.
//
// This convention is load-bearing: the feature tables store a plain URL string,
// so a product card holds a link and no thumbnail column. Getting the rewrite
// wrong shows up as a broken image on every tile at once, and getting it too
// eager — rewriting a URL the platform does not host — breaks the demo dataset
// and anything ever linked from outside.
import 'package:flutter_test/flutter_test.dart';
import 'package:reem/core/media/media_asset.dart';
import 'package:reem/core/media/media_variants.dart';

void main() {
  group('public uploads', () {
    const original = 'http://10.0.2.2:3000/media/files/2026/08/'
        '8b0f6700-4d91-48ac-b004-87fb10d7a13b.png';

    test('a width becomes a suffix, and the format becomes WebP', () {
      expect(
        MediaVariants.thumb(original),
        'http://10.0.2.2:3000/media/files/2026/08/'
            '8b0f6700-4d91-48ac-b004-87fb10d7a13b@480.webp',
      );
    });

    test('the origin is left exactly as it was found', () {
      // The origin a row was written under is not the origin it is read back
      // under; rebuilding it here would orphan every image on a LAN change.
      expect(MediaVariants.at(original, 1080), startsWith('http://10.0.2.2:3000/'));
    });

    test('a JPEG and a WebP original are treated alike', () {
      for (final extension in ['jpg', 'jpeg', 'webp', 'gif']) {
        final url = original.replaceAll('.png', '.$extension');
        expect(MediaVariants.thumb(url), endsWith('@480.webp'));
      }
    });
  });

  group('private uploads', () {
    const private =
        'https://api.reem.sy/media/3f4a9c1e-1b2d-4e5f-8a90-abcdef012345/file';

    test('the width goes in the query, never in the path', () {
      // The bytes stay behind the authorised handler; there is no file path
      // for a private asset that should work without a session.
      expect(MediaVariants.at(private, 480), '$private?w=480');
    });
  });

  group('everything else is left alone', () {
    test('an external link is never rewritten', () {
      // The demo dataset is full of these, and a rewritten one 404s.
      const external = 'https://images.unsplash.com/photo-1529139574466';
      expect(MediaVariants.thumb(external), external);
      expect(MediaVariants.isOurs(external), isFalse);
    });

    test('a URL that already names a variant is not rewritten twice', () {
      const variant = 'http://host/media/files/2026/08/'
          '8b0f6700-4d91-48ac-b004-87fb10d7a13b@480.webp';
      expect(MediaVariants.thumb(variant), variant);
    });

    test('an empty URL stays empty', () {
      expect(MediaVariants.thumb(''), '');
    });
  });

  group('MediaAsset', () {
    test('carries the thumbnail, the hash and the widths the server made', () {
      final asset = MediaAsset.fromJson(const {
        'id': 'a1',
        'url': 'http://host/media/files/2026/08/'
            '8b0f6700-4d91-48ac-b004-87fb10d7a13b.png',
        'thumbnail_url': 'http://host/media/files/2026/08/'
            '8b0f6700-4d91-48ac-b004-87fb10d7a13b@480.webp',
        'blur_hash': 'LDHVAO3X|cPCuyRUo1a5hVf%fQf%',
        'variants': [480, 1080],
        'type': 'image',
        'mime_type': 'image/png',
        'byte_size': 172791,
        'width': 1600,
        'height': 2000,
      });

      expect(asset.thumbnailUrl, endsWith('@480.webp'));
      expect(asset.blurHash, isNotEmpty);
      expect(asset.variants, [480, 1080]);
    });

    test('an upload from before derivatives existed simply has none', () {
      final asset = MediaAsset.fromJson(const {
        'id': 'a1',
        'url': 'http://host/media/files/2026/08/'
            '8b0f6700-4d91-48ac-b004-87fb10d7a13b.png',
        'type': 'image',
        'mime_type': 'image/png',
        'byte_size': 100,
      });

      expect(asset.variants, isEmpty);
      expect(asset.blurHash, isNull);
      // And asking for a thumbnail is still safe — the server falls back.
      expect(MediaVariants.thumb(asset.url), endsWith('@480.webp'));
    });
  });
}
