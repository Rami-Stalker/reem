import 'package:flutter/material.dart';

import '../../../../core/design_system/design_system.dart';
import '../../../../core/localization/l10n_extension.dart';
import '../widgets/admin_page_header.dart';

class AdminUsersScreen extends StatelessWidget {
  const AdminUsersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.dsColors;

    final users = [
      ('Sara M.', 'sara@reem.shop', true),
      ('Layla K.', 'layla@reem.shop', true),
      ('Nour A.', 'nour@reem.shop', false),
      ('Maya H.', 'maya@reem.shop', true),
    ];

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AdminPageHeader(title: l10n.adminUsers),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: DsSpacing.xl),
            child: Container(
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: DsRadius.borderLg,
                border: Border.all(color: colors.border),
              ),
              child: Column(
                children: [
                  for (final (name, email, active) in users)
                    ListTile(
                      leading: CircleAvatar(
                        backgroundColor: colors.primary.withValues(alpha: 0.15),
                        child: Text(
                          name[0],
                          style: TextStyle(
                            color: colors.primary,
                            fontWeight: DsTypography.bold,
                          ),
                        ),
                      ),
                      title: Text(name),
                      subtitle: Text(email),
                      trailing: Chip(
                        label: Text(active ? l10n.active : l10n.no),
                        backgroundColor: active
                            ? colors.success.withValues(alpha: 0.12)
                            : colors.surfaceVariant,
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: DsSpacing.xxxl),
        ],
      ),
    );
  }
}
