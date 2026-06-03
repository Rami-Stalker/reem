import 'package:flutter/material.dart';

class VoiceMessageBubble
    extends StatefulWidget {

  final bool isMe;

  const VoiceMessageBubble({
    super.key,
    this.isMe = false,
  });

  @override
  State<VoiceMessageBubble>
      createState() =>
          _VoiceMessageBubbleState();
}

class _VoiceMessageBubbleState
    extends State<
        VoiceMessageBubble> {

  bool playing = false;

  @override
  Widget build(BuildContext context) {
    return Align(

      alignment:
          widget.isMe
              ? Alignment.centerRight
              : Alignment.centerLeft,

      child: Container(

        width: 280,

        padding:
            const EdgeInsets.all(
          18,
        ),

        decoration: BoxDecoration(

          gradient:
              widget.isMe
                  ? const LinearGradient(
                      colors: [

                        Color(
                            0xffFF9EB5),

                        Color(
                            0xffFF5C8A),
                      ],
                    )
                  : null,

          color:
              widget.isMe
                  ? null
                  : Colors.white,

          borderRadius:
              BorderRadius.circular(
            30,
          ),
        ),

        child: Row(

          children: [

            GestureDetector(

              onTap: () {

                setState(() {
                  playing = !playing;
                });
              },

              child: Container(

                width: 48,
                height: 48,

                decoration:
                    BoxDecoration(

                  shape:
                      BoxShape.circle,

                  color: widget.isMe
                      ? Colors.white
                          .withOpacity(.2)
                      : const Color(
                          0xffFF5C8A,
                        ),
                ),

                child: Icon(

                  playing
                      ? Icons.pause
                      : Icons.play_arrow,

                  color: Colors.white,
                ),
              ),
            ),

            const SizedBox(width: 16),

            Expanded(

              child: Row(

                children: List.generate(
                  22,
                  (index) {

                    return Expanded(

                      child:
                          AnimatedContainer(

                        duration:
                            const Duration(
                          milliseconds:
                              300,
                        ),

                        margin:
                            const EdgeInsets
                                .symmetric(
                          horizontal: 1,
                        ),

                        height:
                            playing
                                ? (index %
                                            5 +
                                        1) *
                                    8
                                : 10,

                        decoration:
                            BoxDecoration(

                          borderRadius:
                              BorderRadius
                                  .circular(
                            20,
                          ),

                          color: widget.isMe
                              ? Colors.white
                              : Colors
                                  .pink,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),

            const SizedBox(width: 14),

            Text(

              "0:28",

              style: TextStyle(

                color:
                    widget.isMe
                        ? Colors.white
                        : Colors.black87,

                fontWeight:
                    FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}