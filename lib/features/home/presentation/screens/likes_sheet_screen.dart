import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../../core/design_system/design_system.dart';

class LikesSheetScreen extends StatelessWidget {
  const LikesSheetScreen({
    super.key,
    required this.likesCount,
  });

  final String likesCount;

  @override
  Widget build(BuildContext context) {
    final colors = context.dsColors;
    
    // Demo users who liked the post
    final users = _generateDemoUsers();

    return BottomSheet(
      onClosing: () => Navigator.of(context).pop(),
      
      builder: (context) =>
      Container(
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(DsRadius.xxxl)),
          boxShadow: context.luxuryShadow,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            // Container(
            //   margin: const EdgeInsets.only(top: DsSpacing.sm),
            //   width: 40,
            //   height: 4,
            //   decoration: BoxDecoration(
            //     color: colors.divider,
            //     borderRadius: DsRadius.borderFull,
            //   ),
            // ),
            
            // Header
            Padding(
              padding: const EdgeInsets.all(DsSpacing.lg),
              child: Row(
                children: [
                  Text(
                    'Liked by',
                    style: TextStyle(
                      fontSize: DsTypography.titleLarge,
                      fontWeight: DsTypography.bold,
                      color: colors.onSurface,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    likesCount,
                    style: TextStyle(
                      fontSize: DsTypography.bodyMedium,
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
      
            const Divider(height: 1),
      
            // Users list
            Flexible(
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: DsSpacing.lg, vertical: DsSpacing.sm),
                itemCount: users.length,
                separatorBuilder: (_, __) => const SizedBox(height: DsSpacing.sm),
                itemBuilder: (context, index) {
                  return _UserTile(
                    user: users[index],
                    index: index,
                  );
                },
              ),
            ),
          ],
        ),
      ).animate().slideY(begin: 0.3, duration: 400.ms).fadeIn(duration: 300.ms),
    );
  }

  List<_User> _generateDemoUsers() {
    return [
      _User(
        name: 'Sara Ahmed',
        username: 'sara_ahmed',
        imageUrl: 'https://images.unsplash.com/photo-1494790108377-be9c29b29330',
        isFollowing: true,
      ),
      _User(
        name: 'Layla Hassan',
        username: 'layla_hassan',
        imageUrl: 'https://images.unsplash.com/photo-1517841905240-472988babdf9',
        isFollowing: false,
      ),
      _User(
        name: 'Nour Ali',
        username: 'nour_ali',
        imageUrl: 'https://images.unsplash.com/photo-1524504388940-b1c1722653e1',
        isFollowing: true,
      ),
      _User(
        name: 'Mariam Ibrahim',
        username: 'mariam_ibrahim',
        imageUrl: 'https://images.unsplash.com/photo-1534528741775-53994a69da53',
        isFollowing: false,
      ),
      _User(
        name: 'Hana Mahmoud',
        username: 'hana_mahmoud',
        imageUrl: 'https://images.unsplash.com/photo-1506794778202-cad84cf45f1d',
        isFollowing: true,
      ),
      _User(
        name: 'Salma Omar',
        username: 'salma_omar',
        imageUrl: 'https://images.unsplash.com/photo-1531746020798-e6953c6e8e04',
        isFollowing: false,
      ),
      _User(
        name: 'Aisha Khalid',
        username: 'aisha_khalid',
        imageUrl: 'https://images.unsplash.com/photo-1519681393784-d120267933ba',
        isFollowing: true,
      ),
      _User(
        name: 'Fatima Youssef',
        username: 'fatima_youssef',
        imageUrl: 'https://images.unsplash.com/photo-1480796927426-f609979314bd',
        isFollowing: false,
      ),
    ];
  }
}

class _User {
  final String name;
  final String username;
  final String imageUrl;
  final bool isFollowing;

  _User({
    required this.name,
    required this.username,
    required this.imageUrl,
    required this.isFollowing,
  });
}

class _UserTile extends StatefulWidget {
  const _UserTile({
    required this.user,
    required this.index,
  });

  final _User user;
  final int index;

  @override
  State<_UserTile> createState() => _UserTileState();
}

class _UserTileState extends State<_UserTile> {
  late bool isFollowing;

  @override
  void initState() {
    super.initState();
    isFollowing = widget.user.isFollowing;
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.dsColors;

    return Row(
      children: [
        // Avatar
        Stack(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: colors.surfaceVariant,
              backgroundImage: NetworkImage(widget.user.imageUrl),
            ),
            if (isFollowing)
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: colors.primary,
                    shape: BoxShape.circle,
                    border: Border.all(color: colors.surface, width: 2),
                  ),
                  child: Icon(
                    Icons.check_rounded,
                    size: 10,
                    color: colors.onPrimary,
                  ),
                ),
              ),
          ],
        ),

        const SizedBox(width: DsSpacing.md),

        // User info
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.user.name,
                style: TextStyle(
                  fontWeight: DsTypography.semiBold,
                  color: colors.onSurface,
                ),
              ),
              Text(
                '@${widget.user.username}',
                style: TextStyle(
                  fontSize: DsTypography.labelSmall,
                  color: colors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),

        // Follow button
        GestureDetector(
          onTap: () {
            setState(() {
              isFollowing = !isFollowing;
            });
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(
              horizontal: DsSpacing.md,
              vertical: DsSpacing.sm,
            ),
            decoration: BoxDecoration(
              color: isFollowing ? colors.surfaceVariant : colors.primary,
              borderRadius: DsRadius.borderFull,
              border: Border.all(
                color: isFollowing ? colors.border : colors.primary,
              ),
            ),
            child: Text(
              isFollowing ? 'Following' : 'Follow',
              style: TextStyle(
                color: isFollowing ? colors.onSurfaceVariant : colors.onPrimary,
                fontWeight: DsTypography.semiBold,
                fontSize: DsTypography.labelMedium,
              ),
            ),
          ),
        ),
      ],
    ).animate().fadeIn(
      delay: (50 * widget.index).ms,
      duration: 300.ms,
    ).slideX(begin: 0.05);
  }
}