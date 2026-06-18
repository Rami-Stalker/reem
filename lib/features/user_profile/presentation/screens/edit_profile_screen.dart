import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design_system/design_system.dart';
import '../../../../core/shared/entities/user.dart';
import '../../../../core/shared/wedgets/app/app_avatar.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../providers/user_profile_providers.dart';

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _bio = TextEditingController();
  final _location = TextEditingController();
  final _imageUrl = TextEditingController();
  bool _seeded = false;

  @override
  void dispose() {
    _name.dispose();
    _bio.dispose();
    _location.dispose();
    _imageUrl.dispose();
    super.dispose();
  }

  void _seed(User user) {
    _name.text = user.name;
    _bio.text = user.bio ?? '';
    _location.text = user.location ?? '';
    _imageUrl.text = user.imageUrl ?? '';
    _seeded = true;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final image = _imageUrl.text.trim();
    final ok = await ref.read(editProfileNotifierProvider.notifier).save(
          name: _name.text.trim(),
          bio: _bio.text.trim(),
          location: _location.text.trim(),
          imageUrl: image.isEmpty ? null : image,
        );

    if (!mounted) return;
    if (ok) {
      await ref.read(authNotifierProvider.notifier).refreshUser();
      ref.invalidate(userProfileNotifierProvider(null));
      if (!mounted) return;
      DsSnackbar.show(
        context,
        message: 'Profile updated',
        type: DsSnackbarType.success,
      );
      context.pop();
    } else {
      final error = ref.read(editProfileNotifierProvider).error;
      if (error != null) {
        DsSnackbar.show(context, message: error, type: DsSnackbarType.error);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(editProfileNotifierProvider);
    final colors = context.dsColors;
    if (state.user != null && !_seeded) _seed(state.user!);

    return ReemScrollPage(
      slivers: [
        const PremiumAppBar(title: 'Edit Profile', showBack: true),
        if (state.isLoading && state.user == null)
          const SliverFillRemaining(
            hasScrollBody: false,
            child: Center(child: CircularProgressIndicator()),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.all(DsSpacing.lg),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                const SizedBox(height: DsSpacing.md),
                Center(
                  child: AppAvatar(
                    radius: 54,
                    imageUrl: _imageUrl.text,
                    heroTag: 'profile_${state.user?.id ?? 'me'}',
                  ),
                ),
                const SizedBox(height: DsSpacing.xxl),
                Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      DsInputField(
                        controller: _name,
                        label: 'Full name',
                        prefixIcon:
                            Icon(Icons.person_outline, color: colors.primary),
                        validator: (v) => (v == null || v.trim().length < 2)
                            ? 'Name must be at least 2 characters'
                            : null,
                      ),
                      DsInputField(
                        controller: _location,
                        label: 'Location',
                        prefixIcon:
                            Icon(Icons.place_outlined, color: colors.primary),
                      ),
                      DsInputField(
                        controller: _imageUrl,
                        label: 'Profile image URL',
                        keyboardType: TextInputType.url,
                        prefixIcon:
                            Icon(Icons.image_outlined, color: colors.primary),
                        onChanged: (_) => setState(() {}),
                        validator: (v) {
                          final value = v?.trim() ?? '';
                          if (value.isEmpty) return null;
                          final uri = Uri.tryParse(value);
                          if (uri == null || !uri.isAbsolute) {
                            return 'Enter a valid URL';
                          }
                          return null;
                        },
                      ),
                      DsInputField(
                        controller: _bio,
                        label: 'Bio',
                        maxLines: 4,
                        prefixIcon: Icon(Icons.edit_note_outlined,
                            color: colors.primary),
                        validator: (v) => (v != null && v.length > 500)
                            ? 'Bio must be under 500 characters'
                            : null,
                      ),
                      const SizedBox(height: DsSpacing.xl),
                      PrimaryButton(
                        label: 'Save changes',
                        isLoading: state.isSaving,
                        onPressed: state.isSaving ? null : _save,
                      ),
                    ],
                  ),
                ),
              ]),
            ),
          ),
      ],
    );
  }
}
