import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ohara/core/design_system/design_system.dart';
import 'package:ohara/core/localization/l10n_extension.dart';
import 'package:ohara/features/policies/domain/entities/admin_policy.dart';
import 'package:ohara/features/policies/presentation/providers/admin_policies_provider.dart';

/// Editing the open draft — both languages, side by side in two tabs.
///
/// The Arabic tab is first and labelled «العربية (المُلزِمة)» because it is:
/// the documents themselves say the Arabic governs, and an editor who writes
/// the English first and translates afterwards is drafting the contract in the
/// wrong language.
Future<void> showPolicyEditorSheet(
  BuildContext context, {
  required AdminPolicyDocument document,
  required AdminPolicyVersion version,
}) {
  return DsBottomSheet.showTitled(
    context,
    title: document.title('ar'),
    subtitle: context.l10n.adminPolicyEditDraft,
    scrollable: false,
    child: _PolicyEditor(document: document, version: version),
  );
}

class _PolicyEditor extends ConsumerStatefulWidget {
  const _PolicyEditor({required this.document, required this.version});

  final AdminPolicyDocument document;
  final AdminPolicyVersion version;

  @override
  ConsumerState<_PolicyEditor> createState() => _PolicyEditorState();
}

class _PolicyEditorState extends ConsumerState<_PolicyEditor>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 2, vsync: this);
  late final Map<String, _LocaleFields> _fields = {
    for (final locale in const ['ar', 'en'])
      locale: _LocaleFields(
        widget.version.translation(locale) ??
            AdminPolicyTranslation(
              locale: locale,
              title: '',
              summary: '',
              body: '',
            ),
      ),
  };
  late final TextEditingController _changeNote = TextEditingController(
    text: widget.version.changeNote ?? '',
  );

  bool _saving = false;
  bool _previewing = false;

  @override
  void dispose() {
    _tabs.dispose();
    for (final fields in _fields.values) {
      fields.dispose();
    }
    _changeNote.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final l10n = context.l10n;

    // Only languages with a body are sent. The server replaces a draft's
    // translations wholesale, so posting an empty English tab would publish a
    // blank English policy — worse than having no English at all, because a
    // reader would be shown an empty page claiming to be the terms.
    final translations = _fields.values
        .map((fields) => fields.toTranslation())
        .where((row) => row.body.trim().isNotEmpty)
        .toList(growable: false);

    if (translations.isEmpty) {
      DsSnackbar.show(
        context,
        message: l10n.adminPolicyBodyTooShort,
        type: DsSnackbarType.error,
      );
      return;
    }

    setState(() => _saving = true);
    try {
      await ref
          .read(policyAdminDataSourceProvider)
          .saveDraft(
            widget.version.id,
            translations: translations,
            changeNote: _changeNote.text.trim().isEmpty
                ? null
                : _changeNote.text.trim(),
          );
      ref.invalidate(adminPoliciesProvider);
      if (!mounted) return;
      // Announce, then close. The other way round shows a snackbar through a
      // context that has just been deactivated by the pop, which either throws
      // or silently swallows the confirmation — and "did that save?" is the one
      // question an editor must never be left with.
      DsSnackbar.show(
        context,
        message: l10n.adminPolicySaved,
        type: DsSnackbarType.success,
      );
      Navigator.of(context).pop();
    } on Object catch (error) {
      if (!mounted) return;
      DsSnackbar.show(context, message: '$error', type: DsSnackbarType.error);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.dsColors;

    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.78,
      child: Column(
        children: [
          TabBar(
            controller: _tabs,
            labelColor: colors.primary,
            unselectedLabelColor: colors.onSurfaceVariant,
            indicatorColor: colors.primary,
            tabs: [
              Tab(text: l10n.adminPolicyLocaleArabic),
              Tab(text: l10n.adminPolicyLocaleEnglish),
            ],
          ),
          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: [
                _LocaleTab(
                  fields: _fields['ar']!,
                  previewing: _previewing,
                  textDirection: TextDirection.rtl,
                ),
                _LocaleTab(
                  fields: _fields['en']!,
                  previewing: _previewing,
                  textDirection: TextDirection.ltr,
                ),
              ],
            ),
          ),
          const SizedBox(height: DsSpacing.sm),
          DsInputField(
            controller: _changeNote,
            label: l10n.adminPolicyChangeNote,
            hint: l10n.adminPolicyChangeNoteHint,
          ),
          const SizedBox(height: DsSpacing.sm),
          Row(
            children: [
              Expanded(
                child: SecondaryButton(
                  label: l10n.adminPolicyPreview,
                  icon: _previewing
                      ? Icons.edit_outlined
                      : Icons.visibility_outlined,
                  onPressed: () => setState(() => _previewing = !_previewing),
                ),
              ),
              const SizedBox(width: DsSpacing.sm),
              Expanded(
                child: PrimaryButton(
                  label: l10n.save,
                  onPressed: _saving ? null : _save,
                  isLoading: _saving,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// One language: title, summary, body — or the body as the app will draw it.
///
/// The preview matters more than it looks. The body is a restricted Markdown
/// the editor cannot see the result of anywhere else, so without this she
/// publishes a heading that turned out to be a paragraph and finds out from a
/// customer.
class _LocaleTab extends StatelessWidget {
  const _LocaleTab({
    required this.fields,
    required this.previewing,
    required this.textDirection,
  });

  final _LocaleFields fields;
  final bool previewing;
  final TextDirection textDirection;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Directionality(
      textDirection: textDirection,
      child: ListView(
        padding: const EdgeInsets.symmetric(vertical: DsSpacing.md),
        children: [
          DsInputField(
            controller: fields.title,
            label: l10n.adminPolicyTitleField,
          ),
          const SizedBox(height: DsSpacing.sm),
          DsInputField(
            controller: fields.summary,
            label: l10n.adminPolicySummaryField,
            maxLines: 2,
          ),
          const SizedBox(height: DsSpacing.sm),
          if (previewing)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(DsSpacing.md),
              decoration: BoxDecoration(
                color: context.dsColors.surfaceVariant,
                borderRadius: BorderRadius.circular(DsRadius.md),
              ),
              child: ListenableBuilder(
                listenable: fields.body,
                builder: (context, _) => DsRichText(text: fields.body.text),
              ),
            )
          else
            DsInputField(
              controller: fields.body,
              label: l10n.adminPolicyBodyField,
              hint: l10n.adminPolicyBodyHint,
              maxLines: 18,
            ),
        ],
      ),
    );
  }
}

class _LocaleFields {
  _LocaleFields(AdminPolicyTranslation source)
    : locale = source.locale,
      title = TextEditingController(text: source.title),
      summary = TextEditingController(text: source.summary),
      body = TextEditingController(text: source.body);

  final String locale;
  final TextEditingController title;
  final TextEditingController summary;
  final TextEditingController body;

  AdminPolicyTranslation toTranslation() => AdminPolicyTranslation(
    locale: locale,
    title: title.text.trim(),
    summary: summary.text.trim(),
    body: body.text,
  );

  void dispose() {
    title.dispose();
    summary.dispose();
    body.dispose();
  }
}

// ── Publishing ─────────────────────────────────────────────────────────────

/// The one action on this screen with a blast radius.
///
/// It asks one question and it is not rhetorical: does everyone have to accept
/// this again? A separate sheet rather than a button on the row, because a
/// re-consent that somebody triggers by mis-tapping "publish" interrupts every
/// account on that side of the marketplace.
Future<void> showPolicyPublishSheet(
  BuildContext context, {
  required AdminPolicyDocument document,
  required AdminPolicyVersion draft,
}) {
  return DsBottomSheet.showTitled(
    context,
    title: context.l10n.adminPolicyPublishTitle('${draft.version}'),
    subtitle: document.title('ar'),
    child: _PublishForm(draft: draft),
  );
}

class _PublishForm extends ConsumerStatefulWidget {
  const _PublishForm({required this.draft});

  final AdminPolicyVersion draft;

  @override
  ConsumerState<_PublishForm> createState() => _PublishFormState();
}

class _PublishFormState extends ConsumerState<_PublishForm> {
  late final TextEditingController _note = TextEditingController(
    text: widget.draft.changeNote ?? '',
  );
  bool _requiresReacceptance = false;
  bool _publishing = false;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _publish() async {
    final l10n = context.l10n;
    final confirmed = await DsDialog.confirm(
      context,
      title: l10n.adminPolicyPublish,
      message: l10n.adminPolicyPublishConfirm,
    );
    if (!confirmed || !mounted) return;

    setState(() => _publishing = true);
    try {
      await ref
          .read(policyAdminDataSourceProvider)
          .publish(
            widget.draft.id,
            requiresReacceptance: _requiresReacceptance,
            changeNote: _note.text.trim().isEmpty ? null : _note.text.trim(),
          );
      ref.invalidate(adminPoliciesProvider);
      ref.invalidate(adminPolicyConsentProvider);
      if (!mounted) return;
      // Announce before closing — see `_PolicyEditorState._save`.
      DsSnackbar.show(
        context,
        message: l10n.adminPolicyPublished,
        type: DsSnackbarType.success,
      );
      Navigator.of(context).pop();
    } on Object catch (error) {
      if (!mounted) return;
      DsSnackbar.show(context, message: '$error', type: DsSnackbarType.error);
    } finally {
      if (mounted) setState(() => _publishing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.dsColors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SwitchListTile(
          value: _requiresReacceptance,
          onChanged: _publishing
              ? null
              : (value) => setState(() => _requiresReacceptance = value),
          contentPadding: EdgeInsets.zero,
          activeThumbColor: colors.warning,
          title: Text(
            l10n.adminPolicyRequiresReacceptance,
            style: context.dsText.body,
          ),
          subtitle: Text(
            l10n.adminPolicyRequiresReacceptanceHint,
            style: context.dsText.caption.copyWith(height: 1.5),
          ),
        ),
        const SizedBox(height: DsSpacing.md),
        DsInputField(
          controller: _note,
          label: l10n.adminPolicyChangeNote,
          hint: l10n.adminPolicyChangeNoteHint,
        ),
        const SizedBox(height: DsSpacing.lg),
        PrimaryButton(
          label: l10n.adminPolicyPublish,
          icon: Icons.publish_rounded,
          onPressed: _publishing ? null : _publish,
          isLoading: _publishing,
        ),
      ],
    );
  }
}
