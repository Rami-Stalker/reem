import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart';
import 'package:reem/features/home/presentation/screens/home_screen.dart';

class AppRouter {
  static final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => HomeScreen(),
        // const Placeholder(), // ضع هنا HomeScreen أو شاشة البداية
      ),
      // أضف بقية المسارات هنا
    ],
  );
}