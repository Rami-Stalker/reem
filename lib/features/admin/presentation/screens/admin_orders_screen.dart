import 'package:flutter/material.dart';
import 'package:reem/features/admin/presentation/providers/admin_provider.dart';

import 'package:reem/features/admin/presentation/screens/admin_section_screen.dart';

class AdminOrdersScreen extends StatelessWidget {
  const AdminOrdersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AdminSectionScreen(config: adminSectionConfigs['orders']!);
  }
}
