import 'package:flutter/widgets.dart';

import 'package:reem/core/config/app_env.dart';
import 'package:share_plus/share_plus.dart';

/// Handing something in Reem to somebody outside it.
///
/// Sharing used to be a counter and nothing else: the post card told the server
/// a share had happened and then did nothing, so the sheet never opened and no
/// link ever left the phone. Everything shareable now goes through here, so the
/// link shape is defined once and the server is only told about a share that
/// actually happened.
abstract final class ShareService {
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
  }) {
    final headline = [
      if (caption != null && caption.trim().isNotEmpty) caption.trim(),
      if (authorName != null && authorName.trim().isNotEmpty)
        '— $authorName',
    ].join('\n');

    return _share(
      context: context,
      text: headline,
      uri: '${AppEnv.shareBaseUrl}/p/$postId',
    );
  }

  /// A product, named so the message reads as a recommendation rather than a
  /// bare URL.
  static Future<bool> product({
    required BuildContext context,
    required String productId,
    String? title,
  }) {
    return _share(
      context: context,
      text: title?.trim() ?? '',
      uri: '${AppEnv.shareBaseUrl}/product/$productId',
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
      uri: '${AppEnv.shareBaseUrl}/invite/$code',
    );
  }

  /// A profile — hers, or a boutique's she wants to pass on.
  ///
  /// The share control on her own profile header had an empty `onPressed` from
  /// the day it was drawn, which is a button that reads as broken rather than
  /// as absent. The link shape matches the app's own `/user/:id` route so that
  /// whatever resolves the other shares resolves this one too.
  static Future<bool> profile({
    required BuildContext context,
    required String userId,
    String? name,
  }) {
    return _share(
      context: context,
      text: name?.trim() ?? '',
      uri: '${AppEnv.shareBaseUrl}/user/$userId',
    );
  }

  /// A saved collection she has chosen to publish. The server issues the token,
  /// so the whole URL arrives ready-made and is passed through untouched.
  static Future<bool> link({
    required BuildContext context,
    required String url,
    String? text,
  }) {
    return _share(context: context, text: text ?? '', uri: url);
  }

  static Future<bool> _share({
    required BuildContext context,
    required String text,
    required String uri,
  }) async {
    // iPad renders the sheet as a popover and needs an anchor, or it throws.
    // The origin is read before the await, while the element is certainly
    // still mounted.
    final box = context.findRenderObject() as RenderBox?;
    final origin = box != null && box.hasSize
        ? box.localToGlobal(Offset.zero) & box.size
        : null;

    final body = text.trim().isEmpty ? uri : '${text.trim()}\n\n$uri';
    final result = await SharePlus.instance.share(
      ShareParams(text: body, sharePositionOrigin: origin),
    );
    return result.status == ShareResultStatus.success;
  }
}
