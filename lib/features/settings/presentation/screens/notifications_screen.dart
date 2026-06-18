import 'package:flutter/material.dart';

import '../../../../core/design_system/design_system.dart';

/// Notification preferences — grouped, toggleable, fully design-system driven.
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  static const _groups = <_PrefGroup>[
    _PrefGroup('Activity', [
      _Pref('likes', Icons.favorite_rounded, 'Likes',
          'When someone loves your posts', true),
      _Pref('comments', Icons.mode_comment_rounded, 'Comments',
          'Replies and mentions', true),
      _Pref('followers', Icons.person_add_rounded, 'New followers',
          'When someone follows you', true),
      _Pref('messages', Icons.chat_bubble_rounded, 'Messages',
          'Direct messages from sellers', false),
    ]),
    _PrefGroup('Orders', [
      _Pref('orders', Icons.local_mall_rounded, 'Order updates',
          'Payment, packing and shipping', true),
      _Pref('delivery', Icons.local_shipping_rounded, 'Delivery',
          'Out for delivery and arrival', true),
    ]),
    _PrefGroup('Just for you', [
      _Pref('offers', Icons.local_offer_rounded, 'Discounts & coupons',
          'Sales and exclusive codes', false),
      _Pref('arrivals', Icons.auto_awesome_rounded, 'New arrivals',
          'Fresh drops from boutiques you follow', true),
      _Pref('rewards', Icons.card_giftcard_rounded, 'Rewards & points',
          'Points, perks and birthday treats', true),
    ]),
  ];

  late final Map<String, bool> _values = {
    for (final g in _groups)
      for (final p in g.prefs) p.key: p.initial,
  };

  @override
  Widget build(BuildContext context) {
    return ReemScrollPage(
      slivers: [
        const PremiumAppBar(title: 'Notifications', showBack: true),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(
              DsSpacing.lg, DsSpacing.sm, DsSpacing.lg, DsSpacing.huge),
          sliver: SliverList.list(
            children: [
              for (final group in _groups) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                      DsSpacing.xs, DsSpacing.sm, DsSpacing.xs, DsSpacing.sm),
                  child: Text(group.title.toUpperCase(),
                      style: DsTypography.overline(context.dsColors.primary)),
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
                              color: context.dsColors.divider),
                        _PrefRow(
                          pref: group.prefs[i],
                          value: _values[group.prefs[i].key]!,
                          onChanged: (v) =>
                              setState(() => _values[group.prefs[i].key] = v),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: DsSpacing.lg),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _PrefRow extends StatelessWidget {
  const _PrefRow({
    required this.pref,
    required this.value,
    required this.onChanged,
  });

  final _Pref pref;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: DsSpacing.md, vertical: DsSpacing.sm),
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
                Text(pref.title,
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: DsTypography.semiBold)),
                const SizedBox(height: DsSpacing.xxs),
                Text(pref.subtitle,
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: c.onSurfaceVariant)),
              ],
            ),
          ),
          const SizedBox(width: DsSpacing.sm),
          Switch(
            value: value,
            onChanged: onChanged,
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

class _PrefGroup {
  const _PrefGroup(this.title, this.prefs);
  final String title;
  final List<_Pref> prefs;
}

class _Pref {
  const _Pref(this.key, this.icon, this.title, this.subtitle, this.initial);
  final String key;
  final IconData icon;
  final String title;
  final String subtitle;
  final bool initial;
}
