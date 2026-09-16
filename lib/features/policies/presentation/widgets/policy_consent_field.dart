import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:reem/core/design_system/design_system.dart';
import 'package:reem/core/router/route_paths.dart';
import 'package:reem/features/policies/domain/entities/policy_document.dart';
import 'package:reem/features/policies/presentation/providers/policies_provider.dart';

/// The consent block on a form that creates something — an account, a shop.
///
/// One checkbox, not four. A signup screen that demands a separate signature
/// per document is a screen nobody reads, so the documents are *named* and
/// *linked* above a single statement, and the server records one acceptance
/// row per document behind it. The record is per-document either way; only the
/// gesture is shared.
///
/// It reports the **version ids** rather than a boolean, because that is what
/// the server stores and what makes the record able to say, years later, which
/// text she was shown. A client that posted `accepted: true` would produce a
/// consent nobody can reconstruct.
///
/// **It revokes rather than grants.** The parent starts out satisfied, and
/// this field withdraws that the moment it knows there is something to sign.
/// The inversion matters: gating a submit button on a *grant* would make the
/// form permanently unsubmittable whenever the policy list failed to load or
/// simply had not arrived yet — a lost registration caused by a failed read.
/// This way a slow or broken read costs at most a few hundred milliseconds in
/// which she could submit unsigned, and the server is still the real gate: it
/// refuses a registration whose ids do not cover a required document, and an
/// account that did slip through meets the consent gate on its next launch.
class PolicyConsentField extends ConsumerStatefulWidget {
  const PolicyConsentField({
    super.key,
    required this.role,
    required this.accepted,
    required this.onChanged,
    required this.introText,
    required this.agreeText,
    this.enabled = true,
  });

  /// `buyer` or `seller` — the vocabulary the API takes.
  final String role;

  final bool accepted;

  /// `(accepted, versionIds)`. The ids are what the parent posts.
  final void Function(bool accepted, List<String> versionIds) onChanged;

  final String introText;
  final String agreeText;
  final bool enabled;

  @override
  ConsumerState<PolicyConsentField> createState() => _PolicyConsentFieldState();
}

class _PolicyConsentFieldState extends ConsumerState<PolicyConsentField> {
  /// The role we have already revoked for. Keyed rather than a bare flag
  /// because the registration form switches between buying and selling, and
  /// the two sign different documents — the shopper's tick must not carry over
  /// into a seller registration.
  String? _revokedFor;

  /// Tell the parent it is not satisfied after all: there *are* documents.
  ///
  /// Once per role, so a later tick is not immediately undone by the next
  /// rebuild. After the frame, because this is decided during build and
  /// calling into a parent's `setState` from inside its own build is how a
  /// screen that worked with a warm provider crashes with a cold one.
  void _requireSignature() {
    if (_revokedFor == widget.role) return;
    _revokedFor = widget.role;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onChanged(false, const []);
    });
  }

  @override
  Widget build(BuildContext context) {
    final locale = policyLocaleOf(context);
    final colors = context.dsColors;
    final required = ref.watch(
      requiredPoliciesProvider((role: widget.role, locale: locale)),
    );

    return required.when(
      // Nothing while it loads — deliberately not a spinner. A spinner is an
      // endless animation, so a form carrying one never settles, and the whole
      // journey it sits in becomes untestable with `pumpAndSettle`. There is
      // nothing to wait for here anyway: the parent is satisfied until this
      // field says otherwise.
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (policies) {
        if (policies.isEmpty) return const SizedBox.shrink();
        _requireSignature();

        final ids = policies
            .map((policy) => policy.versionId)
            .toList(growable: false);

        return Container(
          padding: const EdgeInsets.all(DsSpacing.md),
          decoration: BoxDecoration(
            color: colors.surfaceVariant,
            borderRadius: BorderRadius.circular(DsRadius.md),
            border: Border.all(color: colors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.introText,
                style: context.dsText.bodySmall.tint(colors.onSurfaceVariant),
              ),
              const SizedBox(height: DsSpacing.xs),
              for (final policy in policies)
                _PolicyLink(policy: policy, enabled: widget.enabled),
              const SizedBox(height: DsSpacing.xs),
              CheckboxListTile(
                value: widget.accepted,
                onChanged: widget.enabled
                    ? (value) => widget.onChanged(value ?? false, ids)
                    : null,
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
                dense: true,
                activeColor: colors.primary,
                title: Text(widget.agreeText, style: context.dsText.bodySmall),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _PolicyLink extends StatelessWidget {
  const _PolicyLink({required this.policy, required this.enabled});

  final PolicySummary policy;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final colors = context.dsColors;
    return InkWell(
      onTap: enabled
          ? () => context.push(RoutePaths.policyDetailOf(policy.slug))
          : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: DsSpacing.xxs),
        child: Row(
          children: [
            Icon(Icons.article_outlined, size: 15, color: colors.primary),
            const SizedBox(width: DsSpacing.xs),
            Expanded(
              child: Text(
                policy.title,
                style: context.dsText.bodySmall
                    .tint(colors.primary)
                    .copyWith(
                      decoration: TextDecoration.underline,
                      decorationColor: colors.primary,
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
