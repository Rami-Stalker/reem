import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:reem/core/design_system/design_system.dart';
import 'package:reem/core/errors/failure_exception.dart';
import 'package:reem/core/localization/l10n_extension.dart';
import 'package:reem/core/result/result.dart';
import 'package:reem/features/settings/domain/entities/notification_preferences.dart';
import 'package:reem/features/settings/presentation/providers/settings_provider.dart';
import 'package:reem/l10n/app_localizations.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final preferences = ref.watch(notificationPreferencesProvider);

    return ReemScrollPage(
      // Returned rather than awaited-and-dropped: `refresh` hands back the
      // rebuilt value, and discarding it is what the analyzer flags.
      onRefresh: () => ref.refresh(notificationPreferencesProvider.future),
      slivers: [
        PremiumAppBar(title: context.l10n.notifications, showBack: true),
        preferences.when(
          data: (prefs) => _PreferencesSliver(
            preferences: prefs,
            onChanged: (updated) => _save(context, ref, updated),
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

  Future<void> _save(
    BuildContext context,
    WidgetRef ref,
    NotificationPreferences preferences,
  ) async {
    final result =
        await ref.read(updateNotificationPreferencesUseCaseProvider)(preferences);
    if (!context.mounted) return;

    switch (result) {
      case Success():
        ref.invalidate(notificationPreferencesProvider);
        DsSnackbar.success(context, context.l10n.notificationPrefsSaved);
      case Error(:final failure):
        DsSnackbar.error(context, failure.message);
    }
  }
}

class _PreferencesSliver extends StatelessWidget {
  const _PreferencesSliver({
    required this.preferences,
    required this.onChanged,
  });

  final NotificationPreferences preferences;
  final ValueChanged<NotificationPreferences> onChanged;

  @override
  Widget build(BuildContext context) {
    final groups = _groups(context.l10n, preferences, onChanged);
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(
        DsSpacing.lg,
        DsSpacing.sm,
        DsSpacing.lg,
        DsSpacing.huge,
      ),
      sliver: SliverList.list(
        children: [
          for (final group in groups) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(
                DsSpacing.xs,
                DsSpacing.sm,
                DsSpacing.xs,
                DsSpacing.sm,
              ),
              child: Text(
                group.title.toUpperCase(),
                style: DsTypography.overline(context.dsColors.primary),
              ),
            ),
            SurfaceCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  for (var i = 0; i < group.prefs.length; i++) ...[
                    if (i > 0)
                      Divider(
                        height: 1,
                        indent: 64,
                        color: context.dsColors.divider,
                      ),
                    _PrefRow(pref: group.prefs[i]),
                  ],
                ],
              ),
            ),
            const SizedBox(height: DsSpacing.lg),
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
          onChanged: (value) => save(prefs.copyWith(push: value)),
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
      ]),
    ];
  }
}

class _PrefRow extends StatelessWidget {
  const _PrefRow({required this.pref});

  final _Pref pref;

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: DsSpacing.md,
        vertical: DsSpacing.sm,
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: c.primaryContainer.withValues(alpha: 0.6),
              borderRadius: DsRadius.borderMd,
            ),
            child: Icon(pref.icon, size: 20, color: c.primary),
          ),
          const SizedBox(width: DsSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  pref.title,
                  style: context.dsText.tileTitle.copyWith(
                    fontWeight: DsTypography.semiBold,
                  ),
                ),
                const SizedBox(height: DsSpacing.xxs),
                Text(
                  pref.subtitle,
                  style: context.dsText.cardSubtitle.copyWith(
                    color: c.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: DsSpacing.sm),
          Switch(
            value: pref.value,
            onChanged: pref.onChanged,
            activeThumbColor: c.onPrimary,
            activeTrackColor: c.primary,
            inactiveThumbColor: c.surface,
            inactiveTrackColor: c.surfaceVariant,
            trackOutlineColor: WidgetStatePropertyAll(c.border),
          ),
        ],
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
