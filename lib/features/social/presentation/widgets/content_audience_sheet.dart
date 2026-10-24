import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:reem/core/design_system/design_system.dart';
import 'package:reem/core/localization/l10n_extension.dart';
import 'package:reem/core/utils/relative_time.dart';
import 'package:reem/features/social/domain/entities/content_audience.dart';
import 'package:reem/features/social/presentation/providers/social_providers.dart';

/// «شوهدت من قبل» — who watched her story or reel, and what they sent back.
///
/// For a shopper's story as much as a boutique's: the old viewers screen sat
/// behind a seller-only route, so a woman posting a story had no way to know
/// whether anyone had seen it.
///
/// [onOpenProfile] is called with a viewer's id after the sheet closes, so
/// the caller decides how to get there (the story viewer closes itself first).
Future<void> showContentAudienceSheet(
  BuildContext context, {
  required String contentId,
  ValueChanged<String>? onOpenProfile,
}) async {
  final opened = await DsBottomSheet.show<String>(
    context,
    builder: (_) => _AudienceSheet(contentId: contentId),
  );
  if (opened != null) onOpenProfile?.call(opened);
}

class _AudienceSheet extends ConsumerWidget {
  const _AudienceSheet({required this.contentId});

  final String contentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final audience = ref.watch(contentAudienceProvider(contentId));

    return DsSheetScaffold(
      title: l10n.audienceTitle,
      child: audience.when(
        loading: () => const Padding(
          padding: EdgeInsets.all(DsSpacing.xl),
          child: Center(child: DsLoadingIndicator()),
        ),
        error: (error, _) => DsInlineError(
          message: '$error',
          onRetry: () => ref.invalidate(contentAudienceProvider(contentId)),
        ),
        data: (data) => _AudienceBody(audience: data),
      ),
    );
  }
}

class _AudienceBody extends StatelessWidget {
  const _AudienceBody({required this.audience});

  final ContentAudience audience;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final c = context.dsColors;
    final reactions = audience.reactionBreakdown.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Expanded(
              child: _Figure(
                value: audience.viewersCount,
                label: l10n.audienceViewers,
              ),
            ),
            Expanded(
              child: _Figure(value: audience.views, label: l10n.audienceViews),
            ),
            Expanded(
              child: _Figure(
                value: audience.reactions,
                label: l10n.audienceReactions,
              ),
            ),
          ],
        ),
        if (reactions.isNotEmpty) ...[
          DsGaps.vMd,
          Wrap(
            spacing: DsSpacing.sm,
            runSpacing: DsSpacing.xs,
            children: [
              for (final entry in reactions)
                Container(
                  padding: DsSpacing.pillPadding,
                  decoration: BoxDecoration(
                    color: c.surfaceVariant,
                    borderRadius: DsRadius.borderFull,
                  ),
                  child: Text(
                    '${entry.key} ${entry.value}',
                    style: context.dsText.label,
                  ),
                ),
            ],
          ),
        ],
        DsGaps.vLg,
        if (audience.viewers.isEmpty)
          DsEmptyState(
            icon: Icons.visibility_outlined,
            title: l10n.audienceEmpty,
            message: l10n.audienceEmptyBody,
          )
        else
          for (final viewer in audience.viewers)
            InkWell(
              borderRadius: DsRadius.borderMd,
              onTap: () => Navigator.of(context).pop(viewer.user.id),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: DsSpacing.xs),
                child: Row(
                  children: [
                    DsAvatar(
                      imageUrl: viewer.user.imageUrl,
                      name: viewer.user.name,
                      size: DsSizes.avatarSm,
                    ),
                    DsGaps.hSm,
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            viewer.user.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: context.dsText.tileTitle,
                          ),
                          Text(
                            formatRelativeTime(l10n, viewer.viewedAt),
                            style: context.dsText.micro.tint(
                              c.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (viewer.reaction != null)
                      Text(viewer.reaction!, style: context.dsText.cardTitle),
                  ],
                ),
              ),
            ),
      ],
    );
  }
}

class _Figure extends StatelessWidget {
  const _Figure({required this.value, required this.label});

  final int value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text('$value', style: context.dsText.metric),
        Text(
          label,
          style: context.dsText.micro.tint(context.dsColors.onSurfaceVariant),
        ),
      ],
    );
  }
}
