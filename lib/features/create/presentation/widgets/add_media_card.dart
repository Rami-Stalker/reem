import 'package:flutter/material.dart';
import 'package:reem/core/design_system/design_system.dart';

class AddMediaCard
    extends StatelessWidget {

  final VoidCallback onTap;

  final bool isStory;

  const AddMediaCard({
    super.key,
    required this.onTap,
    this.isStory = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(

      onTap: onTap,

      child: Container(

        height:
            isStory
                ? 520
                : 260,

        decoration: BoxDecoration(

          borderRadius:
              BorderRadius.circular(
            DsRadius.xxl,
          ),

          gradient:
              DsGradients.primary,

          boxShadow:
              DsShadows
                  .glow(
                    DsColors.primary600),
        ),

        child: Stack(

          children: [

            Positioned(

              right: -50,
              top: -40,

              child: Container(

                width: 180,
                height: 180,

                decoration:
                    BoxDecoration(

                  shape:
                      BoxShape.circle,

                  color: Colors.white
                      .withOpacity(.12),
                ),
              ),
            ),

            Center(

              child: Column(

                mainAxisAlignment:
                    MainAxisAlignment
                        .center,

                children: [

                  Container(

                    width: 90,
                    height: 90,

                    decoration:
                        BoxDecoration(

                      shape:
                          BoxShape.circle,

                      color: Colors
                          .white
                          .withOpacity(.18),
                    ),

                    child: const Icon(

                      Icons
                          .add_photo_alternate_rounded,

                      color:
                          Colors.white,

                      size: 42,
                    ),
                  ),

                  const SizedBox(height: 26),

                  const Text(

                    "Upload Luxury Media",

                    style: TextStyle(

                      color:
                          Colors.white,

                      fontSize: 24,

                      fontWeight:
                          FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 12),

                  Text(

                    isStory
                        ? "Share your elegant story moment"
                        : "Create an unforgettable premium post",

                    style: TextStyle(

                      color: Colors
                          .white
                          .withOpacity(.9),

                      fontSize: 15,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}