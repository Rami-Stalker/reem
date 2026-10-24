import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:ohara/core/design_system/design_system.dart';
import 'package:ohara/core/localization/l10n_extension.dart';
import 'package:ohara/core/result/result.dart';
import 'package:ohara/core/router/route_paths.dart';
import 'package:ohara/core/shared/entities/user.dart';
import 'package:ohara/core/shared/services/share_service.dart';
import 'package:ohara/features/auth/presentation/providers/auth_provider.dart';
import 'package:ohara/features/auth/presentation/widgets/auth_prompt_sheet.dart';
import 'package:ohara/features/social/domain/entities/content.dart';
import 'package:ohara/features/social/presentation/providers/social_providers.dart';
import 'package:ohara/features/social/presentation/widgets/edit_content_sheet.dart';
import 'package:ohara/features/social/presentation/widgets/report_sheet.dart';

/// What the «…» on a post is about.
///
/// Built from whichever shape the card holds — the home feed's `Post` or the
/// platform's `Content` — because the menu only needs to know whose it is,
/// what it points at, and whether she already added it to her page.
class PostMenuTarget {
  const PostMenuTarget({
    required this.contentId,
    required this.author,
    this.productId,
    this.isReshared = false,
    this.content,
  });

  final String contentId;
  final User author;
  final String? productId;
  final bool isReshared;

  /// The piece itself, when the card holds the platform's `Content`. Needed
  /// to offer «تعديل» — the edit sheet starts from her current caption.
  final Content? content;
}

/// How the feed that owns the card should react to what she chose.
///
/// Every callback is optional: a screen that cannot remove a card (a single
/// post opened from a link) simply leaves them out and the menu still hides,
/// mutes and reports — the next load of any feed honours it.
class PostMenuCallbacks {
  const PostMenuCallbacks({
    this.onHidden,
    this.onUnhidden,
    this.onMuted,
    this.onUnmuted,
    this.onToggleReshare,
    this.onDeleted,
    this.onEdited,
  });

  /// The card should leave the list now.
  final VoidCallback? onHidden;

  /// «تراجع» — put it back.
  final VoidCallback? onUnhidden;

  /// Every card by this author should leave the list.
  final VoidCallback? onMuted;
  final VoidCallback? onUnmuted;

  /// «أضيفي إلى صفحتي» / «إزالة من صفحتي». Null hides the row.
  final VoidCallback? onToggleReshare;

  /// Her own post was deleted. Null hides «حذف المنشور» — a surface that
  /// cannot take the card away should not offer to.
  final VoidCallback? onDeleted;

  /// Her own post was edited; the card should show the new caption. Null
  /// hides «تعديل».
  final ValueChanged<Content>? onEdited;
}

enum _PostAction {
  edit,
  notInterested,
  mute,
  reshare,
  viewProduct,
  viewAuthor,
  copyLink,
  delete,
  report,
}

/// The post menu.
///
/// It used to be a glyph that did nothing — or, on a post with a product,
/// quietly opened the product, which is not what three dots promise. What a
/// woman expects behind them is the Instagram set, in Ohara's register: the
/// quiet exits first («غير مهتمة», hide this account), then the useful ones,
/// and the report last and in red.
///
/// «غير مهتمة» and the mute are private to her: nobody is notified and nothing
/// reaches moderation. A report is the only choice that involves anyone else,
/// which is why it asks for a reason.
Future<void> showPostOptions(
  BuildContext context,
  WidgetRef ref, {
  required PostMenuTarget target,
  PostMenuCallbacks callbacks = const PostMenuCallbacks(),
}) async {
  final l10n = context.l10n;
  final me = ref.read(authNotifierProvider).user?.id;
  final isMine = me != null && me == target.author.id;
  final name = target.author.name;

  final action = await DsBottomSheet.choose<_PostAction>(
    context,
    choices: [
      if (isMine && target.content != null && callbacks.onEdited != null)
        DsSheetChoice(
          value: _PostAction.edit,
          label: l10n.postMenuEdit,
          icon: Icons.edit_outlined,
        ),
      if (!isMine) ...[
        DsSheetChoice(
          value: _PostAction.notInterested,
          label: l10n.postMenuNotInterested,
          icon: Icons.visibility_off_outlined,
        ),
        DsSheetChoice(
          value: _PostAction.mute,
          label: l10n.postMenuMuteAuthor(name),
          icon: Icons.person_off_outlined,
        ),
      ],
      if (!isMine && callbacks.onToggleReshare != null)
        DsSheetChoice(
          value: _PostAction.reshare,
          label: target.isReshared
              ? l10n.postMenuRemoveFromMyPage
              : l10n.contentAddToMyPage,
          icon: target.isReshared
              ? Icons.library_add_check_rounded
              : Icons.add_to_photos_outlined,
        ),
      if (target.productId != null)
        DsSheetChoice(
          value: _PostAction.viewProduct,
          label: l10n.postMenuViewProduct,
          icon: Icons.shopping_bag_outlined,
        ),
      if (!isMine)
        DsSheetChoice(
          value: _PostAction.viewAuthor,
          label: l10n.postMenuViewAuthor(name),
          icon: Icons.account_circle_outlined,
        ),
      DsSheetChoice(
        value: _PostAction.copyLink,
        label: l10n.postMenuCopyLink,
        icon: Icons.link_rounded,
      ),
      if (isMine && callbacks.onDeleted != null)
        DsSheetChoice(
          value: _PostAction.delete,
          label: l10n.postMenuDelete,
          icon: Icons.delete_outline_rounded,
          destructive: true,
        ),
      if (!isMine)
        DsSheetChoice(
          value: _PostAction.report,
          label: l10n.postMenuReport,
          icon: Icons.flag_outlined,
          destructive: true,
        ),
    ],
  );
  if (action == null || !context.mounted) return;

  final repository = ref.read(socialRepositoryProvider);

  Future<bool> signedIn() => requireAuthenticatedUser(
    context,
    ref,
    title: l10n.signInToInteract,
    message: l10n.signInToInteractBody,
  );

  switch (action) {
    case _PostAction.edit:
      final content = target.content;
      if (content == null) return;
      final updated = await showEditContentSheet(context, content: content);
      if (updated != null) callbacks.onEdited?.call(updated);

    case _PostAction.notInterested:
      if (!await signedIn() || !context.mounted) return;
      final result = await repository.hide(target.contentId);
      if (!context.mounted) return;
      if (result case Error(:final failure)) {
        DsSnackbar.error(context, failure.message);
        return;
      }
      // The snackbar is raised before the card leaves the list: once it is
      // gone its context is too, and the undo must not depend on it.
      final messenger = ScaffoldMessenger.of(context);
      DsSnackbar.show(
        context,
        message: l10n.postMenuNotInterestedDone,
        type: DsSnackbarType.success,
        duration: const Duration(seconds: 5),
        actionLabel: l10n.actionUndo,
        onAction: () async {
          messenger.hideCurrentSnackBar();
          final undone = await repository.unhide(target.contentId);
          if (undone is Success) callbacks.onUnhidden?.call();
        },
      );
      callbacks.onHidden?.call();

    case _PostAction.mute:
      if (!await signedIn() || !context.mounted) return;
      final result = await repository.muteAuthor(target.author.id);
      if (!context.mounted) return;
      if (result case Error(:final failure)) {
        DsSnackbar.error(context, failure.message);
        return;
      }
      final messenger = ScaffoldMessenger.of(context);
      DsSnackbar.show(
        context,
        message: l10n.postMenuMuteAuthorDone(name),
        type: DsSnackbarType.success,
        duration: const Duration(seconds: 5),
        actionLabel: l10n.actionUndo,
        onAction: () async {
          messenger.hideCurrentSnackBar();
          final undone = await repository.unmuteAuthor(target.author.id);
          if (undone is Success) callbacks.onUnmuted?.call();
        },
      );
      callbacks.onMuted?.call();

    case _PostAction.reshare:
      callbacks.onToggleReshare?.call();

    case _PostAction.viewProduct:
      final productId = target.productId;
      if (productId != null) {
        unawaited(context.push(RoutePaths.productDetailsOf(productId)));
      }

    case _PostAction.viewAuthor:
      unawaited(context.push(RoutePaths.userProfileOf(target.author.id)));

    case _PostAction.copyLink:
      await Clipboard.setData(
        ClipboardData(text: ShareService.postUrl(target.contentId)),
      );
      if (context.mounted) DsSnackbar.success(context, l10n.linkCopied);

    case _PostAction.delete:
      final confirmed = await DsDialog.confirm(
        context,
        title: l10n.postDeleteTitle,
        message: l10n.postDeleteBody,
        confirmLabel: l10n.delete,
        cancelLabel: l10n.cancel,
        icon: Icons.delete_outline_rounded,
        destructive: true,
      );
      if (!confirmed || !context.mounted) return;
      final result = await repository.deleteOwn(target.contentId);
      if (!context.mounted) return;
      switch (result) {
        case Success():
          DsSnackbar.success(context, l10n.postDeleted);
          callbacks.onDeleted?.call();
        case Error(:final failure):
          DsSnackbar.error(context, failure.message);
      }

    case _PostAction.report:
      if (!await signedIn() || !context.mounted) return;
      await showReportSheet(
        context,
        submit: (reason) => repository.report(target.contentId, reason),
        submitDetailed: (reason, detail) =>
            repository.report(target.contentId, reason, detail: detail),
      );
  }
}
