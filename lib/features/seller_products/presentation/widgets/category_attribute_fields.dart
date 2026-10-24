import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ohara/core/design_system/design_system.dart';
import 'package:ohara/core/localization/l10n_extension.dart';
import 'package:ohara/features/catalog/domain/entities/category_attributes.dart';
import 'package:ohara/features/catalog/presentation/providers/categories_provider.dart';

/// The extra fields the chosen category asks a product to carry.
///
/// Without these the form could be filled in perfectly and still be refused:
/// «ملابس» declares `material` as required, every shelf under it inherits
/// that, and `POST /seller/products` answers `This category requires:
/// material` for a draft that omits it. The form had no idea the field
/// existed. The section appears only when the category governs something, and
/// vanishes again when she picks one that does not.
class CategoryAttributeFields extends ConsumerWidget {
  const CategoryAttributeFields({
    super.key,
    required this.categoryId,
    required this.values,
    required this.onChanged,
    this.enabled = true,
    this.showErrors = false,
  });

  final String? categoryId;

  /// The live answers, keyed as the server stores them.
  final Map<String, String> values;
  final void Function(String key, String value) onChanged;
  final bool enabled;

  /// Set once she has tried to save, so an untouched form is not scolded.
  final bool showErrors;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = categoryId;
    if (id == null) return const SizedBox.shrink();

    final schema = ref.watch(categoryAttributesProvider(id));
    return switch (schema) {
      AsyncData(:final value) when !value.isEmpty => _fields(context, value),
      _ => const SizedBox.shrink(),
    };
  }

  Widget _fields(BuildContext context, CategoryAttributeSchema schema) {
    final l10n = context.l10n;
    final palette = context.atelier;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(
            top: DsSpacing.lg,
            bottom: DsSpacing.xs,
          ),
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            child: Text(
              l10n.formCategoryDetails.toUpperCase(),
              style: DsTypography.overline(palette.muted),
            ),
          ),
        ),
        for (final attribute in schema.attributes)
          if (attribute.options.isEmpty)
            DsInputField(
              // Rebuilt when the category changes, so the controller-less form
              // has to be keyed by both or two categories sharing a key would
              // reuse the other's text.
              key: ValueKey('${categoryId}_${attribute.key}'),
              initialValue: values[attribute.key],
              label: attribute.isRequired
                  ? attribute.title
                  : '${attribute.title} — ${l10n.formOptional}',
              enabled: enabled,
              errorText: _errorFor(context, attribute),
              onChanged: (value) => onChanged(attribute.key, value),
            )
          else
            _Options(
              attribute: attribute,
              selected: values[attribute.key],
              enabled: enabled,
              errorText: _errorFor(context, attribute),
              onSelected: (value) => onChanged(attribute.key, value),
            ),
      ],
    );
  }

  String? _errorFor(BuildContext context, CategoryAttribute attribute) {
    if (!showErrors || !attribute.isRequired) return null;
    final answered = (values[attribute.key] ?? '').trim().isNotEmpty;
    return answered ? null : context.l10n.formFieldRequired;
  }
}

class _Options extends StatelessWidget {
  const _Options({
    required this.attribute,
    required this.selected,
    required this.enabled,
    required this.onSelected,
    this.errorText,
  });

  final CategoryAttribute attribute;
  final String? selected;
  final bool enabled;
  final ValueChanged<String> onSelected;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    final palette = context.atelier;

    return Padding(
      padding: const EdgeInsets.only(bottom: DsSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(
              DsSpacing.xs,
              0,
              0,
              DsSpacing.xs,
            ),
            child: Text(
              attribute.title,
              style: context.dsText.body.semibold.tint(palette.muted),
            ),
          ),
          Wrap(
            spacing: DsSpacing.sm,
            runSpacing: DsSpacing.xs,
            children: [
              for (final option in attribute.options)
                ChoiceChip(
                  label: Text(option),
                  selected: selected == option,
                  onSelected: enabled ? (_) => onSelected(option) : null,
                  selectedColor: palette.primarySoft,
                ),
            ],
          ),
          if (errorText != null)
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(
                DsSpacing.xs,
                DsSpacing.xs,
                0,
                0,
              ),
              child: Text(
                errorText!,
                style: context.dsText.caption.tint(palette.critical),
              ),
            ),
        ],
      ),
    );
  }
}
