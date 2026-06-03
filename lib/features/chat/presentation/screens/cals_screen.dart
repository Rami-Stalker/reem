// // import 'package:flutter/material.dart';

// // import '../../../core/widgets/backgrounds/luxury_blurred_background.dart';

// // import '../widgets/chat_tile.dart';
// // import '../widgets/glass_search_bar.dart';
// // import '../widgets/online_avatar.dart';
// // import '../widgets/luxury_chat_fab.dart';

// // class ChatsScreen
// //     extends StatelessWidget {

// //   const ChatsScreen({
// //     super.key,
// //   });

// //   @override
// //   Widget build(BuildContext context) {
// //     return Scaffold(

// //       floatingActionButton:
// //           LuxuryChatFab(
// //         onTap: () {},
// //       ),

// //       body: LuxuryBlurredBackground(

// //         child: SafeArea(

// //           child: Padding(

// //             padding:
// //                 const EdgeInsets.all(
// //               22,
// //             ),

// //             child: Column(

// //               crossAxisAlignment:
// //                   CrossAxisAlignment
// //                       .start,

// //               children: [

// //                 const Text(

// //                   "Messages",

// //                   style: TextStyle(

// //                     fontSize: 34,

// //                     fontWeight:
// //                         FontWeight.bold,
// //                   ),
// //                 ),

// //                 const SizedBox(height: 8),

// //                 Text(

// //                   "Connect beautifully with your customers",

// //                   style: TextStyle(

// //                     color: Colors
// //                         .grey[600],

// //                     height: 1.7,
// //                   ),
// //                 ),

// //                 const SizedBox(height: 28),

// //                 const GlassSearchBar(),

// //                 const SizedBox(height: 28),

// //                 SizedBox(

// //                   height: 90,

// //                   child: ListView.separated(

// //                     scrollDirection:
// //                         Axis.horizontal,

// //                     itemBuilder:
// //                         (_, index) {

// //                       return const OnlineAvatar(

// //                         image:
// //                             "https://images.unsplash.com/photo-1494790108377-be9c29b29330",

// //                         online: true,
// //                       );
// //                     },

// //                     separatorBuilder:
// //                         (_, __) {

// //                       return const SizedBox(
// //                         width: 16,
// //                       );
// //                     },

// //                     itemCount: 10,
// //                   ),
// //                 ),

// //                 const SizedBox(height: 26),

// //                 Expanded(

// //                   child: ListView.builder(

// //                     itemCount: 12,

// //                     itemBuilder:
// //                         (_, index) {

// //                       return ChatTile(
// //                         onTap: () {},
// //                       );
// //                     },
// //                   ),
// //                 ),
// //               ],
// //             ),
// //           ),
// //         ),
// //       ),
// //     );
// //   }
// // }

// import 'dart:ui';

// import 'package:flutter/material.dart';

// // import '../../../core/widgets/backgrounds/luxury_blurred_background.dart';

// import '../widgets/chat_gradient_orb.dart';
// import '../widgets/glass_search_bar.dart';
// import '../widgets/luxury_chat_fab.dart';
// import '../widgets/chat_tile.dart';
// import '../widgets/encrypted_chat_banner.dart';
// import '../widgets/luxury_chat_empty_state.dart';

// class ChatsScreen extends StatefulWidget {
//   const ChatsScreen({super.key});

//   @override
//   State<ChatsScreen> createState() => _ChatsScreenState();
// }

// class _ChatsScreenState extends State<ChatsScreen>
//     with TickerProviderStateMixin {
//   late AnimationController headerController;

//   late Animation<double> fadeAnimation;

//   @override
//   void initState() {
//     super.initState();

//     headerController = AnimationController(
//       vsync: this,

//       duration: const Duration(milliseconds: 1200),
//     );

//     fadeAnimation = CurvedAnimation(
//       parent: headerController,

//       curve: Curves.easeOutQuart,
//     );

//     headerController.forward();
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       floatingActionButton: LuxuryChatFab(onTap: () {}),

//       body:
//           // LuxuryBlurredBackground(
//           //   child:
//           Stack(
//             children: [
//               const Positioned(top: -100, right: -80, child: ChatGradientOrb()),

//               const Positioned(
//                 bottom: -120,
//                 left: -100,
//                 child: ChatGradientOrb(),
//               ),

//               SafeArea(
//                 child: FadeTransition(
//                   opacity: fadeAnimation,

//                   child: Padding(
//                     padding: const EdgeInsets.all(22),

//                     child: Column(
//                       crossAxisAlignment: CrossAxisAlignment.start,

//                       children: [
//                         Row(
//                           children: [
//                             Expanded(
//                               child: Column(
//                                 crossAxisAlignment: CrossAxisAlignment.start,

//                                 children: [
//                                   ShaderMask(
//                                     shaderCallback: (rect) {
//                                       return const LinearGradient(
//                                         colors: [
//                                           Color(0xffFF9EB5),

//                                           Color(0xffFF5C8A),
//                                         ],
//                                       ).createShader(rect);
//                                     },

//                                     child: const Text(
//                                       "Luxury Chats",

//                                       style: TextStyle(
//                                         fontSize: 38,

//                                         fontWeight: FontWeight.w900,

//                                         color: Colors.white,
//                                       ),
//                                     ),
//                                   ),

//                                   const SizedBox(height: 10),

//                                   Text(
//                                     "Elegant conversations with your audience ✨",

//                                     style: TextStyle(
//                                       color: Colors.grey[700],

//                                       height: 1.7,
//                                     ),
//                                   ),
//                                 ],
//                               ),
//                             ),

//                             ClipRRect(
//                               borderRadius: BorderRadius.circular(26),

//                               child: BackdropFilter(
//                                 filter: ImageFilter.blur(
//                                   sigmaX: 20,

//                                   sigmaY: 20,
//                                 ),

//                                 child: Container(
//                                   width: 64,

//                                   height: 64,

//                                   decoration: BoxDecoration(
//                                     color: Colors.white.withOpacity(.65),

//                                     borderRadius: BorderRadius.circular(26),
//                                   ),

//                                   child: const Icon(
//                                     Icons.notifications_active_rounded,

//                                     color: Color(0xffFF5C8A),

//                                     size: 30,
//                                   ),
//                                 ),
//                               ),
//                             ),
//                           ],
//                         ),

//                         const SizedBox(height: 28),

//                         const GlassSearchBar(),

//                         const SizedBox(height: 22),

//                         const EncryptedChatBanner(),

//                         const SizedBox(height: 18),

//                         Expanded(
//                           child: ListView(
//                             physics: const BouncingScrollPhysics(),

//                             children: const [
//                               ChatTile(
//                                 name: "Lujain Fashion",

//                                 image:
//                                     "https://images.unsplash.com/photo-1494790108377-be9c29b29330",

//                                 message: "Your premium order is ready ✨",

//                                 unread: 4,

//                                 online: true,
//                               ),

//                               ChatTile(
//                                 name: "Luxury Boutique",

//                                 image:
//                                     "https://images.unsplash.com/photo-1524504388940-b1c1722653e1",

//                                 message: "New exclusive collection launched 💖",

//                                 unread: 2,

//                                 online: true,
//                               ),

//                               ChatTile(
//                                 name: "Beauty Queen",

//                                 image:
//                                     "https://images.unsplash.com/photo-1488426862026-3ee34a7d66df",

//                                 message: "Can you send more photos please?",

//                                 unread: 0,

//                                 online: false,
//                               ),

//                               ChatTile(
//                                 name: "Pink Store",

//                                 image:
//                                     "https://images.unsplash.com/photo-1544005313-94ddf0286df2",

//                                 message:
//                                     "Thank you for your luxury experience 💕",

//                                 unread: 7,

//                                 online: true,
//                               ),
//                             ],
//                           ),
//                         ),
//                       ],
//                     ),
//                   ),
//                 ),
//               ),
//             ],
//           ),
//       // ),
//     );
//   }
// }
