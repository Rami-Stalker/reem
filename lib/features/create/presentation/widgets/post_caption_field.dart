import 'package:flutter/material.dart';
import 'package:ohara/core/design_system/design_system.dart';
import 'package:ohara/core/localization/l10n_extension.dart';


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
      child: DsComposerField(
        controller: controller,
        enabled: enabled,
        hint: context.l10n.createCaptionHint,
        shape: DsComposerShape.bare,
        textInputAction: TextInputAction.newline,
        minLines: 5,
        maxLines: 7,
        maxLength: 2000,
        textStyle: context.dsText.bodyLarge.copyWith(height: 1.8),
      ),
    );
  }
}
