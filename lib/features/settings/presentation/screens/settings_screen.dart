import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';

import '../widgets/settings_section.dart';
import '../widgets/settings_tile.dart';
import '../widgets/settings_switch_tile.dart';

class SettingsScreen
    extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,

      appBar: AppBar(
        elevation: 0,
        backgroundColor:
            AppColors.background,

        centerTitle: true,

        title: const Text(
          "الإعدادات",
          style: TextStyle(
            color: AppColors.textDark,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),

      body: ListView(
        physics:
            const BouncingScrollPhysics(),

        children: const [

          SizedBox(height: 20),

          SettingsSection(
            title: "الحساب",
            children: [

              SettingsTile(
                icon: Icons.person_outline,
                title: "تعديل الملف الشخصي",
              ),

              SettingsTile(
                icon: Icons.lock_outline,
                title: "الخصوصية والأمان",
              ),

              SettingsTile(
                icon: Icons.notifications_none,
                title: "الإشعارات",
              ),
            ],
          ),

          SettingsSection(
            title: "التطبيق",
            children: [

              SettingsSwitchTile(
                icon: Icons.dark_mode_outlined,
                title: "الوضع الليلي",
              ),

              SettingsSwitchTile(
                icon: Icons.language_outlined,
                title: "اللغة العربية",
              ),
            ],
          ),

          SettingsSection(
            title: "أخرى",
            children: [

              SettingsTile(
                icon: Icons.help_outline,
                title: "المساعدة",
              ),

              SettingsTile(
                icon: Icons.info_outline,
                title: "حول التطبيق",
              ),

              SettingsTile(
                icon: Icons.logout,
                title: "تسجيل الخروج",
                danger: true,
              ),
            ],
          ),

          SizedBox(height: 100),
        ],
      ),
    );
  }
}