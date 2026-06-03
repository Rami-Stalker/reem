import 'package:flutter/material.dart';

import 'glass_circle_button.dart';
import 'luxury_avatar.dart';

class LuxuryAppBar
    extends StatelessWidget {
  const LuxuryAppBar({super.key});

  @override
  Widget build(BuildContext context) {
    return SliverAppBar(
      expandedHeight: 320,
      pinned: true,
      stretch: true,
      elevation: 0,
      backgroundColor:
          Colors.transparent,

      flexibleSpace: FlexibleSpaceBar(
        collapseMode:
            CollapseMode.parallax,

        background: Stack(
          fit: StackFit.expand,
          children: [

            /// COVER
            Image.network(
              "https://images.unsplash.com/photo-1515886657613-9f3515b0c78f",
              fit: BoxFit.cover,
            ),

            /// OVERLAY
            Container(
              decoration: BoxDecoration(
                gradient:
                    LinearGradient(
                  begin:
                      Alignment.topCenter,
                  end:
                      Alignment.bottomCenter,
                  colors: [
                    Colors.black
                        .withOpacity(.2),
                    Colors.black
                        .withOpacity(.5),
                  ],
                ),
              ),
            ),

            /// AVATAR
            const Align(
              alignment:
                  Alignment.bottomCenter,
              child: Padding(
                padding:
                    EdgeInsets.only(
                  bottom: 30,
                ),
                child: LuxuryAvatar(),
              ),
            ),
          ],
        ),
      ),

      actions: [
        Padding(
          padding:
              const EdgeInsets.only(
            right: 14,
          ),
          child: GlassCircleButton(
            icon:
                Icons.settings_outlined,
            onTap: () {},
          ),
        ),
      ],
    );
  }
}