import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design_system/design_system.dart';
import '../../../../core/localization/l10n_extension.dart';
import '../../../../core/router/route_paths.dart';
import '../../domain/entities/auth_account.dart';
import '../utils/auth_form_validators.dart';

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

    return ReemScrollPage(
      slivers: [
        PremiumAppBar(title: l10n.resetPassword, showBack: true),
        SliverFillRemaining(
          hasScrollBody: false,
          child: Padding(
            padding: DsSpacing.screenPadding,
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Spacer(),
                  Text(
                    l10n.forgetPassword,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: colors.onSurfaceVariant,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: DsSpacing.xxxl),
                  DsInputField(
                    controller: _phoneController,
                    label: context.l10n.phone,
                    keyboardType: TextInputType.phone,
                    prefixIcon: Icon(
                      Icons.phone_outlined,
                      color: colors.primary,
                    ),
                    validator: (value) =>
                        AuthFormValidators.requiredPhone(context.l10n, value),
                  ),
                  const SizedBox(height: DsSpacing.lg),
                  PrimaryButton(label: l10n.send, onPressed: _submit),
                  const Spacer(flex: 2),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
