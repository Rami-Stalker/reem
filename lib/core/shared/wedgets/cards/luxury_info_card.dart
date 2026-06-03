import 'package:flutter/material.dart';

import '../../../design_system/design_system.dart';

class LuxuryInfoCard
    extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const LuxuryInfoCard({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      borderRadius: 30,

      child: Row(
        children: [

          Container(
            width: 62,
            height: 62,

            decoration: BoxDecoration(
              shape: BoxShape.circle,

              gradient:
                  const LinearGradient(
                colors: [
                  Color(0xffFF9EB5),
                  Color(0xffFF5C8A),
                ],
              ),
            ),

            child: Icon(
              icon,
              color: Colors.white,
            ),
          ),

          const SizedBox(width: 18),

          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment
                      .start,

              children: [

                Text(
                  title,

                  style:
                      const TextStyle(
                    fontSize: 17,
                    fontWeight:
                        FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 8),

                Text(
                  subtitle,

                  style: TextStyle(
                    color:
                        Colors.grey[700],

                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}