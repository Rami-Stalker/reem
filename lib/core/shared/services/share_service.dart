import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:ohara/core/shared/services/share_links.dart';
import 'package:ohara/core/shared/value_objects/money.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Handing something in Ohara to somebody outside it.
///
/// Sharing used to be a counter and nothing else: the post card told the server
/// a share had happened and then did nothing, so the sheet never opened and no
/// link ever left the phone. Then the sheet opened — carrying a bare URL on a
/// domain that does not exist, which WhatsApp could not preview and the browser
/// could not reach.
///
/// What leaves the phone now is what the client asked for and what a shopper
/// actually forwards: the photograph, the name, the price, the boutique, and a
/// link that opens the product — in the app if she has it, on a real page if
/// she does not.
///
/// ## The image
///
/// Attached as a file, not linked. A WhatsApp message carrying a picture *is*
/// the recommendation; a link preview is a card she has to decide to trust.
/// It is also best-effort by design: the download is bounded by
/// [_imageTimeout], and a slow or dead photograph degrades to the text share
/// that worked before rather than leaving her holding a spinner. Every message
/// carries the link either way, so nothing is lost when the picture is.
abstract final class ShareService {
  /// Long enough for a product photograph on a Syrian mobile connection, short
  /// enough that she does not think the button is broken.
  static const Duration _imageTimeout = Duration(seconds: 6);

  /// Well under WhatsApp's own limit, and under what is polite to send on a
  /// metered connection. Anything larger is shared as text with a link.
  static const int _maxImageBytes = 5 * 1024 * 1024;

  /// The public link to a post — what «نسخ الرابط» copies and what the share
  /// sheet sends, so the two can never disagree.
  static String postUrl(String postId) => ShareLinks.content(postId);

  static String productUrl(String productId) => ShareLinks.product(productId);

  /// A product: its picture, its name, its price, its boutique and its link.
  ///
  /// The five lines are the client's specification, in the order a reader wants
  /// them — and each is dropped rather than faked when it is not known, so a
  /// product with no live offer is shared without an invented price.
  static Future<bool> product({
    required BuildContext context,
    required String productId,
    String? title,
    Money? price,
    String? sellerName,
    String? imageUrl,
  }) {
    final lines = [
      if (title != null && title.trim().isNotEmpty) title.trim(),
      if (price != null && !price.isZero) price.format(),
      if (sellerName != null && sellerName.trim().isNotEmpty)
        'من ${sellerName.trim()}',
    ];

    return _share(
      context: context,
      text: lines.join('\n'),
      uri: productUrl(productId),
      imageUrl: imageUrl,
    );
  }

  /// A post, with its caption as the invitation.
  ///
  /// Returns true when she went through with it. The engagement counter is the
  /// caller's business, and it should only be bumped on a true — a share sheet
  /// she dismissed is not a share.
  static Future<bool> post({
    required BuildContext context,
    required String postId,
    String? caption,
    String? authorName,
    String? imageUrl,
  }) {
    final headline = [
      if (caption != null && caption.trim().isNotEmpty) caption.trim(),
      if (authorName != null && authorName.trim().isNotEmpty) '— $authorName',
    ].join('\n');

    return _share(
      context: context,
      text: headline,
      uri: postUrl(postId),
      imageUrl: imageUrl,
    );
  }

  /// Her invite. The code travels in the link, so a friend who taps it is
  /// credited without having to type anything.
  static Future<bool> referral({
    required BuildContext context,
    required String code,
    String? hint,
  }) {
    final invitation = [
      if (hint != null && hint.trim().isNotEmpty) hint.trim(),
      code,
    ].join('\n');

    return _share(
      context: context,
      text: invitation,
      uri: ShareLinks.referral(code),
    );
  }

  /// A profile — hers, or a boutique's she wants to pass on.
  ///
  /// The share control on her own profile header had an empty `onPressed` from
  /// the day it was drawn, which is a button that reads as broken rather than
  /// as absent.
  static Future<bool> profile({
    required BuildContext context,
    required String userId,
    String? name,
    String? imageUrl,
  }) {
    return _share(
      context: context,
      text: name?.trim() ?? '',
      uri: ShareLinks.profile(userId),
      imageUrl: imageUrl,
    );
  }

  /// One boutique's whole shelf.
  static Future<bool> storefront({
    required BuildContext context,
    required String sellerId,
    String? name,
    String? imageUrl,
  }) {
    return _share(
      context: context,
      text: name == null || name.trim().isEmpty
          ? ''
          : 'تسوّقي من ${name.trim()} على أوهارا',
      uri: ShareLinks.storefront(sellerId),
      imageUrl: imageUrl,
    );
  }

  /// A deliberation room she is inviting somebody into.
  static Future<bool> roomInvite({
    required BuildContext context,
    required String slug,
    String? title,
  }) {
    return _share(
      context: context,
      text: [
        if (title != null && title.trim().isNotEmpty) title.trim(),
        'ساعديني في الاختيار على أوهارا',
      ].join('\n'),
      uri: ShareLinks.roomInvite(slug),
    );
  }

  /// A shelf of the catalogue.
  static Future<bool> collection({
    required BuildContext context,
    required String key,
    String? title,
  }) {
    return _share(
      context: context,
      text: title?.trim() ?? '',
      uri: ShareLinks.collection(key),
    );
  }

  /// A link the server already assembled, passed through untouched.
  static Future<bool> link({
    required BuildContext context,
    required String url,
    String? text,
    String? imageUrl,
  }) {
    return _share(
      context: context,
      text: text ?? '',
      uri: url,
      imageUrl: imageUrl,
    );
  }

  static Future<bool> _share({
    required BuildContext context,
    required String text,
    required String uri,
    String? imageUrl,
  }) async {
    // iPad renders the sheet as a popover and needs an anchor, or it throws.
    // The origin is read before the await, while the element is certainly
    // still mounted.
    final box = context.findRenderObject() as RenderBox?;
    final origin = box != null && box.hasSize
        ? box.localToGlobal(Offset.zero) & box.size
        : null;

    final file = await _download(imageUrl);

    final body = text.trim().isEmpty ? uri : '${text.trim()}\n\n$uri';
    try {
      final result = await SharePlus.instance.share(
        ShareParams(
          text: body,
          sharePositionOrigin: origin,
          files: file == null ? null : [file],
        ),
      );
      return result.status == ShareResultStatus.success;
    } catch (error, stack) {
      // A share sheet that throws is a share that did not happen, not a crash
      // worth taking the screen down for — and the caller reads the false to
      // leave its counter alone.
      debugPrint('Share failed: $error\n$stack');
      return false;
    }
  }

  /// The picture, fetched to a temporary file so the OS can attach it.
  ///
  /// Returns null — silently, and on every failure path — because there is no
  /// outcome here worth interrupting her for. The link in the message body is
  /// the thing that must arrive; the photograph is what makes it persuasive.
  ///
  /// The filename is derived from the URL rather than made unique, so sharing
  /// the same dress twice rewrites one file instead of leaving a second copy
  /// behind. The directory is the OS temporary one, which both platforms
  /// reclaim on their own; nothing here needs a sweeper.
  static Future<XFile?> _download(String? url) async {
    final source = url?.trim();
    if (source == null || source.isEmpty) return null;
    if (!source.startsWith('http://') && !source.startsWith('https://')) {
      return null;
    }
    // There is no OS share sheet on the desktop shells this project also
    // builds for, and no temporary directory convention worth guessing at.
    if (kIsWeb) return null;

    try {
      // Its own Dio, deliberately: the app's instance carries the access token
      // and the response cache, and a product photograph on a CDN wants
      // neither. Sending a bearer token to a third-party host would be a
      // credential leak for the sake of an image.
      final dio = Dio(
        BaseOptions(
          responseType: ResponseType.bytes,
          connectTimeout: _imageTimeout,
          receiveTimeout: _imageTimeout,
          sendTimeout: _imageTimeout,
          followRedirects: true,
          // The CDN answers with the bytes or it does not; a 404 must not
          // become a thrown error that swallows the whole share.
          validateStatus: (status) => status != null && status < 400,
        ),
      );
      final response = await dio
          .get<List<int>>(source)
          .timeout(_imageTimeout);

      final bytes = response.data;
      if (bytes == null || bytes.isEmpty || bytes.length > _maxImageBytes) {
        return null;
      }

      final mimeType = _mimeOf(response.headers.value('content-type'), bytes);
      if (mimeType == null) return null;

      final directory = await getTemporaryDirectory();
      final name = _fileName(source, mimeType);
      final file = File(p.join(directory.path, name));
      await file.writeAsBytes(bytes, flush: true);

      return XFile(file.path, mimeType: mimeType, name: name);
    } catch (error) {
      debugPrint('Share image unavailable: $error');
      return null;
    }
  }

  /// The type, from the header when it is honest and from the bytes when it is
  /// not.
  ///
  /// Both matter. Android decides what it is attaching from the MIME type, and
  /// a CDN that answers `application/octet-stream` would have the photograph
  /// arrive as a file nobody can open. Anything that is not a picture is
  /// refused outright rather than attached — a share sheet is the wrong place
  /// to discover that a URL pointed at an HTML error page.
  static String? _mimeOf(String? header, List<int> bytes) {
    final declared = header?.split(';').first.trim().toLowerCase();
    final sniffed = _sniff(bytes);
    if (sniffed != null) return sniffed;
    if (declared != null && declared.startsWith('image/')) return declared;
    return null;
  }

  static String? _sniff(List<int> bytes) {
    bool startsWith(List<int> magic) {
      if (bytes.length < magic.length) return false;
      for (var i = 0; i < magic.length; i++) {
        if (bytes[i] != magic[i]) return false;
      }
      return true;
    }

    if (startsWith([0xFF, 0xD8, 0xFF])) return 'image/jpeg';
    if (startsWith([0x89, 0x50, 0x4E, 0x47])) return 'image/png';
    if (startsWith([0x47, 0x49, 0x46, 0x38])) return 'image/gif';
    if (bytes.length >= 12 &&
        startsWith([0x52, 0x49, 0x46, 0x46]) &&
        bytes[8] == 0x57 &&
        bytes[9] == 0x45 &&
        bytes[10] == 0x42 &&
        bytes[11] == 0x50) {
      return 'image/webp';
    }
    return null;
  }

  /// A stable, harmless filename.
  ///
  /// Never the one from the URL: that string arrives from a remote host and
  /// goes into a path, which is how a `../` ends up somewhere it should not.
  static String _fileName(String source, String mimeType) {
    final extension = switch (mimeType) {
      'image/png' => 'png',
      'image/gif' => 'gif',
      'image/webp' => 'webp',
      _ => 'jpg',
    };
    return 'reem-share-${source.hashCode.toUnsigned(32)}.$extension';
  }
}
