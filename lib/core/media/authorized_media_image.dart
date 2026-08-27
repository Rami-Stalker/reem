import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_blurhash/flutter_blurhash.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reem/core/media/media_variants.dart';
import 'package:reem/core/presentation/providers/core_providers.dart';
import 'package:reem/core/storage/secure_storage_service.dart';

/// The bearer token, for the one client that is not Dio.
///
/// `CachedNetworkImage` fetches through its own HTTP client, so none of the
/// interceptors apply to it. Private media — a photograph sent into a
/// conversation — lives behind an authorised endpoint, and without this the
/// image loader gets a 401 and draws an error box.
final mediaAuthHeadersProvider = FutureProvider<Map<String, String>>((
  ref,
) async {
  final token = await ref
      .watch(secureStorageProvider)
      .read(SecureStorageKeys.accessToken);
  return token == null || token.isEmpty
      ? const {}
      : {'Authorization': 'Bearer $token'};
});

/// Draws a media URL, attaching a bearer token when the URL needs one.
///
/// Two kinds of URL reach image widgets in this app. A public one
/// (`…/media/files/2026/08/x.jpg`, or an external link) is fetched plainly and
/// cached like any other picture. A private one (`…/media/<id>/file`) is
/// fetched with the session's token.
///
/// Both end up in the same on-disk cache, and for chat that is the right
/// answer rather than a compromise: these are her own conversations, and a
/// messaging app that re-downloads every photograph on every scroll is unusable
/// on the connections this platform serves. Identity documents are the case
/// where caching would be wrong, and those are never drawn — see
/// `DsMediaField`, which renders them as a chip instead.
class AuthorizedMediaImage extends ConsumerWidget {
  const AuthorizedMediaImage({
    super.key,
    required this.url,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.borderRadius,
    this.blurHash,
    this.variantWidth,
  });

  final String url;
  final BoxFit fit;
  final double? width;
  final double? height;
  final BorderRadius? borderRadius;

  /// Decoded into a blurred stand-in while the photograph is in flight, so the
  /// space it will occupy already has its colours instead of being a grey
  /// rectangle that pops.
  final String? blurHash;

  /// Which resized copy to ask for — see [MediaVariants]. Null fetches the
  /// original, which is right for a full-screen view and wasteful anywhere
  /// else.
  final int? variantWidth;

  /// `/media/<uuid>/file` — the shape `MediaService.urlFor` gives a private
  /// asset. Anything else is public and needs no header.
  static final _privatePath = RegExp(
    r'/media/[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/file',
    caseSensitive: false,
  );

  static bool isPrivate(String url) => _privatePath.hasMatch(url);

  /// What is actually fetched: the requested copy when one was asked for.
  String get _resolved =>
      variantWidth == null ? url : MediaVariants.at(url, variantWidth!);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!isPrivate(url)) return _image(const {});

    // The token resolves from secure storage, so the first frame has none.
    // Waiting for it beats fetching without it: an unauthorised attempt would
    // be cached as a failure by the loader and the photograph would stay
    // broken until the whole cache was cleared.
    final headers = ref.watch(mediaAuthHeadersProvider);
    return headers.when(
      loading: () => _placeholder(context),
      error: (_, _) => _placeholder(context),
      data: _image,
    );
  }

  Widget _image(Map<String, String> headers) {
    final image = CachedNetworkImage(
      imageUrl: _resolved,
      httpHeaders: headers.isEmpty ? null : headers,
      fit: fit,
      width: width,
      height: height,
      placeholder: (context, _) => _placeholder(context),
      errorWidget: (context, _, _) => _broken(context),
    );
    final radius = borderRadius;
    return radius == null
        ? image
        : ClipRRect(borderRadius: radius, child: image);
  }

  Widget _placeholder(BuildContext context) {
    final hash = blurHash;
    if (hash != null && hash.isNotEmpty) {
      return SizedBox(
        width: width,
        height: height,
        // `decodingWidth`/`Height` default to 32×32, which is all the detail a
        // hash carries — decoding it at the widget's real size would be
        // upscaling noise at a cost.
        child: BlurHash(hash: hash, imageFit: fit),
      );
    }
    return Container(
      width: width,
      height: height,
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
    );
  }

  Widget _broken(BuildContext context) => Container(
    width: width,
    height: height,
    color: Theme.of(context).colorScheme.surfaceContainerHighest,
    alignment: Alignment.center,
    child: Icon(
      Icons.broken_image_outlined,
      color: Theme.of(context).colorScheme.outline,
    ),
  );
}
