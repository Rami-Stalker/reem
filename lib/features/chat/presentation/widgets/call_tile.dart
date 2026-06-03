// import 'package:flutter/material.dart';

// import '../../../core/theme/colors.dart';

// import 'online_avatar.dart';
// import 'unread_badge.dart';

// class ChatTile
//     extends StatelessWidget {

//   final VoidCallback onTap;

//   const ChatTile({
//     super.key,
//     required this.onTap,
//   });

//   @override
//   Widget build(BuildContext context) {
//     return GestureDetector(

//       onTap: onTap,

//       child: Container(

//         margin:
//             const EdgeInsets.only(
//           bottom: 18,
//         ),

//         padding:
//             const EdgeInsets.all(
//           18,
//         ),

//         decoration: BoxDecoration(

//           color: Colors.white,

//           borderRadius:
//               BorderRadius.circular(
//             30,
//           ),

//           boxShadow: [

//             BoxShadow(

//               color: Colors.black
//                   .withOpacity(.04),

//               blurRadius: 18,

//               offset:
//                   const Offset(0, 10),
//             ),
//           ],
//         ),

//         child: Row(

//           children: [

//             const OnlineAvatar(

//               image:
//                   "https://images.unsplash.com/photo-1494790108377-be9c29b29330",

//               online: true,
//             ),

//             const SizedBox(width: 18),

//             Expanded(

//               child: Column(

//                 crossAxisAlignment:
//                     CrossAxisAlignment
//                         .start,

//                 children: [

//                   const Text(

//                     "Lujain Fashion",

//                     style: TextStyle(

//                       fontSize: 17,

//                       fontWeight:
//                           FontWeight.bold,
//                     ),
//                   ),

//                   const SizedBox(height: 8),

//                   Text(

//                     "Your order has been shipped ✨",

//                     maxLines: 1,

//                     overflow:
//                         TextOverflow
//                             .ellipsis,

//                     style: TextStyle(

//                       color: Colors
//                           .grey[600],
//                     ),
//                   ),
//                 ],
//               ),
//             ),

//             Column(

//               children: [

//                 Text(

//                   "2:30 PM",

//                   style: TextStyle(

//                     color:
//                         Colors.grey[500],

//                     fontSize: 12,
//                   ),
//                 ),

//                 const SizedBox(height: 12),

//                 const UnreadBadge(
//                   count: 3,
//                 ),
//               ],
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }

import 'package:flutter/material.dart';

class CallTile
    extends StatelessWidget {

  final bool video;

  final bool missed;

  const CallTile({
    super.key,
    this.video = false,
    this.missed = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(

      margin:
          const EdgeInsets.only(
        bottom: 18,
      ),

      padding:
          const EdgeInsets.all(
        18,
      ),

      decoration: BoxDecoration(

        color: Colors.white,

        borderRadius:
            BorderRadius.circular(
          30,
        ),

        boxShadow: [

          BoxShadow(

            color: Colors.black
                .withOpacity(.04),

            blurRadius: 20,
          ),
        ],
      ),

      child: Row(

        children: [

          const CircleAvatar(

            radius: 32,

            backgroundImage:
                NetworkImage(
              "https://images.unsplash.com/photo-1494790108377-be9c29b29330",
            ),
          ),

          const SizedBox(width: 18),

          Expanded(

            child: Column(

              crossAxisAlignment:
                  CrossAxisAlignment
                      .start,

              children: [

                const Text(

                  "Lujain Fashion",

                  style: TextStyle(

                    fontSize: 17,

                    fontWeight:
                        FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 8),

                Row(

                  children: [

                    Icon(

                      missed
                          ? Icons
                              .call_received_rounded
                          : Icons
                              .call_made_rounded,

                      color:
                          missed
                              ? Colors.red
                              : Colors.green,

                      size: 18,
                    ),

                    const SizedBox(width: 8),

                    Text(

                      missed
                          ? "Missed call"
                          : "Outgoing call",

                      style: TextStyle(

                        color: Colors
                            .grey[600],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          Container(

            width: 54,
            height: 54,

            decoration:
                const BoxDecoration(

              shape: BoxShape.circle,

              gradient:
                  LinearGradient(

                colors: [

                  Color(0xffFF9EB5),
                  Color(0xffFF5C8A),
                ],
              ),
            ),

            child: Icon(

              video
                  ? Icons
                      .videocam_rounded
                  : Icons.call_rounded,

              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}