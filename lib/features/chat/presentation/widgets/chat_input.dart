import 'dart:async';

import 'package:flutter/material.dart';
import 'package:ohara/core/design_system/design_system.dart';
import 'package:ohara/core/localization/l10n_extension.dart';

class ChatInput extends StatefulWidget {
  const ChatInput({
    super.key,
    required this.onSend,
    this.onTyping,
    this.onImage,
    this.onVoice,
    this.onProduct,
    this.onOrder,
    this.isSending = false,
  });

  final ValueChanged<String> onSend;
  final ValueChanged<bool>? onTyping;
  final VoidCallback? onImage;
  final VoidCallback? onVoice;

  /// «أرسلي قطعة» and «أرسلي طلب». Null draws the action as unavailable.
  final VoidCallback? onProduct;
  final VoidCallback? onOrder;
  final bool isSending;

  @override
  State<ChatInput> createState() => _ChatInputState();
}

class _ChatInputState extends State<ChatInput>
    with SingleTickerProviderStateMixin {
  late AnimationController controller;
  final textController = TextEditingController();
  Timer? typingTimer;
  bool expanded = false;
  bool typing = false;

  /// Whether the field holds anything to send. Tracked so the button can be
  /// a microphone while it is empty and a send arrow once it is not.
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );
    textController.addListener(() {
      final hasText = textController.text.trim().isNotEmpty;
      if (hasText != _hasText) setState(() => _hasText = hasText);
    });
  }

  @override
  void dispose() {
    typingTimer?.cancel();
    textController.dispose();
    controller.dispose();
    super.dispose();
  }

  void toggle() {
    setState(() => expanded = !expanded);
    expanded ? controller.forward() : controller.reverse();
  }

  /// [action], after folding the tray away; null stays null.
  VoidCallback? _closing(VoidCallback? action) {
    if (action == null) return null;
    return () {
      if (expanded) toggle();
      action();
    };
  }

  void send() {
    final text = textController.text.trim();
    if (text.isEmpty || widget.isSending) return;
    textController.clear();
    setTyping(false);
    widget.onSend(text);
  }

  /// When "typing" was last said to the other side.
  DateTime? typingSentAt;

  void handleTyping(String value) {
    typingTimer?.cancel();
    if (value.trim().isEmpty) {
      setTyping(false);
      return;
    }
    setTyping(true);
    // Said again every few seconds while she keeps typing: the other side
    // drops "typing…" after a few seconds of silence, so a phone that went
    // offline mid-sentence cannot leave it up for ever.
    final last = typingSentAt;
    if (last != null && DateTime.now().difference(last) > _typingRenewal) {
      typingSentAt = DateTime.now();
      widget.onTyping?.call(true);
    }
    typingTimer = Timer(const Duration(seconds: 2), () => setTyping(false));
  }

  static const _typingRenewal = Duration(seconds: 3);

  void setTyping(bool value) {
    if (typing == value) return;
    typing = value;
    typingSentAt = value ? DateTime.now() : null;
    widget.onTyping?.call(value);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.dsColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // With nothing typed the button records a voice note — the one tap a
    // question asked aloud should cost; once there are words it sends them.
    final voiceMode = !_hasText && widget.onVoice != null && !widget.isSending;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        DsSpacing.md,
        DsSpacing.xs,
        DsSpacing.md,
        DsSpacing.sm + MediaQuery.paddingOf(context).bottom,
      ),
      child: Container(
        padding: const EdgeInsets.all(DsSpacing.xs),
        decoration: BoxDecoration(
          // A floating capsule, solid enough to read on: no blur behind it,
          // which over a moving ground would be a full repaint every frame.
          color: (isDark ? colors.surfaceElevated : colors.surface).withValues(
            alpha: 0.95,
          ),
          borderRadius: DsRadius.borderXxxl,
          border: Border.all(color: colors.border.withValues(alpha: 0.7)),
          boxShadow: context.shadowSoft,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizeTransition(
              sizeFactor: CurvedAnimation(
                parent: controller,
                curve: DsMotion.gentle,
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  DsSpacing.xs,
                  DsSpacing.sm,
                  DsSpacing.xs,
                  DsSpacing.md,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    // Each closes the tray before it opens its own sheet.
                    _action(
                      context,
                      Icons.photo_rounded,
                      context.l10n.mediaImage,
                      _closing(widget.onImage),
                    ),
                    _action(
                      context,
                      Icons.mic_rounded,
                      context.l10n.chatVoice,
                      _closing(widget.onVoice),
                    ),
                    _action(
                      context,
                      Icons.shopping_bag_rounded,
                      context.l10n.chatProduct,
                      _closing(widget.onProduct),
                    ),
                    _action(
                      context,
                      Icons.receipt_long_rounded,
                      context.l10n.chatOrder,
                      _closing(widget.onOrder),
                    ),
                  ],
                ),
              ),
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Tooltip(
                  message: context.l10n.chatAttachments,
                  child: GestureDetector(
                    onTap: toggle,
                    child: AnimatedContainer(
                      duration: DsMotion.moderate,
                      width: DsSizes.controlLg,
                      height: DsSizes.controlLg,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: expanded
                            ? colors.primaryContainer
                            : colors.surfaceVariant,
                      ),
                      child: AnimatedRotation(
                        turns: expanded ? .125 : 0,
                        duration: DsMotion.normal,
                        child: Icon(
                          Icons.add_rounded,
                          color: colors.primary,
                          size: DsSizes.iconMd,
                        ),
                      ),
                    ),
                  ),
                ),
                DsGaps.hXs,
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: DsSpacing.xs,
                    ),
                    child: DsComposerField(
                      controller: textController,
                      hint: context.l10n.chatWriteMessage,
                      // The capsule around it is the field's chrome.
                      shape: DsComposerShape.bare,
                      maxLength: 5000,
                      onChanged: handleTyping,
                      onSubmitted: (_) => send(),
                    ),
                  ),
                ),
                DsGaps.hXs,
                Tooltip(
                  message: voiceMode
                      ? context.l10n.chatVoice
                      : context.l10n.send,
                  child: GestureDetector(
                    onTap: voiceMode ? widget.onVoice : send,
                    child: Container(
                      width: DsSizes.controlLg,
                      height: DsSizes.controlLg,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: context.primaryGradient,
                        boxShadow: context.glowShadow(
                          colors.primary,
                          blur: 12,
                          alpha: 0.3,
                        ),
                      ),
                      child: widget.isSending
                          ? const Center(
                              child: DsLoadingIndicator.inline(
                                color: DsColors.onMedia,
                              ),
                            )
                          : AnimatedSwitcher(
                              duration: DsMotion.normal,
                              transitionBuilder: (child, animation) =>
                                  ScaleTransition(
                                    scale: animation,
                                    child: child,
                                  ),
                              child: Icon(
                                voiceMode
                                    ? Icons.mic_rounded
                                    : Icons.send_rounded,
                                key: ValueKey(voiceMode),
                                color: DsColors.onMedia,
                              ),
                            ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// A null [onTap] draws the action as unavailable rather than as a button
  /// that quietly does nothing when pressed — which is what Product and Order
  /// were, and what a tap on them is still worth telling her about honestly.
  Widget _action(
    BuildContext context,
    IconData icon,
    String title,
    VoidCallback? onTap,
  ) {
    final enabled = onTap != null;
    return Semantics(
      button: true,
      enabled: enabled,
      label: title,
      child: Opacity(
        opacity: enabled ? 1 : 0.4,
        child: GestureDetector(
          onTap: onTap,
          child: Column(
            children: [
              Container(
                width: DsSizes.fabSize,
                height: DsSizes.fabSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      context.dsColors.primaryContainer,
                      context.dsColors.secondaryContainer,
                    ],
                  ),
                  boxShadow: context.shadowXs,
                ),
                child: Icon(icon, color: context.dsColors.primary),
              ),
              DsGaps.vXs,
              Text(title, style: context.dsText.labelStrong),
            ],
          ),
        ),
      ),
    );
  }
}
