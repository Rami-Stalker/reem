import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:reem/core/design_system/components/buttons/gradient_icon_button.dart';


class ParallaxProductHeader
    extends StatelessWidget {
  const ParallaxProductHeader({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return SliverAppBar(
      expandedHeight: 520,

      pinned: true,
      stretch: true,

      elevation: 0,

      backgroundColor:
          Colors.transparent,

      flexibleSpace:
          FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,

          children: [

            /// IMAGE
            Hero(
              tag: 'product',

              child: Image.network(
                'https://images.unsplash.com/photo-1515886657613-9f3515b0c78f',

                fit: BoxFit.cover,
              ),
            ),

            /// OVERLAY
            Container(
              decoration:
                  BoxDecoration(
                gradient:
                    LinearGradient(
                  begin:
                      Alignment.topCenter,

                  end:
                      Alignment
                          .bottomCenter,

                  colors: [

                    Colors.black
                        .withOpacity(.08),

                    Colors.black
                        .withOpacity(.65),
                  ],
                ),
              ),
            ),

            /// GLOW
            Positioned(
              bottom: -100,
              right: -40,

              child: Container(
                width: 220,
                height: 220,

                decoration:
                    BoxDecoration(
                  shape: BoxShape.circle,

                  color: Colors.pink
                      .withOpacity(.18),
                ),
              )
                  .animate(
                    onPlay:
                        (controller) =>
                            controller
                                .repeat(
                      reverse: true,
                    ),
                  )
                  .scale(
                    begin:
                        const Offset(
                      .9,
                      .9,
                    ),

                    end:
                        const Offset(
                      1.1,
                      1.1,
                    ),

                    duration:
                        5.seconds,
                  ),
            ),
          ],
        ),
      ),

      leading: Padding(
        padding:
            const EdgeInsets.all(12),

        child: GradientIconButton(
          icon:
              Icons.arrow_back_ios_new,

          onTap: () {
            Navigator.pop(context);
          },
        ),
      ),

      actions: [

        Padding(
          padding:
              const EdgeInsets.all(12),

          child: GradientIconButton(
            icon: Icons.favorite,

            onTap: () {},
          ),
        ),
      ],
    );
  }
}