import 'package:app_settings/app_settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ohara/core/design_system/design_system.dart';
import 'package:ohara/core/errors/failure_exception.dart';
import 'package:ohara/core/localization/l10n_extension.dart';
import 'package:ohara/core/notifications/push_notification_service.dart';
import 'package:ohara/core/notifications/push_providers.dart';
import 'package:ohara/core/result/result.dart';
import 'package:ohara/features/settings/domain/entities/notification_preferences.dart';
import 'package:ohara/features/settings/presentation/providers/settings_provider.dart';
import 'package:ohara/l10n/app_localizations.dart';

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Re-reads the system permission when she comes back from the OS settings.
  ///
  /// This is the only moment the answer can have changed without the app being
  /// involved — neither platform notifies an app that its notification
  /// permission was revoked — and so the only thing that can keep the banner
  /// below honest.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.invalidate(pushPermissionProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    final preferences = ref.watch(notificationPreferencesProvider);
    final permission = ref.watch(pushPermissionProvider).value;

    return OharaScrollPage(
      // Returned rather than awaited-and-dropped: `refresh` hands back the
      // rebuilt value, and discarding it is what the analyzer flags.
      onRefresh: () => ref.refresh(notificationPreferencesProvider.future),
      slivers: [
        VanityAppBar(
          title: context.l10n.notifications,
          icon: Icons.notifications_active_outlined,
          showBack: true,
        ),
        if (permission == PushPermission.denied) const _BlockedBanner(),
        preferences.when(
          data: (prefs) => _PreferencesSliver(
            preferences: prefs,
            onChanged: _save,
            onPushChanged: (wanted) => _setPush(prefs, wanted),
          ),
          loading: () => const _LoadingSliver(),
          error: (error, _) => _ErrorSliver(
            // l10n-ignore: a prefix being stripped off an error string
            message: messageOf(error),
            onRetry: () => ref.invalidate(notificationPreferencesProvider),
          ),
        ),
      ],
    );
  }

  /// Turning push on is three things, not one.
  ///
  /// The switch used to save a boolean and nothing else, which on a handset
  /// that had never been asked for permission produced the worst possible
  /// outcome: a preference saying yes, a phone saying nothing, and no way for
  /// her to tell which of them was wrong. So the order here is deliberate.
  ///
  ///  1. **Ask the phone first.** If she refuses, the preference is not saved:
  ///     a switch left on over a system that will not deliver is a lie.
  ///  2. **A permanent refusal opens the settings app.** Both platforms show
  ///     their prompt once and once only, so from that point the only place
  ///     the decision can be changed is the operating system — and an in-app
  ///     switch that silently does nothing is worse than no switch at all.
  ///  3. **Register the handset, last.** The token does not exist until the
  ///     permission does, and the server cannot send to an address it has
  ///     never been given.
  Future<void> _setPush(NotificationPreferences prefs, bool wanted) async {
    final push = ref.read(pushServiceProvider);
    final l10n = context.l10n;

    if (!wanted) {
      await _save(prefs.copyWith(push: false));
      return;
    }

    if (!push.isAvailable) {
      if (!mounted) return;
      DsSnackbar.error(context, l10n.notifPushUnavailable);
      return;
    }

    var state = await push.permission();
    if (state == PushPermission.notDetermined) {
      state = await push.request();
    }
    if (!mounted) return;

    if (state == PushPermission.denied || state == PushPermission.unavailable) {
      DsSnackbar.error(context, l10n.notifPushBlocked);
      await AppSettings.openAppSettings(type: AppSettingsType.notification);
      return;
    }

    ref.invalidate(pushPermissionProvider);
    await _save(prefs.copyWith(push: true));
    await ref.read(pushRegistrarProvider).attach(locale: l10n.localeName);
  }

  Future<void> _save(NotificationPreferences preferences) async {
    final result = await ref.read(updateNotificationPreferencesUseCaseProvider)(
      preferences,
    );
    if (!mounted) return;

    switch (result) {
      case Success():
        ref.invalidate(notificationPreferencesProvider);
        DsSnackbar.success(context, context.l10n.notificationPrefsSaved);
      case Error(:final failure):
        DsSnackbar.error(context, failure.message);
    }
  }
}

/// Shown when the phone will not deliver anything, whatever these switches say.
///
/// Without it the screen is actively misleading: every toggle can be on, the
/// server can be sending correctly, and nothing arrives — with no clue anywhere
/// in the app that the operating system is the one refusing.
class _BlockedBanner extends StatelessWidget {
  const _BlockedBanner();

  @override
  Widget build(BuildContext context) {
    final palette = context.boutique;
    final gutter = vanityGutter(context);
    return SliverToBoxAdapter(
      child: Padding(
        padding: EdgeInsets.fromLTRB(gutter, DsSpacing.lg, gutter, 0),
        child: Container(
          padding: DsSpacing.paddingMd,
          decoration: BoxDecoration(
            color: palette.caution.withValues(alpha: 0.1),
            borderRadius: DsRadius.borderXxl,
            border: Border.all(color: palette.caution.withValues(alpha: 0.4)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              VanityPearl(
                icon: Icons.notifications_off_rounded,
                color: palette.caution,
              ),
              DsGaps.hMd,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.l10n.notifPushBlockedTitle,
                      style: context.dsText.bodyStrong.tint(palette.ink),
                    ),
                    DsGaps.vXxs,
                    Text(
                      context.l10n.notifPushBlockedBody,
                      style: context.dsText.caption.tint(palette.muted),
                    ),
                    Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: TextButton(
                        onPressed: () => AppSettings.openAppSettings(
                          type: AppSettingsType.notification,
                        ),
                        child: Text(context.l10n.notifPushOpenSettings),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PreferencesSliver extends StatelessWidget {
  const _PreferencesSliver({
    required this.preferences,
    required this.onChanged,
    required this.onPushChanged,
  });

  final NotificationPreferences preferences;
  final ValueChanged<NotificationPreferences> onChanged;

  /// Push is not saved like the others: it has to negotiate with the operating
  /// system before it can honestly be set. See `_setPush`.
  final ValueChanged<bool> onPushChanged;

  @override
  Widget build(BuildContext context) {
    final groups = _groups(context.l10n, preferences, onChanged);
    final gutter = vanityGutter(context);
    return SliverPadding(
      padding: EdgeInsets.fromLTRB(
        gutter,
        DsSpacing.xl,
        gutter,
        DsSpacing.huge,
      ),
      sliver: SliverList.list(
        children: [
          for (final group in groups) ...[
            VanityTray(
              title: group.title,
              children: [for (final pref in group.prefs) _PrefRow(pref: pref)],
            ),
            DsGaps.vXl,
          ],
        ],
      ),
    );
  }

  List<_PrefGroup> _groups(
    AppLocalizations l10n,
    NotificationPreferences prefs,
    ValueChanged<NotificationPreferences> save,
  ) {
    return [
      _PrefGroup(l10n.notifChannels, [
        _Pref(
          icon: Icons.notifications_active_rounded,
          title: l10n.notifPush,
          subtitle: l10n.notifPushBlurb,
          value: prefs.push,
          onChanged: onPushChanged,
        ),
        _Pref(
          icon: Icons.email_rounded,
          title: l10n.notifEmail,
          subtitle: l10n.notifEmailBlurb,
          value: prefs.email,
          onChanged: (value) => save(prefs.copyWith(email: value)),
        ),
        _Pref(
          icon: Icons.sms_rounded,
          title: l10n.notifSms,
          subtitle: l10n.notifSmsBlurb,
          value: prefs.sms,
          onChanged: (value) => save(prefs.copyWith(sms: value)),
        ),
      ]),
      _PrefGroup(l10n.notifActivity, [
        _Pref(
          icon: Icons.storefront_rounded,
          title: l10n.notifSellerPosts,
          subtitle: l10n.notifSellerPostsBlurb,
          value: prefs.inAppPosts,
          onChanged: (value) => save(prefs.copyWith(inAppPosts: value)),
        ),
        _Pref(
          icon: Icons.auto_stories_rounded,
          title: l10n.notifSellerStories,
          subtitle: l10n.notifSellerStoriesBlurb,
          value: prefs.inAppStories,
          onChanged: (value) => save(prefs.copyWith(inAppStories: value)),
        ),
        // Three subjects the server has always honoured and the app had no
        // switch for: a woman tired of being told somebody voted in her room
        // had nowhere to say so.
        _Pref(
          icon: Icons.favorite_rounded,
          title: l10n.notifSocial,
          subtitle: l10n.notifSocialBlurb,
          value: prefs.inAppSocial,
          onChanged: (value) => save(prefs.copyWith(inAppSocial: value)),
        ),
        _Pref(
          icon: Icons.groups_rounded,
          title: l10n.notifRooms,
          subtitle: l10n.notifRoomsBlurb,
          value: prefs.inAppRooms,
          onChanged: (value) => save(prefs.copyWith(inAppRooms: value)),
        ),
      ]),
      _PrefGroup(l10n.notifCommerce, [
        _Pref(
          icon: Icons.local_mall_rounded,
          title: l10n.notifOrders,
          subtitle: l10n.notifOrdersBlurb,
          value: prefs.inAppOrders,
          onChanged: (value) => save(prefs.copyWith(inAppOrders: value)),
        ),
        _Pref(
          icon: Icons.local_offer_rounded,
          title: l10n.notifOffers,
          subtitle: l10n.notifOffersBlurb,
          value: prefs.inAppCoupons,
          onChanged: (value) => save(prefs.copyWith(inAppCoupons: value)),
        ),
        _Pref(
          icon: Icons.verified_user_rounded,
          title: l10n.notifModeration,
          subtitle: l10n.notifModerationBlurb,
          value: prefs.inAppModeration,
          onChanged: (value) => save(prefs.copyWith(inAppModeration: value)),
        ),
      ]),
    ];
  }
}

class _PrefRow extends StatelessWidget {
  const _PrefRow({required this.pref});

  final _Pref pref;

  @override
  Widget build(BuildContext context) {
    final palette = context.boutique;
    return VanityRow(
      icon: pref.icon,
      title: pref.title,
      subtitle: pref.subtitle,
      // A subject she has silenced keeps its place with its pearl unlit.
      color: pref.value ? null : palette.muted,
      onTap: () => pref.onChanged(!pref.value),
      trailing: PearlSwitch(
        value: pref.value,
        onChanged: pref.onChanged,
        semanticLabel: pref.title,
      ),
    );
  }
}

class _LoadingSliver extends StatelessWidget {
  const _LoadingSliver();

  @override
  Widget build(BuildContext context) {
    return SliverFillRemaining(
      hasScrollBody: false,
      child: Center(
        child: DsLoadingIndicator(label: context.l10n.notificationsLoading),
      ),
    );
  }
}

class _ErrorSliver extends StatelessWidget {
  const _ErrorSliver({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return SliverFillRemaining(
      hasScrollBody: false,
      child: DsErrorState(
        title: context.l10n.notificationsLoadFailed,
        message: message,
        onRetry: onRetry,
      ),
    );
  }
}

class _PrefGroup {
  const _PrefGroup(this.title, this.prefs);
  final String title;
  final List<_Pref> prefs;
}

class _Pref {
  const _Pref({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
}
