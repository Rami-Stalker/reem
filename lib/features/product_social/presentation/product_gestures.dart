import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:reem/core/design_system/design_system.dart';
import 'package:reem/core/localization/l10n_extension.dart';
import 'package:reem/core/platform/app_haptics.dart';
import 'package:reem/core/router/route_paths.dart';
import 'package:reem/core/shared/entities/product.dart';
import 'package:reem/core/shared/services/share_service.dart';
import 'package:reem/features/auth/presentation/providers/auth_provider.dart';
import 'package:reem/features/auth/presentation/widgets/auth_prompt_sheet.dart';
import 'package:reem/features/product_social/domain/entities/product_engagement.dart';
import 'package:reem/features/product_social/presentation/providers/product_social_providers.dart';
import 'package:reem/features/profile/presentation/providers/profile_provider.dart';
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

  ProductEngagement get _current =>
      ref.read(productEngagementOfProvider(product.id)) ??
      ProductEngagement.fromProduct(product);

  /// Every write is account-bound. Without the gate a guest would see the
  /// heart fill and then quietly un-fill on a 401.
  Future<bool> _signedIn() => requireAuthenticatedUser(
    context,
    ref,
    title: context.l10n.signInToInteract,
    message: context.l10n.signInToInteractBody,
    from: RoutePaths.productDetailsOf(product.id),
  );

  Future<void> like({bool fromDoubleTap = false}) async {
    if (!fromDoubleTap) AppHaptics.selection();
    final willLike = fromDoubleTap ? true : !_current.isLiked;
    if (willLike == _current.isLiked) return;
    if (!await _signedIn() || !context.mounted) return;

    final outcome = await _store.setLiked(product.id, willLike);
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
    DsSnackbar.show(
      context,
      message: wasSaved ? l10n.postUnsaved : l10n.postSaved,
      type: DsSnackbarType.success,
      actionLabel: wasSaved ? null : l10n.viewSaved,
      onAction: wasSaved ? null : () => context.push(RoutePaths.favorites),
    );
    unawaited(ref.read(favoritesNotifierProvider.notifier).load());
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
