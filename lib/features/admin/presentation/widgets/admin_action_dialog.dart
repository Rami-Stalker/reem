import 'dart:convert';

import 'package:flutter/material.dart';

import 'package:reem/core/design_system/design_system.dart';
import 'package:reem/core/localization/l10n_extension.dart';
import 'package:reem/features/admin/domain/entities/admin_console_entity.dart';
import 'package:reem/features/admin/presentation/providers/admin_actions.dart';

/// The one form behind every governance action in the console.
///
/// It reads an [AdminRecordAction]'s field list and builds the inputs, so a
/// new action is a few lines of data rather than another dialog. Returns the
/// payload to send, or `null` if the operator backed out.
Future<Map<String, dynamic>?> showAdminActionDialog({
  required BuildContext context,
  required AdminRecordAction action,
  AdminRecord? record,
}) {
  return showDialog<Map<String, dynamic>>(
    context: context,
    builder: (context) => _AdminActionDialog(action: action, record: record),
  );
}

class _AdminActionDialog extends StatefulWidget {
  const _AdminActionDialog({required this.action, this.record});

  final AdminRecordAction action;
  final AdminRecord? record;

  @override
  State<_AdminActionDialog> createState() => _AdminActionDialogState();
}

class _AdminActionDialogState extends State<_AdminActionDialog> {
  final _text = <String, TextEditingController>{};
  final _choice = <String, String>{};
  final _toggle = <String, bool>{};
  String? _error;

  @override
  void initState() {
    super.initState();
    for (final field in widget.action.fields) {
      if (field.isHidden) continue;
      final seed = field.seedFrom == null
          ? null
          : widget.record?.raw[field.seedFrom!];
      switch (field.kind) {
        case AdminFieldKind.text:
          _text[field.key] = TextEditingController(text: _seedText(seed));
        case AdminFieldKind.choice:
          final token = seed?.toString().toUpperCase();
          _choice[field.key] =
              field.choices.any((choice) => choice.value == token)
              ? token!
              : field.choices.first.value;
        case AdminFieldKind.toggle:
          _toggle[field.key] = seed is bool ? seed : false;
      }
    }
  }

  /// A setting's value arrives as arbitrary JSON, not a string. Seeding the
  /// box with `{a: 1}` — Dart's `toString` for a map — would hand the operator
  /// something that is not valid JSON to edit.
  String _seedText(Object? seed) {
    if (seed == null) return '';
    if (seed is String) return seed;
    if (seed is num || seed is bool) return seed.toString();
    return const JsonEncoder.withIndent('  ').convert(seed);
  }

  @override
  void dispose() {
    for (final controller in _text.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.dsColors;

    return AlertDialog(
      title: Text(widget.action.label(l10n)),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.record != null) ...[
                Text(
                  widget.record!.title,
                  style: context.dsText.body.semibold.tint(colors.onSurface),
                ),
                const SizedBox(height: DsSpacing.md),
              ],
              for (final field in widget.action.fields)
                if (!field.isHidden) ...[
                  _fieldInput(field),
                  const SizedBox(height: DsSpacing.md),
                ],
              if (_error != null)
                Text(_error!, style: context.dsText.body.tint(colors.error)),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
        PrimaryButton(
          label: l10n.adminApply,
          isExpanded: false,
          onPressed: _submit,
        ),
      ],
    );
  }

  Widget _fieldInput(AdminActionField field) {
    final l10n = context.l10n;
    return switch (field.kind) {
      AdminFieldKind.text => DsInputField(
        controller: _text[field.key],
        label: field.label(l10n),
        hint: field.hint?.call(l10n),
        maxLines: field.maxLines,
        minLines: field.maxLines > 1 ? field.maxLines : null,
      ),
      AdminFieldKind.choice => DropdownButtonFormField<String>(
        initialValue: _choice[field.key],
        decoration: InputDecoration(labelText: field.label(l10n)),
        items: [
          for (final choice in field.choices)
            DropdownMenuItem(
              value: choice.value,
              child: Text(choice.label(l10n)),
            ),
        ],
        onChanged: (value) =>
            setState(() => _choice[field.key] = value ?? _choice[field.key]!),
      ),
      AdminFieldKind.toggle => SwitchListTile.adaptive(
        value: _toggle[field.key] ?? false,
        dense: true,
        contentPadding: EdgeInsets.zero,
        title: Text(field.label(l10n)),
        onChanged: (value) => setState(() => _toggle[field.key] = value),
      ),
    };
  }

  void _submit() {
    final l10n = context.l10n;
    final payload = <String, dynamic>{};

    for (final field in widget.action.fields) {
      if (field.constantValue != null) {
        payload[field.key] = field.constantValue;
        continue;
      }
      switch (field.kind) {
        case AdminFieldKind.text:
          final raw = _text[field.key]!.text.trim();
          if (raw.isEmpty) {
            if (field.isRequired) {
              setState(() => _error = l10n.adminFieldRequired(field.label(l10n)));
              return;
            }
            continue;
          }
          // The settings value is the one field that is genuinely JSON, and a
          // malformed one is worth catching here rather than as a 400 the
          // operator has to translate back into "the braces are wrong".
          if (field.key == 'value') {
            try {
              payload[field.key] = jsonDecode(raw);
            } on FormatException {
              // A bare word is a perfectly good string value; only refuse the
              // input that was clearly meant to be structured and is not.
              if (raw.startsWith('{') || raw.startsWith('[')) {
                setState(() => _error = l10n.adminInvalidJson);
                return;
              }
              payload[field.key] = raw;
            }
            continue;
          }
          if (field.key == 'rate_bps') {
            final rate = int.tryParse(raw);
            if (rate == null || rate < 0 || rate > 5000) {
              setState(() => _error = l10n.adminInvalidRate);
              return;
            }
            payload[field.key] = rate;
            continue;
          }
          payload[field.key] = raw;
        case AdminFieldKind.choice:
          payload[field.key] = _choice[field.key];
        case AdminFieldKind.toggle:
          payload[field.key] = _toggle[field.key] ?? false;
      }
    }

    Navigator.pop(context, payload);
  }
}
