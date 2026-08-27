import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:reem/core/design_system/effects/backgrounds/luxury_blurred_background.dart';

class ChatProfileScreen extends StatelessWidget {
  const ChatProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LuxuryBlurredBackground(
        child: SafeArea(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),

            padding: const EdgeInsets.all(22),

            child: Column(
              children: [
                Row(
                  children: [
                    GestureDetector(
                      onTap: () {
                        Navigator.pop(context);
                      },

                      child: _circleButton(Icons.arrow_back_ios_new_rounded),
                    ),

                    const Spacer(),

                    _circleButton(Icons.more_vert_rounded),
                  ],
                ),

                const SizedBox(height: 40),

                Hero(
                  tag: "profile",

                  child: Container(
                    width: 150,
                    height: 150,

                    decoration: BoxDecoration(
                      shape: BoxShape.circle,

                      image: const DecorationImage(
                        image: NetworkImage(
                          "https://images.unsplash.com/photo-1494790108377-be9c29b29330",
                        ),

                        fit: BoxFit.cover,
                      ),

                      boxShadow: [
                        BoxShadow(
                          color: Colors.pink.withOpacity(.25),

                          blurRadius: 40,

                          spreadRadius: 6,
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 26),

                ShaderMask(
                  shaderCallback: (rect) {
                    return const LinearGradient(
                      colors: [Color(0xffFF9EB5), Color(0xffFF5C8A)],
                    ).createShader(rect);
                  },

                  child: const Text(
                    "Lujain Fashion",

                    style: TextStyle(
                      fontSize: 34,

                      fontWeight: FontWeight.w900,

                      color: Colors.white,
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                Text(
                  "Luxury Fashion Brand ✨",

                  style: TextStyle(color: Colors.grey[700], fontSize: 16),
                ),

                const SizedBox(height: 36),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,

                  children: [
                    _action(Icons.call_rounded, "Call"),

                    _action(Icons.videocam_rounded, "Video"),

                    _action(Icons.search_rounded, "Search"),

                    _action(Icons.notifications, "Mute"),
                  ],
                ),

                const SizedBox(height: 42),

                _section(
                  title: "Shared Media",
                  child: SizedBox(
                    height: 120,

                    child: ListView(
                      scrollDirection: Axis.horizontal,

                      children: List.generate(5, (index) {
                        return Container(
                          width: 110,

                          margin: const EdgeInsetsDirectional.only(end: 16),

                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(28),

                            image: DecorationImage(
                              image: NetworkImage(
                                "https://picsum.photos/300/40$index",
                              ),

                              fit: BoxFit.cover,
                            ),
                          ),
                        );
                      }),
                    ),
                  ),
                ),

                const SizedBox(height: 26),

                _section(
                  title: "Options",

                  child: Column(
                    children: [
                      _tile(Icons.photo_library, "Media & Files"),

                      _tile(Icons.favorite, "Favorite Messages"),

                      _tile(Icons.wallpaper, "Chat Theme"),

                      _tile(Icons.lock, "Privacy Settings"),
                    ],
                  ),
                ),

                const SizedBox(height: 26),

                _dangerTile(Icons.delete_rounded, "Delete Conversation"),

                const SizedBox(height: 20),

                _dangerTile(Icons.block_rounded, "Block User"),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _circleButton(IconData icon) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),

      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),

        child: Container(
          width: 58,
          height: 58,

          decoration: BoxDecoration(
            color: Colors.white.withOpacity(.7),

            borderRadius: BorderRadius.circular(24),
          ),

          child: Icon(icon, color: const Color(0xffFF5C8A)),
        ),
      ),
    );
  }

  Widget _action(IconData icon, String title) {
    return Column(
      children: [
        Container(
          width: 72,
          height: 72,

          decoration: const BoxDecoration(
            shape: BoxShape.circle,

            gradient: LinearGradient(
              colors: [Color(0xffFF9EB5), Color(0xffFF5C8A)],
            ),
          ),

          child: Icon(icon, color: Colors.white),
        ),

        const SizedBox(height: 12),

        Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _section({required String title, required Widget child}) {
    return Container(
      width: double.infinity,

      padding: const EdgeInsets.all(22),

      decoration: BoxDecoration(
        color: Colors.white.withOpacity(.7),

        borderRadius: BorderRadius.circular(34),
      ),

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,

        children: [
          Text(
            title,

            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),

          const SizedBox(height: 22),

          child,
        ],
      ),
    );
  }

  Widget _tile(IconData icon, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),

      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,

            decoration: BoxDecoration(
              shape: BoxShape.circle,

              color: const Color(0xffFFF3F7),
            ),

            child: Icon(icon, color: const Color(0xffFF5C8A)),
          ),

          const SizedBox(width: 18),

          Expanded(
            child: Text(
              title,

              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
            ),
          ),

          const Icon(Icons.arrow_forward_ios, size: 18),
        ],
      ),
    );
  }

  Widget _dangerTile(IconData icon, String title) {
    return Container(
      padding: const EdgeInsets.all(20),

      decoration: BoxDecoration(
        color: Colors.red.withOpacity(.08),

        borderRadius: BorderRadius.circular(26),
      ),

      child: Row(
        children: [
          Icon(icon, color: Colors.red),

          const SizedBox(width: 16),

          Text(
            title,

            style: const TextStyle(
              color: Colors.red,

              fontWeight: FontWeight.bold,

              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }
}
