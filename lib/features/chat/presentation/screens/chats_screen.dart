import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:reem/core/design_system/effects/backgrounds/luxury_blurred_background.dart';
import 'package:reem/features/chat/presentation/widgets/chat_gradient_orb.dart';
import 'package:reem/features/chat/presentation/widgets/chat_tile.dart';
import 'package:reem/features/chat/presentation/widgets/encrypted_chat_banner.dart';
import 'package:reem/features/chat/presentation/widgets/glass_search_bar.dart';
import 'package:reem/features/chat/presentation/widgets/luxury_chat_fab.dart';
import 'package:reem/features/chat/presentation/widgets/online_presence_ring.dart';

class ChatsScreen extends StatefulWidget {
  const ChatsScreen({super.key});

  @override
  State<ChatsScreen> createState() => _ChatsScreenState();
}

class _ChatsScreenState extends State<ChatsScreen>
    with TickerProviderStateMixin {
  late AnimationController headerController;

  late Animation<double> fadeAnimation;

  late Animation<Offset> slideAnimation;

  @override
  void initState() {
    super.initState();

    headerController = AnimationController(
      vsync: this,

      duration: const Duration(milliseconds: 1400),
    );

    fadeAnimation = CurvedAnimation(
      parent: headerController,

      curve: Curves.easeOutQuart,
    );

    slideAnimation =
        Tween<Offset>(begin: const Offset(0, -.08), end: Offset.zero).animate(
          CurvedAnimation(parent: headerController, curve: Curves.easeOutExpo),
        );

    headerController.forward();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: LuxuryChatFab(onTap: () {}),

      body: LuxuryBlurredBackground(
        child: Stack(
          children: [
            const Positioned(top: -120, right: -100, child: ChatGradientOrb()),

            const Positioned(
              bottom: -150,
              left: -120,
              child: ChatGradientOrb(),
            ),

            SafeArea(
              child: FadeTransition(
                opacity: fadeAnimation,

                child: SlideTransition(
                  position: slideAnimation,

                  child: Padding(
                    padding: const EdgeInsets.all(22),

                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,

                      children: [
                        /// HEADER
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,

                                children: [
                                  ShaderMask(
                                    shaderCallback: (rect) {
                                      return const LinearGradient(
                                        colors: [
                                          Color(0xffFF9EB5),

                                          Color(0xffFF5C8A),
                                        ],
                                      ).createShader(rect);
                                    },

                                    child: const Text(
                                      'Luxury Chats',

                                      style: TextStyle(
                                        fontSize: 40,

                                        fontWeight: FontWeight.w900,

                                        color: Colors.white,
                                      ),
                                    ),
                                  ),

                                  const SizedBox(height: 12),

                                  Text(
                                    'Elegant conversations with your premium audience ✨',

                                    style: TextStyle(
                                      color: Colors.grey[700],

                                      height: 1.7,

                                      fontSize: 15,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            ClipRRect(
                              borderRadius: BorderRadius.circular(28),

                              child: BackdropFilter(
                                filter: ImageFilter.blur(
                                  sigmaX: 20,

                                  sigmaY: 20,
                                ),

                                child: Container(
                                  width: 68,

                                  height: 68,

                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(.7),

                                    borderRadius: BorderRadius.circular(28),
                                  ),

                                  child: Stack(
                                    alignment: Alignment.center,

                                    children: [
                                      const Icon(
                                        Icons.notifications_active_rounded,

                                        color: Color(0xffFF5C8A),

                                        size: 30,
                                      ),

                                      Positioned(
                                        top: 16,
                                        right: 18,

                                        child: Container(
                                          width: 10,

                                          height: 10,

                                          decoration: const BoxDecoration(
                                            shape: BoxShape.circle,

                                            color: Colors.red,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 28),

                        /// SEARCH
                        const GlassSearchBar(),

                        const SizedBox(height: 24),

                        /// ENCRYPTED BANNER
                        const EncryptedChatBanner(),

                        const SizedBox(height: 18),

                        /// ACTIVE USERS
                        SizedBox(
                          height: 100,

                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,

                            physics: const BouncingScrollPhysics(),

                            itemBuilder: (_, index) {
                              return Column(
                                children: [
                                  OnlinePresenceRing(
                                    child: CircleAvatar(
                                      radius: 30,

                                      backgroundImage: NetworkImage(
                                        'https://picsum.photos/200/${index + 10}',
                                      ),
                                    ),
                                  ),

                                  const SizedBox(height: 10),

                                  Text(
                                    'User ${index + 1}',

                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              );
                            },

                            separatorBuilder: (_, __) =>
                                const SizedBox(width: 18),

                            itemCount: 10,
                          ),
                        ),

                        const SizedBox(height: 22),

                        /// CHATS
                        Expanded(
                          child: ListView(
                            physics: const BouncingScrollPhysics(),

                            children: [
                              ChatTile(
                                name: 'Lujain Fashion',

                                image:
                                    'https://images.unsplash.com/photo-1494790108377-be9c29b29330',

                                message: 'Your luxury order is ready ✨',

                                unread: 5,

                                online: true,

                                typing: false,

                                onTap: () {},
                              ),

                              ChatTile(
                                name: 'Pink Boutique',

                                image:
                                    'https://images.unsplash.com/photo-1524504388940-b1c1722653e1',

                                message: 'Can you send more photos please 💕',

                                unread: 2,

                                online: true,

                                typing: true,

                                onTap: () {},
                              ),

                              ChatTile(
                                name: 'Luxury Queen',

                                image:
                                    'https://images.unsplash.com/photo-1488426862026-3ee34a7d66df',

                                message: 'Everything looks stunning 😍',

                                unread: 0,

                                online: false,

                                typing: false,

                                onTap: () {},
                              ),

                              ChatTile(
                                name: 'Beauty Store',

                                image:
                                    'https://images.unsplash.com/photo-1544005313-94ddf0286df2',

                                message: 'Thank you for shopping with us ✨',

                                unread: 9,

                                online: true,

                                typing: false,

                                onTap: () {},
                              ),

                              const SizedBox(height: 120),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
