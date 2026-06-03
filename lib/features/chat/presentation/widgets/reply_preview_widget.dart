import 'package:flutter/material.dart';

class ReplyPreviewWidget
    extends StatelessWidget {

  final String sender;

  final String message;

  final VoidCallback? onClose;

  const ReplyPreviewWidget({
    super.key,
    required this.sender,
    required this.message,
    this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Container(

      margin:
          const EdgeInsets.only(
        bottom: 16,
      ),

      padding:
          const EdgeInsets.all(
        16,
      ),

      decoration: BoxDecoration(

        color:
            const Color(
          0xffFFF4F8,
        ),

        borderRadius:
            BorderRadius.circular(
          24,
        ),

        border: Border.all(

          color:
              const Color(
            0xffFFB5C8,
          ),
        ),
      ),

      child: Row(

        children: [

          Container(

            width: 5,

            height: 52,

            decoration:
                BoxDecoration(

              borderRadius:
                  BorderRadius
                      .circular(20),

              gradient:
                  const LinearGradient(

                colors: [

                  Color(0xffFF9EB5),

                  Color(0xffFF5C8A),
                ],
              ),
            ),
          ),

          const SizedBox(width: 16),

          Expanded(

            child: Column(

              crossAxisAlignment:
                  CrossAxisAlignment
                      .start,

              children: [

                Text(

                  sender,

                  style: const TextStyle(

                    color:
                        Color(
                      0xffFF5C8A,
                    ),

                    fontWeight:
                        FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 6),

                Text(

                  message,

                  maxLines: 1,

                  overflow:
                      TextOverflow
                          .ellipsis,

                  style: TextStyle(

                    color:
                        Colors.grey[700],
                  ),
                ),
              ],
            ),
          ),

          GestureDetector(

            onTap: onClose,

            child: Container(

              width: 36,
              height: 36,

              decoration:
                  BoxDecoration(

                shape:
                    BoxShape.circle,

                color:
                    Colors.white,
              ),

              child: const Icon(
                Icons.close_rounded,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }
}