import 'package:flutter/material.dart';
import 'package:reem/core/design_system/design_system.dart';
import 'package:reem/core/localization/l10n_extension.dart';


class PostCaptionField extends StatelessWidget {
  const PostCaptionField({
    super.key,
    required this.controller,
    this.enabled = true,
  });

  final TextEditingController controller;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(DsSpacing.xl),
      decoration: BoxDecoration(
        color: DsColors.onMedia,
        borderRadius: BorderRadius.circular(DsRadius.xl),
        boxShadow: DsShadows.medium(DsColors.primary600),
      ),
      child: TextField(
        controller: controller,
        enabled: enabled,
        textInputAction: TextInputAction.newline,
        maxLines: 7,
        maxLength: 2000,
        decoration: InputDecoration(
          hintText: context.l10n.createCaptionHint,
          hintStyle: context.dsText.body
              .tint(context.dsColors.onSurfaceVariant),
          border: InputBorder.none,
          counterText: '',
        ),
        style: context.dsText.bodyLarge.copyWith(height: 1.8),
      ),
    );
  }
}
