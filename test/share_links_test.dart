import 'package:flutter_test/flutter_test.dart';

import 'package:reem/core/config/app_env.dart';
import 'package:reem/core/shared/entities/media.dart';
import 'package:reem/core/shared/services/share_links.dart';

/// The link contract, from both ends.
///
/// A share link is the only thing this app produces that outlives the session
/// it was made in: it is pasted into WhatsApp, forwarded, and opened weeks
/// later — often by somebody who has never heard of Reem. So the two halves
/// tested here are the two that were broken.
///
/// **Building.** Every link used to be a string literal at its call site
/// (`'${shareBaseUrl}/p/$postId'` in one place, `/product/$id` in another)
/// pointing at `https://reem.shop`, a host that has never resolved.
///
/// **Reading.** Nothing anywhere could turn one back into a screen. The app had
/// no route for a link it handed out, so even a woman with Reem installed
/// landed on a 404.
///
/// The server holds the other half of this contract in
/// `backend/src/modules/links/share-links.ts`, and its own suite asserts the
/// same shapes.
void main() {
  group('building a link', () {
    test('every kind points at a host that answers', () {
      // Not `reem.shop`. The origin is the API's, which by definition exists
      // and which serves the landing page for every one of these paths.
      final origin = AppEnv.shareBaseUrl;
      expect(origin, startsWith('http'));
      expect(origin, isNot(endsWith('/')));
      expect(origin, isNot(contains('reem.shop')));

      expect(ShareLinks.product('abc'), '$origin/product/abc');
      expect(ShareLinks.content('p1'), '$origin/p/p1');
      expect(ShareLinks.profile('u1'), '$origin/user/u1');
      expect(ShareLinks.storefront('u1'), '$origin/user/u1/products');
      expect(ShareLinks.collection('new_arrivals'), '$origin/collection/new_arrivals');
      expect(ShareLinks.roomInvite('s1'), '$origin/rooms/join/s1');
      expect(ShareLinks.referral('LAMA7'), '$origin/invite/LAMA7');
    });

    test('a value that would break the path is encoded', () {
      expect(ShareLinks.roomInvite('a b/c'), endsWith('/rooms/join/a%20b%2Fc'));
    });
  });

  group('reading a link', () {
    String? route(String url) => ShareLinks.routeFor(Uri.parse(url));

    test('a product link opens the product page, whose route is not its path', () {
      // The whole reason this function exists. Android and iOS hand the app
      // `/product/abc`; the app's product page has always been
      // `/product-details?id=abc`.
      expect(route('https://x.test/product/abc'), '/product-details?id=abc');
    });

    test('a post link opens the piece', () {
      expect(route('https://x.test/p/p1'), '/content/p1');
    });

    test('the short profile form is canonicalised on arrival', () {
      expect(route('https://x.test/u/u1'), '/user/u1');
    });

    test('a path that is already a route is returned unchanged', () {
      // Returning anything else here would be a redirect to the current
      // location, which GoRouter resolves by looping.
      expect(route('https://x.test/user/u1'), '/user/u1');
      expect(route('https://x.test/user/u1/products'), '/user/u1/products');
      expect(route('https://x.test/content/p1'), '/content/p1');
      expect(route('https://x.test/collection/deals'), '/collection/deals');
      expect(route('https://x.test/rooms/join/s1'), '/rooms/join/s1');
    });

    test('a query string survives the round trip', () {
      expect(route('https://x.test/user/u1?tab=reels'), '/user/u1?tab=reels');
    });

    test('the app does not claim an invitation', () {
      // An invite is sent to somebody who does *not* have Reem. Swallowing it
      // would hide the download button from the one person it was written for.
      expect(route('https://x.test/invite/LAMA7'), isNull);
      expect(ShareLinks.isAppHandled(Uri.parse('https://x.test/invite/LAMA7')), isFalse);
    });

    test('the app does not claim a path it has no screen for', () {
      expect(route('https://x.test/'), isNull);
      expect(route('https://x.test/something-else'), isNull);
      expect(route('https://x.test/product'), isNull);
      expect(route('https://x.test/product/a/b'), isNull);
      expect(route('https://x.test/user/u1/follows/followers'), isNull);
    });

    test("the app's own product route is not mistaken for a share path", () {
      // `'/product-details'.startsWith('/product')` is true. A prefix test here
      // would have caught the product page and bounced it back to itself for
      // ever, which is why the match is segment-wise.
      expect(route('https://x.test/product-details?id=abc'), isNull);
    });

    test('a link round-trips: what is built is what is read', () {
      for (final url in [
        ShareLinks.product('abc'),
        ShareLinks.content('p1'),
        ShareLinks.profile('u1'),
        ShareLinks.storefront('u1'),
        ShareLinks.collection('deals'),
        ShareLinks.roomInvite('s1'),
      ]) {
        expect(route(url), isNotNull, reason: '$url resolved to nothing');
      }
    });
  });

  group('the picture a share carries', () {
    test('a video-first gallery hands out its poster, never the clip', () {
      // `displayUrl` falls back to the video URL when no poster was derived,
      // which is right for a player and wrong for a share sheet and an
      // `og:image` — both would hand out an MP4 and render nothing.
      final reel = [
        const MediaItem(
          url: 'https://cdn.test/clip.mp4',
          type: MediaType.video,
          thumbnailUrl: 'https://cdn.test/poster.jpg',
        ),
      ];
      expect(reel.stillImageUrl, 'https://cdn.test/poster.jpg');
    });

    test('a clip with no poster yields nothing rather than a video', () {
      final reel = [
        const MediaItem(url: 'https://cdn.test/clip.mp4', type: MediaType.video),
      ];
      expect(reel.stillImageUrl, isNull);
    });

    test('the first real photograph wins', () {
      final gallery = [
        const MediaItem(url: 'https://cdn.test/a.jpg'),
        const MediaItem(url: 'https://cdn.test/b.jpg'),
      ];
      expect(gallery.stillImageUrl, 'https://cdn.test/a.jpg');
      expect(const <MediaItem>[].stillImageUrl, isNull);
    });
  });
}
