import 'package:flutter/material.dart';

import '../../../../core/design_system/design_system.dart';
import '../../../../core/design_system/patterns/reem_page_scaffold.dart';
import '../../../../core/shared/wedgets/app/premium_app_bar.dart';
import '../../../../core/shared/wedgets/app/reem_section_header.dart';
import '../widgets/notification_card.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  static const _items = [
    _NotificationOption('Push Notifications', true),
    _NotificationOption('Order Updates', true),
    _NotificationOption('New Stories', true),
    _NotificationOption('Discount & Coupons', false),
    _NotificationOption('Rewards & Points', true),
    _NotificationOption('Messages', false),
  ];

  @override
  Widget build(BuildContext context) {
    return ReemScrollPage(
      slivers: [
        const PremiumAppBar(title: 'Notifications', showBack: true),
        SliverPadding(
          padding: const EdgeInsets.all(DsSpacing.lg),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              const ReemSectionHeader(
                title: 'Stay in the loop',
                subtitle: 'Never miss a drop or deal',
              ),
              const SizedBox(height: DsSpacing.lg),
              for (var i = 0; i < _items.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: DsSpacing.md),
                  child: NotificationCard(
                    title: _items[i].title,
                    initialValue: _items[i].enabled,
                  ),
                ),
            ]),
          ),
        ),
      ],
    );
  }
}

class _NotificationOption {
  const _NotificationOption(this.title, this.enabled);
  final String title;
  final bool enabled;
}
