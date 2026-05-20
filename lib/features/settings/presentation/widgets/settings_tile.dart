import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';

class SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final bool danger;

  const SettingsTile({
    super.key,
    required this.icon,
    required this.title,
    this.danger = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin:
          const EdgeInsets.only(
        bottom: 14,
      ),

      padding:
          const EdgeInsets.symmetric(
        horizontal: 18,
        vertical: 18,
      ),

      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(20),

        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.04),
            blurRadius: 10,
          ),
        ],
      ),

      child: Row(
        children: [

          Icon(
            icon,
            color: danger
                ? Colors.red
                : AppColors.primary,
          ),

          const SizedBox(width: 16),

          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 16,
                color: danger
                    ? Colors.red
                    : AppColors.textDark,
                fontWeight:
                    FontWeight.w600,
              ),
            ),
          ),

          const Icon(
            Icons.arrow_forward_ios_rounded,
            size: 16,
          ),
        ],
      ),
    );
  }
}