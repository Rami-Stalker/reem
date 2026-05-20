import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';

class HighlightsSection
    extends StatelessWidget {
  const HighlightsSection({super.key});

  @override
  Widget build(BuildContext context) {
    final highlights = [
      "إطلالات",
      "مكياج",
      "عطور",
      "فساتين",
    ];

    return SizedBox(
      height: 95,

      child: ListView.builder(
        padding:
            const EdgeInsets.symmetric(
          horizontal: 18,
        ),
        scrollDirection: Axis.horizontal,
        itemCount: highlights.length,
        itemBuilder: (context, index) {
          return Padding(
            padding:
                const EdgeInsets.only(
              left: 16,
            ),

            child: Column(
              children: [

                Container(
                  padding:
                      const EdgeInsets.all(
                          3),

                  decoration:
                      const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient:
                        LinearGradient(
                      colors: [
                        AppColors.primary,
                        AppColors.secondary,
                      ],
                    ),
                  ),

                  child: CircleAvatar(
                    radius: 30,
                    backgroundColor:
                        Colors.white,

                    child: Text(
                      highlights[index][0],
                      style:
                          const TextStyle(
                        fontSize: 22,
                        fontWeight:
                            FontWeight
                                .bold,
                        color: AppColors
                            .primary,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 8),

                Text(highlights[index]),
              ],
            ),
          );
        },
      ),
    );
  }
}