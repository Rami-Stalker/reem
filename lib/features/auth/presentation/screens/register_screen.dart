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

    return ReemScrollPage(
      slivers: [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Padding(
            padding: DsSpacing.screenPadding,
            child: Form(
              key: _formKey,
              autovalidateMode: AutovalidateMode.onUserInteraction,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: DsSpacing.xxxl),
                  Icon(
                    Icons.spa_rounded,
                    size: 48,
                    color: colors.primary,
                  ).animate().scale(duration: 600.ms),
                  const SizedBox(height: DsSpacing.xl),
                  DsGradientText(
                    l10n.finishSignUp,
                    style: context.dsText.pageTitle.bold,
                  ),
                  const SizedBox(height: DsSpacing.sm),
                  Text(
                    l10n.loginSubtitle,
                    textAlign: TextAlign.center,
                    style: context.dsText.body.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: DsSpacing.xxxl),
                  _RoleSelector(
                    value: _role,
                    onChanged: auth.isLoading
                        ? (_) {}
                        : (r) => setState(() {
                            _role = r;
                            _acceptedPolicies = true;
                            _policyVersionIds = const [];
                          }),
                  ),
                  const SizedBox(height: DsSpacing.md),
                  Row(
                    children: [
                      Expanded(
                        child: DsInputField(
                          controller: _firstNameController,
                          label: context.l10n.firstName,
                          prefixIcon: Icon(
                            Icons.person_outline,
                            color: colors.primary,
                          ),
                          validator: (v) =>
                              AuthFormValidators.requiredField(
                                context.l10n,
                                context.l10n.firstName,
                                v,
                              ),
                        ),
                      ),
                      const SizedBox(width: DsSpacing.sm),
                      Expanded(
                        child: DsInputField(
                          controller: _lastNameController,
                          label: context.l10n.lastName,
                          prefixIcon: Icon(
                            Icons.person_outline,
                            color: colors.primary,
                          ),
                          validator: (v) =>
                              AuthFormValidators.requiredField(
                                context.l10n,
                                context.l10n.lastName,
                                v,
                              ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: DsSpacing.md),
                  _VerifiedNumber(phone: widget.phone),
                  const SizedBox(height: DsSpacing.md),
                  Row(
                    children: [
                      Expanded(
                        child: DsInputField(
                          controller: _countryController,
                          label: context.l10n.country,
                          prefixIcon: Icon(
                            Icons.public_outlined,
                            color: colors.primary,
                          ),
                          validator: (v) =>
                              AuthFormValidators.requiredField(
                                context.l10n,
                                context.l10n.country,
                                v,
                              ),
                        ),
                      ),
                      const SizedBox(width: DsSpacing.sm),
                      Expanded(
                        child: DsInputField(
                          controller: _cityController,
                          label: context.l10n.city,
                          prefixIcon: Icon(
                            Icons.location_city_outlined,
                            color: colors.primary,
                          ),
                          validator: (v) =>
                              AuthFormValidators.requiredField(
                                context.l10n,
                                context.l10n.city,
                                v,
                              ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: DsSpacing.md),
                  SwitchListTile(
                    value: _wantsPassword,
                    onChanged: auth.isLoading
                        ? null
                        : (value) => setState(() => _wantsPassword = value),
                    contentPadding: EdgeInsets.zero,
                    activeThumbColor: colors.primary,
                    title: Text(
                      l10n.passwordOptional,
                      style: context.dsText.body,
                    ),
                    subtitle: Text(
                      l10n.passwordOptionalHint,
                      style: context.dsText.cardSubtitle.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ),
                  if (_wantsPassword) ...[
                    const SizedBox(height: DsSpacing.md),
                    DsInputField(
                      controller: _passwordController,
                      label: l10n.password,
                      obscureText: true,
                      autofillHints: const [AutofillHints.newPassword],
                      prefixIcon: Icon(
                        Icons.lock_outline,
                        color: colors.primary,
                      ),
                      onChanged: (_) => setState(() {}),
                      validator: (value) => _wantsPassword
                          ? AuthFormValidators.strongPassword(l10n, value)
                          : null,
                    ),
                    const SizedBox(height: DsSpacing.sm),
                    _PasswordStrengthIndicator(
                      password: _passwordController.text,
                    ),
                    const SizedBox(height: DsSpacing.md),
                    DsInputField(
                      controller: _confirmPasswordController,
                      label: l10n.confirmPassword,
                      obscureText: true,
                      prefixIcon: Icon(
                        Icons.lock_outline,
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
                  ],
                  const SizedBox(height: DsSpacing.lg),
                  // Q43/Q138 P1 — Reem is a women-only platform, and the only
                  // enforcement is this declaration. The server refuses a
                  // registration without it, so it is a real gate rather than
                  // a notice: the button stays disabled until she makes it.
                  CheckboxListTile(
                    value: _declaredFemale,
                    onChanged: auth.isLoading
                        ? null
                        : (value) =>
                              setState(() => _declaredFemale = value ?? false),
                    controlAffinity: ListTileControlAffinity.leading,
                    contentPadding: EdgeInsets.zero,
                    activeColor: colors.primary,
                    title: Text(
                      l10n.declaredFemaleLabel,
                      style: context.dsText.body,
                    ),
                  ),
                  const SizedBox(height: DsSpacing.md),
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
                  const SizedBox(height: DsSpacing.md),
                  PrimaryButton(
                    label: l10n.signup,
                    onPressed:
                        auth.isLoading || !_declaredFemale || !_acceptedPolicies
                        ? null
                        : _submit,
                    isLoading: auth.isLoading,
                  ),
                  const SizedBox(height: DsSpacing.xxxl),
                ],
              ),
            ),
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
    return Container(
      padding: const EdgeInsets.all(DsSpacing.md),
      decoration: BoxDecoration(
        color: colors.successContainer,
        borderRadius: BorderRadius.circular(DsRadius.md),
      ),
      child: Row(
        children: [
          Icon(Icons.verified_rounded, color: colors.success),
          const SizedBox(width: DsSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.l10n.numberVerified,
                  style: context.dsText.label.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
                Text(
                  phone,
                  textDirection: TextDirection.ltr,
                  style: context.dsText.cardTitle,
                ),
              ],
            ),
          ),
        ],
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
    return Row(
      children: [
        Expanded(
          child: _RoleChip(
            label: context.l10n.roleBuyer,
            icon: Icons.shopping_bag_outlined,
            selected: value == UserRole.customer,
            onTap: () => onChanged(UserRole.customer),
          ),
        ),
        const SizedBox(width: DsSpacing.sm),
        Expanded(
          child: _RoleChip(
            label: context.l10n.roleSeller,
            icon: Icons.storefront_outlined,
            selected: value == UserRole.seller,
            onTap: () => onChanged(UserRole.seller),
          ),
        ),
      ],
    );
  }
}

class _RoleChip extends StatelessWidget {
  const _RoleChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.dsColors;
    return InkWell(
      borderRadius: BorderRadius.circular(DsRadius.lg),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(
          vertical: DsSpacing.md,
          horizontal: DsSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: selected
              ? colors.primary.withValues(alpha: 0.12)
              : colors.surfaceVariant,
          borderRadius: BorderRadius.circular(DsRadius.lg),
          border: Border.all(
            color: selected ? colors.primary : colors.border,
            width: selected ? 1.6 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: selected ? colors.primary : colors.onSurfaceVariant,
            ),
            const SizedBox(height: DsSpacing.xs),
            Text(
              label,
              textAlign: TextAlign.center,
              style: context.dsText.label.copyWith(
                color: selected ? colors.primary : colors.onSurfaceVariant,
                fontWeight: selected ? DsTypography.bold : DsTypography.regular,
              ),
            ),
          ],
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
        ClipRRect(
          borderRadius: BorderRadius.circular(DsRadius.xs),
          child: LinearProgressIndicator(
            minHeight: 6,
            value: score / 5,
            color: color,
            backgroundColor: colors.surfaceVariant,
          ),
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
