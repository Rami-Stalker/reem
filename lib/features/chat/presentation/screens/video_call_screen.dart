import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:reem/core/design_system/effects/backgrounds/luxury_blurred_background.dart';

class VideoCallScreen
    extends StatefulWidget {

  const VideoCallScreen({
    super.key,
  });

  @override
  State<VideoCallScreen>
      createState() =>
          _VideoCallScreenState();
}

class _VideoCallScreenState
    extends State<
        VideoCallScreen>

    with
        SingleTickerProviderStateMixin {

  late AnimationController
      controller;

  @override
  void initState() {
    super.initState();

    controller =
        AnimationController(

      vsync: this,

      duration:
          const Duration(
        seconds: 2,
      ),
    )..repeat(reverse: true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(

      body: LuxuryBlurredBackground(
        child: Stack(
        
          fit: StackFit.expand,
        
          children: [
        
            Image.network(
        
              'https://images.unsplash.com/photo-1494790108377-be9c29b29330',
        
              fit: BoxFit.cover,
            ),
        
            Container(
        
              decoration:
                  BoxDecoration(
        
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
                        .withOpacity(.7),
                  ],
                ),
              ),
            ),
        
            SafeArea(
        
              child: Padding(
        
                padding:
                    const EdgeInsets.all(
                  24,
                ),
        
                child: Column(
        
                  children: [
        
                    Row(
        
                      mainAxisAlignment:
                          MainAxisAlignment
                              .spaceBetween,
        
                      children: [
        
                        _glassButton(
                          Icons.close,
                        ),
        
                        ClipRRect(
        
                          borderRadius:
                              BorderRadius
                                  .circular(
                            20,
                          ),
        
                          child:
                              BackdropFilter(
        
                            filter:
                                ImageFilter
                                    .blur(
        
                              sigmaX: 20,
        
                              sigmaY: 20,
                            ),
        
                            child:
                                Container(
        
                              padding:
                                  const EdgeInsets
                                      .symmetric(
                                horizontal:
                                    18,
        
                                vertical:
                                    12,
                              ),
        
                              decoration:
                                  BoxDecoration(
        
                                color: Colors
                                    .white
                                    .withOpacity(
                                        .15),
        
                                borderRadius:
                                    BorderRadius
                                        .circular(
                                  20,
                                ),
                              ),
        
                              child:
                                  const Text(
        
                                '00:48',
        
                                style:
                                    TextStyle(
        
                                  color: Colors
                                      .white,
        
                                  fontWeight:
                                      FontWeight
                                          .bold,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
        
                    const Spacer(),
        
                    AnimatedBuilder(
        
                      animation:
                          controller,
        
                      builder:
                          (_, child) {
        
                        return Transform.scale(
        
                          scale:
                              1 +
                                  controller
                                          .value *
                                      .06,
        
                          child: child,
                        );
                      },
        
                      child: Container(
        
                        width: 130,
                        height: 130,
        
                        decoration:
                            BoxDecoration(
        
                          shape:
                              BoxShape.circle,
        
                          border:
                              Border.all(
        
                            color: Colors
                                .white,
        
                            width: 4,
                          ),
        
                          image:
                              const DecorationImage(
        
                            image:
                                NetworkImage(
                              'https://images.unsplash.com/photo-1494790108377-be9c29b29330',
                            ),
        
                            fit:
                                BoxFit.cover,
                          ),
                        ),
                      ),
                    ),
        
                    const SizedBox(height: 26),
        
                    const Text(
        
                      'Lujain Fashion',
        
                      style: TextStyle(
        
                        color: Colors.white,
        
                        fontSize: 34,
        
                        fontWeight:
                            FontWeight.bold,
                      ),
                    ),
        
                    const SizedBox(height: 12),
        
                    Text(
        
                      'Luxury Video Call ✨',
        
                      style: TextStyle(
        
                        color: Colors.white
                            .withOpacity(.75),
        
                        fontSize: 16,
                      ),
                    ),
        
                    const Spacer(),
        
                    Row(
        
                      mainAxisAlignment:
                          MainAxisAlignment
                              .spaceEvenly,
        
                      children: [
        
                        _callButton(
                          Icons.mic_off,
                          Colors.white24,
                        ),
        
                        _callButton(
                          Icons.call_end,
                          Colors.red,
                        ),
        
                        _callButton(
                          Icons.videocam_off,
                          Colors.white24,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _glassButton(
    IconData icon,
  ) {
    return ClipRRect(

      borderRadius:
          BorderRadius.circular(
        18,
      ),

      child: BackdropFilter(

        filter: ImageFilter.blur(
          sigmaX: 20,
          sigmaY: 20,
        ),

        child: Container(

          width: 54,
          height: 54,

          decoration: BoxDecoration(

            color:
                Colors.white
                    .withOpacity(.15),

            borderRadius:
                BorderRadius.circular(
              18,
            ),
          ),

          child: Icon(
            icon,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _callButton(
    IconData icon,
    Color color,
  ) {
    return Container(

      width: 78,
      height: 78,

      decoration:
          BoxDecoration(

        shape:
            BoxShape.circle,

        color: color,
      ),

      child: Icon(
        icon,
        color: Colors.white,
        size: 34,
      ),
    );
  }
}