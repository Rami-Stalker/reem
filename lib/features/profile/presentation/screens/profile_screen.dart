import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';

import '../widgets/profile_header.dart';
import '../widgets/profile_stats.dart';
import '../widgets/profile_action_buttons.dart';
import '../widgets/highlights_section.dart';
import '../widgets/profile_post_grid.dart';
import '../widgets/profile_menu_tile.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,

      body: CustomScrollView(
        physics:
            const BouncingScrollPhysics(),

        slivers: [

          /// APP BAR
          SliverAppBar(
            floating: true,
            pinned: true,
            elevation: 0,
            backgroundColor:
                AppColors.background,

            title: const Text(
              "ملفي الشخصي",
              style: TextStyle(
                color: AppColors.textDark,
                fontWeight: FontWeight.bold,
              ),
            ),

            centerTitle: true,

            actions: [
              IconButton(
                onPressed: () {},
                icon: const Icon(
                  Icons.settings_outlined,
                  color: AppColors.textDark,
                ),
              ),
            ],
          ),

          SliverToBoxAdapter(
            child: Column(
              children: const [

                SizedBox(height: 10),

                /// HEADER
                ProfileHeader(),

                SizedBox(height: 24),

                /// STATS
                ProfileStats(),

                SizedBox(height: 24),

                /// ACTION BUTTONS
                ProfileActionButtons(),

                SizedBox(height: 28),

                /// HIGHLIGHTS
                HighlightsSection(),

                SizedBox(height: 30),
              ],
            ),
          ),

          /// MENU
          SliverToBoxAdapter(
            child: Column(
              children: const [

                ProfileMenuTile(
                  icon:
                      Icons.shopping_bag_outlined,
                  title: "طلباتي",
                ),

                ProfileMenuTile(
                  icon:
                      Icons.favorite_border,
                  title: "المفضلة",
                ),

                ProfileMenuTile(
                  icon:
                      Icons.local_offer_outlined,
                  title: "الكوبونات والعروض",
                ),

                ProfileMenuTile(
                  icon:
                      Icons.location_on_outlined,
                  title: "العناوين",
                ),

                ProfileMenuTile(
                  icon:
                      Icons.credit_card_outlined,
                  title: "طرق الدفع",
                ),
              ],
            ),
          ),

          /// POSTS GRID
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.only(
                top: 28,
                right: 18,
                left: 18,
                bottom: 12,
              ),
              child: Text(
                "منشوراتي",
                style: TextStyle(
                  fontSize: 22,
                  fontWeight:
                      FontWeight.bold,
                ),
              ),
            ),
          ),

          const ProfilePostGrid(),

          const SliverToBoxAdapter(
            child: SizedBox(height: 120),
          ),
        ],
      ),
    );
  }
}