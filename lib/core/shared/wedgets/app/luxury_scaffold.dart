import 'package:flutter/material.dart';

import '../backgrounds/animated_gradient_background.dart';

class LuxuryScaffold
    extends StatelessWidget {
  final Widget body;
  final Widget? bottomNavigationBar;
  final Widget? floatingActionButton;

  const LuxuryScaffold({
    super.key,
    required this.body,
    this.bottomNavigationBar,
    this.floatingActionButton,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      extendBodyBehindAppBar: true,

      backgroundColor: Colors.transparent,

      floatingActionButton:
          floatingActionButton,

      bottomNavigationBar:
          bottomNavigationBar,

      body: Stack(
        children: [

          /// ANIMATED BG
          const AnimatedGradientBackground(),

          /// MAIN CONTENT
          SafeArea(
            child: body,
          ),
        ],
      ),
    );
  }
}