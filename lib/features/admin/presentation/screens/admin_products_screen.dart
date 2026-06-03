import 'package:flutter/material.dart';

import '../../../../core/design_system/design_system.dart';
import '../../../../core/localization/l10n_extension.dart';
import '../widgets/admin_page_header.dart';

class AdminProductsScreen extends StatelessWidget {
  const AdminProductsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.dsColors;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AdminPageHeader(
            title: l10n.adminProducts,
            subtitle: l10n.adminManageCatalog,
            actions: [
              PrimaryButton(label: l10n.add, onPressed: () {}),
            ],
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: DsSpacing.xl),
            child: Wrap(
              spacing: DsSpacing.md,
              runSpacing: DsSpacing.md,
              children: List.generate(6, (i) {
                return SizedBox(
                  width: 220,
                  child: Container(
                    padding: const EdgeInsets.all(DsSpacing.md),
                    decoration: BoxDecoration(
                      color: colors.surface,
                      borderRadius: DsRadius.borderLg,
                      border: Border.all(color: colors.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          height: 120,
                          decoration: BoxDecoration(
                            color: colors.surfaceVariant,
                            borderRadius: DsRadius.borderMd,
                          ),
                          child: Icon(Icons.image_outlined, color: colors.onSurfaceVariant),
                        ),
                        const SizedBox(height: DsSpacing.sm),
                        Text(
                          '${l10n.products} ${i + 1}',
                          style: TextStyle(fontWeight: DsTypography.semiBold),
                        ),
                        Text(
                          '\$${(29 + i * 12)}.00',
                          style: TextStyle(color: colors.primary),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ),
          const SizedBox(height: DsSpacing.xxxl),
        ],
      ),
    );
  }
}
