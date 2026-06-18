import 'package:flutter/material.dart';
import 'package:reem/features/admin/presentation/providers/admin_provider.dart';

import 'admin_section_screen.dart';

class AdminUsersScreen extends StatelessWidget {
  const AdminUsersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AdminSectionScreen(config: adminSectionConfigs['users']!);
  }
}
