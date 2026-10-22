import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:reem/core/design_system/design_system.dart';
import 'package:reem/core/localization/l10n_extension.dart';
import 'package:reem/core/router/route_paths.dart';
import 'package:reem/features/auth/domain/entities/auth_account.dart';
import 'package:reem/features/auth/presentation/utils/auth_form_validators.dart';
import 'package:reem/features/auth/presentation/widgets/auth_motion.dart';

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final phone = Uri.encodeComponent(_phoneController.text.trim());
    context.go(
      '${RoutePaths.otpVerification}?phone=$phone&purpose=${OtpPurpose.passwordReset.wire}',
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.dsColors;

    return AuthStage(
      showBack: true,
      children: [
        const Spacer(),
        const AuthEmblem(icon: Icons.key_rounded)
            .animate()
            .fadeIn(duration: 500.ms)
            .scale(
              begin: const Offset(0.85, 0.85),
              duration: 800.ms,
              curve: DsMotion.softSpring,
            ),
        AuthHeading(
          eyebrow: l10n.resetPassword,
          title: l10n.forgetPassword,
          subtitle: l10n.authForgotSubtitle,
        ).authEnter(1),
        DsGaps.vXl,
        AuthPanel(
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                DsInputField(
                  controller: _phoneController,
                  label: l10n.phone,
                  // l10n-ignore: a dialling mask, not language
                  hint: '09XX XXX XXX',
                  keyboardType: TextInputType.phone,
                  autofillHints: const [AutofillHints.telephoneNumber],
                  prefixIcon: Icon(
                    Icons.phone_iphone_rounded,
                    color: colors.primary,
                  ),
                  validator: (value) =>
                      AuthFormValidators.requiredPhone(l10n, value),
                  onSubmitted: (_) => _submit(),
                ),
                DsGaps.vLg,
                PrimaryButton(
                  label: l10n.send,
                  icon: Icons.send_rounded,
                  onPressed: _submit,
                ),
              ],
            ),
          ),
        ).authEnter(2),
        const Spacer(flex: 2),
        DsGaps.vXl,
        AuthTrustNote(text: l10n.authTrustNote).authEnter(3),
        DsGaps.vLg,
      ],
    );
  }
}
