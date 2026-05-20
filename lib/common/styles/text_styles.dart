import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';

class TStyle {
  static const mainTitle = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.bold,
    color: Colors.pink,
  );

  static const sectionTitle = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    color: Colors.black87,
  );
}

class AppTextStyles {
  static const logo = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.bold,
    color: AppColors.primary,
  );

  static const title = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.bold,
    color: AppColors.textDark,
  );

  static const body = TextStyle(
    fontSize: 15,
    color: AppColors.textLight,
  );
}