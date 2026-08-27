import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design_system/design_system.dart';
import '../../../checkout/domain/entities/checkout.dart';
import '../../domain/entities/address_draft.dart';
import '../../domain/entities/address_entity.dart';
import '../providers/address_book_provider.dart';

/// Adding an address, or correcting one.
///
/// The governorate is a picker rather than a text field, and that is not
/// tidiness: the platform prices a delivery from the governorate and refuses
/// the ones it has no courier for, so a typed «حلب » with a trailing space is
/// an address that quotes nothing and can be assigned to nobody. Districts
/// come from the same list and carry the rural flag, so choosing a village
/// sets the tier Q53 prices it at instead of asking her what a tier is.
Future<AddressDraft?> showAddressFormSheet(
  BuildContext context, {
  AddressEntity? existing,
}) {
  return showModalBottomSheet<AddressDraft>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _AddressFormSheet(existing: existing),
  );
}

class _AddressFormSheet extends ConsumerStatefulWidget {
  const _AddressFormSheet({this.existing});

  final AddressEntity? existing;

  @override
  ConsumerState<_AddressFormSheet> createState() => _AddressFormSheetState();
}

class _AddressFormSheetState extends ConsumerState<_AddressFormSheet> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _label;
  late final TextEditingController _recipientName;
  late final TextEditingController _recipientPhone;
  late final TextEditingController _city;
  late final TextEditingController _addressLine;
  late final TextEditingController _landmark;
  late final TextEditingController _instructions;

  String? _governorate;
  String? _district;
  late bool _isRural;
  late bool _isDefault;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _label = TextEditingController(text: existing?.label ?? 'المنزل');
    _recipientName = TextEditingController(text: existing?.recipientName ?? '');
    _recipientPhone = TextEditingController(
      text: existing?.recipientPhone ?? '',
    );
    _city = TextEditingController(text: existing?.city ?? '');
    _addressLine = TextEditingController(text: existing?.addressLine ?? '');
    _landmark = TextEditingController(text: existing?.landmark ?? '');
    _instructions = TextEditingController(
      text: existing?.deliveryInstructions ?? '',
    );
    _governorate = existing?.governorate;
    _district = existing?.district;
    _isRural = existing?.isRural ?? false;
    // Her first address becomes the default on the server whether she asks or
    // not, so pre-ticking it here would be a checkbox that does nothing.
    _isDefault = existing?.isDefault ?? false;
  }

  @override
  void dispose() {
    _label.dispose();
    _recipientName.dispose();
    _recipientPhone.dispose();
    _city.dispose();
    _addressLine.dispose();
    _landmark.dispose();
    _instructions.dispose();
    super.dispose();
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_governorate == null) return;

    Navigator.of(context).pop(
      AddressDraft(
        label: _label.text,
        recipientName: _recipientName.text,
        recipientPhone: _recipientPhone.text,
        governorate: _governorate!,
        district: _district,
        city: _city.text,
        addressLine: _addressLine.text,
        landmark: _landmark.text,
        isRural: _isRural,
        deliveryInstructions: _instructions.text,
        isDefault: _isDefault,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.dsColors;
    final governorates = ref.watch(deliveryGovernoratesProvider);
    final isEditing = widget.existing != null;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.92,
        ),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(DsRadius.xxxl),
          ),
        ),
        child: SafeArea(
          top: false,
          child: Form(
            key: _formKey,
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.all(DsSpacing.lg),
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 4,
                    decoration: BoxDecoration(
                      color: colors.border,
                      borderRadius: DsRadius.borderFull,
                    ),
                  ),
                ),
                const SizedBox(height: DsSpacing.lg),
                Text(
                  isEditing ? 'تعديل العنوان' : 'عنوان جديد',
                  style: TextStyle(
                    fontSize: DsTypography.titleLarge,
                    fontWeight: DsTypography.bold,
                    color: colors.onSurface,
                  ),
                ),
                const SizedBox(height: DsSpacing.xl),

                _Field(
                  controller: _label,
                  label: 'اسم العنوان',
                  hint: 'المنزل، العمل، بيت أهلي',
                  maxLength: 40,
                  required: true,
                ),
                _Field(
                  controller: _recipientName,
                  label: 'اسم المستلِمة',
                  hint: 'من يستلم الطلب',
                  maxLength: 120,
                  required: true,
                  minLength: 2,
                ),
                _Field(
                  controller: _recipientPhone,
                  label: 'رقم الهاتف',
                  hint: '09XX XXX XXX',
                  keyboardType: TextInputType.phone,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9+ ]')),
                  ],
                  maxLength: 20,
                  required: true,
                  minLength: 6,
                ),

                governorates.when(
                  loading: () => const Padding(
                    padding: EdgeInsets.symmetric(vertical: DsSpacing.md),
                    child: LinearProgressIndicator(),
                  ),
                  error: (_, _) => _GovernorateUnavailable(
                    onRetry: () => ref.invalidate(deliveryGovernoratesProvider),
                  ),
                  data: (list) => list.isEmpty
                      ? _GovernorateUnavailable(
                          onRetry: () =>
                              ref.invalidate(deliveryGovernoratesProvider),
                        )
                      : _GovernoratePicker(
                          governorates: list,
                          governorate: _governorate,
                          district: _district,
                          onChanged: (governorate, district, isRural) {
                            setState(() {
                              _governorate = governorate;
                              _district = district;
                              _isRural = isRural;
                            });
                          },
                        ),
                ),

                _Field(
                  controller: _city,
                  label: 'المدينة أو البلدة',
                  hint: 'المزة، جرمانا، ...',
                  maxLength: 60,
                  required: true,
                  minLength: 2,
                ),
                _Field(
                  controller: _addressLine,
                  label: 'العنوان',
                  hint: 'الشارع، البناء، الطابق، رقم الشقة',
                  maxLength: 280,
                  required: true,
                  minLength: 3,
                  maxLines: 2,
                ),
                _Field(
                  controller: _landmark,
                  label: 'علامة مميزة (اختياري)',
                  hint: 'قرب صيدلية النور',
                  maxLength: 140,
                ),
                _Field(
                  controller: _instructions,
                  label: 'تعليمات للتوصيل (اختياري)',
                  hint: 'اتصلي قبل الوصول',
                  maxLength: 280,
                  maxLines: 2,
                ),

                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  value: _isDefault,
                  onChanged: (value) => setState(() => _isDefault = value),
                  title: Text(
                    'اجعليه عنواني الافتراضي',
                    style: TextStyle(color: colors.onSurface),
                  ),
                  subtitle: Text(
                    'هو الذي يفتح عليه الدفع',
                    style: TextStyle(
                      color: colors.onSurfaceVariant,
                      fontSize: DsTypography.labelSmall,
                    ),
                  ),
                ),

                const SizedBox(height: DsSpacing.lg),
                PrimaryButton(
                  label: isEditing ? 'حفظ التعديل' : 'حفظ العنوان',
                  onPressed: _governorate == null ? null : _submit,
                ),
                const SizedBox(height: DsSpacing.sm),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _GovernoratePicker extends StatelessWidget {
  const _GovernoratePicker({
    required this.governorates,
    required this.governorate,
    required this.district,
    required this.onChanged,
  });

  final List<Governorate> governorates;
  final String? governorate;
  final String? district;

  /// Reports all three together because they move together: changing the
  /// governorate invalidates the district, and the district is what carries
  /// the rural flag.
  final void Function(String governorate, String? district, bool isRural)
  onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.dsColors;
    final selected = governorates
        .where((g) => g.name == governorate)
        .firstOrNull;
    final districts = selected?.districts ?? const <GovernorateDistrict>[];

    return Padding(
      padding: const EdgeInsets.only(bottom: DsSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'المحافظة',
            style: TextStyle(
              color: colors.onSurfaceVariant,
              fontSize: DsTypography.labelSmall,
              fontWeight: DsTypography.semiBold,
            ),
          ),
          const SizedBox(height: DsSpacing.sm),
          DropdownButtonFormField<String>(
            initialValue: governorate,
            isExpanded: true,
            decoration: const InputDecoration(hintText: 'اختاري المحافظة'),
            items: [
              for (final g in governorates)
                DropdownMenuItem(
                  value: g.name,
                  child: Text('${g.name} · ${g.etaLabel}'),
                ),
            ],
            onChanged: (value) {
              if (value == null) return;
              // The old district belongs to the old governorate; keeping it
              // would price a Damascus suburb against an Aleppo delivery.
              onChanged(value, null, false);
            },
            validator: (value) =>
                value == null || value.isEmpty ? 'اختاري المحافظة' : null,
          ),
          if (districts.isNotEmpty) ...[
            const SizedBox(height: DsSpacing.md),
            Text(
              'المنطقة',
              style: TextStyle(
                color: colors.onSurfaceVariant,
                fontSize: DsTypography.labelSmall,
                fontWeight: DsTypography.semiBold,
              ),
            ),
            const SizedBox(height: DsSpacing.sm),
            DropdownButtonFormField<String>(
              initialValue: district,
              isExpanded: true,
              decoration: const InputDecoration(
                hintText: 'اختاري المنطقة (اختياري)',
              ),
              items: [
                for (final d in districts)
                  DropdownMenuItem(
                    value: d.name,
                    child: Text(d.isRural ? '${d.name} · ريف' : d.name),
                  ),
              ],
              onChanged: (value) {
                final match = districts.where((d) => d.name == value).firstOrNull;
                onChanged(governorate!, value, match?.isRural ?? false);
              },
            ),
          ],
        ],
      ),
    );
  }
}

/// The list would not load.
///
/// Deliberately blocks the save rather than falling back to a free-text field:
/// an address saved against a governorate the platform does not recognise
/// quotes no fee and can be assigned to no courier, so it would fail later, at
/// checkout, where it is far more expensive to discover.
class _GovernorateUnavailable extends StatelessWidget {
  const _GovernorateUnavailable({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final colors = context.dsColors;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: DsSpacing.md),
      child: Row(
        children: [
          Icon(Icons.wifi_off_rounded, color: colors.onSurfaceVariant, size: 20),
          const SizedBox(width: DsSpacing.sm),
          Expanded(
            child: Text(
              'تعذّر تحميل قائمة المحافظات',
              style: TextStyle(color: colors.onSurfaceVariant),
            ),
          ),
          TextButton(onPressed: onRetry, child: const Text('إعادة المحاولة')),
        ],
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.controller,
    required this.label,
    this.hint,
    this.keyboardType,
    this.inputFormatters,
    this.maxLength,
    this.maxLines = 1,
    this.required = false,
    this.minLength,
  });

  final TextEditingController controller;
  final String label;
  final String? hint;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final int? maxLength;
  final int maxLines;
  final bool required;
  final int? minLength;

  @override
  Widget build(BuildContext context) {
    final colors = context.dsColors;

    return Padding(
      padding: const EdgeInsets.only(bottom: DsSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: colors.onSurfaceVariant,
              fontSize: DsTypography.labelSmall,
              fontWeight: DsTypography.semiBold,
            ),
          ),
          const SizedBox(height: DsSpacing.sm),
          TextFormField(
            controller: controller,
            keyboardType: keyboardType,
            inputFormatters: inputFormatters,
            maxLines: maxLines,
            // The server's own ceiling, enforced here so a long line is
            // stopped by the keyboard rather than by a 400 after she taps save.
            maxLength: maxLength,
            decoration: InputDecoration(hintText: hint, counterText: ''),
            validator: (value) {
              final text = value?.trim() ?? '';
              if (required && text.isEmpty) return 'هذا الحقل مطلوب';
              if (text.isNotEmpty &&
                  minLength != null &&
                  text.length < minLength!) {
                return 'أقصر من اللازم';
              }
              return null;
            },
          ),
        ],
      ),
    );
  }
}
