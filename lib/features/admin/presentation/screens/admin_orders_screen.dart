import 'package:flutter/material.dart';

import '../../../../core/design_system/design_system.dart';
import '../../../../core/localization/l10n_extension.dart';
import '../widgets/admin_page_header.dart';

class AdminOrdersScreen extends StatelessWidget {
  const AdminOrdersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.dsColors;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AdminPageHeader(
            title: l10n.adminOrders,
            subtitle: l10n.orderStatus,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: DsSpacing.xl),
            child: Container(
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: DsRadius.borderLg,
                border: Border.all(color: colors.border),
              ),
              child: DataTable(
                headingRowColor: WidgetStateProperty.all(
                  colors.surfaceVariant,
                ),
                columns: [
                  DataColumn(label: Text(l10n.myOrders, style: _headerStyle(colors))),
                  DataColumn(label: Text(l10n.profile, style: _headerStyle(colors))),
                  DataColumn(label: Text(l10n.total, style: _headerStyle(colors))),
                  DataColumn(label: Text(l10n.orderStatus, style: _headerStyle(colors))),
                ],
                rows: const [
                  DataRow(cells: [
                    DataCell(Text('#10284')),
                    DataCell(Text('Sara M.')),
                    DataCell(Text('\$129')),
                    DataCell(Text('Shipped')),
                  ]),
                  DataRow(cells: [
                    DataCell(Text('#10283')),
                    DataCell(Text('Layla K.')),
                    DataCell(Text('\$89')),
                    DataCell(Text('Processing')),
                  ]),
                  DataRow(cells: [
                    DataCell(Text('#10282')),
                    DataCell(Text('Nour A.')),
                    DataCell(Text('\$245')),
                    DataCell(Text('Delivered')),
                  ]),
                ],
              ),
            ),
          ),
          const SizedBox(height: DsSpacing.xxxl),
        ],
      ),
    );
  }

  TextStyle _headerStyle(DsColorScheme colors) => TextStyle(
        fontWeight: DsTypography.semiBold,
        color: colors.onSurfaceVariant,
        fontSize: DsTypography.labelMedium,
      );
}
