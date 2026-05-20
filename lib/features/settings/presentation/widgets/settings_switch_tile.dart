import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';

class SettingsSwitchTile
    extends StatefulWidget {
  final IconData icon;
  final String title;

  const SettingsSwitchTile({
    super.key,
    required this.icon,
    required this.title,
  });

  @override
  State<SettingsSwitchTile>
      createState() =>
          _SettingsSwitchTileState();
}

class _SettingsSwitchTileState
    extends State<SettingsSwitchTile> {
  bool value = true;

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
        vertical: 10,
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
            widget.icon,
            color: AppColors.primary,
          ),

          const SizedBox(width: 16),

          Expanded(
            child: Text(
              widget.title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight:
                    FontWeight.w600,
              ),
            ),
          ),

          Switch(
            value: value,
            activeColor:
                AppColors.primary,
            onChanged: (v) {
              setState(() {
                value = v;
              });
            },
          )
        ],
      ),
    );
  }
}