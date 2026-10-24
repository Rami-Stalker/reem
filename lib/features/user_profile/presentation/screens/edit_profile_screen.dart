import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:ohara/core/design_system/design_system.dart';
import 'package:ohara/core/localization/l10n_extension.dart';
import 'package:ohara/core/shared/entities/user.dart';
import 'package:ohara/features/auth/presentation/providers/auth_provider.dart';
import 'package:ohara/features/user_profile/presentation/providers/user_profile_providers.dart';

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
  final _email = TextEditingController();
  String? _imageUrl;
  bool _seeded = false;

  @override
  void dispose() {
    _name.dispose();
    _bio.dispose();
    _location.dispose();
    _email.dispose();
    super.dispose();
  }

  void _seed(User user) {
    _name.text = user.name;
    _bio.text = user.bio ?? '';
    _location.text = user.location ?? '';
    _email.text = user.email ?? '';
    _imageUrl = user.imageUrl;
    _seeded = true;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final image = _imageUrl?.trim() ?? '';
    final ok = await ref
        .read(editProfileNotifierProvider.notifier)
        .save(
          name: _name.text.trim(),
          bio: _bio.text.trim(),
          location: _location.text.trim(),
          imageUrl: image.isEmpty ? null : image,
          // Always sent, so clearing the field clears the address — the
          // profile checklist asks for one and this is where it is given.
          email: _email.text.trim(),
        );

    if (!mounted) return;
    if (ok) {
      await ref.read(authNotifierProvider.notifier).refreshUser();
      ref.invalidate(userProfileNotifierProvider(null));
      if (!mounted) return;
      DsSnackbar.show(
        context,
        message: context.l10n.profileUpdated,
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

    return OharaScrollPage(
      slivers: [
        PremiumAppBar(title: context.l10n.profileEditTitle, showBack: true),
        if (state.isLoading && state.user == null)
          const SliverFillRemaining(
            hasScrollBody: false,
            child: DsLoadingIndicator(),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.all(DsSpacing.lg),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                const SizedBox(height: DsSpacing.md),
                Center(
                  child: DsAvatarPicker(
                    imageUrl: _imageUrl,
                    enabled: !state.isLoading,
                    // Saved with the rest of the form, not on pick: the upload
                    // has happened, but until she taps save the profile still
                    // points at the old photograph, and going back should mean
                    // going back.
                    onChanged: (url) => setState(() => _imageUrl = url),
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
                        label: context.l10n.profileFullName,
                        prefixIcon: Icon(
                          Icons.person_outline,
                          color: colors.primary,
                        ),
                        validator: (v) => (v == null || v.trim().length < 2)
                            ? context.l10n.profileNameTooShort
                            : null,
                      ),
                      DsInputField(
                        controller: _location,
                        label: context.l10n.profileLocation,
                        prefixIcon: Icon(
                          Icons.place_outlined,
                          color: colors.primary,
                        ),
                      ),
                      // Q34's «بريد إلكتروني للاستعادة» — the last step on the
                      // profile checklist, and the one that had no field
                      // anywhere in the app, so the completion ring could
                      // never reach 100%.
                      DsInputField(
                        controller: _email,
                        label: context.l10n.profileRecoveryEmail,
                        helperText: context.l10n.profileRecoveryEmailHint,
                        keyboardType: TextInputType.emailAddress,
                        prefixIcon: Icon(
                          Icons.alternate_email_rounded,
                          color: colors.primary,
                        ),
                        validator: (value) {
                          final email = value?.trim() ?? '';
                          if (email.isEmpty) return null;
                          final valid = RegExp(
                            r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
                          ).hasMatch(email);
                          return valid ? null : context.l10n.profileEmailInvalid;
                        },
                      ),
                      DsInputField(
                        controller: _bio,
                        label: context.l10n.profileBio,
                        maxLines: 4,
                        prefixIcon: Icon(
                          Icons.edit_note_outlined,
                          color: colors.primary,
                        ),
                        validator: (v) => (v != null && v.length > 500)
                            ? context.l10n.profileBioTooLong
                            : null,
                      ),
                      const SizedBox(height: DsSpacing.xl),
                      PrimaryButton(
                        label: context.l10n.profileSaveChanges,
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
