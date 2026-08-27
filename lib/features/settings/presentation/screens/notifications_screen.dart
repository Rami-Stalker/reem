import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:reem/core/design_system/design_system.dart';
import 'package:reem/core/result/result.dart';
import 'package:reem/features/settings/domain/entities/notification_preferences.dart';
import 'package:reem/features/settings/presentation/providers/settings_provider.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final preferences = ref.watch(notificationPreferencesProvider);

    return ReemScrollPage(
      onRefresh: () async {
        await ref.refresh(notificationPreferencesProvider.future);
      },
      slivers: [
        const PremiumAppBar(title: 'Notifications', showBack: true),
        preferences.when(
          data: (prefs) => _PreferencesSliver(
            preferences: prefs,
            onChanged: (updated) => _save(context, ref, updated),
          ),
          loading: () => const _LoadingSliver(),
          error: (error, _) => _ErrorSliver(
            message: error.toString().replaceFirst('Exception: ', ''),
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
        DsSnackbar.success(context, 'Notification preferences updated.');
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
    final groups = _groups(preferences, onChanged);
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
    NotificationPreferences prefs,
    ValueChanged<NotificationPreferences> save,
  ) {
    return [
      _PrefGroup('Channels', [
        _Pref(
          icon: Icons.notifications_active_rounded,
          title: 'Push notifications',
          subtitle: 'Message alerts, order updates, and campaigns.',
          value: prefs.push,
          onChanged: (value) => save(prefs.copyWith(push: value)),
        ),
        _Pref(
          icon: Icons.email_rounded,
          title: 'Email notifications',
          subtitle: 'Receipts, account notices, and longer updates.',
          value: prefs.email,
          onChanged: (value) => save(prefs.copyWith(email: value)),
        ),
        _Pref(
          icon: Icons.sms_rounded,
          title: 'SMS notifications',
          subtitle: 'Critical delivery and account messages.',
          value: prefs.sms,
          onChanged: (value) => save(prefs.copyWith(sms: value)),
        ),
      ]),
      _PrefGroup('Activity', [
        _Pref(
          icon: Icons.storefront_rounded,
          title: 'Seller posts',
          subtitle: 'New posts from sellers you follow.',
          value: prefs.inAppPosts,
          onChanged: (value) => save(prefs.copyWith(inAppPosts: value)),
        ),
        _Pref(
          icon: Icons.auto_stories_rounded,
          title: 'Seller stories',
          subtitle: 'Fresh stories from followed boutiques.',
          value: prefs.inAppStories,
          onChanged: (value) => save(prefs.copyWith(inAppStories: value)),
        ),
      ]),
      _PrefGroup('Commerce', [
        _Pref(
          icon: Icons.local_mall_rounded,
          title: 'Order updates',
          subtitle: 'Payment, packing, shipping, and delivery progress.',
          value: prefs.inAppOrders,
          onChanged: (value) => save(prefs.copyWith(inAppOrders: value)),
        ),
        _Pref(
          icon: Icons.local_offer_rounded,
          title: 'Promotions and coupons',
          subtitle: 'Discounts, coupons, rewards, and campaign offers.',
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
    final theme = Theme.of(context);
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
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: DsTypography.semiBold,
                  ),
                ),
                const SizedBox(height: DsSpacing.xxs),
                Text(
                  pref.subtitle,
                  style: theme.textTheme.bodySmall?.copyWith(
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
        child: DsLoadingIndicator(label: 'Loading preferences'),
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
        title: 'Preferences could not load',
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
