import 'dart:math' as math;

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
    final palette = context.boutique;
    final gutter = vanityGutter(context);
    if (state.user != null && !_seeded) _seed(state.user!);

    return OharaScrollPage(
      slivers: [
        VanityAppBar(
          title: context.l10n.profileEditTitle,
          icon: Icons.badge_outlined,
          showBack: true,
        ),
        if (state.isLoading && state.user == null)
          const SliverFillRemaining(
            hasScrollBody: false,
            child: DsLoadingIndicator(),
          )
        else
          SliverPadding(
            padding: EdgeInsets.fromLTRB(gutter, DsSpacing.xl, gutter, 120),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // Her portrait, in a ring of small lit bulbs.
                Center(
                  child: _PortraitRing(
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
                ),
                DsGaps.vXxl,
                Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      VanityTray(
                        padding: const EdgeInsets.fromLTRB(
                          DsSpacing.md,
                          DsSpacing.lg,
                          DsSpacing.md,
                          DsSpacing.xs,
                        ),
                        children: [
                          DsInputField(
                            controller: _name,
                            label: context.l10n.profileFullName,
                            prefixIcon: Icon(
                              Icons.person_outline,
                              color: palette.primary,
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
                              color: palette.primary,
                            ),
                          ),
                          DsInputField(
                            controller: _bio,
                            label: context.l10n.profileBio,
                            maxLines: 4,
                            prefixIcon: Icon(
                              Icons.edit_note_outlined,
                              color: palette.primary,
                            ),
                            validator: (v) => (v != null && v.length > 500)
                                ? context.l10n.profileBioTooLong
                                : null,
                          ),
                        ],
                      ),
                      DsGaps.vXl,
                      VanityTray(
                        padding: const EdgeInsets.fromLTRB(
                          DsSpacing.md,
                          DsSpacing.lg,
                          DsSpacing.md,
                          DsSpacing.xs,
                        ),
                        children: [
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
                              color: palette.primary,
                            ),
                            validator: (value) {
                              final email = value?.trim() ?? '';
                              if (email.isEmpty) return null;
                              final valid = RegExp(
                                r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
                              ).hasMatch(email);
                              return valid
                                  ? null
                                  : context.l10n.profileEmailInvalid;
                            },
                          ),
                        ],
                      ),
                      DsGaps.vXxl,
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

/// A ring of small lit bulbs round her portrait — the vanity's mirror light.
class _PortraitRing extends StatelessWidget {
  const _PortraitRing({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final palette = context.boutique;
    return Container(
      padding: const EdgeInsets.all(DsSpacing.md),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            palette.gold.withValues(alpha: 0.18),
            palette.primary.withValues(alpha: 0),
          ],
        ),
      ),
      child: CustomPaint(
        foregroundPainter: _BulbRing(
          color: palette.gold,
          rtl: Directionality.of(context) == TextDirection.rtl,
        ),
        child: Padding(padding: DsSpacing.paddingSm, child: child),
      ),
    );
  }
}

class _BulbRing extends CustomPainter {
  const _BulbRing({required this.color, required this.rtl});

  final Color color;
  final bool rtl;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2;
    canvas.drawCircle(
      center,
      radius - 2,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = color.withValues(alpha: 0.5),
    );
    const count = 16;
    for (var i = 0; i < count; i++) {
      // Leave the lower end corner free for the picker's camera badge.
      if (rtl ? (i == 5 || i == 6) : (i == 1 || i == 2)) continue;
      final a = math.pi * 2 * i / count;
      final p = center + Offset(math.cos(a), math.sin(a)) * (radius - 2);
      canvas.drawCircle(p, 3.2, Paint()..color = DsColors.gold100);
      canvas.drawCircle(
        p,
        3.2,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4
          ..color = color,
      );
    }
  }

  @override
  bool shouldRepaint(_BulbRing old) => old.color != color || old.rtl != rtl;
}
