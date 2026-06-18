import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design_system/design_system.dart';
import '../../../../core/design_system/components/snackbars/app_snackbar.dart'
    show DsSnackbar, DsSnackbarType;
import '../../../../core/router/route_paths.dart';
import '../../../../core/shared/wedgets/app/premium_app_bar.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../cart/presentation/providers/cart_providers.dart';
import '../../domain/entities/checkout.dart';
import '../providers/checkout_providers.dart';

class CheckoutScreen extends ConsumerStatefulWidget {
  const CheckoutScreen({super.key});

  @override
  ConsumerState<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends ConsumerState<CheckoutScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _city = TextEditingController();
  final _address = TextEditingController();
  final _landmark = TextEditingController();
  final _instructions = TextEditingController();
  final _coupon = TextEditingController();

  String? _governorate;
  String? _paymentMethod;
  bool _seeded = false;

  @override
  void dispose() {
    for (final c in [
      _name,
      _phone,
      _city,
      _address,
      _landmark,
      _instructions,
      _coupon,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  double get _subtotal =>
      ref.read(cartNotifierProvider).cart.summary.subtotal;

  Future<void> _place() async {
    if (!_formKey.currentState!.validate()) return;
    if (_governorate == null) {
      DsSnackbar.show(context,
          message: 'Select a governorate', type: DsSnackbarType.error);
      return;
    }
    if (_paymentMethod == null) {
      DsSnackbar.show(context,
          message: 'Select a payment method', type: DsSnackbarType.error);
      return;
    }

    final placed = await ref.read(checkoutControllerProvider.notifier).place(
          shipping: ShippingInput(
            recipientName: _name.text.trim(),
            recipientPhone: _phone.text.trim(),
            governorate: _governorate!,
            city: _city.text.trim(),
            addressLine: _address.text.trim(),
            landmark: _landmark.text.trim().isEmpty ? null : _landmark.text.trim(),
          ),
          paymentMethod: _paymentMethod!,
          couponCode: _coupon.text.trim().isEmpty ? null : _coupon.text.trim(),
          deliveryInstructions:
              _instructions.text.trim().isEmpty ? null : _instructions.text.trim(),
        );

    if (!mounted) return;
    if (placed != null) {
      await ref.read(cartNotifierProvider.notifier).refresh();
      if (!mounted) return;
      DsSnackbar.show(context,
          message: 'Order ${placed.order.number} placed!',
          type: DsSnackbarType.success);
      context.pushReplacement(RoutePaths.orderDetailOf(placed.order.id));
    } else {
      final error = ref.read(checkoutControllerProvider).error;
      if (error != null) {
        DsSnackbar.show(context, message: error, type: DsSnackbarType.error);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.dsColors;
    final state = ref.watch(checkoutControllerProvider);
    final controller = ref.read(checkoutControllerProvider.notifier);
    final cart = ref.watch(cartNotifierProvider).cart;

    // Prefill from the signed-in user once.
    if (!_seeded) {
      final user = ref.read(authNotifierProvider).user;
      if (user != null) {
        _name.text = user.name;
        _phone.text = user.phone;
        _seeded = true;
      }
    }

    final deliveryFee = state.quote?.deliveryFee ?? 0;
    final total = cart.summary.subtotal + deliveryFee;

    return ReemScrollPage(
      bottom: _BottomBar(
        total: total,
        isPlacing: state.isPlacing,
        onPlace: _place,
      ),
      slivers: [
        const PremiumAppBar(title: 'Checkout', showBack: true),
        if (state.isLoadingOptions)
          const SliverFillRemaining(
            hasScrollBody: false,
            child: Center(child: CircularProgressIndicator()),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              DsSpacing.lg,
              DsSpacing.md,
              DsSpacing.lg,
              140,
            ),
            sliver: SliverToBoxAdapter(
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _label(context, 'Delivery details'),
                    DsInputField(
                      controller: _name,
                      label: 'Full name',
                      validator: _required,
                    ),
                    DsInputField(
                      controller: _phone,
                      label: 'Phone number',
                      keyboardType: TextInputType.phone,
                      validator: (v) {
                        final value = v?.trim() ?? '';
                        if (!RegExp(r'^\+?[0-9]{7,15}$').hasMatch(value)) {
                          return 'Enter a valid phone number';
                        }
                        return null;
                      },
                    ),
                    DropdownButtonFormField<String>(
                      value: _governorate,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'Governorate'),
                      items: [
                        for (final g in state.governorates)
                          DropdownMenuItem(
                            value: g.name,
                            child: Text('${g.name}  ·  \$${g.fee.toStringAsFixed(0)}'),
                          ),
                      ],
                      onChanged: (value) {
                        setState(() => _governorate = value);
                        if (value != null) {
                          controller.selectGovernorate(value, _subtotal);
                        }
                      },
                    ),
                    const SizedBox(height: DsSpacing.md),
                    DsInputField(
                      controller: _city,
                      label: 'City',
                      validator: _required,
                    ),
                    DsInputField(
                      controller: _address,
                      label: 'Detailed address',
                      maxLines: 2,
                      validator: _required,
                    ),
                    DsInputField(
                      controller: _landmark,
                      label: 'Nearby landmark (optional)',
                    ),
                    DsInputField(
                      controller: _instructions,
                      label: 'Delivery instructions (optional)',
                      hint: 'e.g. Call before delivery',
                    ),
                    const SizedBox(height: DsSpacing.sm),
                    _label(context, 'Coupon'),
                    DsInputField(
                      controller: _coupon,
                      label: 'Coupon code (optional)',
                    ),
                    const SizedBox(height: DsSpacing.sm),
                    _label(context, 'Payment method'),
                    for (final method in state.paymentMethods)
                      _PaymentTile(
                        option: method,
                        selected: _paymentMethod == method.method,
                        onTap: () =>
                            setState(() => _paymentMethod = method.method),
                      ),
                    const SizedBox(height: DsSpacing.lg),
                    _label(context, 'Order summary'),
                    _summaryRow(context, 'Subtotal', cart.summary.subtotal),
                    _summaryRow(context, 'Delivery', deliveryFee),
                    const Divider(),
                    _summaryRow(context, 'Total', total, emphasize: true),
                    if (state.quote != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          'Estimated in ~${state.quote!.estimatedDays} day(s)',
                          style: TextStyle(
                            fontSize: DsTypography.bodySmall,
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  String? _required(String? v) =>
      (v == null || v.trim().isEmpty) ? 'Required' : null;

  Widget _label(BuildContext context, String text) => Padding(
        padding: const EdgeInsets.only(
          top: DsSpacing.sm,
          bottom: DsSpacing.xs,
        ),
        child: Text(
          text,
          style: TextStyle(
            fontFamily: DsTypography.fontFamily,
            fontWeight: DsTypography.bold,
            fontSize: DsTypography.titleSmall,
            color: context.dsColors.onSurface,
          ),
        ),
      );

  Widget _summaryRow(BuildContext context, String label, double value,
      {bool emphasize = false}) {
    final colors = context.dsColors;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(
                  color: emphasize ? colors.onSurface : colors.onSurfaceVariant,
                  fontWeight:
                      emphasize ? DsTypography.bold : DsTypography.regular)),
          Text('\$${value.toStringAsFixed(2)}',
              style: TextStyle(
                  fontFamily: DsTypography.fontFamily,
                  fontWeight: emphasize ? DsTypography.bold : DsTypography.medium,
                  color: emphasize ? colors.primary : colors.onSurface)),
        ],
      ),
    );
  }
}

class _PaymentTile extends StatelessWidget {
  const _PaymentTile({
    required this.option,
    required this.selected,
    required this.onTap,
  });

  final PaymentMethodOption option;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.dsColors;
    final icon = switch (option.method) {
      'visa' => Icons.credit_card,
      'sham_cash' => Icons.account_balance_wallet_outlined,
      'bemo' => Icons.account_balance_outlined,
      _ => Icons.payments_outlined,
    };
    return InkWell(
      borderRadius: BorderRadius.circular(DsRadius.lg),
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: DsSpacing.sm),
        padding: const EdgeInsets.all(DsSpacing.md),
        decoration: BoxDecoration(
          color: selected
              ? colors.primary.withValues(alpha: 0.1)
              : colors.surfaceVariant,
          borderRadius: BorderRadius.circular(DsRadius.lg),
          border: Border.all(
            color: selected ? colors.primary : colors.border,
            width: selected ? 1.6 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: selected ? colors.primary : colors.onSurfaceVariant),
            const SizedBox(width: DsSpacing.md),
            Expanded(
              child: Text(
                option.label,
                style: TextStyle(
                  fontFamily: DsTypography.fontFamily,
                  fontWeight: DsTypography.semiBold,
                  color: colors.onSurface,
                ),
              ),
            ),
            Icon(
              selected ? Icons.radio_button_checked : Icons.radio_button_off,
              color: selected ? colors.primary : colors.onSurfaceVariant,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({
    required this.total,
    required this.isPlacing,
    required this.onPlace,
  });

  final double total;
  final bool isPlacing;
  final VoidCallback onPlace;

  @override
  Widget build(BuildContext context) {
    final colors = context.dsColors;
    return Container(
      padding: EdgeInsets.fromLTRB(
        DsSpacing.lg,
        DsSpacing.md,
        DsSpacing.lg,
        DsSpacing.md + MediaQuery.of(context).padding.bottom,
      ),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(top: BorderSide(color: colors.border)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Total',
                    style: TextStyle(
                        fontSize: DsTypography.bodySmall,
                        color: colors.onSurfaceVariant)),
                Text('\$${total.toStringAsFixed(2)}',
                    style: TextStyle(
                        fontFamily: DsTypography.fontFamily,
                        fontSize: DsTypography.titleMedium,
                        fontWeight: DsTypography.bold,
                        color: colors.onSurface)),
              ],
            ),
          ),
          SizedBox(
            width: 180,
            child: PrimaryButton(
              label: 'Place order',
              isLoading: isPlacing,
              onPressed: isPlacing ? null : onPlace,
            ),
          ),
        ],
      ),
    );
  }
}
