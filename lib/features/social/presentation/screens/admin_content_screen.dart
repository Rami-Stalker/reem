import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ohara/core/design_system/design_system.dart';
import 'package:ohara/core/localization/l10n_extension.dart';
import 'package:ohara/core/media/media_decode.dart';
import 'package:ohara/core/media/media_variants.dart';
import 'package:ohara/core/utils/relative_time.dart';
import 'package:ohara/features/admin/presentation/widgets/admin_page_header.dart';
import 'package:ohara/features/social/domain/entities/content.dart';
import 'package:ohara/features/social/presentation/providers/admin_content_notifier.dart';

/// Everything published, for a moderator.
///
/// Unlike every other read on the platform this one is deliberately **not**
/// filtered by visibility: a moderator sees a private woman's page, content
/// already taken down, and everything anybody has complained about. A queue
/// that only shows what a shopper can see cannot answer a report.
///
/// The removal dialog demands a reason and will not submit without one. That
/// is enforced in three places — here, in the service, and by a CHECK
/// constraint on the moderation-action table — because "the admin must say
/// why" is the requirement, and a rule enforced in one layer has two ways
/// around it.
class AdminContentScreen extends ConsumerWidget {
  const AdminContentScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(adminContentProvider);
    final notifier = ref.read(adminContentProvider.notifier);

    return OharaScrollPage(
      background: const AdminConsoleBackground(),
      onRefresh: notifier.load,
      slivers: [
        // The console's own sky rather than the shop's app bar: this page
        // lives under the rail like every other room of the console.
        SliverToBoxAdapter(
          child: AdminPageHeader(
            title: context.l10n.adminContentTitle,
            icon: Icons.photo_library_rounded,
            subtitle: state.pending > 0
                ? context.l10n.adminContentReported(state.pending)
                : null,
            actions: [
              IconButton(
                tooltip: context.l10n.refresh,
                onPressed: notifier.load,
                icon: const Icon(Icons.refresh_rounded),
              ),
            ],
          ),
        ),
        SliverPadding(
          padding: EdgeInsets.symmetric(horizontal: courtGutter(context)),
          sliver: SliverToBoxAdapter(
            child: _Filters(
              selected: state.filter,
              onSelect: notifier.setFilter,
            ),
          ),
        ),
        if (state.isLoading && state.items.isEmpty)
          const SliverFillRemaining(
            hasScrollBody: false,
            child: Center(child: DsLoadingIndicator()),
          )
        else if (state.error != null && state.items.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: DsErrorState(message: state.error, onRetry: notifier.load),
          )
        else if (state.items.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: DsEmptyState(
              icon: Icons.verified_outlined,
              title: context.l10n.adminContentEmpty,
            ),
          )
        else
          SliverPadding(
            padding: EdgeInsets.all(courtGutter(context)),
            sliver: SliverList.separated(
              itemCount: state.items.length,
              separatorBuilder: (_, _) => DsGaps.vSm,
              itemBuilder: (context, index) {
                final content = state.items[index];
                return _ModerationRow(
                  content: content,
                  onRemove: () => _remove(context, ref, content),
                  onReinstate: content.isRemoved
                      ? () => _reinstate(context, ref, content)
                      : null,
                );
              },
            ),
          ),
        DsGaps.sliverBottomSafe,
      ],
    );
  }

  Future<void> _remove(
    BuildContext context,
    WidgetRef ref,
    Content content,
  ) async {
    final reason = await showModerationReasonDialog(
      context,
      title: context.l10n.adminContentRemoveTitle,
      body: context.l10n.adminContentRemoveBody,
      confirmLabel: context.l10n.adminContentRemoveConfirm,
    );
    if (reason == null) return;
    await ref.read(adminContentProvider.notifier).remove(content.id, reason);
  }

  Future<void> _reinstate(
    BuildContext context,
    WidgetRef ref,
    Content content,
  ) async {
    final reason = await showModerationReasonDialog(
      context,
      title: context.l10n.adminContentReinstateTitle,
      body: context.l10n.adminContentReinstateBody,
      confirmLabel: context.l10n.adminContentReinstateConfirm,
    );
    if (reason == null) return;
    await ref.read(adminContentProvider.notifier).reinstate(content.id, reason);
  }
}

class _Filters extends StatelessWidget {
  const _Filters({required this.selected, required this.onSelect});

  final AdminContentFilter selected;
  final ValueChanged<AdminContentFilter> onSelect;

  String _label(BuildContext context, AdminContentFilter filter) =>
      switch (filter) {
        AdminContentFilter.all => context.l10n.adminContentFilterAll,
        AdminContentFilter.reported => context.l10n.adminContentFilterReported,
        AdminContentFilter.underReview =>
          context.l10n.adminContentFilterUnderReview,
        AdminContentFilter.removed => context.l10n.adminContentFilterRemoved,
        AdminContentFilter.customers =>
          context.l10n.adminContentFilterCustomers,
        AdminContentFilter.sellers => context.l10n.adminContentFilterSellers,
      };

  @override
  Widget build(BuildContext context) {
    return CourtFilterBeads<AdminContentFilter>(
      selected: selected,
      onSelected: (filter) {
        if (filter != null) onSelect(filter);
      },
      options: [
        for (final filter in AdminContentFilter.values)
          CourtFilterOption(value: filter, label: _label(context, filter)),
      ],
    );
  }
}

class _ModerationRow extends StatelessWidget {
  const _ModerationRow({
    required this.content,
    required this.onRemove,
    this.onReinstate,
  });

  final Content content;
  final VoidCallback onRemove;
  final VoidCallback? onReinstate;

  @override
  Widget build(BuildContext context) {
    final console = context.console;
    final cover = content.cover;

    return AdminPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: DsSizes.thumbMd,
                height: DsSizes.thumbMd,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(DsRadius.sm),
                  child: cover == null
                      ? const DsMediaFallback()
                      : CachedNetworkImage(
                          imageUrl: MediaVariants.thumb(cover.displayUrl),
                          memCacheWidth: MediaDecode.widthFor(
                            context,
                            DsSizes.thumbMd,
                          ),
                          fit: BoxFit.cover,
                          errorWidget: (_, _, _) => const DsMediaFallback(),
                        ),
                ),
              ),
              DsGaps.hSm,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            content.author.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: context.dsText.tileTitle,
                          ),
                        ),
                        DsGaps.hXs,
                        // Whose content this is, as she was when she wrote it.
                        DsBadge(
                          label: content.authorKind.isCustomer
                              ? context.l10n.contentFromShopper
                              : context.l10n.contentFromBoutique,
                          tone: DsBadgeTone.neutral,
                        ),
                      ],
                    ),
                    DsGaps.vXxs,
                    Text(
                      content.caption.isEmpty
                          ? context.l10n.adminContentNoCaption
                          : content.caption,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: context.dsText.body,
                    ),
                    DsGaps.vXxs,
                    Text(
                      formatRelativeTime(context.l10n, content.createdAt),
                      style: context.dsText.micro.tint(console.muted),
                    ),
                  ],
                ),
              ),
              _StateBadge(content: content),
            ],
          ),
          if (content.removalReason != null) ...[
            DsGaps.vSm,
            // The reason, kept where a review can read it. A takedown without
            // one is refused before it reaches the database.
            Text(
              context.l10n.adminContentRemovedFor(content.removalReason!),
              style: context.dsText.caption.tint(console.critical),
            ),
          ],
          DsGaps.vSm,
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (onReinstate != null)
                SecondaryButton(
                  label: context.l10n.adminContentReinstateConfirm,
                  onPressed: onReinstate,
                )
              else
                DsButton(
                  label: context.l10n.adminContentRemoveConfirm,
                  variant: DsButtonVariant.danger,
                  onPressed: onRemove,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StateBadge extends StatelessWidget {
  const _StateBadge({required this.content});

  final Content content;

  @override
  Widget build(BuildContext context) {
    if (content.isRemoved) {
      return DsBadge(
        label: context.l10n.adminContentStateRemoved,
        tone: DsBadgeTone.sale,
      );
    }
    if (content.isUnderReview) {
      return DsBadge(
        label: context.l10n.contentUnderReview,
        tone: DsBadgeTone.warning,
      );
    }
    return DsBadge(
      label: context.l10n.adminContentStateActive,
      tone: DsBadgeTone.success,
    );
  }
}

/// The reason dialog. It cannot be confirmed empty, and it says why.
Future<String?> showModerationReasonDialog(
  BuildContext context, {
  required String title,
  required String body,
  required String confirmLabel,
}) {
  return showDialog<String>(
    context: context,
    builder: (context) =>
        _ReasonDialog(title: title, body: body, confirmLabel: confirmLabel),
  );
}

class _ReasonDialog extends StatefulWidget {
  const _ReasonDialog({
    required this.title,
    required this.body,
    required this.confirmLabel,
  });

  final String title;
  final String body;
  final String confirmLabel;

  @override
  State<_ReasonDialog> createState() => _ReasonDialogState();
}

class _ReasonDialogState extends State<_ReasonDialog> {
  final _reason = TextEditingController();

  /// Ten characters, matching the server and the database CHECK. Long enough
  /// to be a sentence a woman can act on rather than a word she cannot.
  static const _minimum = 10;

  @override
  void initState() {
    super.initState();
    _reason.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final valid = _reason.text.trim().length >= _minimum;

    return AlertDialog(
      title: Text(widget.title, style: context.dsText.sectionTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.body, style: context.dsText.body),
          DsGaps.vMd,
          DsInputField(
            controller: _reason,
            label: context.l10n.adminContentReasonLabel,
            hint: context.l10n.adminContentReasonHint,
            maxLines: 3,
          ),
          if (!valid && _reason.text.isNotEmpty) ...[
            DsGaps.vXs,
            Text(
              context.l10n.adminContentReasonTooShort,
              style: context.dsText.micro.tint(context.dsColors.error),
            ),
          ],
        ],
      ),
      actions: [
        GhostButton(
          label: context.l10n.cancel,
          onPressed: () => Navigator.of(context).pop(),
        ),
        DsButton(
          label: widget.confirmLabel,
          variant: DsButtonVariant.danger,
          // The whole point: no reason, no removal.
          onPressed: valid
              ? () => Navigator.of(context).pop(_reason.text.trim())
              : null,
        ),
      ],
    );
  }
}
