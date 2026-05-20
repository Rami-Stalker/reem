// home_screen.dart
// Premium Feminine Home Screen
// Glow & Gift

import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../data/datasources/dummy_data.dart';

import '../widgets/custom_app_bar.dart';
import '../widgets/stories_section.dart';
import '../widgets/post_card.dart';
import '../widgets/discount_banner.dart';
import '../widgets/bottom_nav_bar.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  int currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,

      /// FLOATING BUTTON
      floatingActionButton: Container(
        height: 68,
        width: 68,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
            colors: [AppColors.primary, AppColors.secondary],
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: .35),
              blurRadius: 20,
              spreadRadius: 2,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: FloatingActionButton(
          elevation: 0,
          backgroundColor: Colors.transparent,
          onPressed: () {
            // add story/post
          },
          child: const Icon(Icons.add, size: 32, color: Colors.white),
        ),
      ),

      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,

      bottomNavigationBar: BottomNavBar(
        currentIndex: currentIndex,
        onTap: (index) {
          setState(() {
            currentIndex = index;
          });
        },
      ),

      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          /// APP BAR
          const CustomAppBar(),

          /// STORIES
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(top: 6),
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 700),
                opacity: 1,
                child: const StoriesSection(),
              ),
            ),
          ),

          /// DISCOUNT BANNER
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 10),
              child: DiscountBanner(),
            ),
          ),

          /// CATEGORIES
          SliverToBoxAdapter(
            child: SizedBox(
              height: 55,
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                scrollDirection: Axis.horizontal,
                children: [
                  _categoryChip(title: "الكل", active: true),
                  _categoryChip(title: "فساتين"),
                  _categoryChip(title: "حقائب"),
                  _categoryChip(title: "أحذية"),
                  _categoryChip(title: "مكياج"),
                  _categoryChip(title: "عطور"),
                ],
              ),
            ),
          ),

          /// POSTS
          SliverPadding(
            padding: const EdgeInsets.only(top: 12),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate((context, index) {
                final post = posts[index];

                return TweenAnimationBuilder(
                  duration: Duration(milliseconds: 400 + (index * 200)),
                  tween: Tween(begin: 40.0, end: 0.0),
                  builder: (context, value, child) {
                    return Transform.translate(
                      offset: Offset(0, value),
                      child: Opacity(
                        opacity: value == 0 ? 1 : .7,
                        child: child,
                      ),
                    );
                  },
                  child: PostCard(post: post),
                );
              }, childCount: posts.length),
            ),
          ),

          /// SPACE
          const SliverToBoxAdapter(child: SizedBox(height: 120)),
        ],
      ),
    );
  }

  Widget _categoryChip({required String title, bool active = false}) {
    return Container(
      margin: const EdgeInsets.only(left: 12),
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),

        gradient: active
            ? const LinearGradient(
                colors: [AppColors.primary, AppColors.secondary],
              )
            : null,

        color: active ? null : Colors.white,

        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .04),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Center(
        child: Text(
          title,
          style: TextStyle(
            color: active ? Colors.white : AppColors.textDark,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
