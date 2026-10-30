import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ohara/core/design_system/design_system.dart';
import 'package:ohara/core/localization/l10n_extension.dart';
import 'package:ohara/core/localization/readable_message.dart';
import 'package:ohara/core/media/media_decode.dart';
import 'package:ohara/core/media/media_lightbox.dart';
import 'package:ohara/core/media/media_variants.dart';
import 'package:ohara/core/utils/relative_time.dart';
import 'package:ohara/features/admin/presentation/widgets/admin_page_header.dart';
import 'package:ohara/features/social/domain/entities/content.dart';
import 'package:ohara/features/social/presentation/providers/admin_content_notifier.dart';
import 'package:ohara/features/social/presentation/widgets/report_sheet.dart';
import 'package:ohara/l10n/app_localizations.dart';

/// Everything published, for a moderator.
///
/// Posts, reels and stories go live the moment they are posted — nobody
/// approves them first. This screen is the other half of that: a moderator
/// sees what was reported or flagged by the word screen, and can remove,
/// restore, or keep it.
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
        else ...[
          SliverPadding(
            padding: EdgeInsets.all(courtGutter(context)),
            sliver: SliverList.separated(
              itemCount: state.items.length,
              separatorBuilder: (_, _) => DsGaps.vSm,
              itemBuilder: (context, index) {
                final item = state.items[index];
                return _ModerationRow(
                  key: ValueKey(item.content.id),
                  item: item,
                  busy: state.busyIds.contains(item.content.id),
                  onOpen: () => _openMedia(context, item.content),
                  onRemove: () => _remove(context, ref, item),
                  onReinstate: () => _reinstate(context, ref, item),
                  onKeep: () => _keep(context, ref, item),
                );
              },
            ),
          ),
          if (state.hasMore)
            SliverPadding(
              padding: EdgeInsets.symmetric(horizontal: courtGutter(context)),
              sliver: SliverToBoxAdapter(
                child: SecondaryButton(
                  label: context.l10n.adminContentLoadMore,
                  isLoading: state.isLoadingMore,
                  onPressed: state.isLoadingMore ? null : notifier.loadMore,
                ),
              ),
            ),
        ],
        DsGaps.sliverBottomSafe,
      ],
    );
  }

  /// The piece at full size — a moderator decides on what she can see, not a
  /// 56-pixel thumbnail.
  Future<void> _openMedia(BuildContext context, Content content) async {
    final video = content.video;
    if (video != null) {
      await Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          fullscreenDialog: true,
          builder: (_) => _VideoPreview(
            url: video.url,
            thumbnailUrl: video.thumbnailUrl,
            title: content.author.name,
          ),
        ),
      );
      return;
    }
    final cover = content.cover;
    if (cover == null) return;
    await MediaLightbox.open(
      context,
      url: cover.url,
      title: content.author.name,
    );
  }

  Future<void> _remove(
    BuildContext context,
    WidgetRef ref,
    AdminContentItem item,
  ) async {
    final reason = await showModerationReasonDialog(
      context,
      title: context.l10n.adminContentRemoveHeading,
      body: context.l10n.adminContentRemoveBody,
      confirmLabel: context.l10n.adminContentRemoveConfirm,
      presets: _removalPresets(context.l10n, item),
    );
    if (reason == null || !context.mounted) return;
    await _report(
      context,
      ref.read(adminContentProvider.notifier).remove(item.content.id, reason),
      context.l10n.adminContentRemovedToast,
    );
  }

  Future<void> _reinstate(
    BuildContext context,
    WidgetRef ref,
    AdminContentItem item,
  ) async {
    final reason = await showModerationReasonDialog(
      context,
      title: context.l10n.adminContentReinstateHeading,
      body: context.l10n.adminContentReinstateBody,
      confirmLabel: context.l10n.adminContentReinstateConfirm,
      destructive: false,
    );
    if (reason == null || !context.mounted) return;
    await _report(
      context,
      ref
          .read(adminContentProvider.notifier)
          .reinstate(item.content.id, reason),
      context.l10n.adminContentReinstatedToast,
    );
  }

  Future<void> _keep(
    BuildContext context,
    WidgetRef ref,
    AdminContentItem item,
  ) async {
    final note = await showModerationReasonDialog(
      context,
      title: context.l10n.adminContentKeepTitle,
      body: context.l10n.adminContentKeepBody,
      confirmLabel: context.l10n.adminContentKeep,
      label: context.l10n.adminContentNoteLabel,
      reasonRequired: false,
      destructive: false,
    );
    if (note == null || !context.mounted) return;
    await _report(
      context,
      ref.read(adminContentProvider.notifier).keep(item.content.id, note: note),
      context.l10n.adminContentKeptToast,
    );
  }

  /// Says the outcome back to her, either way. A decision that failed while
  /// the list was on screen used to vanish into state nobody drew.
  Future<void> _report(
    BuildContext context,
    Future<String?> decision,
    String success,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    final failure = await decision;
    if (failure == null) {
      DsSnackbar.on(messenger, message: success, type: DsSnackbarType.success);
    } else {
      DsSnackbar.on(
        messenger,
        message: readableMessage(l10n, failure),
        type: DsSnackbarType.error,
      );
    }
  }
}

/// Ready-made reasons, so a takedown takes one tap and still tells her
/// something she can act on. The word screen's own match leads when it fired.
List<String> _removalPresets(AppLocalizations l10n, AdminContentItem item) => [
  if (item.autoFlagged) l10n.adminContentPresetOffPlatform,
  l10n.adminContentPresetImmodest,
  if (!item.autoFlagged) l10n.adminContentPresetOffPlatform,
  l10n.adminContentPresetSpam,
  l10n.adminContentPresetStolen,
  l10n.adminContentPresetHarassment,
  l10n.adminContentPresetCounterfeit,
];

class _Filters extends StatelessWidget {
  const _Filters({required this.selected, required this.onSelect});

  final AdminContentFilter selected;
  final ValueChanged<AdminContentFilter> onSelect;

  String _label(BuildContext context, AdminContentFilter filter) =>
      switch (filter) {
        AdminContentFilter.all => context.l10n.adminContentFilterAll,
        AdminContentFilter.reported => context.l10n.adminContentFilterReported,
        AdminContentFilter.posts => context.l10n.adminContentFilterPosts,
        AdminContentFilter.reels => context.l10n.adminContentFilterReels,
        AdminContentFilter.stories => context.l10n.adminContentFilterStories,
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
    super.key,
    required this.item,
    required this.busy,
    required this.onOpen,
    required this.onRemove,
    required this.onReinstate,
    required this.onKeep,
  });

  final AdminContentItem item;
  final bool busy;
  final VoidCallback onOpen;
  final VoidCallback onRemove;
  final VoidCallback onReinstate;
  final VoidCallback onKeep;

  String _formatLabel(BuildContext context) => switch (item.content.format) {
    ContentFormat.post => context.l10n.adminContentFormatPost,
    ContentFormat.reel => context.l10n.adminContentFormatReel,
    ContentFormat.story => context.l10n.adminContentFormatStory,
    _ => context.l10n.adminContentFormatOther,
  };

  IconData get _formatIcon => switch (item.content.format) {
    ContentFormat.reel => Icons.play_circle_outline_rounded,
    ContentFormat.story => Icons.amp_stories_outlined,
    _ => Icons.image_outlined,
  };

  @override
  Widget build(BuildContext context) {
    final console = context.console;
    final content = item.content;
    final cover = content.cover;
    final thumbUrl = content.shareImageUrl ?? cover?.displayUrl;

    return AdminPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Semantics(
                button: true,
                label: context.l10n.adminContentOpenMedia,
                child: GestureDetector(
                  onTap: content.hasMedia ? onOpen : null,
                  child: SizedBox(
                    width: DsSizes.thumbMd,
                    height: DsSizes.thumbMd,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(DsRadius.sm),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          if (thumbUrl == null)
                            const DsMediaFallback()
                          else
                            CachedNetworkImage(
                              imageUrl: MediaVariants.thumb(thumbUrl),
                              memCacheWidth: MediaDecode.widthFor(
                                context,
                                DsSizes.thumbMd,
                              ),
                              fit: BoxFit.cover,
                              errorWidget: (_, _, _) => const DsMediaFallback(),
                            ),
                          if (content.format.isVideo)
                            const Center(
                              child: Icon(
                                Icons.play_arrow_rounded,
                                color: Colors.white,
                                shadows: [
                                  Shadow(blurRadius: 6, color: Colors.black54),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              DsGaps.hSm,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      content.author.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.dsText.tileTitle,
                    ),
                    DsGaps.vXxs,
                    Wrap(
                      spacing: DsSpacing.xxs,
                      runSpacing: DsSpacing.xxs,
                      children: [
                        DsBadge(
                          label: _formatLabel(context),
                          icon: _formatIcon,
                          tone: DsBadgeTone.info,
                        ),
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
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: context.dsText.body,
                    ),
                    DsGaps.vXxs,
                    Text(
                      formatRelativeTime(
                        context.l10n,
                        content.publishedAt ?? content.createdAt,
                      ),
                      style: context.dsText.micro.tint(console.muted),
                    ),
                  ],
                ),
              ),
              _StateBadge(item: item),
            ],
          ),
          if (item.hasReports) ...[DsGaps.vSm, _ReportsSummary(item: item)],
          if (item.removalReason != null && item.isRemoved) ...[
            DsGaps.vSm,
            // The reason, kept where a review can read it. A takedown without
            // one is refused before it reaches the database.
            Text(
              context.l10n.adminContentRemovedFor(item.removalReason!),
              style: context.dsText.caption.tint(console.criticalInk),
            ),
          ],
          DsGaps.vSm,
          Row(
            children: [
              if (item.isRemoved)
                Expanded(
                  child: SecondaryButton(
                    label: context.l10n.adminContentReinstateConfirm,
                    icon: Icons.restore_rounded,
                    isLoading: busy,
                    onPressed: busy ? null : onReinstate,
                  ),
                )
              else ...[
                if (item.hasReports) ...[
                  Expanded(
                    child: SecondaryButton(
                      label: context.l10n.adminContentKeep,
                      icon: Icons.check_rounded,
                      onPressed: busy ? null : onKeep,
                    ),
                  ),
                  DsGaps.hSm,
                ],
                Expanded(
                  child: DsButton(
                    label: context.l10n.adminContentRemoveConfirm,
                    icon: Icons.delete_outline_rounded,
                    variant: DsButtonVariant.danger,
                    size: DsButtonSize.md,
                    isLoading: busy,
                    onPressed: busy ? null : onRemove,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

/// How many open reports, and what they say — a moderator should not have to
/// open another screen to learn why a row is in front of her.
class _ReportsSummary extends StatelessWidget {
  const _ReportsSummary({required this.item});

  final AdminContentItem item;

  String _reason(AppLocalizations l10n, String raw) {
    final split = raw.indexOf(':');
    final code = split < 0 ? raw : raw.substring(0, split);
    final detail = split < 0 ? '' : raw.substring(split + 1).trim();
    if (code == 'auto_flag') return l10n.adminContentAutoFlagged;
    final known = ReportReason.values
        .where((reason) => reason.wire == code)
        .firstOrNull;
    final label = known?.label(l10n) ?? code;
    return detail.isEmpty ? label : '$label — $detail';
  }

  @override
  Widget build(BuildContext context) {
    final console = context.console;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(DsSpacing.sm),
      decoration: BoxDecoration(
        color: console.caution.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(DsRadius.sm),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.flag_outlined, size: 16, color: console.cautionInk),
              DsGaps.hXxs,
              Text(
                context.l10n.adminContentReportsCount(item.reportsCount),
                style: context.dsText.caption.tint(console.cautionInk),
              ),
            ],
          ),
          for (final raw in item.reportReasons) ...[
            DsGaps.vXxs,
            Text(
              '• ${_reason(context.l10n, raw)}',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: context.dsText.micro.tint(console.ink),
            ),
          ],
        ],
      ),
    );
  }
}

class _StateBadge extends StatelessWidget {
  const _StateBadge({required this.item});

  final AdminContentItem item;

  @override
  Widget build(BuildContext context) {
    final content = item.content;
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

/// A reel, played at full size for a moderator to judge.
class _VideoPreview extends StatelessWidget {
  const _VideoPreview({
    required this.url,
    required this.title,
    this.thumbnailUrl,
  });

  final String url;
  final String? thumbnailUrl;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DsColors.mediaGround,
      extendBodyBehindAppBar: true,
      appBar: OharaAppBar(title: title, transparent: true),
      body: Center(
        child: DsVideoPlayer(
          url: url,
          thumbnailUrl: thumbnailUrl,
          fit: BoxFit.contain,
        ),
      ),
    );
  }
}

/// The reason dialog. When a reason is [reasonRequired] it cannot be confirmed
/// empty, and it says why. [presets] fill the field in one tap and can still
/// be edited before sending.
///
/// Returns the trimmed text, an empty string for an optional note left blank,
/// or `null` when cancelled.
Future<String?> showModerationReasonDialog(
  BuildContext context, {
  required String title,
  required String body,
  required String confirmLabel,
  String? label,
  List<String> presets = const [],
  bool reasonRequired = true,
  bool destructive = true,
}) {
  return showDialog<String>(
    context: context,
    builder: (context) => _ReasonDialog(
      title: title,
      body: body,
      confirmLabel: confirmLabel,
      label: label,
      presets: presets,
      reasonRequired: reasonRequired,
      destructive: destructive,
    ),
  );
}

class _ReasonDialog extends StatefulWidget {
  const _ReasonDialog({
    required this.title,
    required this.body,
    required this.confirmLabel,
    required this.presets,
    required this.reasonRequired,
    required this.destructive,
    this.label,
  });

  final String title;
  final String body;
  final String confirmLabel;
  final String? label;
  final List<String> presets;
  final bool reasonRequired;
  final bool destructive;

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

  void _usePreset(String preset) {
    _reason
      ..text = preset
      ..selection = TextSelection.collapsed(offset: preset.length);
  }

  @override
  Widget build(BuildContext context) {
    final text = _reason.text.trim();
    // An optional note may be empty, but a short one is still refused by the
    // server, so the same floor applies once she starts typing.
    final valid = widget.reasonRequired
        ? text.length >= _minimum
        : text.isEmpty || text.length >= _minimum;

    return AlertDialog(
      title: Text(widget.title, style: context.dsText.sectionTitle),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.body, style: context.dsText.body),
            if (widget.presets.isNotEmpty) ...[
              DsGaps.vMd,
              Text(
                context.l10n.adminContentQuickReasons,
                style: context.dsText.caption,
              ),
              DsGaps.vXs,
              Wrap(
                spacing: DsSpacing.xs,
                runSpacing: DsSpacing.xs,
                children: [
                  for (final preset in widget.presets)
                    DsChip(
                      label: preset,
                      selected: text == preset,
                      onTap: () => _usePreset(preset),
                    ),
                ],
              ),
            ],
            DsGaps.vMd,
            DsInputField(
              controller: _reason,
              label: widget.label ?? context.l10n.adminContentReasonLabel,
              hint: context.l10n.adminContentReasonHint,
              maxLines: 3,
            ),
            if (!valid && text.isNotEmpty) ...[
              DsGaps.vXs,
              Text(
                context.l10n.adminContentReasonTooShort,
                style: context.dsText.micro.tint(context.dsColors.errorInk),
              ),
            ],
          ],
        ),
      ),
      actions: [
        GhostButton(
          label: context.l10n.cancel,
          onPressed: () => Navigator.of(context).pop(),
        ),
        DsButton(
          label: widget.confirmLabel,
          variant: widget.destructive
              ? DsButtonVariant.danger
              : DsButtonVariant.primary,
          isExpanded: false,
          size: DsButtonSize.md,
          // The whole point: no reason, no removal.
          onPressed: valid ? () => Navigator.of(context).pop(text) : null,
        ),
      ],
    );
  }
}
