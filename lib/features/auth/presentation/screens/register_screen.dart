import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:reem/core/design_system/design_system.dart';
import 'package:reem/core/localization/l10n_extension.dart';
import 'package:reem/core/router/route_paths.dart';
import 'package:reem/core/shared/entities/user.dart';
import 'package:reem/features/auth/presentation/providers/auth_provider.dart';
import 'package:reem/features/auth/presentation/utils/auth_form_validators.dart';
import 'package:reem/features/auth/presentation/widgets/auth_motion.dart';
import 'package:reem/features/policies/presentation/widgets/policy_consent_field.dart';

/// The signup form, reached only after the number has been verified.
///
/// It is not an entry point any more. `phone` and `registrationTicket` come
/// from `POST /auth/otp/login/verify`, and the server refuses to create an
/// account without the ticket — which is what stops one person registering
/// every number in a contact list and locking those women out of ever signing
/// up under their own.
///
/// The password fields are optional and collapsed by default. A Reem account
/// signs in with a code; a password is a convenience she can add, and it can
/// never admit a device the account has not used before.
class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({
    super.key,
    required this.phone,
    required this.registrationTicket,
    this.from,
  });

  /// The number whose control was just proved. Shown, never edited: editing it
  /// here would mean the ticket no longer matches, and the server would refuse.
  final String phone;
  final String registrationTicket;
  final String? from;

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _countryController = TextEditingController();
  final _cityController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  UserRole _role = UserRole.customer;
  bool _declaredFemale = false;

  /// The terms she has agreed to, and the exact issues of them.
  ///
  /// Version ids rather than a bare flag: the server records one acceptance
  /// per document against the text that was on this screen, which is what
  /// makes the consent reconstructible.
  ///
  /// Starts **true** and `PolicyConsentField` revokes it the moment it knows
  /// there is something to sign — see its class doc for why the default runs
  /// that way round. Both are reset when she switches between buying and
  /// selling: the two roles sign different documents, and carrying a shopper's
  /// tick into a seller registration would record a signature against terms
  /// she was never shown.
  bool _acceptedPolicies = true;
  List<String> _policyVersionIds = const [];

  /// Off by default, and that is the recommended state — see the class doc.
  bool _wantsPassword = false;

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _countryController.dispose();
    _cityController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final ok = await ref
        .read(authNotifierProvider.notifier)
        .register(
          firstName: _firstNameController.text.trim(),
          lastName: _lastNameController.text.trim(),
          phone: widget.phone,
          registrationTicket: widget.registrationTicket,
          password: _wantsPassword ? _passwordController.text : null,
          acceptedPolicyVersionIds: _policyVersionIds,
          country: _countryController.text.trim(),
          city: _cityController.text.trim(),
          declaredFemale: _declaredFemale,
          role: _role,
        );

    if (!mounted) return;
    if (ok) {
      // No "now verify your phone" step any more: the number was verified
      // before the account existed, which is the point of the ticket. Sending
      // her to a verification screen here asked her to prove the same thing
      // twice and left the account looking unverified until she did.
      final from = widget.from;
      context.go(from == null || from.isEmpty ? RoutePaths.home : from);
    } else {
      final error = ref.read(authNotifierProvider).error;
      if (error != null) {
        DsSnackbar.show(context, message: error, type: DsSnackbarType.error);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final auth = ref.watch(authNotifierProvider);
    final colors = context.dsColors;

    return AuthStage(
      step: 2,
      children: [
        const AuthEmblem(icon: Icons.spa_rounded, size: 84)
            .animate()
            .fadeIn(duration: 500.ms)
            .scale(
              begin: const Offset(0.85, 0.85),
              duration: 800.ms,
              curve: DsMotion.softSpring,
            ),
        AuthHeading(
          title: l10n.finishSignUp,
          subtitle: l10n.loginSubtitle,
        ).authEnter(1),
        DsGaps.vXl,
        _VerifiedNumber(phone: widget.phone).authEnter(2),
        DsGaps.vXl,
        Form(
          key: _formKey,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AuthSectionLabel(l10n.authSectionJoinAs),
              DsGaps.vSm,
              _RoleSelector(
                value: _role,
                onChanged: auth.isLoading
                    ? (_) {}
                    : (r) => setState(() {
                        _role = r;
                        _acceptedPolicies = true;
                        _policyVersionIds = const [];
                      }),
              ).authEnter(3),
              DsGaps.vXl,
              AuthPanel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AuthSectionLabel(
                      l10n.authSectionAboutYou,
                      icon: Icons.face_retouching_natural_rounded,
                    ),
                    DsGaps.vMd,
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: DsInputField(
                            controller: _firstNameController,
                            label: l10n.firstName,
                            textInputAction: TextInputAction.next,
                            autofillHints: const [AutofillHints.givenName],
                            textCapitalization: TextCapitalization.words,
                            validator: (v) => AuthFormValidators.requiredField(
                              l10n,
                              l10n.firstName,
                              v,
                            ),
                          ),
                        ),
                        DsGaps.hSm,
                        Expanded(
                          child: DsInputField(
                            controller: _lastNameController,
                            label: l10n.lastName,
                            textInputAction: TextInputAction.next,
                            autofillHints: const [AutofillHints.familyName],
                            textCapitalization: TextCapitalization.words,
                            validator: (v) => AuthFormValidators.requiredField(
                              l10n,
                              l10n.lastName,
                              v,
                            ),
                          ),
                        ),
                      ],
                    ),
                    DsGaps.vXl,
                    AuthSectionLabel(
                      l10n.authSectionWhere,
                      icon: Icons.place_rounded,
                    ),
                    DsGaps.vMd,
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: DsInputField(
                            controller: _countryController,
                            label: l10n.country,
                            textInputAction: TextInputAction.next,
                            autofillHints: const [AutofillHints.countryName],
                            prefixIcon: Icon(
                              Icons.public_rounded,
                              color: colors.primary,
                            ),
                            validator: (v) => AuthFormValidators.requiredField(
                              l10n,
                              l10n.country,
                              v,
                            ),
                          ),
                        ),
                        DsGaps.hSm,
                        Expanded(
                          child: DsInputField(
                            controller: _cityController,
                            label: l10n.city,
                            textInputAction: TextInputAction.done,
                            autofillHints: const [AutofillHints.addressCity],
                            prefixIcon: Icon(
                              Icons.location_city_rounded,
                              color: colors.primary,
                            ),
                            validator: (v) => AuthFormValidators.requiredField(
                              l10n,
                              l10n.city,
                              v,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ).authEnter(4),
              DsGaps.vLg,
              AuthPanel(
                padding: const EdgeInsets.fromLTRB(
                  DsSpacing.xl,
                  DsSpacing.lg,
                  DsSpacing.xl,
                  DsSpacing.lg,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AuthSectionLabel(
                      l10n.authSectionSecurity,
                      icon: Icons.shield_moon_rounded,
                    ),
                    SwitchListTile(
                      value: _wantsPassword,
                      onChanged: auth.isLoading
                          ? null
                          : (value) => setState(() => _wantsPassword = value),
                      contentPadding: EdgeInsets.zero,
                      activeThumbColor: colors.primary,
                      title: Text(
                        l10n.passwordOptional,
                        style: context.dsText.bodyStrong,
                      ),
                      subtitle: Text(
                        l10n.passwordOptionalHint,
                        style: context.dsText.caption,
                      ),
                    ),
                    AnimatedSize(
                      duration: DsMotion.moderate,
                      curve: DsMotion.gentle,
                      alignment: Alignment.topCenter,
                      child: !_wantsPassword
                          ? const SizedBox(width: double.infinity)
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                DsGaps.vSm,
                                DsInputField(
                                  controller: _passwordController,
                                  label: l10n.password,
                                  obscureText: true,
                                  autofillHints: const [
                                    AutofillHints.newPassword,
                                  ],
                                  prefixIcon: Icon(
                                    Icons.lock_outline_rounded,
                                    color: colors.primary,
                                  ),
                                  onChanged: (_) => setState(() {}),
                                  validator: (value) => _wantsPassword
                                      ? AuthFormValidators.strongPassword(
                                          l10n,
                                          value,
                                        )
                                      : null,
                                ),
                                DsGaps.vSm,
                                _PasswordStrengthIndicator(
                                  password: _passwordController.text,
                                ),
                                DsGaps.vMd,
                                DsInputField(
                                  controller: _confirmPasswordController,
                                  label: l10n.confirmPassword,
                                  obscureText: true,
                                  prefixIcon: Icon(
                                    Icons.lock_outline_rounded,
                                    color: colors.primary,
                                  ),
                                  validator: (v) {
                                    if (!_wantsPassword) return null;
                                    if (v != _passwordController.text) {
                                      return l10n.confirmPasswordMismatch;
                                    }
                                    return null;
                                  },
                                ),
                                DsGaps.vXs,
                              ],
                            ),
                    ),
                  ],
                ),
              ).authEnter(5),
              DsGaps.vLg,
              AuthPanel(
                padding: const EdgeInsets.fromLTRB(
                  DsSpacing.xl,
                  DsSpacing.lg,
                  DsSpacing.xl,
                  DsSpacing.lg,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AuthSectionLabel(
                      l10n.authSectionPromise,
                      icon: Icons.favorite_rounded,
                    ),
                    DsGaps.vXs,
                    // Q43/Q138 P1 — Reem is a women-only platform, and the
                    // only enforcement is this declaration. The server refuses
                    // a registration without it, so it is a real gate rather
                    // than a notice: the button stays disabled until she
                    // makes it.
                    CheckboxListTile(
                      value: _declaredFemale,
                      onChanged: auth.isLoading
                          ? null
                          : (value) => setState(
                              () => _declaredFemale = value ?? false,
                            ),
                      controlAffinity: ListTileControlAffinity.leading,
                      contentPadding: EdgeInsets.zero,
                      activeColor: colors.primary,
                      title: Text(
                        l10n.declaredFemaleLabel,
                        style: context.dsText.body,
                      ),
                    ),
                    DsGaps.vXs,
                    // The terms, named and linked, above one statement. The
                    // server refuses a registration whose accepted ids do not
                    // cover every required document, so this is a real gate
                    // rather than a notice — the same shape as the declaration
                    // above it.
                    PolicyConsentField(
                      role: _role == UserRole.seller ? 'seller' : 'buyer',
                      accepted: _acceptedPolicies,
                      enabled: !auth.isLoading,
                      introText: l10n.registerConsentIntro,
                      agreeText: l10n.registerConsentAgree,
                      onChanged: (accepted, ids) => setState(() {
                        _acceptedPolicies = accepted;
                        _policyVersionIds = accepted ? ids : const [];
                      }),
                    ),
                  ],
                ),
              ).authEnter(6),
              DsGaps.vXl,
              PrimaryButton(
                label: l10n.signup,
                icon: Icons.auto_awesome_rounded,
                onPressed:
                    auth.isLoading || !_declaredFemale || !_acceptedPolicies
                    ? null
                    : _submit,
                isLoading: auth.isLoading,
              ).authEnter(7),
              DsGaps.vXl,
              AuthTrustNote(text: l10n.authTrustNote),
              DsGaps.vXxl,
            ],
          ),
        ),
      ],
    );
  }
}

/// The number she just proved, shown rather than asked for.
///
/// A field she could edit would be a trap: the ticket is bound to one number,
/// so typing a different one produces a refusal she has no way to understand.
class _VerifiedNumber extends StatelessWidget {
  const _VerifiedNumber({required this.phone});

  final String phone;

  @override
  Widget build(BuildContext context) {
    final colors = context.dsColors;
    return Center(
      child: Container(
        padding: const EdgeInsetsDirectional.fromSTEB(
          DsSpacing.xs,
          DsSpacing.xs,
          DsSpacing.lg,
          DsSpacing.xs,
        ),
        decoration: BoxDecoration(
          borderRadius: DsRadius.borderPill,
          color: colors.surface.withValues(alpha: 0.8),
          border: Border.all(color: colors.success.withValues(alpha: 0.35)),
          boxShadow: context.shadowXs,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: DsSizes.avatarSm,
              height: DsSizes.avatarSm,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: colors.successContainer,
              ),
              child: Icon(
                Icons.verified_rounded,
                color: colors.success,
                size: DsSizes.iconSm,
              ),
            ),
            DsGaps.hSm,
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    context.l10n.numberVerified,
                    style: context.dsText.caption.copyWith(
                      color: colors.success,
                    ),
                  ),
                  Text(
                    phone,
                    textDirection: TextDirection.ltr,
                    style: context.dsText.bodyStrong.tabular,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Lets a new user choose how they want to join: shop as a Customer or sell on
/// Reem as a Seller. Admins are provisioned separately (never self-registered).
class _RoleSelector extends StatelessWidget {
  const _RoleSelector({required this.value, required this.onChanged});

  final UserRole value;
  final ValueChanged<UserRole> onChanged;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: _RoleCard(
              label: context.l10n.roleBuyer,
              hint: context.l10n.authRoleBuyerHint,
              icon: Icons.shopping_bag_rounded,
              selected: value == UserRole.customer,
              onTap: () => onChanged(UserRole.customer),
            ),
          ),
          DsGaps.hSm,
          Expanded(
            child: _RoleCard(
              label: context.l10n.roleSeller,
              hint: context.l10n.authRoleSellerHint,
              icon: Icons.storefront_rounded,
              selected: value == UserRole.seller,
              onTap: () => onChanged(UserRole.seller),
            ),
          ),
        ],
      ),
    );
  }
}

/// One way to join, as a card: lit with the rose blend when chosen, frosted
/// when not, with a check that pops in at the corner.
class _RoleCard extends StatelessWidget {
  const _RoleCard({
    required this.label,
    required this.hint,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String hint;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.dsColors;
    final ink = selected ? DsColors.onMedia : colors.onSurface;
    final muted = selected ? DsColors.onMediaMuted : colors.onSurfaceVariant;

    return Semantics(
      selected: selected,
      button: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: DsRadius.borderXxl,
          child: AnimatedContainer(
            duration: DsMotion.moderate,
            curve: DsMotion.gentle,
            padding: const EdgeInsets.all(DsSpacing.md),
            decoration: BoxDecoration(
              borderRadius: DsRadius.borderXxl,
              gradient: selected ? context.primaryGradient : null,
              color: selected ? null : colors.surface.withValues(alpha: 0.7),
              border: Border.all(
                color: selected
                    ? DsColors.onMediaFaint
                    : colors.border.withValues(alpha: 0.8),
              ),
              boxShadow: selected ? context.primaryGlow : context.shadowXs,
            ),
            child: Stack(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AnimatedContainer(
                      duration: DsMotion.moderate,
                      width: DsSizes.avatarMd,
                      height: DsSizes.avatarMd,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: selected
                            ? DsColors.mediaPlate
                            : colors.primaryContainer,
                      ),
                      child: Icon(
                        icon,
                        color: selected ? DsColors.onMedia : colors.primary,
                        size: DsSizes.iconSm,
                      ),
                    ),
                    DsGaps.vSm,
                    Text(
                      label,
                      style: context.dsText.cardTitle.bold.copyWith(color: ink),
                    ),
                    DsGaps.vXxs,
                    Text(
                      hint,
                      style: context.dsText.caption.copyWith(color: muted),
                    ),
                  ],
                ),
                PositionedDirectional(
                  top: 0,
                  end: 0,
                  child: AnimatedScale(
                    scale: selected ? 1 : 0,
                    duration: DsMotion.moderate,
                    curve: DsMotion.softSpring,
                    child: const Icon(
                      Icons.check_circle_rounded,
                      color: DsColors.onMedia,
                      size: DsSizes.iconSm,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PasswordStrengthIndicator extends StatelessWidget {
  const _PasswordStrengthIndicator({required this.password});

  final String password;

  @override
  Widget build(BuildContext context) {
    final colors = context.dsColors;
    final score = _score(password);
    final label = score <= 1
        ? context.l10n.passwordWeak
        : score <= 3
        ? context.l10n.passwordGood
        : context.l10n.passwordStrong;
    final color = score <= 1
        ? colors.error
        : score <= 3
        ? colors.warning
        : colors.success;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DsMeter(
          value: score / 5,
          weight: DsMeterWeight.regular,
          color: color,
          track: colors.surfaceVariant,
        ),
        const SizedBox(height: DsSpacing.xs),
        Text(
          context.l10n.passwordStrengthLabel(label),
          style: context.dsText.caption.copyWith(color: color),
        ),
      ],
    );
  }

  int _score(String value) {
    if (value.isEmpty) return 0;
    var score = 0;
    if (value.length >= 10) score++;
    if (RegExp(r'[a-z]').hasMatch(value)) score++;
    if (RegExp(r'[A-Z]').hasMatch(value)) score++;
    if (RegExp(r'[0-9]').hasMatch(value)) score++;
    if (RegExp(r'[^A-Za-z0-9]').hasMatch(value)) score++;
    return score;
  }
}
