import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:ohara/core/design_system/design_system.dart';
import 'package:ohara/core/localization/l10n_extension.dart';
import 'package:ohara/core/result/result.dart';
import 'package:ohara/core/router/route_paths.dart';
import 'package:ohara/features/auth/presentation/providers/auth_provider.dart';
import 'package:ohara/features/social/presentation/providers/social_providers.dart';
import 'package:ohara/features/social/presentation/widgets/create_sheet.dart';
import 'package:ohara/features/user_profile/presentation/providers/user_profile_providers.dart';

/// «صفحتي» — the shopper's own page, from her side.
///
/// Three things she could not do from anywhere in the app: see her page as
/// others see it, open or close it (the switch existed on the server and in
/// the repository, with no control), and start a post, a reel or a story.
/// A page nobody can open looks like a broken feature to the woman visiting
/// it, so the card says plainly which state hers is in.
class MyPageCard extends ConsumerStatefulWidget {
  const MyPageCard({super.key, this.showViewPage = true, this.profileKey});

  /// Off on the page itself — she is already looking at it.
  final bool showViewPage;

  /// Which loaded profile to read and correct: `null` is "my profile", and on
  /// her page opened by id it is that id, so the page's own header moves too.
  final String? profileKey;

  @override
  ConsumerState<MyPageCard> createState() => _MyPageCardState();
}

class _MyPageCardState extends ConsumerState<MyPageCard> {
  bool _saving = false;

  Future<void> _setPublic(bool isPublic) async {
    if (_saving) return;
    setState(() => _saving = true);
    final result = await ref
        .read(socialRepositoryProvider)
        .setProfilePublic(isPublic);
    if (!mounted) return;
    setState(() => _saving = false);

    final l10n = context.l10n;
    switch (result) {
      case Success(:final data):
        ref
            .read(userProfileNotifierProvider(widget.profileKey).notifier)
            .applyVisibility(data);
        DsSnackbar.success(
          context,
          data ? l10n.myPageMadePublic : l10n.myPageMadePrivate,
        );
      case Error(:final failure):
        DsSnackbar.error(context, failure.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    final l10n = context.l10n;
    final me = ref.watch(authNotifierProvider.select((s) => s.user));
    final profile = ref.watch(
      userProfileNotifierProvider(widget.profileKey).select((s) => s.profile),
    );
    if (me == null) return const SizedBox.shrink();

    final isPublic = profile?.profileIsPublic ?? false;

    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                isPublic ? Icons.public_rounded : Icons.lock_outline_rounded,
                color: c.primary,
                size: DsSizes.iconMd,
              ),
              DsGaps.hSm,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.myPageTitle,
                      style: context.dsText.cardTitle.bold.tint(c.onSurface),
                    ),
                    DsGaps.vXxxs,
                    Text(
                      isPublic ? l10n.myPagePublicBody : l10n.myPagePrivateBody,
                      style: context.dsText.caption.tint(c.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            ],
          ),
          DsGaps.vSm,
          // The switch is only drawn once her profile has answered: a toggle
          // painted "off" before the server says so would invite her to open a
          // page that is already open.
          if (profile != null)
            // A list tile paints its ink on the nearest Material. The card is
            // a decorated box, not one, so Flutter refused to build the tile —
            // the red error panel on her own profile in a debug build.
            Material(
              type: MaterialType.transparency,
              child: SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                value: isPublic,
                onChanged: _saving ? null : _setPublic,
                title: Text(
                  l10n.myPagePublicToggle,
                  style: context.dsText.tileTitle.tint(c.onSurface),
                ),
              ),
            ),
          DsGaps.vSm,
          Row(
            children: [
              for (final format in CreateFormat.values) ...[
                if (format != CreateFormat.post) DsGaps.hSm,
                Expanded(
                  child: CreateFormatTile(
                    format: format,
                    compact: true,
                    onTap: () => openComposer(context, format),
                  ),
                ),
              ],
            ],
          ),
          if (widget.showViewPage) ...[
            DsGaps.vMd,
            DsButton(
              label: l10n.viewMyPage,
              icon: Icons.account_circle_outlined,
              variant: DsButtonVariant.secondary,
              size: DsButtonSize.sm,
              onPressed: () => context.push(RoutePaths.userProfileOf(me.id)),
            ),
          ],
        ],
      ),
    );
  }
}
