import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';

class ProfileActionButtons
    extends StatelessWidget {
  const ProfileActionButtons({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:
          const EdgeInsets.symmetric(
        horizontal: 18,
      ),

      child: Row(
        children: [

          Expanded(
            child: _button(
              title: "تعديل الملف",
              filled: true,
            ),
          ),

          const SizedBox(width: 14),

          Expanded(
            child: _button(
              title: "مشاركة",
            ),
          ),
        ],
      ),
    );
  }

  Widget _button({
    required String title,
    bool filled = false,
  }) {
    return Container(
      height: 56,

      decoration: BoxDecoration(
        borderRadius:
            BorderRadius.circular(18),

        gradient: filled
            ? const LinearGradient(
                colors: [
                  AppColors.primary,
                  AppColors.secondary,
                ],
              )
            : null,

        color:
            filled ? null : Colors.white,

        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.04),
            blurRadius: 10,
          )
        ],
      ),

      child: Center(
        child: Text(
          title,
          style: TextStyle(
            color: filled
                ? Colors.white
                : AppColors.textDark,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}