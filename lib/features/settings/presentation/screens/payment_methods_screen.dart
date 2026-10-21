import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:reem/core/design_system/design_system.dart';
import 'package:reem/core/router/route_paths.dart';
import 'package:reem/features/checkout/domain/entities/checkout.dart';
import 'package:reem/features/settings/presentation/providers/payment_options_provider.dart';
import 'package:reem/features/wallet/presentation/providers/wallet_provider.dart';

/// How she can pay.
///
/// This screen used to render three invented cards and an «Add payment method»
/// button wired to `() {}`. It was wrong twice over: there was nothing behind
/// it, and it promised a saved-card wallet on a platform whose nine payment
/// rails are cash on delivery, the mobile-money operators, a bank transfer, a
/// hawala and the platform's own balance. Card processing is not something a
/// Syrian merchant can offer, so a card manager is not a missing feature here
/// — it is the wrong screen.
///
/// What she actually needs to know before checkout is which rails are open and
/// what her balance is, so that is what this shows, read from the same
/// endpoint checkout prices against.
class PaymentMethodsScreen extends ConsumerWidget {
  const PaymentMethodsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final options = ref.watch(paymentOptionsProvider);
    final wallet = ref.watch(walletNotifierProvider);
    final colors = context.dsColors;

    return ReemScrollPage(
      slivers: [
        const PremiumAppBar(title: 'طرق الدفع', showBack: true),
        SliverPadding(
          padding: const EdgeInsets.all(DsSpacing.lg),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              const ReemSectionHeader(
                title: 'الدفع عند الطلب',
                subtitle: 'تختارين الطريقة عند إتمام الشراء',
              ),
              const SizedBox(height: DsSpacing.lg),

              // Her balance first: it is the one method whose availability
              // depends on a number, and the number is hers.
              _WalletTile(
                balance: wallet.summary?.balance.format(),
                isLoading: wallet.isLoading && wallet.summary == null,
                onTap: () => context.push(RoutePaths.wallet),
              ),
              const SizedBox(height: DsSpacing.lg),

              Text(
                'الطرق المتاحة',
                style: context.dsText.tileTitle.bold.tint(colors.onSurface),
              ),
              const SizedBox(height: DsSpacing.md),

              options.when(
                loading: () => const _OptionsSkeleton(),
                error: (_, _) => _OptionsFailed(
                  onRetry: () => ref.invalidate(paymentOptionsProvider),
                ),
                data: (list) {
                  if (list.isEmpty) return const _NoOptions();
                  return Column(
                    children: [
                      for (final option in list)
                        Padding(
                          padding: const EdgeInsets.only(bottom: DsSpacing.md),
                          child: _MethodTile(option: option),
                        ),
                    ],
                  );
                },
              ),

              const SizedBox(height: DsSpacing.sm),
              _Note(
                text:
                    'لا نحفظ بيانات بطاقات. تُدفع كل عملية عند إتمامها بالطريقة التي تختارينها.',
              ),
            ]),
          ),
        ),
      ],
    );
  }
}

class _WalletTile extends StatelessWidget {
  const _WalletTile({
    required this.balance,
    required this.isLoading,
    required this.onTap,
  });

  final String? balance;
  final bool isLoading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.dsColors;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(DsSpacing.lg),
        decoration: BoxDecoration(
          borderRadius: DsRadius.borderXxl,
          gradient: context.primaryGradient,
          boxShadow: context.luxuryShadow,
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(DsSpacing.sm),
              decoration: BoxDecoration(
                color: colors.onPrimary.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.account_balance_wallet_rounded,
                color: colors.onPrimary,
              ),
            ),
            const SizedBox(width: DsSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'محفظة أوهارا',
                    style: context.dsText.tileTitle.bold.tint(colors.onPrimary),
                  ),
                  DsGaps.vXxs,
                  if (isLoading)
                    SizedBox(
                      height: 14,
                      width: 90,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: colors.onPrimary.withValues(alpha: 0.25),
                          borderRadius: DsRadius.borderFull,
                        ),
                      ),
                    )
                  else
                    Text(
                      balance ?? '—',
                      style: context.dsText.sectionTitle.tint(colors.onPrimary.withValues(alpha: 0.92)),
                    ),
                ],
              ),
            ),
            Icon(Icons.chevron_left_rounded, color: colors.onPrimary),
          ],
        ),
      ),
    );
  }
}

class _MethodTile extends StatelessWidget {
  const _MethodTile({required this.option});

  final PaymentMethodOption option;

  /// The rails are distinct enough that one generic icon would lose the thing
  /// that tells them apart at a glance.
  IconData get _icon => switch (option.method) {
    'cod' || 'courier_collect' => Icons.local_shipping_outlined,
    'syriatel_cash' || 'mtn_cash' => Icons.smartphone_rounded,
    'sham_cash' => Icons.account_balance_wallet_outlined,
    'bank_transfer' => Icons.account_balance_outlined,
    'bank_card' => Icons.credit_card_rounded,
    'hawala' => Icons.swap_horiz_rounded,
    'platform_wallet' => Icons.savings_outlined,
    _ => Icons.payments_outlined,
  };

  /// What actually happens after she picks this at checkout.
  ///
  /// «يُؤكَّد الدفع قبل تجهيز الطلب» was the same sentence for a card, a bank
  /// transfer and a hawala — three rails that ask three different things of
  /// her. Each one now says what it will ask.
  String? get _hint => switch (option.method) {
    'cod' => 'تدفعين نقداً للمندوبة عند الاستلام',
    'courier_collect' => 'تحصيل عبر شركة التوصيل',
    'platform_wallet' => 'يُخصم من رصيدكِ فوراً',
    'syriatel_cash' ||
    'mtn_cash' ||
    'sham_cash' => 'نفتح لكِ صفحة الدفع بعد تأكيد الطلب',
    'bank_card' => 'صفحة دفع آمنة — لا نحفظ بيانات بطاقتك',
    'bank_transfer' => 'تحوّلين المبلغ ثم ترسلين رقم الحوالة من صفحة الطلب',
    'hawala' => 'حوالة داخلية، ثم ترسلين رقم الإشعار من صفحة الطلب',
    _ =>
      option.requiresOnlineConfirmation
          ? 'يُؤكَّد الدفع قبل تجهيز الطلب'
          : null,
  };

  @override
  Widget build(BuildContext context) {
    final colors = context.dsColors;
    final hint = _hint;

    return Container(
      padding: const EdgeInsets.all(DsSpacing.lg),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: DsRadius.borderXxl,
        border: Border.all(color: colors.border),
        boxShadow: context.softShadow,
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: colors.primary.withValues(alpha: 0.12),
            ),
            child: Icon(_icon, color: colors.primary, size: 22),
          ),
          const SizedBox(width: DsSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  option.label,
                  style: context.dsText.body.semibold.tint(colors.onSurface),
                ),
                if (hint != null) ...[
                  DsGaps.vXxs,
                  Text(
                    hint,
                    style: context.dsText.caption.tint(colors.onSurfaceVariant),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Note extends StatelessWidget {
  const _Note({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = context.dsColors;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          Icons.lock_outline_rounded,
          size: 16,
          color: colors.onSurfaceVariant,
        ),
        const SizedBox(width: DsSpacing.sm),
        Expanded(
          child: Text(
            text,
            style: context.dsText.caption.tint(colors.onSurfaceVariant).copyWith(height: 1.5),
          ),
        ),
      ],
    );
  }
}

class _NoOptions extends StatelessWidget {
  const _NoOptions();

  @override
  Widget build(BuildContext context) {
    final colors = context.dsColors;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: DsSpacing.xl),
      child: Text(
        'لا طرق دفع متاحة حالياً',
        textAlign: TextAlign.center,
        style: context.dsText.body.tint(colors.onSurfaceVariant),
      ),
    );
  }
}

class _OptionsFailed extends StatelessWidget {
  const _OptionsFailed({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final colors = context.dsColors;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: DsSpacing.xl),
      child: Column(
        children: [
          Text(
            'تعذّر تحميل طرق الدفع',
            style: context.dsText.body.tint(colors.onSurfaceVariant),
          ),
          const SizedBox(height: DsSpacing.md),
          SecondaryButton(label: 'إعادة المحاولة', onPressed: onRetry),
        ],
      ),
    );
  }
}

class _OptionsSkeleton extends StatelessWidget {
  const _OptionsSkeleton();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < 4; i++) ...[
          const DsShimmer(child: DsSkeleton.box(height: 78)),
          const SizedBox(height: DsSpacing.md),
        ],
      ],
    );
  }
}
