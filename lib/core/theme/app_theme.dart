import 'package:flutter/material.dart';

class AppTheme {
  static ThemeData get light => ThemeData(
    colorScheme: ColorScheme.fromSeed(seedColor: Colors.pink),
    useMaterial3: true,
    fontFamily: 'Cairo',
    appBarTheme: const AppBarTheme(
      elevation: 0,
      centerTitle: true,
    ),
    buttonTheme: const ButtonThemeData(
      buttonColor: Colors.pink,
    ),
  );
}