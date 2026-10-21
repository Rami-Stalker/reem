import 'package:flutter/material.dart';

import 'package:reem/core/auth/app_permissions.dart';
import 'package:reem/features/admin/domain/entities/admin_console_entity.dart';
import 'package:reem/l10n/app_localizations.dart';

/// What an operator can actually *do* from the console, declared as data.
///
/// The console renders twelve tables from one screen, and each of those tables
/// has between one and three governance actions behind it. Written as widgets
/// that would be twelve dialogs; written as data it is one dialog that reads a
/// field list, plus one place where a reviewer can see the whole surface of
/// what staff are able to change and which permission each change costs.
///
/// The permission on an action is for *offering* it. Every one of these ends in
/// a request the server judges again on its own terms.
enum AdminFieldKind { choice, text, toggle }

class AdminChoice {
  const AdminChoice(this.value, this.label);

  final String value;
  final String Function(AppLocalizations) label;
}

class AdminActionField {
  const AdminActionField({
    required this.key,
    required this.kind,
    required this.label,
    this.choices = const [],
    this.isRequired = false,
    this.maxLines = 1,
    this.seedFrom,
    this.constantValue,
    this.hint,
  });

  /// Choice field, seeded from the record's own current value.
  const AdminActionField.choice({
    required this.key,
    required this.label,
    required this.choices,
    this.seedFrom,
    this.isRequired = true,
  }) : kind = AdminFieldKind.choice,
       maxLines = 1,
       constantValue = null,
       hint = null;

  const AdminActionField.text({
    required this.key,
    required this.label,
    this.isRequired = false,
    this.maxLines = 1,
    this.seedFrom,
    this.hint,
  }) : kind = AdminFieldKind.text,
       choices = const [],
       constantValue = null;

  const AdminActionField.toggle({
    required this.key,
    required this.label,
    this.seedFrom,
  }) : kind = AdminFieldKind.toggle,
       choices = const [],
       isRequired = false,
       maxLines = 1,
       constantValue = null,
       hint = null;

  /// A value the action always sends, with nothing for the operator to fill in.
  const AdminActionField.constant({required this.key, required Object value})
    : kind = AdminFieldKind.toggle,
      label = _noLabel,
      choices = const [],
      isRequired = false,
      maxLines = 1,
      seedFrom = null,
      constantValue = value,
      hint = null;

  final String key;
  final AdminFieldKind kind;
  final String Function(AppLocalizations) label;
  final List<AdminChoice> choices;
  final bool isRequired;
  final int maxLines;

  /// Key on the raw record to read the current value from, so a form opens
  /// showing what is true now rather than an empty box.
  final String? seedFrom;
  final Object? constantValue;
  final String Function(AppLocalizations)? hint;

  bool get isHidden => constantValue != null;

  static String _noLabel(AppLocalizations l10n) => '';
}

class AdminRecordAction {
  const AdminRecordAction({
    required this.id,
    required this.label,
    required this.icon,
    required this.permission,
    this.fields = const [],
    this.destructive = false,
    this.availableWhen,
  });

  final String id;
  final String Function(AppLocalizations) label;
  final IconData icon;
  final String permission;
  final List<AdminActionField> fields;
  final bool destructive;

  /// Actions that only make sense for some rows — "restore" on an account that
  /// is not suspended is noise, and offering it invites a pointless request.
  final bool Function(AdminRecord record)? availableWhen;

  bool appliesTo(AdminRecord record) =>
      availableWhen == null || availableWhen!(record);
}

// ---------------------------------------------------------------------------
// Choice vocabularies. These mirror the Prisma enums the API validates against.
// ---------------------------------------------------------------------------

const _productStatuses = [
  AdminChoice('ACTIVE', _lActive),
  AdminChoice('DRAFT', _lDraft),
  AdminChoice('OUT_OF_STOCK', _lOutOfStock),
  AdminChoice('ARCHIVED', _lArchived),
];

const _ticketStatuses = [
  AdminChoice('OPEN', _lOpen),
  AdminChoice('PENDING', _lPending),
  AdminChoice('RESOLVED', _lResolved),
  AdminChoice('CLOSED', _lClosed),
];

const _priorities = [
  AdminChoice('LOW', _lLow),
  AdminChoice('NORMAL', _lNormal),
  AdminChoice('HIGH', _lHigh),
  AdminChoice('URGENT', _lUrgent),
];

const _moderationStatuses = [
  AdminChoice('APPROVED', _lApproved),
  AdminChoice('REJECTED', _lRejected),
  AdminChoice('ESCALATED', _lEscalated),
  AdminChoice('OPEN', _lOpen),
];

const _reportStatuses = [
  AdminChoice('REVIEWING', _lReviewing),
  AdminChoice('RESOLVED', _lResolved),
  AdminChoice('DISMISSED', _lDismissed),
  AdminChoice('OPEN', _lOpen),
];

const _commissionStatuses = [
  AdminChoice('PENDING', _lPending),
  AdminChoice('EARNED', _lEarned),
  AdminChoice('PAID', _lPaid),
  AdminChoice('REVERSED', _lReversed),
];

/// Staff roles an operator can grant, plus the two ordinary ones.
///
/// `SUPER_ADMIN` is deliberately absent: the last unrevocable role in the
/// system is not something to hand out from a dropdown on a list screen.
const _grantableRoles = [
  AdminChoice('CUSTOMER', _lRoleCustomer),
  AdminChoice('SELLER', _lRoleSeller),
  AdminChoice('SUPPORT', _lRoleSupport),
  AdminChoice('SUPPORT_ADMIN', _lRoleSupportAdmin),
  AdminChoice('CONTENT_MODERATOR', _lRoleContentModerator),
  AdminChoice('OPERATIONS_ADMIN', _lRoleOperationsAdmin),
  AdminChoice('FINANCE_ADMIN', _lRoleFinanceAdmin),
  AdminChoice('ADMIN', _lRoleAdmin),
];

/// The decisions a seller application can receive.
const sellerReviewDecisions = [
  AdminChoice('APPROVED', _lApproved),
  AdminChoice('UNDER_REVIEW', _lReviewing),
  AdminChoice('NEEDS_MORE_DOCUMENTS', _lNeedsDocuments),
  AdminChoice('NEEDS_MORE_INFO', _lNeedsInfo),
  AdminChoice('REJECTED', _lRejected),
  AdminChoice('SUSPENDED', _lSuspended),
];

// ---------------------------------------------------------------------------
// The action catalogue, by section key.
// ---------------------------------------------------------------------------

/// What a reviewer may do with a claim on the badge.
///
/// Every one of them carries a required reason, approvals included. The badge
/// is a public claim Reem makes about a real woman, and a grant nobody can
/// later explain is exactly the state this whole feature replaced.
const _verificationDecisions = [
  AdminChoice('APPROVED', _lVerificationApprove),
  AdminChoice('NEEDS_MORE_INFO', _lVerificationNeedsInfo),
  AdminChoice('UNDER_REVIEW', _lVerificationUnderReview),
  AdminChoice('REJECTED', _lVerificationReject),
  AdminChoice('REVOKED', _lVerificationRevoke),
];

String _lVerificationApprove(AppLocalizations l10n) =>
    l10n.adminVerificationApprove;
String _lVerificationNeedsInfo(AppLocalizations l10n) =>
    l10n.adminVerificationNeedsInfo;
String _lVerificationUnderReview(AppLocalizations l10n) =>
    l10n.adminVerificationUnderReview;
String _lVerificationReject(AppLocalizations l10n) =>
    l10n.adminVerificationReject;
String _lVerificationRevoke(AppLocalizations l10n) =>
    l10n.adminVerificationRevoke;
String _lVerificationDecision(AppLocalizations l10n) =>
    l10n.adminVerificationDecision;
String _lVerificationReasonHint(AppLocalizations l10n) =>
    l10n.adminVerificationReasonReaches;

const adminSectionActions = <String, List<AdminRecordAction>>{
  'accountVerifications': [
    AdminRecordAction(
      id: 'decide',
      label: _lVerificationDecision,
      icon: Icons.verified_user_outlined,
      permission: AppPermissions.userManage,
      fields: [
        AdminActionField.choice(
          key: 'status',
          label: _lFieldStatus,
          choices: _verificationDecisions,
          seedFrom: 'status',
        ),
        AdminActionField.text(
          key: 'reason',
          label: _lFieldReason,
          isRequired: true,
          maxLines: 3,
          // She reads this, verbatim. The server refuses a decision without it.
          hint: _lVerificationReasonHint,
        ),
      ],
    ),
  ],
  'users': [
    AdminRecordAction(
      id: 'role',
      label: _lChangeRole,
      icon: Icons.badge_outlined,
      permission: AppPermissions.userManage,
      fields: [
        AdminActionField.choice(
          key: 'role',
          label: _lFieldRole,
          choices: _grantableRoles,
          seedFrom: 'role',
        ),
        AdminActionField.text(
          key: 'reason',
          label: _lFieldReason,
          isRequired: true,
          maxLines: 3,
        ),
      ],
    ),
    AdminRecordAction(
      id: 'suspend',
      label: _lSuspendAccount,
      icon: Icons.block_outlined,
      permission: AppPermissions.userManage,
      destructive: true,
      availableWhen: _isNotDisabled,
      fields: [
        AdminActionField.constant(key: 'disabled', value: true),
        AdminActionField.text(
          key: 'reason',
          label: _lFieldReason,
          isRequired: true,
          maxLines: 3,
        ),
      ],
    ),
    AdminRecordAction(
      id: 'restore',
      label: _lRestoreAccount,
      icon: Icons.lock_open_rounded,
      permission: AppPermissions.userManage,
      availableWhen: _isDisabled,
      fields: [
        AdminActionField.constant(key: 'disabled', value: false),
        AdminActionField.text(
          key: 'reason',
          label: _lFieldReason,
          isRequired: true,
          maxLines: 3,
        ),
      ],
    ),
  ],
  'products': [
    AdminRecordAction(
      id: 'status',
      label: _lSetStatus,
      icon: Icons.published_with_changes_rounded,
      permission: AppPermissions.productManage,
      fields: [
        AdminActionField.choice(
          key: 'status',
          label: _lFieldStatus,
          choices: _productStatuses,
          seedFrom: 'status',
        ),
        AdminActionField.text(
          key: 'reason',
          label: _lFieldReason,
          maxLines: 3,
        ),
      ],
    ),
    AdminRecordAction(
      id: 'curation',
      label: _lCuration,
      icon: Icons.star_outline_rounded,
      permission: AppPermissions.productManage,
      fields: [
        AdminActionField.toggle(
          key: 'is_featured',
          label: _lFieldFeatured,
          seedFrom: 'is_featured',
        ),
        AdminActionField.toggle(
          key: 'show_in_feed',
          label: _lFieldShowInFeed,
          seedFrom: 'show_in_feed',
        ),
      ],
    ),
  ],
  'support': [
    AdminRecordAction(
      id: 'triage',
      label: _lTriage,
      icon: Icons.support_agent_outlined,
      permission: AppPermissions.supportWrite,
      fields: [
        AdminActionField.choice(
          key: 'status',
          label: _lFieldStatus,
          choices: _ticketStatuses,
          seedFrom: 'status',
        ),
        AdminActionField.choice(
          key: 'priority',
          label: _lFieldPriority,
          choices: _priorities,
          seedFrom: 'priority',
        ),
      ],
    ),
  ],
  'moderation': [
    AdminRecordAction(
      id: 'decide',
      label: _lDecideCase,
      icon: Icons.gavel_outlined,
      permission: AppPermissions.contentModerate,
      fields: [
        AdminActionField.choice(
          key: 'status',
          label: _lFieldStatus,
          choices: _moderationStatuses,
          seedFrom: 'status',
        ),
        AdminActionField.text(
          key: 'resolution',
          label: _lFieldResolution,
          isRequired: true,
          maxLines: 4,
          seedFrom: 'resolution',
        ),
      ],
    ),
  ],
  'reports': [
    AdminRecordAction(
      id: 'decide',
      label: _lDecideReport,
      icon: Icons.rule_folder_outlined,
      permission: AppPermissions.supportWrite,
      fields: [
        AdminActionField.choice(
          key: 'status',
          label: _lFieldStatus,
          choices: _reportStatuses,
          seedFrom: 'status',
        ),
      ],
    ),
  ],
  'commissions': [
    AdminRecordAction(
      id: 'ledger',
      label: _lSetCommissionStatus,
      icon: Icons.payments_outlined,
      permission: AppPermissions.financeWrite,
      // The commissions payload carries rules and ledger entries side by side.
      // Only a ledger entry has a settlement status to move.
      availableWhen: _isLedgerEntry,
      fields: [
        AdminActionField.choice(
          key: 'status',
          label: _lFieldStatus,
          choices: _commissionStatuses,
          seedFrom: 'status',
        ),
      ],
    ),
  ],
  'settings': [
    AdminRecordAction(
      id: 'edit',
      label: _lEditSetting,
      icon: Icons.tune_rounded,
      permission: AppPermissions.authorizationManage,
      fields: [
        AdminActionField.text(
          key: 'key',
          label: _lFieldSettingKey,
          isRequired: true,
          seedFrom: 'key',
        ),
        AdminActionField.text(
          key: 'value',
          label: _lFieldSettingValue,
          isRequired: true,
          maxLines: 6,
          seedFrom: 'value',
          hint: _lJsonHint,
        ),
        AdminActionField.toggle(
          key: 'sensitive',
          label: _lFieldSensitive,
          seedFrom: 'sensitive',
        ),
      ],
    ),
  ],
};

/// Actions that create a record rather than change one, keyed by section.
const adminSectionCreateActions = <String, AdminRecordAction>{
  'commissions': AdminRecordAction(
    // l10n-ignore: a record id, matched server-side
    id: 'new-rule',
    label: _lNewRule,
    icon: Icons.add_rounded,
    permission: AppPermissions.financeWrite,
    fields: [
      AdminActionField.text(
        key: 'name',
        label: _lFieldRuleName,
        isRequired: true,
      ),
      AdminActionField.text(
        key: 'rate_bps',
        label: _lFieldRateBps,
        isRequired: true,
        hint: _lRateHint,
      ),
      AdminActionField.text(key: 'category', label: _lFieldCategory),
      AdminActionField.text(key: 'seller_tier', label: _lFieldSellerTier),
    ],
  ),
  'settings': AdminRecordAction(
    // l10n-ignore: a record id, matched server-side
    id: 'new-setting',
    label: _lNewSetting,
    icon: Icons.add_rounded,
    permission: AppPermissions.authorizationManage,
    fields: [
      AdminActionField.text(
        key: 'key',
        label: _lFieldSettingKey,
        isRequired: true,
      ),
      AdminActionField.text(
        key: 'value',
        label: _lFieldSettingValue,
        isRequired: true,
        maxLines: 6,
        hint: _lJsonHint,
      ),
      AdminActionField.toggle(key: 'sensitive', label: _lFieldSensitive),
    ],
  ),
};

bool _isDisabled(AdminRecord record) => record.flag('is_disabled') ?? false;
bool _isNotDisabled(AdminRecord record) => !_isDisabled(record);
/// The commissions payload is one list of two kinds of row. Only a ledger
/// entry has a settlement status to move; a rule is a rate, not a payment.
bool _isLedgerEntry(AdminRecord record) => record.field('kind') == 'ledger';

// Tear-offs, because a const list cannot hold a closure.
String _lActive(AppLocalizations l) => l.adminStatusActive;
String _lDraft(AppLocalizations l) => l.adminStatusDraft;
String _lOutOfStock(AppLocalizations l) => l.adminStatusOutOfStock;
String _lArchived(AppLocalizations l) => l.adminStatusArchived;
String _lOpen(AppLocalizations l) => l.adminStatusOpen;
String _lPending(AppLocalizations l) => l.adminStatusPending;
String _lResolved(AppLocalizations l) => l.adminStatusResolved;
String _lClosed(AppLocalizations l) => l.adminStatusClosed;
String _lApproved(AppLocalizations l) => l.adminStatusApproved;
String _lRejected(AppLocalizations l) => l.adminStatusRejected;
String _lEscalated(AppLocalizations l) => l.adminStatusEscalated;
String _lReviewing(AppLocalizations l) => l.adminStatusReviewing;
String _lDismissed(AppLocalizations l) => l.adminStatusDismissed;
String _lEarned(AppLocalizations l) => l.adminStatusEarned;
String _lPaid(AppLocalizations l) => l.adminStatusPaid;
String _lReversed(AppLocalizations l) => l.adminStatusReversed;
String _lNeedsDocuments(AppLocalizations l) =>
    l.verificationStatusNeedsMoreDocuments;
String _lNeedsInfo(AppLocalizations l) => l.verificationStatusNeedsMoreInfo;
String _lSuspended(AppLocalizations l) => l.verificationStatusSuspended;
String _lLow(AppLocalizations l) => l.adminPriorityLow;
String _lNormal(AppLocalizations l) => l.adminPriorityNormal;
String _lHigh(AppLocalizations l) => l.adminPriorityHigh;
String _lUrgent(AppLocalizations l) => l.adminPriorityUrgent;

String _lRoleCustomer(AppLocalizations l) => l.adminRoleCustomer;
String _lRoleSeller(AppLocalizations l) => l.adminRoleSeller;
String _lRoleSupport(AppLocalizations l) => l.adminRoleSupport;
String _lRoleSupportAdmin(AppLocalizations l) => l.adminRoleSupportAdmin;
String _lRoleContentModerator(AppLocalizations l) =>
    l.adminRoleContentModerator;
String _lRoleOperationsAdmin(AppLocalizations l) => l.adminRoleOperationsAdmin;
String _lRoleFinanceAdmin(AppLocalizations l) => l.adminRoleFinanceAdmin;
String _lRoleAdmin(AppLocalizations l) => l.adminRoleAdmin;

String _lChangeRole(AppLocalizations l) => l.adminActionChangeRole;
String _lSuspendAccount(AppLocalizations l) => l.adminActionSuspendAccount;
String _lRestoreAccount(AppLocalizations l) => l.adminActionRestoreAccount;
String _lSetStatus(AppLocalizations l) => l.adminActionSetStatus;
String _lCuration(AppLocalizations l) => l.adminActionCuration;
String _lTriage(AppLocalizations l) => l.adminActionTriage;
String _lDecideCase(AppLocalizations l) => l.adminActionDecideCase;
String _lDecideReport(AppLocalizations l) => l.adminActionDecideReport;
String _lSetCommissionStatus(AppLocalizations l) =>
    l.adminActionSetCommissionStatus;
String _lEditSetting(AppLocalizations l) => l.adminActionEditSetting;
String _lNewRule(AppLocalizations l) => l.adminActionNewRule;
String _lNewSetting(AppLocalizations l) => l.adminActionNewSetting;

String _lFieldRole(AppLocalizations l) => l.adminFieldRole;
String _lFieldStatus(AppLocalizations l) => l.formStatus;
String _lFieldPriority(AppLocalizations l) => l.adminFieldPriority;
String _lFieldReason(AppLocalizations l) => l.adminFieldReason;
String _lFieldResolution(AppLocalizations l) => l.adminFieldResolution;
String _lFieldFeatured(AppLocalizations l) => l.adminFieldFeatured;
String _lFieldShowInFeed(AppLocalizations l) => l.adminFieldShowInFeed;
String _lFieldSettingKey(AppLocalizations l) => l.adminFieldSettingKey;
String _lFieldSettingValue(AppLocalizations l) => l.adminFieldSettingValue;
String _lFieldSensitive(AppLocalizations l) => l.adminFieldSensitive;
String _lFieldRuleName(AppLocalizations l) => l.adminFieldRuleName;
String _lFieldRateBps(AppLocalizations l) => l.adminFieldRateBps;
String _lFieldCategory(AppLocalizations l) => l.adminFieldCategory;
String _lFieldSellerTier(AppLocalizations l) => l.adminFieldSellerTier;
String _lJsonHint(AppLocalizations l) => l.adminJsonHint;
String _lRateHint(AppLocalizations l) => l.adminRateHint;

/// The localized name of a status token, wherever it came from.
///
/// The console shows statuses from six different enums in the same column, so
/// the lookup is one flat table rather than six. A token with no entry falls
/// back to a readable form of itself instead of showing `NEEDS_MORE_DOCUMENTS`
/// to an Arabic-speaking operator.
String adminStatusLabel(AppLocalizations l10n, String token) {
  return switch (token.toUpperCase()) {
    'ACTIVE' => l10n.adminStatusActive,
    'DRAFT' => l10n.adminStatusDraft,
    'OUT_OF_STOCK' => l10n.adminStatusOutOfStock,
    'ARCHIVED' => l10n.adminStatusArchived,
    'OPEN' => l10n.adminStatusOpen,
    'PENDING' => l10n.adminStatusPending,
    'RESOLVED' => l10n.adminStatusResolved,
    'CLOSED' => l10n.adminStatusClosed,
    'APPROVED' => l10n.adminStatusApproved,
    'REJECTED' => l10n.adminStatusRejected,
    'ESCALATED' => l10n.adminStatusEscalated,
    'REVIEWING' || 'UNDER_REVIEW' => l10n.adminStatusReviewing,
    'DISMISSED' => l10n.adminStatusDismissed,
    'EARNED' => l10n.adminStatusEarned,
    'PAID' => l10n.adminStatusPaid,
    'REVERSED' => l10n.adminStatusReversed,
    'NOT_SUBMITTED' => l10n.adminStatusNotSubmitted,
    'NEEDS_MORE_DOCUMENTS' => l10n.verificationStatusNeedsMoreDocuments,
    'NEEDS_MORE_INFO' => l10n.verificationStatusNeedsMoreInfo,
    'SUSPENDED' => l10n.verificationStatusSuspended,
    'LOW' => l10n.adminPriorityLow,
    'NORMAL' => l10n.adminPriorityNormal,
    'HIGH' => l10n.adminPriorityHigh,
    'URGENT' => l10n.adminPriorityUrgent,
    'SUPER_ADMIN' => l10n.adminRoleSuperAdmin,
    'OPERATIONS_ADMIN' => l10n.adminRoleOperationsAdmin,
    'SUPPORT_ADMIN' => l10n.adminRoleSupportAdmin,
    'FINANCE_ADMIN' => l10n.adminRoleFinanceAdmin,
    'CONTENT_MODERATOR' => l10n.adminRoleContentModerator,
    'ADMIN' => l10n.adminRoleAdmin,
    'SUPPORT' => l10n.adminRoleSupport,
    'SELLER' => l10n.adminRoleSeller,
    'CUSTOMER' => l10n.adminRoleCustomer,
    _ => token
        .split(RegExp(r'[_\s]+'))
        .where((word) => word.isNotEmpty)
        .map((word) => '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}')
        .join(' '),
  };
}

/// The localized name of a summary counter.
///
/// Sections return a scalar or two beside their page — how many applications
/// are waiting, how much commission is unsettled — and the console renders
/// them as chips. Printed raw they read `open: 11` in the middle of an Arabic
/// screen, which is a debug line, not an answer.
String adminSummaryLabel(AppLocalizations l10n, String key) {
  return switch (key) {
    'open' => l10n.adminStatusOpen,
    'pending' => l10n.adminStatusPending,
    'pending_commission' => l10n.adminPendingCommission,
    'rules_count' => l10n.adminCommissionRules,
    _ => key
        .split(RegExp(r'[_\s]+'))
        .where((word) => word.isNotEmpty)
        .map(
          (word) => '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}',
        )
        .join(' '),
  };
}
