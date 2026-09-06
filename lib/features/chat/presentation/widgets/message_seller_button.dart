import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:reem/core/design_system/design_system.dart';
import 'package:reem/core/localization/l10n_extension.dart';
import 'package:reem/core/router/route_paths.dart';
import 'package:reem/features/auth/presentation/widgets/auth_prompt_sheet.dart';
import 'package:reem/features/chat/domain/entities/chat_start_request.dart';
import 'package:reem/features/chat/presentation/providers/chat_provider.dart';

/// Opens — or reopens — a conversation and navigates to it.
///
/// Everything that lets her reach a boutique goes through here, so the auth
/// gate, the failure message and the "reuse the existing thread" behaviour are
/// identical from the product page, the storefront and the order.
///
/// Returns true when a conversation was opened.
Future<bool> openConversation(
  BuildContext context,
  WidgetRef ref,
  ChatStartRequest request,
) async {
  final l10n = context.l10n;

  // A guest can browse and even fill a bag, but a conversation belongs to an
  // account — the seller has to be able to reply to *someone*.
  final signedIn = await requireAuthenticatedUser(
    context,
    ref,
    title: l10n.signInToMessage,
    message: l10n.signInToMessageBody,
    from: RoutePaths.chats,
  );
  if (!signedIn || !context.mounted) return false;

  final thread =
      await ref.read(chatNotifierProvider.notifier).startConversation(request);
  if (!context.mounted) return false;

  if (thread == null) {
    final reason = ref.read(chatNotifierProvider).error;
    DsSnackbar.error(context, reason ?? l10n.chatStartFailed);
    return false;
  }

  await context.push('${RoutePaths.chatDetails}?id=${thread.id}');
  return true;
}

/// The «راسلي المتجر» action.
///
/// Holds its own busy flag rather than reading one from the notifier: two of
/// these can sit on one screen (a product and its seller), and a shared flag
/// would spin both.
class MessageSellerButton extends ConsumerStatefulWidget {
  const MessageSellerButton({
    super.key,
    required this.request,
    this.label,
    this.icon = Icons.chat_bubble_outline_rounded,
    this.variant = DsButtonVariant.secondary,
    this.size = DsButtonSize.md,
    this.isExpanded = true,
  });

  final ChatStartRequest request;

  /// Defaults to «راسلي المتجر»; an order parcel names itself instead.
  final String? label;
  final IconData icon;
  final DsButtonVariant variant;
  final DsButtonSize size;
  final bool isExpanded;

  @override
  ConsumerState<MessageSellerButton> createState() =>
      _MessageSellerButtonState();
}

class _MessageSellerButtonState extends ConsumerState<MessageSellerButton> {
  bool _busy = false;

  Future<void> _open() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await openConversation(context, ref, widget.request);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DsButton(
      label: widget.label ?? context.l10n.messageSeller,
      icon: widget.icon,
      variant: widget.variant,
      size: widget.size,
      isExpanded: widget.isExpanded,
      isLoading: _busy,
      onPressed: _busy ? null : _open,
    );
  }
}
