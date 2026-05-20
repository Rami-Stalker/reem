// profile_menu_tile.dart

import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';

class ProfileMenuTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback? onTap;
  final bool danger;

  const ProfileMenuTile({
    super.key,
    required this.icon,
    required this.title,
    this.onTap,
    this.danger = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:
          const EdgeInsets.symmetric(
        horizontal: 18,
        vertical: 7,
      ),

      child: Material(
        color: Colors.transparent,

        child: InkWell(
          borderRadius:
              BorderRadius.circular(24),

          onTap: onTap,

          child: Ink(
            padding:
                const EdgeInsets.symmetric(
              horizontal: 18,
              vertical: 18,
            ),

            decoration: BoxDecoration(
              color: Colors.white,

              borderRadius:
                  BorderRadius.circular(
                      24),

              boxShadow: [
                BoxShadow(
                  color:
                      Colors.black.withOpacity(
                          .04),

                  blurRadius: 14,

                  offset:
                      const Offset(0, 6),
                ),
              ],
            ),

            child: Row(
              children: [

                /// ICON CONTAINER
                Container(
                  width: 52,
                  height: 52,

                  decoration: BoxDecoration(
                    borderRadius:
                        BorderRadius.circular(
                            18),

                    gradient: danger
                        ? const LinearGradient(
                            colors: [
                              Color(
                                  0xffFF8A80),
                              Color(
                                  0xffFF5252),
                            ],
                          )
                        : const LinearGradient(
                            colors: [
                              AppColors
                                  .secondary,
                              AppColors
                                  .primary,
                            ],
                          ),
                  ),

                  child: Icon(
                    icon,
                    color: Colors.white,
                    size: 26,
                  ),
                ),

                const SizedBox(width: 16),

                /// TITLE
                Expanded(
                  child: Text(
                    title,

                    style: TextStyle(
                      fontSize: 16,
                      fontWeight:
                          FontWeight.w700,

                      color: danger
                          ? Colors.red
                          : AppColors
                              .textDark,
                    ),
                  ),
                ),

                /// ARROW
                Container(
                  width: 38,
                  height: 38,

                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors
                        .softPink,
                  ),

                  child: const Icon(
                    Icons
                        .arrow_forward_ios_rounded,
                    size: 16,
                    color: AppColors
                        .primary,
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