import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:ohara/core/design_system/design_system.dart';
import 'package:ohara/core/localization/l10n_extension.dart';
import 'package:ohara/core/router/route_paths.dart';
import 'package:ohara/features/checkout/presentation/order_labels.dart';
import 'package:ohara/features/store_ads/domain/entities/store_ads.dart';
import 'package:ohara/features/store_ads/presentation/providers/store_ads_providers.dart';
import 'package:ohara/features/store_ads/presentation/widgets/ad_payment_widgets.dart';
import 'package:ohara/features/store_ads/presentation/widgets/store_ads_labels.dart';

/// «ادفعي باقتكِ» — the transfer, step by step.
///
/// Where to send the money and exactly how much, copyable; the box for the
/// transaction number her wallet, bank or exchange office gave her; and then
/// where it stands. It always shows her one open payment, so it is the same
/// page whether she arrives from the plans, the banner or a notification.
class AdPlanPaymentScreen extends ConsumerStatefulWidget {
  const AdPlanPaymentScreen({super.key});

  @override
  ConsumerState<AdPlanPaymentScreen> createState() =>
      _AdPlanPaymentScreenState();
}

class _AdPlanPaymentScreenState extends ConsumerState<AdPlanPaymentScreen> {
  final _reference = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _reference.dispose();
    super.dispose();
  }

  Future<void> _send(AdPlanPurchase purchase) async {
    final l10n = context.l10n;
    final reference = _reference.text.trim();
    if (reference.length < 3) {
      DsSnackbar.show(
        context,
        message: l10n.adsErrorReferenceRequired,
        type: DsSnackbarType.error,
      );
      return;
    }
    setState(() => _busy = true);
    final failure = await ref
        .read(storeAdsActionsProvider)
        .submitReference(purchase.id, reference);
    if (!mounted) return;
    setState(() => _busy = false);
    if (failure == null) _reference.clear();
    DsSnackbar.show(
      context,
      message: failure == null
          ? l10n.adsPaymentSent
          : adFailureMessage(l10n, failure),
      type: failure == null ? DsSnackbarType.success : DsSnackbarType.error,
    );
  }

  Future<void> _cancel(AdPlanPurchase purchase) async {
    final l10n = context.l10n;
    setState(() => _busy = true);
    final failure = await ref
        .read(storeAdsActionsProvider)
        .cancelPurchase(purchase.id);
    if (!mounted) return;
    setState(() => _busy = false);
    if (failure != null) {
      DsSnackbar.show(
        context,
        message: adFailureMessage(l10n, failure),
        type: DsSnackbarType.error,
      );
      return;
    }
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final view = ref.watch(adPlansProvider);
    final purchase = view.value?.pendingPurchase;
    final gutter = atelierGutter(context);

    return OharaScrollPage(
      onRefresh: () async => ref.invalidate(adPlansProvider),
      background: const SellerAtelierBackground(),
      backgroundColor: context.atelier.background,
      slivers: [
        AtelierAppBar(
          icon: Icons.payments_rounded,
          title: l10n.adsPaymentTitle,
          showBack: true,
        ),
        DsGaps.sliverMd,
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: gutter),
            child: view.isLoading && purchase == null
                ? const DsShimmer(
                    child: DsSkeleton.box(
                      height: 260,
                      borderRadius: DsRadius.xl,
                    ),
                  )
                : purchase == null || !purchase.status.isOpen
                ? _Settled(onDone: () => context.go(RoutePaths.sellerAds))
                : _PaymentBody(
                    purchase: purchase,
                    reference: _reference,
                    busy: _busy,
                    onSend: () => _send(purchase),
                    onCancel: () => _cancel(purchase),
                  ),
          ),
        ),
        DsGaps.sliverBottomSafe,
      ],
    );
  }
}

class _PaymentBody extends StatelessWidget {
  const _PaymentBody({
    required this.purchase,
    required this.reference,
    required this.busy,
    required this.onSend,
    required this.onCancel,
  });

  final AdPlanPurchase purchase;
  final TextEditingController reference;
  final bool busy;
  final VoidCallback onSend;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final palette = context.atelier;
    final text = context.dsText;
    final jewel = purchase.tier.jewel;
    final method = l10n.paymentMethodName(purchase.method);
    final reviewing = purchase.status == AdPurchaseStatus.awaitingReview;
    final rejected = purchase.status == AdPurchaseStatus.rejected;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // What she is paying for.
        Container(
          padding: DsSpacing.cardPaddingLg,
          decoration: BoxDecoration(
            gradient: jewel?.gradient,
            borderRadius: DsRadius.borderXl,
          ),
          child: Row(
            children: [
              Icon(
                jewel?.icon ?? Icons.star_rounded,
                size: DsSizes.iconLg,
                color: jewel?.ink,
              ),
              DsGaps.hMd,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.adsPaymentPlan(purchase.tier.label(l10n)),
                      style: text.cardTitle.tint(jewel?.ink ?? palette.ink),
                    ),
                    Text(
                      formatSyp(purchase.amount),
                      style: text.metric.tint(jewel?.ink ?? palette.ink),
                    ),
                  ],
                ),
              ),
              Icon(adPaymentIcon(purchase.method), color: jewel?.ink),
            ],
          ),
        ),
        DsGaps.vLg,

        if (reviewing)
          _StatusCard(
            tone: DsTone.info,
            icon: Icons.hourglass_top_rounded,
            title: l10n.adsPaymentReviewTitle,
            body: l10n.adsPaymentReviewBody(purchase.reference ?? ''),
          ),
        if (rejected)
          _StatusCard(
            tone: DsTone.critical,
            icon: Icons.error_outline_rounded,
            title: l10n.adsPaymentRejectedTitle,
            body: purchase.rejectionReason ?? '',
          ),
        if (reviewing || rejected) DsGaps.vLg,

        // Step one: send the money.
        _Step(
          number: 1,
          title: l10n.adsPaymentStepSend(formatSyp(purchase.amount), method),
          child: Container(
            padding: DsSpacing.cardPadding,
            decoration: BoxDecoration(
              color: palette.raised,
              borderRadius: DsRadius.borderLg,
              border: Border.all(color: palette.line),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: SelectableText(
                    purchase.instructions ?? l10n.adsPayNoMethods,
                    style: text.bodyStrong.tint(palette.ink),
                  ),
                ),
                if (purchase.instructions != null)
                  DsIconButton(
                    icon: Icons.copy_rounded,
                    tooltip: l10n.adsPaymentCopy,
                    onPressed: () {
                      Clipboard.setData(
                        ClipboardData(text: purchase.instructions!),
                      );
                      DsSnackbar.show(
                        context,
                        message: l10n.adsPaymentCopied,
                        type: DsSnackbarType.success,
                      );
                    },
                  ),
              ],
            ),
          ),
        ),
        DsGaps.vLg,

        // Step two: the transaction number.
        _Step(
          number: 2,
          title: reviewing
              ? l10n.adsPaymentStepChange
              : l10n.adsPaymentStepReference,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DsInputField(
                controller: reference,
                label: l10n.adsPaymentReferenceField,
              ),
              DsGaps.vMd,
              DsButton(
                label: l10n.adsPaymentSend,
                icon: Icons.send_rounded,
                isLoading: busy,
                onPressed: busy ? null : onSend,
              ),
            ],
          ),
        ),
        DsGaps.vLg,
        Text(
          l10n.adsPaymentHowLong,
          style: text.caption.tint(palette.muted),
          textAlign: TextAlign.center,
        ),
        DsGaps.vMd,
        DsButton(
          label: l10n.adsPaymentCancel,
          variant: DsButtonVariant.ghost,
          onPressed: busy ? null : onCancel,
        ),
      ],
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({required this.number, required this.title, required this.child});

  final int number;
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final palette = context.atelier;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Container(
              width: DsSizes.iconLg,
              height: DsSizes.iconLg,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: palette.primary,
                shape: BoxShape.circle,
              ),
              child: Text(
                '$number',
                style: context.dsText.labelStrong.tint(palette.onPrimary),
              ),
            ),
            DsGaps.hSm,
            Expanded(
              child: Text(
                title,
                style: context.dsText.bodyStrong.tint(palette.ink),
              ),
            ),
          ],
        ),
        DsGaps.vSm,
        child,
      ],
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({
    required this.tone,
    required this.icon,
    required this.title,
    required this.body,
  });

  final DsTone tone;
  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final color = context.toneColor(tone);
    return Container(
      padding: DsSpacing.cardPaddingLg,
      decoration: BoxDecoration(
        color: context.toneContainer(tone),
        borderRadius: DsRadius.borderLg,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color),
          DsGaps.hSm,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: context.dsText.bodyStrong.tint(color)),
                if (body.isNotEmpty) ...[
                  DsGaps.vXxs,
                  Text(body, style: context.dsText.bodySmall.tint(color)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Settled extends StatelessWidget {
  const _Settled({required this.onDone});

  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return DsEmptyState(
      icon: Icons.check_circle_outline_rounded,
      title: l10n.adsPaymentNothingOpen,
      actionLabel: l10n.adsCenterTitle,
      onAction: onDone,
    );
  }
}
