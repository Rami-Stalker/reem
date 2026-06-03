import 'dart:ui';

import 'package:flutter/material.dart';

import '../../../design_system/design_system.dart';

class AnimatedSearchBar extends StatefulWidget {
  const AnimatedSearchBar({super.key});

  @override
  State<AnimatedSearchBar> createState() => _AnimatedSearchBarState();
}

class _AnimatedSearchBarState extends State<AnimatedSearchBar> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.dsColors;
    return AnimatedContainer(
      duration: DsMotion.moderate,
      height: 56,
      decoration: BoxDecoration(
        borderRadius: DsRadius.borderXxxl,
        boxShadow: _focused ? context.softShadow : null,
      ),
      child: ClipRRect(
        borderRadius: DsRadius.borderXxxl,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: DsBlur.medium, sigmaY: DsBlur.medium),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: DsSpacing.lg),
            decoration: BoxDecoration(
              gradient: context.ds.glassGradient,
              borderRadius: DsRadius.borderXxxl,
              border: Border.all(
                color: _focused ? colors.primary : colors.glassBorder,
                width: _focused ? 1.5 : 1,
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.search_rounded, color: colors.primary),
                const SizedBox(width: DsSpacing.sm),
                Expanded(
                  child: TextField(
                    onTap: () => setState(() => _focused = true),
                    onTapOutside: (_) => setState(() => _focused = false),
                    style: TextStyle(color: colors.onSurface),
                    decoration: InputDecoration(
                      hintText: 'Search dresses, beauty, gifts…',
                      hintStyle: TextStyle(color: colors.onSurfaceVariant),
                      border: InputBorder.none,
                      isDense: true,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
