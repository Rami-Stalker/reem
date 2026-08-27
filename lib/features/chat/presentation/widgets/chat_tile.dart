import 'dart:ui';

import 'package:flutter/material.dart';

import 'package:reem/features/chat/presentation/widgets/unread_badge.dart';

class ChatTile
    extends StatefulWidget {

  final String name;

  final String image;

  final String message;

  final int unread;

  final bool online;

  final bool typing;

  final VoidCallback? onTap;

  const ChatTile({
    super.key,
    required this.name,
    required this.image,
    required this.message,
    required this.unread,
    required this.online,
    this.typing = false,
    this.onTap,
  });

  @override
  State<ChatTile>
      createState() =>
          _ChatTileState();
}

class _ChatTileState
    extends State<ChatTile>

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
        milliseconds: 1800,
      ),
    )..repeat(reverse: true);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(

      onTap: widget.onTap,

      child: AnimatedBuilder(

        animation: controller,

        builder:
            (_, child) {

          return Transform.translate(

            offset: Offset(
              0,
              controller.value * -2,
            ),

            child: child,
          );
        },

        child: Container(

          margin:
              const EdgeInsets.only(
            bottom: 20,
          ),

          child: ClipRRect(

            borderRadius:
                BorderRadius.circular(
              34,
            ),

            child: BackdropFilter(

              filter: ImageFilter.blur(
                sigmaX: 20,
                sigmaY: 20,
              ),

              child: Container(

                padding:
                    const EdgeInsets.all(
                  18,
                ),

                decoration:
                    BoxDecoration(

                  color: Colors.white
                      .withOpacity(.72),

                  borderRadius:
                      BorderRadius
                          .circular(
                    34,
                  ),

                  border: Border.all(

                    color: Colors.white
                        .withOpacity(.28),
                  ),

                  boxShadow: [

                    BoxShadow(

                      color: Colors.black
                          .withOpacity(.04),

                      blurRadius: 24,

                      offset:
                          const Offset(
                        0,
                        10,
                      ),
                    ),
                  ],
                ),

                child: Row(

                  children: [

                    Stack(

                      children: [

                        Hero(

                          tag:
                              widget.image,

                          child: Container(

                            width: 76,
                            height: 76,

                            decoration:
                                BoxDecoration(

                              shape:
                                  BoxShape.circle,

                              image:
                                  DecorationImage(

                                image:
                                    NetworkImage(
                                  widget.image,
                                ),

                                fit:
                                    BoxFit.cover,
                              ),

                              boxShadow: [

                                BoxShadow(

                                  color: Colors
                                      .pink
                                      .withOpacity(
                                          .2),

                                  blurRadius:
                                      18,
                                ),
                              ],
                            ),
                          ),
                        ),

                        if (widget.online)

                          Positioned(

                            bottom: 4,
                            right: 4,

                            child:
                                AnimatedContainer(

                              duration:
                                  const Duration(
                                milliseconds:
                                    600,
                              ),

                              width:
                                  18,

                              height:
                                  18,

                              decoration:
                                  BoxDecoration(

                                shape:
                                    BoxShape
                                        .circle,

                                color:
                                    Colors
                                        .green,

                                border:
                                    Border.all(

                                  color:
                                      Colors
                                          .white,

                                  width:
                                      3,
                                ),

                                boxShadow: [

                                  BoxShadow(

                                    color: Colors
                                        .green
                                        .withOpacity(
                                            .5),

                                    blurRadius:
                                        12,
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),

                    const SizedBox(width: 18),

                    Expanded(

                      child: Column(

                        crossAxisAlignment:
                            CrossAxisAlignment
                                .start,

                        children: [

                          Row(

                            children: [

                              Expanded(

                                child: Text(

                                  widget.name,

                                  maxLines: 1,

                                  overflow:
                                      TextOverflow
                                          .ellipsis,

                                  style:
                                      const TextStyle(

                                    fontSize:
                                        18,

                                    fontWeight:
                                        FontWeight
                                            .w800,
                                  ),
                                ),
                              ),

                              Text(

                                '2:48 PM',

                                style:
                                    TextStyle(

                                  color: Colors
                                      .grey[500],

                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(
                              height: 10),

                          widget.typing

                              ? Row(

                                  children: [

                                    SizedBox(

                                      width:
                                          36,

                                      child:
                                          Row(

                                        children: List.generate(
                                          3,
                                          (index) {

                                            return Expanded(

                                              child:
                                                  AnimatedContainer(

                                                duration:
                                                    Duration(
                                                  milliseconds:
                                                      400 +
                                                          index *
                                                              120,
                                                ),

                                                margin:
                                                    const EdgeInsets.symmetric(
                                                  horizontal:
                                                      1,
                                                ),

                                                height:
                                                    controller.value *
                                                            8 +
                                                        4,

                                                decoration:
                                                    BoxDecoration(

                                                  shape:
                                                      BoxShape.circle,

                                                  color:
                                                      const Color(
                                                    0xffFF5C8A,
                                                  ),
                                                ),
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                                    ),

                                    const SizedBox(
                                        width:
                                            12),

                                    const Text(

                                      'typing...',

                                      style:
                                          TextStyle(

                                        color:
                                            Color(
                                          0xffFF5C8A,
                                        ),

                                        fontWeight:
                                            FontWeight
                                                .w600,
                                      ),
                                    ),
                                  ],
                                )

                              : Text(

                                  widget.message,

                                  maxLines: 1,

                                  overflow:
                                      TextOverflow
                                          .ellipsis,

                                  style:
                                      TextStyle(

                                    color:
                                        Colors.grey[
                                            700],

                                    height:
                                        1.4,
                                  ),
                                ),
                        ],
                      ),
                    ),

                    const SizedBox(width: 12),

                    Column(

                      crossAxisAlignment:
                          CrossAxisAlignment
                              .end,

                      children: [

                        if (widget.unread >
                            0)

                          UnreadBadge(
                            count:
                                widget.unread,
                          ),

                        const SizedBox(
                            height: 16),

                        Container(

                          width: 14,
                          height: 14,

                          decoration:
                              BoxDecoration(

                            shape:
                                BoxShape.circle,

                            gradient:
                                const LinearGradient(

                              colors: [

                                Color(
                                    0xffFF9EB5),

                                Color(
                                    0xffFF5C8A),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}