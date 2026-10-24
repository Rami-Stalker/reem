import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ohara/core/design_system/design_system.dart';
import 'package:ohara/core/localization/l10n_extension.dart';
import 'package:ohara/core/result/result.dart';
import 'package:ohara/features/social/domain/entities/content.dart';
import 'package:ohara/features/social/presentation/providers/social_providers.dart';

/// Editing her own post, reel or story: the caption, and who may see it.
///
/// The pictures and the clip are not editable here on purpose — swapping the
/// video under a reel that has already been liked and shared changes what
/// every one of those women endorsed. A new clip is a new reel.
///
/// Returns the piece as the server now has it, or null if she backed out.
/// An edit that trips the word screen goes back to a moderator, and the
/// snackbar says so rather than letting the reel vanish from her feed
/// without a word.
Future<Content?> showEditContentSheet(
  BuildContext context, {
  required Content content,
}) {
  return DsBottomSheet.show<Content>(
    context,
    builder: (_) => _EditContentSheet(content: content),
  );
}

class _EditContentSheet extends ConsumerStatefulWidget {
  const _EditContentSheet({required this.content});

  final Content content;

  @override
  ConsumerState<_EditContentSheet> createState() => _EditContentSheetState();
}

class _EditContentSheetState extends ConsumerState<_EditContentSheet> {
  late final TextEditingController _caption = TextEditingController(
    text: widget.content.caption,
  );
  late ContentVisibility _visibility =
      widget.content.visibility == ContentVisibility.followers
      ? ContentVisibility.followers
      : ContentVisibility.public;
  bool _saving = false;

  @override
  void dispose() {
    _caption.dispose();
    super.dispose();
  }

  bool get _changed =>
      _caption.text.trim() != widget.content.caption.trim() ||
      _visibility != widget.content.visibility;

  Future<void> _save() async {
    if (_saving) return;
    if (!_changed) {
      Navigator.of(context).pop();
      return;
    }
    setState(() => _saving = true);
    final caption = _caption.text.trim();
    final result = await ref
        .read(socialRepositoryProvider)
        .edit(
          widget.content.id,
          caption: caption == widget.content.caption.trim() ? null : caption,
          visibility: _visibility == widget.content.visibility
              ? null
              : _visibility,
        );
    if (!mounted) return;
    setState(() => _saving = false);
    switch (result) {
      case Success(:final data):
        // The server's answer wins; anything it did not send back keeps what
        // the card already showed — counts and her own viewer state above all.
        final updated = widget.content.copyWith(
          body: data.body ?? caption,
          visibility: data.visibility,
          status: data.status,
          moderationState: data.moderationState,
        );
        DsSnackbar.success(
          context,
          updated.isUnderReview
              ? context.l10n.contentEditedUnderReview
              : context.l10n.contentEdited,
        );
        Navigator.of(context).pop(updated);
      case Error(:final failure):
        DsSnackbar.error(context, failure.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return DsSheetScaffold(
      title: l10n.contentEditTitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          DsInputField(
            controller: _caption,
            label: l10n.composerCaptionLabel,
            hint: l10n.composerCaptionHint,
            maxLines: 4,
            enabled: !_saving,
            onChanged: (_) => setState(() {}),
          ),
          DsGaps.vLg,
          Text(l10n.composerAudience, style: context.dsText.labelLarge),
          DsGaps.vSm,
          StudioSegment(
            options: [
              StudioSegmentOption(
                icon: Icons.public_rounded,
                label: l10n.composerAudiencePublic,
                hint: l10n.composerAudiencePublicHint,
              ),
              StudioSegmentOption(
                icon: Icons.people_rounded,
                label: l10n.composerAudienceFollowers,
                hint: l10n.composerAudienceFollowersHint,
              ),
            ],
            selected: _visibility == ContentVisibility.followers ? 1 : 0,
            onSelect: _saving
                ? (_) {}
                : (index) => setState(
                    () => _visibility = index == 1
                        ? ContentVisibility.followers
                        : ContentVisibility.public,
                  ),
          ),
          DsGaps.vXl,
          PrimaryButton(
            label: l10n.contentEditSave,
            icon: Icons.check_rounded,
            isLoading: _saving,
            onPressed: _saving ? null : _save,
          ),
        ],
      ),
    );
  }
}
