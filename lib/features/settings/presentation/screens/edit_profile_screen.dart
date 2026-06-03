import 'package:flutter/material.dart';

import '../../../../core/design_system/design_system.dart';
import '../../../../core/design_system/patterns/reem_page_scaffold.dart';
import '../../../../core/shared/wedgets/app/premium_app_bar.dart';
import '../../../profile/presentation/widgets/editable_profile_field.dart';
import '../../../profile/presentation/widgets/luxury_avatar.dart';

class EditProfileScreen extends StatelessWidget {
  const EditProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ReemScrollPage(
      slivers: [
        const PremiumAppBar(title: 'Edit Profile', showBack: true),
        SliverPadding(
          padding: const EdgeInsets.all(DsSpacing.lg),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              const SizedBox(height: DsSpacing.md),
              const Center(child: LuxuryAvatar()),
              const SizedBox(height: DsSpacing.xxl),
              const EditableProfileField(
                hint: 'Full Name',
                icon: Icons.person_outline,
              ),
              const EditableProfileField(
                hint: 'Email Address',
                icon: Icons.email_outlined,
              ),
              const EditableProfileField(
                hint: 'Phone Number',
                icon: Icons.phone_outlined,
              ),
              const EditableProfileField(
                hint: 'Bio',
                icon: Icons.edit_note_outlined,
                maxLines: 4,
              ),
              const SizedBox(height: DsSpacing.xl),
              PrimaryButton(label: 'Save changes', onPressed: () {}),
            ]),
          ),
        ),
      ],
    );
  }
}
