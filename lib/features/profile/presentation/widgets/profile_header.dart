import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';

class ProfileHeader extends StatelessWidget {
  const ProfileHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [

        /// AVATAR
        Container(
          padding: const EdgeInsets.all(4),

          decoration: BoxDecoration(
            shape: BoxShape.circle,

            gradient: const LinearGradient(
              colors: [
                AppColors.primary,
                AppColors.secondary,
              ],
            ),

            boxShadow: [
              BoxShadow(
                color: AppColors.primary
                    .withOpacity(.25),
                blurRadius: 20,
              )
            ],
          ),

          child: const CircleAvatar(
            radius: 52,
            backgroundImage: NetworkImage(
              "https://images.unsplash.com/photo-1494790108377-be9c29b29330",
            ),
          ),
        ),

        const SizedBox(height: 18),

        /// NAME
        const Text(
          "Lujain Beauty",
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),

        const SizedBox(height: 8),

        /// BIO
        Padding(
          padding:
              const EdgeInsets.symmetric(
            horizontal: 40,
          ),
          child: Text(
            "Fashion • Beauty • Lifestyle ✨\nSharing feminine elegance everyday.",
            textAlign: TextAlign.center,
            style: TextStyle(
              height: 1.6,
              color: Colors.grey[700],
            ),
          ),
        ),
      ],
    );
  }
}