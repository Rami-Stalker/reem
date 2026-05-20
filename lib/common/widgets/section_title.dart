import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

class SectionTitle extends StatelessWidget {
  final String title;
  final Widget? action;

  const SectionTitle({super.key, required this.title, this.action});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          title,
          style: const TextStyle(
            color: AppColors.primary,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        const Spacer(),
        ?action,
      ],
    );
  }
}