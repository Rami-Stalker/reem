import 'package:flutter/material.dart';

import 'animated_dot_indicator.dart';

class PageIndicator
    extends StatelessWidget {
  final int currentPage;
  final int count;

  const PageIndicator({
    super.key,
    required this.currentPage,
    required this.count,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment:
          MainAxisAlignment.center,

      children: List.generate(
        count,
        (index) =>
            AnimatedDotIndicator(
          active:
              currentPage == index,
        ),
      ),
    );
  }
}