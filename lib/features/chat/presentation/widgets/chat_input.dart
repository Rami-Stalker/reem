// import 'package:flutter/material.dart';

// import 'voice_record_button.dart';

// class ChatInput
//     extends StatelessWidget {

//   const ChatInput({
//     super.key,
//   });

//   @override
//   Widget build(BuildContext context) {
//     return Container(

//       padding:
//           const EdgeInsets.fromLTRB(
//         20,
//         18,
//         20,
//         30,
//       ),

//       decoration: BoxDecoration(

//         color:
//             Colors.white
//                 .withOpacity(.82),

//         borderRadius:
//             const BorderRadius.vertical(

//           top: Radius.circular(34),
//         ),
//       ),

//       child: Row(

//         children: [

//           _icon(
//             Icons.add_rounded,
//           ),

//           const SizedBox(width: 14),

//           Expanded(

//             child: Container(

//               padding:
//                   const EdgeInsets.symmetric(
//                 horizontal: 20,
//               ),

//               decoration:
//                   BoxDecoration(

//                 color:
//                     const Color(
//                   0xffF8F8FA,
//                 ),

//                 borderRadius:
//                     BorderRadius
//                         .circular(24),
//               ),

//               child: TextField(

//                 decoration:
//                     InputDecoration(

//                   hintText:
//                       "Type luxury message...",

//                   border:
//                       InputBorder.none,

//                   hintStyle: TextStyle(
//                     color:
//                         Colors.grey[500],
//                   ),
//                 ),
//               ),
//             ),
//           ),

//           const SizedBox(width: 14),

//           const VoiceRecordButton(),
//         ],
//       ),
//     );
//   }

//   Widget _icon(
//     IconData icon,
//   ) {
//     return Container(

//       width: 52,
//       height: 52,

//       decoration:
//           const BoxDecoration(

//         shape: BoxShape.circle,

//         gradient:
//             LinearGradient(

//           colors: [

//             Color(0xffFF9EB5),
//             Color(0xffFF5C8A),
//           ],
//         ),
//       ),

//       child: Icon(
//         icon,
//         color: Colors.white,
//       ),
//     );
//   }
// }

import 'dart:ui';

import 'package:flutter/material.dart';

class ChatInput extends StatefulWidget {
  const ChatInput({super.key});

  @override
  State<ChatInput> createState() => _ChatInputState();
}

class _ChatInputState extends State<ChatInput>
    with SingleTickerProviderStateMixin {
  late AnimationController controller;

  bool expanded = false;

  @override
  void initState() {
    super.initState();

    controller = AnimationController(
      vsync: this,

      duration: const Duration(milliseconds: 450),
    );
  }

  void toggle() {
    setState(() {
      expanded = !expanded;
    });

    if (expanded) {
      controller.forward();
    } else {
      controller.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(36)),

      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),

        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),

          decoration: BoxDecoration(color: Colors.white.withOpacity(.78)),

          child: Column(
            mainAxisSize: MainAxisSize.min,

            children: [
              SizeTransition(
                sizeFactor: controller,

                child: Padding(
                  padding: const EdgeInsets.only(bottom: 22),

                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,

                    children: [
                      _action(Icons.photo, "Gallery"),

                      _action(Icons.camera_alt, "Camera"),

                      _action(Icons.mic, "Voice"),

                      _action(Icons.location_on, "Location"),
                    ],
                  ),
                ),
              ),

              Row(
                children: [
                  GestureDetector(
                    onTap: toggle,

                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 400),

                      width: 56,
                      height: 56,

                      decoration: BoxDecoration(
                        shape: BoxShape.circle,

                        gradient: const LinearGradient(
                          colors: [Color(0xffFF9EB5), Color(0xffFF5C8A)],
                        ),
                      ),

                      child: AnimatedRotation(
                        turns: expanded ? .125 : 0,

                        duration: const Duration(milliseconds: 300),

                        child: const Icon(
                          Icons.add_rounded,

                          color: Colors.white,

                          size: 30,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(width: 16),

                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20),

                      decoration: BoxDecoration(
                        color: Colors.white,

                        borderRadius: BorderRadius.circular(24),
                      ),

                      child: TextField(
                        decoration: InputDecoration(
                          hintText: "Write elegant message...",

                          border: InputBorder.none,

                          hintStyle: TextStyle(color: Colors.grey[500]),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(width: 16),

                  Container(
                    width: 58,
                    height: 58,

                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,

                      gradient: LinearGradient(
                        colors: [Color(0xffFF9EB5), Color(0xffFF5C8A)],
                      ),
                    ),

                    child: const Icon(Icons.send_rounded, color: Colors.white),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _action(IconData icon, String title) {
    return Column(
      children: [
        Container(
          width: 64,
          height: 64,

          decoration: BoxDecoration(
            shape: BoxShape.circle,

            color: Colors.white,

            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(.05), blurRadius: 16),
            ],
          ),

          child: Icon(icon, color: const Color(0xffFF5C8A)),
        ),

        const SizedBox(height: 10),

        Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      ],
    );
  }
}
