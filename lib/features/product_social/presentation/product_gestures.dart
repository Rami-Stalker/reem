import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:reem/core/design_system/design_system.dart';
import 'package:reem/core/localization/l10n_extension.dart';
import 'package:reem/core/platform/app_haptics.dart';
import 'package:reem/core/router/route_paths.dart';
import 'package:reem/core/shared/entities/media.dart';
import 'package:reem/core/shared/entities/product.dart';
import 'package:reem/core/shared/services/share_service.dart';
import 'package:reem/features/auth/presentation/providers/auth_provider.dart';
import 'package:reem/features/auth/presentation/widgets/auth_prompt_sheet.dart';
import 'package:reem/features/product_social/domain/entities/product_engagement.dart';
import 'package:reem/features/product_social/presentation/providers/product_social_providers.dart';
import 'package:reem/features/profile/presentation/providers/profile_provider.dart';
import 'package:reem/features/profile/presentation/widgets/save_to_collection_sheet.dart';
import 'package:reem/features/social/presentation/widgets/report_sheet.dart';
import 'package:reem/features/social_posts/domain/entities/comment_thread.dart';
import 'package:reem/features/social_posts/presentation/widgets/comment_sheet.dart';
import 'package:reem/features/user_profile/presentation/providers/user_profile_providers.dart';

/// The post gestures, on a product — one implementation for every surface.
///
/// A product can be told as a post in «وصل حديثاً», on a department page, on
/// a woman's page and on its own product page. The heart, the thread, the
/// share, the pick and the bookmark must behave the same in all four, or the
/// client finds (as she did) that the posts under «مكياج» are not the posts
/// under «وصل حديثاً». So the behaviour lives here and each surface only
/// decides how the buttons look.
final class ProductGestures {
  const ProductGestures(this.context, this.ref, this.product);

  final BuildContext context;
  final WidgetRef ref;
  final Product product;

  ProductEngagementNotifier get _store =>
      ref.read(productEngagementProvider.notifier);

  /// The engagement to paint: the shared store's entry, or the tallies the
  /// card was served with while the store has none.
  static ProductEngagement watch(WidgetRef ref, Product product) =>
      ref.watch(productEngagementOfProvider(product.id)) ??
      ProductEngagement.fromProduct(product);

  /// The same, for a surface that holds a product's *id* and not the product.
  ///
  /// A bundle's piece, a drop's item and a closet suggestion are all
  /// projections built for their own screen; they carry a title, a price and a
  /// product id. Without this they would be the exception to "every product,
  /// everywhere", and the exception is precisely what the client asked not to
  /// assume. There is no served fallback to fall back to, so the tallies are
  /// blank until the batch read answers — which it will, because
  /// [ProductEngagementNotifier.seedIds] queued them.
  static ProductEngagement watchId(WidgetRef ref, String productId) =>
      ref.watch(productEngagementOfProvider(productId)) ??
      const ProductEngagement();

  ProductEngagement get _current =>
      ref.read(productEngagementOfProvider(product.id)) ??
      ProductEngagement.fromProduct(product);

  /// Every write is account-bound. Without the gate a guest would see the
  /// heart fill and then quietly un-fill on a 401.
  Future<bool> _signedIn() => _requireAccount(context, ref, product.id);

  static Future<bool> _requireAccount(
    BuildContext context,
    WidgetRef ref,
    String productId,
  ) => requireAuthenticatedUser(
    context,
    ref,
    title: context.l10n.signInToInteract,
    message: context.l10n.signInToInteractBody,
    from: RoutePaths.productDetailsOf(productId),
  );

  Future<void> like({bool fromDoubleTap = false}) =>
      likeById(context, ref, product.id, fromDoubleTap: fromDoubleTap);

  /// The like, keyed on the id — the one implementation.
  ///
  /// [like] delegates here rather than repeating it, so the haptic, the
  /// sign-in gate, the optimistic write and the message on a refusal are the
  /// same whether the caller holds a `Product` or only its id.
  static Future<void> likeById(
    BuildContext context,
    WidgetRef ref,
    String productId, {
    bool fromDoubleTap = false,
  }) async {
    if (!fromDoubleTap) AppHaptics.selection();
    final store = ref.read(productEngagementProvider.notifier);
    final current =
        ref.read(productEngagementOfProvider(productId)) ??
        const ProductEngagement();
    final willLike = fromDoubleTap ? true : !current.isLiked;
    if (willLike == current.isLiked) return;
    if (!await _requireAccount(context, ref, productId) || !context.mounted) {
      return;
    }

    final outcome = await store.setLiked(productId, willLike);
    if (outcome == EngagementOutcome.failed && context.mounted) {
      DsSnackbar.error(context, context.l10n.actionDidNotSave);
    }
  }

  /// The bookmark: «المفضّلة», the same shelf the grid's heart fills.
  Future<void> save() async {
    AppHaptics.selection();
    if (!await _signedIn() || !context.mounted) return;

    final l10n = context.l10n;
    final wasSaved = _current.isSaved;
    final outcome = await _store.setSaved(product.id, !wasSaved);
    if (!context.mounted) return;
    if (outcome == EngagementOutcome.failed) {
      DsSnackbar.error(context, l10n.actionDidNotSave);
      return;
    }
    unawaited(ref.read(favoritesNotifierProvider.notifier).load());

    if (wasSaved) {
      DsSnackbar.show(
        context,
        message: l10n.postUnsaved,
        type: DsSnackbarType.success,
      );
      return;
    }

    // Saved, and now the second half of the gesture: where to keep it. The
    // sheet offers «بدون مجموعة» first and is dismissible, so the fast path is
    // unchanged — the piece is already on the shelf either way.
    await SaveToCollectionSheet.show(
      context,
      kind: SaveTargetKind.product,
      targetId: product.id,
    );
  }

  /// «أضيفي إلى صفحتي».
  ///
  /// No sheet in the way: adding a piece to her page is as light as a heart,
  /// and the snackbar says where it went — including, when her page is still
  /// private, that only she can see it, so a pick nobody else sees is never a
  /// surprise.
  Future<void> pick() async {
    AppHaptics.selection();
    if (!await _signedIn() || !context.mounted) return;

    final l10n = context.l10n;
    final me = ref.read(authNotifierProvider).user;
    // Only claimed when known: her own profile is loaded whenever she has
    // looked at her page or her profile this session, and otherwise the plain
    // confirmation is the honest one.
    final myPage = ref.exists(userProfileNotifierProvider(null))
        ? ref.read(userProfileNotifierProvider(null)).profile
        : null;
    final pageIsPrivate =
        myPage != null && !myPage.isSeller && !myPage.profileIsPublic;
    final adding = !_current.isPicked;
    final outcome = await _store.setPicked(product.id, adding);
    if (!context.mounted) return;
    if (outcome == EngagementOutcome.failed) {
      DsSnackbar.error(context, l10n.actionDidNotSave);
      return;
    }
    if (adding) AppHaptics.confirm();

    final router = GoRouter.of(context);
    DsSnackbar.show(
      context,
      message: !adding
          ? l10n.productUnpickedDone
          : pageIsPrivate
          ? l10n.productPickedPrivate
          : l10n.productPickedDone,
      type: DsSnackbarType.success,
      actionLabel: adding && me != null ? l10n.viewMyPage : null,
      onAction: adding && me != null
          ? () => router.push(RoutePaths.userProfileOf(me.id))
          : null,
    );
  }

  Future<void> share() async {
    AppHaptics.selection();
    final shared = await ShareService.product(
      context: context,
      productId: product.id,
      title: product.title,
      // The five things the message carries. Each is nullable and each is
      // dropped rather than faked: a product with no live offer travels
      // without a price instead of with a wrong one.
      price: product.price,
      sellerName: product.displaySeller?.name,
      imageUrl: product.media.stillImageUrl,
    );
    if (!shared) return;
    await _store.recordShare(product.id);
  }

  Future<void> comment() async {
    if (!await _signedIn() || !context.mounted) return;
    await showCommentSheet(
      context,
      CommentThread.product(product.id),
      onCountChanged: (delta) => _store.adjustComments(product.id, delta),
    );
  }

  void openProduct() => context.push(RoutePaths.productDetailsOf(product.id));

  void openSeller() {
    final seller = product.displaySeller;
    if (seller == null) return;
    context.push(RoutePaths.userProfileOf(seller.id));
  }

  /// The product's «…» menu.
  Future<void> options({bool showOpenProduct = true}) async {
    final l10n = context.l10n;
    final engagement = _current;
    final seller = product.displaySeller;

    final action = await DsBottomSheet.choose<_ProductAction>(
      context,
      choices: [
        DsSheetChoice(
          value: _ProductAction.pick,
          label: engagement.isPicked
              ? l10n.postMenuRemoveFromMyPage
              : l10n.contentAddToMyPage,
          icon: engagement.isPicked
              ? Icons.library_add_check_rounded
              : Icons.add_to_photos_outlined,
        ),
        DsSheetChoice(
          value: _ProductAction.save,
          label: engagement.isSaved ? l10n.postMenuUnsave : l10n.postMenuSave,
          icon: engagement.isSaved
              ? Icons.bookmark_remove_outlined
              : Icons.bookmark_add_outlined,
        ),
        if (showOpenProduct)
          DsSheetChoice(
            value: _ProductAction.open,
            label: l10n.postMenuViewProduct,
            icon: Icons.shopping_bag_outlined,
          ),
        if (seller != null)
          DsSheetChoice(
            value: _ProductAction.seller,
            label: l10n.postMenuViewAuthor(seller.name),
            icon: Icons.storefront_outlined,
          ),
        DsSheetChoice(
          value: _ProductAction.share,
          label: l10n.contentShare,
          icon: Icons.send_rounded,
        ),
        DsSheetChoice(
          value: _ProductAction.copyLink,
          label: l10n.postMenuCopyLink,
          icon: Icons.link_rounded,
        ),
        DsSheetChoice(
          value: _ProductAction.report,
          label: l10n.productMenuReport,
          icon: Icons.flag_outlined,
          destructive: true,
        ),
      ],
    );
    if (action == null || !context.mounted) return;

    switch (action) {
      case _ProductAction.pick:
        await pick();
      case _ProductAction.save:
        await save();
      case _ProductAction.open:
        openProduct();
      case _ProductAction.seller:
        openSeller();
      case _ProductAction.share:
        await share();
      case _ProductAction.copyLink:
        await Clipboard.setData(
          ClipboardData(text: ShareService.productUrl(product.id)),
        );
        if (context.mounted) DsSnackbar.success(context, l10n.linkCopied);
      case _ProductAction.report:
        if (!await _signedIn() || !context.mounted) return;
        await showReportSheet(
          context,
          submit: (reason) => ref
              .read(productSocialRepositoryProvider)
              .report(product.id, reason),
        );
    }
  }
}

enum _ProductAction { pick, save, open, seller, share, copyLink, report }
