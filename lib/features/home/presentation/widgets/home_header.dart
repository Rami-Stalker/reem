import 'package:flutter/material.dart';

class HomeHeader extends StatelessWidget {
  final String userName;
  final VoidCallback? onProfileTap;
  final VoidCallback? onNotificationsTap;

  const HomeHeader({
    super.key,
    required this.userName,
    this.onProfileTap,
    this.onNotificationsTap,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        GestureDetector(
          onTap: onProfileTap,
          child: CircleAvatar(
            radius: 24,
            backgroundImage: AssetImage('assets/user.png'), // أو من الشبكة
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            'Hi, $userName 👋',
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ),
        IconButton(
            onPressed: onNotificationsTap,
            icon: const Icon(Icons.notifications_outlined)),
      ],
    );
  }
}