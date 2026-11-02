import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ohara/core/design_system/design_system.dart';
import 'package:ohara/core/localization/l10n_extension.dart';
import 'package:ohara/core/shared/entities/media.dart';
import 'package:ohara/core/shared/value_objects/money.dart';
import 'package:ohara/core/utils/relative_time.dart';
import 'package:ohara/features/seller_products/domain/entities/managed_product.dart';
import 'package:ohara/features/seller_store/domain/entities/seller_store.dart';
import 'package:ohara/features/seller_store/presentation/providers/seller_store_providers.dart';
import 'package:ohara/features/seller_store/presentation/widgets/store_form_parts.dart';

/// «عروضي» — her offers, as distinct from her products: the pieces she has
/// on sale, and the discount codes she gives her shoppers. The product list
/// itself is the «المنتجات» tab.
class MyOffersScreen extends ConsumerWidget {
  const MyOffersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final listings = ref.watch(saleCandidatesProvider);
    final coupons = ref.watch(sellerCouponsProvider);

    Future<void> refresh() async {
      ref
        ..invalidate(saleCandidatesProvider)
        ..invalidate(sellerCouponsProvider);
    }

    return StoreSettingsPage(
      icon: Icons.local_offer_rounded,
      title: l10n.myProducts,
      subtitle: l10n.myOffersSubtitle,
      onRefresh: refresh,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SectionHeader(
            title: l10n.offersSaleTitle,
            action: l10n.offersAddSale,
            onAction: () => _SaleSheet.pickAndShow(context),
          ),
          DsGaps.vSm,
          listings.when(
            loading: () => const StoreLoading(),
            error: (error, _) => DsErrorState(
              message: '$error',
              onRetry: () => ref.invalidate(saleCandidatesProvider),
            ),
            data: (items) {
              final onSale = items.where(isOnSale).toList();
              if (onSale.isEmpty) {
                return DsEmptyState(
                  icon: Icons.sell_outlined,
                  title: l10n.offersSaleEmpty,
                  message: l10n.offersSaleEmptyBody,
                );
              }
              return Column(
                children: [
                  for (final item in onSale) ...[
                    _SaleTile(listing: item),
                    DsGaps.vXs,
                  ],
                ],
              );
            },
          ),
          DsGaps.vXl,
          _SectionHeader(
            title: l10n.offersCodesTitle,
            action: l10n.offersNewCode,
            onAction: () => _NewCodeSheet.show(context),
          ),
          DsGaps.vSm,
          coupons.when(
            loading: () => const StoreLoading(),
            error: (error, _) => DsErrorState(
              message: '$error',
              onRetry: () => ref.invalidate(sellerCouponsProvider),
            ),
            data: (codes) => codes.isEmpty
                ? DsEmptyState(
                    icon: Icons.confirmation_number_outlined,
                    title: l10n.offersCodesEmpty,
                    message: l10n.offersCodesEmptyBody,
                  )
                : Column(
                    children: [
                      for (final code in codes) ...[
                        _CodeTile(coupon: code),
                        DsGaps.vXs,
                      ],
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

bool isOnSale(ManagedProduct listing) =>
    (listing.compareAtPrice?.approximateValue ?? 0) >
    listing.price.approximateValue;

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.action,
    required this.onAction,
  });

  final String title;
  final String action;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: AtelierHeading(title: title)),
        TextButton.icon(
          onPressed: onAction,
          icon: const Icon(Icons.add_rounded, size: 18),
          label: Text(action),
        ),
      ],
    );
  }
}

class _Thumb extends StatelessWidget {
  const _Thumb({required this.media});

  final List<MediaItem> media;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: DsRadius.borderMd,
    child: SizedBox.square(
      dimension: DsSizes.thumbMd,
      child: media.isEmpty
          ? const DsMediaFallback()
          : DsMediaFrame(item: media.first),
    ),
  );
}

class _SaleTile extends ConsumerWidget {
  const _SaleTile({required this.listing});

  final ManagedProduct listing;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final palette = context.atelier;
    final before = listing.compareAtPrice!;
    final percent =
        (100 * (1 - listing.price.approximateValue / before.approximateValue))
            .round();
    return SellerPanel(
      child: Row(
        children: [
          _Thumb(media: listing.media),
          DsGaps.hMd,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  listing.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.dsText.tileTitle.bold.tint(palette.ink),
                ),
                Row(
                  children: [
                    Text(
                      listing.price.format(),
                      style: context.dsText.body.bold.tint(palette.gold),
                    ),
                    DsGaps.hXs,
                    Flexible(
                      child: Text(
                        before.format(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.dsText.caption
                            .tint(palette.muted)
                            .copyWith(decoration: TextDecoration.lineThrough),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          DsBadge(label: '-$percent%', tone: DsBadgeTone.sale),
          PopupMenuButton<String>(
            tooltip: l10n.offersSaleRemove,
            onSelected: (_) => _endSale(context, ref),
            itemBuilder: (_) => [
              PopupMenuItem(value: 'end', child: Text(l10n.offersSaleRemove)),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _endSale(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    try {
      await storeCall(
        () => ref
            .read(sellerStoreApiProvider)
            .setSale(
              listing.id,
              price: listing.compareAtPrice!.raw,
              compareAt: null,
            ),
      );
      ref.invalidate(saleCandidatesProvider);
      if (context.mounted) DsSnackbar.success(context, l10n.offersSaleRemoved);
    } catch (error) {
      if (context.mounted) DsSnackbar.error(context, '$error');
    }
  }
}

/// Choosing a piece and a percentage, with the new price shown as she picks.
class _SaleSheet extends ConsumerStatefulWidget {
  const _SaleSheet({required this.listing});

  final ManagedProduct listing;

  static Future<void> pickAndShow(BuildContext context) async {
    final listing = await DsBottomSheet.show<ManagedProduct>(
      context,
      builder: (sheet) => DsSheetScaffold(
        title: context.l10n.offersPickPiece,
        scrollable: false,
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.6,
          child: const _PiecePicker(),
        ),
      ),
    );
    if (listing == null || !context.mounted) return;
    await DsBottomSheet.show<void>(
      context,
      builder: (_) => DsSheetScaffold(
        title: listing.title,
        child: _SaleSheet(listing: listing),
      ),
    );
  }

  @override
  ConsumerState<_SaleSheet> createState() => _SaleSheetState();
}

class _SaleSheetState extends ConsumerState<_SaleSheet> {
  static const _choices = [10, 15, 20, 25, 30, 40, 50];
  int _percent = 20;
  bool _saving = false;

  /// The price before any sale: the crossed-out one if already on sale.
  Money get _original => isOnSale(widget.listing)
      ? widget.listing.compareAtPrice!
      : widget.listing.price;

  String get _newRaw {
    final value = _original.approximateValue * (100 - _percent) / 100;
    final digits = _original.currency.fractionDigits;
    return digits == 0 ? value.round().toString() : value.toStringAsFixed(digits);
  }

  Future<void> _apply() async {
    setState(() => _saving = true);
    final l10n = context.l10n;
    try {
      await storeCall(
        () => ref
            .read(sellerStoreApiProvider)
            .setSale(
              widget.listing.id,
              price: _newRaw,
              compareAt: _original.raw,
            ),
      );
      if (!mounted) return;
      ref.invalidate(saleCandidatesProvider);
      Navigator.of(context).pop();
      DsSnackbar.success(context, l10n.offersSaleApplied);
    } catch (error) {
      if (mounted) DsSnackbar.error(context, '$error');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final palette = context.atelier;
    final after = Money(raw: _newRaw, currency: _original.currency);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l10n.offersSalePercent,
          style: context.dsText.labelStrong.tint(palette.ink),
        ),
        DsGaps.vXs,
        Wrap(
          spacing: DsSpacing.xs,
          runSpacing: DsSpacing.xs,
          children: [
            for (final percent in _choices)
              ChoiceChip(
                label: Text('$percent%'),
                selected: percent == _percent,
                onSelected: (_) => setState(() => _percent = percent),
              ),
          ],
        ),
        DsGaps.vMd,
        SellerPanel(
          child: Row(
            children: [
              Expanded(
                child: Text(
                  l10n.offersSaleNewPrice(after.format()),
                  style: context.dsText.body.bold.tint(palette.ink),
                ),
              ),
              Text(
                _original.format(),
                style: context.dsText.caption
                    .tint(palette.muted)
                    .copyWith(decoration: TextDecoration.lineThrough),
              ),
            ],
          ),
        ),
        DsGaps.vMd,
        DsButton(
          label: l10n.offersSaleApply,
          icon: Icons.sell_rounded,
          isLoading: _saving,
          onPressed: _saving ? null : _apply,
        ),
      ],
    );
  }
}

class _PiecePicker extends ConsumerWidget {
  const _PiecePicker();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.atelier;
    final listings = ref.watch(saleCandidatesProvider);
    return listings.when(
      loading: () => const StoreLoading(),
      error: (error, _) => DsErrorState(message: '$error'),
      data: (items) => ListView.separated(
        itemCount: items.length,
        separatorBuilder: (_, _) => DsGaps.vXs,
        itemBuilder: (context, index) {
          final item = items[index];
          return SellerPanel(
            onTap: () => Navigator.of(context).pop(item),
            child: Row(
              children: [
                _Thumb(media: item.media),
                DsGaps.hMd,
                Expanded(
                  child: Text(
                    item.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: context.dsText.body.tint(palette.ink),
                  ),
                ),
                Text(
                  item.price.format(),
                  style: context.dsText.body.bold.tint(palette.ink),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _CodeTile extends ConsumerWidget {
  const _CodeTile({required this.coupon});

  final SellerCoupon coupon;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final palette = context.atelier;
    final (status, tone) = coupon.isExpired || coupon.isUsedUp
        ? (l10n.offersCodeExpired, DsBadgeTone.neutral)
        : coupon.isActive
        ? (l10n.offersCodeLive, DsBadgeTone.success)
        : (l10n.offersCodeStopped, DsBadgeTone.warning);
    final usage = coupon.maxUses == null
        ? l10n.offersCodeUsed(coupon.usedCount)
        : l10n.offersCodeUsage(coupon.maxUses!, coupon.usedCount);
    return SellerPanel(
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: DsSpacing.sm,
              vertical: DsSpacing.xs,
            ),
            decoration: BoxDecoration(
              color: palette.gold.withValues(alpha: 0.12),
              borderRadius: DsRadius.borderMd,
            ),
            child: Text(
              '${coupon.percent}%',
              style: context.dsText.tileTitle.bold.tint(palette.gold),
            ),
          ),
          DsGaps.hMd,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                InkWell(
                  onTap: () async {
                    await Clipboard.setData(ClipboardData(text: coupon.code));
                    if (context.mounted) {
                      DsSnackbar.success(context, l10n.offersCodeCopied);
                    }
                  },
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        coupon.code,
                        style: context.dsText.tileTitle.bold
                            .tint(palette.ink)
                            .tabular,
                      ),
                      DsGaps.hXxs,
                      Icon(Icons.copy_rounded, size: 14, color: palette.muted),
                    ],
                  ),
                ),
                Text(
                  [
                    usage,
                    l10n.offersCodeExpires(
                      formatCalendarDate(l10n, coupon.expiresAt),
                    ),
                  ].join(' · '),
                  style: context.dsText.caption.tint(palette.muted),
                ),
              ],
            ),
          ),
          DsBadge(label: status, tone: tone),
          if (!coupon.isExpired && !coupon.isUsedUp)
            PopupMenuButton<bool>(
              onSelected: (active) => _toggle(context, ref, active),
              itemBuilder: (_) => [
                PopupMenuItem(
                  value: !coupon.isActive,
                  child: Text(
                    coupon.isActive ? l10n.offersCodeStop : l10n.offersCodeResume,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Future<void> _toggle(BuildContext context, WidgetRef ref, bool active) async {
    try {
      await storeCall(
        () => ref
            .read(sellerStoreApiProvider)
            .setCouponActive(coupon.id, active: active),
      );
      ref.invalidate(sellerCouponsProvider);
    } catch (error) {
      if (context.mounted) DsSnackbar.error(context, '$error');
    }
  }
}

class _NewCodeSheet extends ConsumerStatefulWidget {
  const _NewCodeSheet();

  static Future<void> show(BuildContext context) => DsBottomSheet.show<void>(
    context,
    builder: (_) => DsSheetScaffold(
      title: context.l10n.offersNewCode,
      child: const _NewCodeSheet(),
    ),
  );

  @override
  ConsumerState<_NewCodeSheet> createState() => _NewCodeSheetState();
}

class _NewCodeSheetState extends ConsumerState<_NewCodeSheet> {
  final _formKey = GlobalKey<FormState>();
  final _code = TextEditingController();
  final _percent = TextEditingController(text: '15');
  final _minOrder = TextEditingController();
  final _maxUses = TextEditingController();
  int _days = 14;
  bool _saving = false;

  @override
  void dispose() {
    _code.dispose();
    _percent.dispose();
    _minOrder.dispose();
    _maxUses.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    final l10n = context.l10n;
    try {
      await storeCall(
        () => ref.read(sellerStoreApiProvider).createCoupon({
          'code': _code.text.trim(),
          'discount_percent': int.parse(_percent.text.trim()),
          if (_minOrder.text.trim().isNotEmpty)
            'min_order_amount': num.parse(_minOrder.text.trim()),
          if (_maxUses.text.trim().isNotEmpty)
            'max_uses': int.parse(_maxUses.text.trim()),
          'expires_at': DateTime.now()
              .add(Duration(days: _days))
              .toUtc()
              .toIso8601String(),
        }),
      );
      if (!mounted) return;
      ref.invalidate(sellerCouponsProvider);
      Navigator.of(context).pop();
      DsSnackbar.success(context, l10n.offersCodeCreated);
    } catch (error) {
      if (mounted) DsSnackbar.error(context, '$error');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final palette = context.atelier;
    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DsInputField(
            controller: _code,
            label: l10n.offersCodeField,
            hint: l10n.offersCodeHint,
            prefixIcon: const Icon(Icons.confirmation_number_outlined),
            textCapitalization: TextCapitalization.characters,
            autocorrect: false,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp('[A-Za-z0-9]')),
              LengthLimitingTextInputFormatter(20),
            ],
            validator: (value) =>
                RegExp(r'^[A-Za-z0-9]{3,20}$').hasMatch(value ?? '')
                ? null
                : l10n.offersCodeInvalid,
          ),
          DsGaps.vMd,
          DsInputField(
            controller: _percent,
            label: l10n.offersCodePercent,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            validator: (value) {
              final percent = int.tryParse(value ?? '');
              return percent != null && percent >= 5 && percent <= 90
                  ? null
                  : l10n.offersCodePercentInvalid;
            },
          ),
          DsGaps.vMd,
          DsInputField(
            controller: _minOrder,
            label: l10n.offersCodeMinOrder,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          ),
          DsGaps.vMd,
          DsInputField(
            controller: _maxUses,
            label: l10n.offersCodeMaxUses,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          ),
          DsGaps.vMd,
          Text(
            l10n.offersCodeExpiry,
            style: context.dsText.labelStrong.tint(palette.ink),
          ),
          DsGaps.vXs,
          Wrap(
            spacing: DsSpacing.xs,
            children: [
              for (final days in const [3, 7, 14, 30, 60])
                ChoiceChip(
                  label: Text(l10n.offersCodeDays(days)),
                  selected: days == _days,
                  onSelected: (_) => setState(() => _days = days),
                ),
            ],
          ),
          DsGaps.vMd,
          Text(
            l10n.offersCodesEmptyBody,
            style: context.dsText.caption.tint(palette.muted),
          ),
          DsGaps.vMd,
          DsButton(
            label: l10n.offersCodeCreate,
            icon: Icons.check_rounded,
            isLoading: _saving,
            onPressed: _saving ? null : _create,
          ),
        ],
      ),
    );
  }
}
