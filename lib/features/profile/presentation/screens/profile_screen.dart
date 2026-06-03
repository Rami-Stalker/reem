import 'package:flutter/material.dart';

import '../../../../core/design_system/design_system.dart';
import '../../../../core/design_system/patterns/reem_page_scaffold.dart';
import '../widgets/luxury_app_bar.dart';
import '../widgets/luxury_post_grid.dart';
import '../widgets/profile_info_section.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ReemScrollPage(
      slivers: const [
        LuxuryAppBar(),
        SliverToBoxAdapter(child: ProfileInfoSection()),
        LuxuryPostGrid(),
        SliverToBoxAdapter(child: SizedBox(height: 140)),
      ],
    );
  }
}
