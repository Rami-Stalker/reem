import 'package:flutter/material.dart';
import 'package:reem/core/design_system/design_system.dart';


class MusicSelectorCard
    extends StatelessWidget {

  const MusicSelectorCard({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Container(

      padding:
          const EdgeInsets.all(22),

      decoration: BoxDecoration(

        gradient:
            DsGradients.primary,

        borderRadius:
            BorderRadius.circular(
          DsRadius.xl,
        ),

        boxShadow:
            DsShadows
                .glow(DsColors.primary600),
      ),

      child: Row(

        children: [

          Container(

            width: 62,
            height: 62,

            decoration: BoxDecoration(

              shape: BoxShape.circle,

              color: Colors.white
                  .withOpacity(.18),
            ),

            child: const Icon(

              Icons.music_note_rounded,

              color: Colors.white,

              size: 30,
            ),
          ),

          const SizedBox(width: 18),

          Expanded(

            child: Column(

              crossAxisAlignment:
                  CrossAxisAlignment
                      .start,

              children: const [

                Text(

                  "Luxury Sound",

                  style: TextStyle(

                    color: Colors.white,

                    fontSize: 18,

                    fontWeight:
                        FontWeight.bold,
                  ),
                ),

                SizedBox(height: 8),

                Text(

                  "Select elegant music for your story",

                  style: TextStyle(

                    color:
                        Colors.white70,

                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),

          Container(

            width: 52,
            height: 52,

            decoration:
                BoxDecoration(

              shape:
                  BoxShape.circle,

              color: Colors.white
                  .withOpacity(.2),
            ),

            child: const Icon(

              Icons.play_arrow_rounded,

              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}