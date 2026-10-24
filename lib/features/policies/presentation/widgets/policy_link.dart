import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:ohara/core/design_system/design_system.dart';
import 'package:ohara/core/router/route_paths.dart';

/// The slugs the app links to by name.
///
/// Constants rather than string literals at four call sites, because a link to
/// a policy is a link that either opens the document or 404s, and a typo in
/// `'returns'` is the kind of dead end nobody finds until a customer does. The
/// server's slugs are stable by design — they are what ends up in a support
/// reply — so naming them here is safe and a rename becomes one edit.
abstract final class PolicySlugs {
  // l10n-ignore: policy slugs the server matches on.
  static const customerTerms = 'customer-terms';
  // l10n-ignore: policy slug.
  static const sellerTerms = 'seller-terms';
  static const privacy = 'privacy';
  static const returns = 'returns';
  static const commissions = 'commissions';
  static const disputes = 'disputes';
  static const liability = 'liability';
  static const content = 'content';
}

/// A quiet inline link to one policy, for the screen where it actually
/// matters: returns at the till, content in the composer, commissions on the
/// earnings page, disputes on an order.
///
/// Small and low-contrast on purpose. These are not calls to action — the
/// screen has one of those already, and a policy link competing with «إتمام
/// الشراء» would be a worse screen, not a more transparent one. What matters is
/// that the answer is one tap from the question rather than three levels deep
/// in a settings menu.
class PolicyLink extends StatelessWidget {
  const PolicyLink({super.key, required this.label, required this.slug});

  final String label;

  /// One of [PolicySlugs].
  final String slug;

  @override
  Widget build(BuildContext context) {
    final colors = context.dsColors;
    return InkWell(
      onTap: () => context.push(RoutePaths.policyDetailOf(slug)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: DsSpacing.xxs),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.article_outlined, size: 13, color: colors.primary),
            const SizedBox(width: DsSpacing.xxs),
            Flexible(
              child: Text(
                label,
                style: context.dsText.caption
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

/// A sentence explaining what an action commits her to, with the documents
/// under it. The shape used at checkout, in the composer and on an order.
class PolicyNotice extends StatelessWidget {
  const PolicyNotice({
    super.key,
    required this.message,
    required this.links,
    this.alignment = CrossAxisAlignment.start,
  });

  final String message;
  final List<PolicyLink> links;
  final CrossAxisAlignment alignment;

  @override
  Widget build(BuildContext context) {
    final colors = context.dsColors;
    return Column(
      crossAxisAlignment: alignment,
      children: [
        Text(
          message,
          textAlign: alignment == CrossAxisAlignment.center
              ? TextAlign.center
              : TextAlign.start,
          style: context.dsText.caption
              .tint(colors.onSurfaceVariant)
              .copyWith(height: 1.5),
        ),
        const SizedBox(height: DsSpacing.xxs),
        Wrap(
          spacing: DsSpacing.md,
          runSpacing: DsSpacing.xxs,
          alignment: alignment == CrossAxisAlignment.center
              ? WrapAlignment.center
              : WrapAlignment.start,
          children: links,
        ),
      ],
    );
  }
}
