import 'package:flutter/material.dart';

import 'package:ohara/core/design_system/design_system.dart';
import 'package:ohara/core/localization/l10n_extension.dart';
import 'package:ohara/features/seller_returns/domain/entities/return_request.dart';
import 'package:ohara/features/seller_returns/presentation/providers/seller_returns_provider.dart';

/// Every seller-facing word for a return, in one place.
///
/// The wire values are English SCREAMING_CASE and the interface is Arabic, so
/// this is the seam where one becomes the other. It is an extension on
/// [BuildContext] rather than getters on the enums: the enums live in the
/// domain layer, and a domain type that reaches for `AppLocalizations` cannot
/// be tested without a widget tree.
extension ReturnLabels on BuildContext {
  String returnStatusLabel(ReturnStatus status) => switch (status) {
    ReturnStatus.requested => l10n.returnStatusRequested,
    ReturnStatus.approved => l10n.returnStatusApproved,
    ReturnStatus.inTransit => l10n.returnStatusInTransit,
    ReturnStatus.received => l10n.returnStatusReceived,
    ReturnStatus.refunded => l10n.returnStatusRefunded,
    ReturnStatus.exchanged => l10n.returnStatusExchanged,
    ReturnStatus.rejected => l10n.returnStatusRejected,
    ReturnStatus.cancelled => l10n.returnStatusCancelled,
  };

  /// The colour carries the same meaning everywhere in the seller's app:
  /// warning is "your move", positive is "settled", critical is "it ended
  /// badly", muted is "nothing left to do".
  Color returnStatusColor(ReturnStatus status) {
    final palette = atelier;
    return switch (status) {
      ReturnStatus.requested => palette.caution,
      ReturnStatus.approved || ReturnStatus.inTransit => palette.primary,
      ReturnStatus.received => palette.caution,
      ReturnStatus.refunded || ReturnStatus.exchanged => palette.positive,
      ReturnStatus.rejected => palette.critical,
      ReturnStatus.cancelled => palette.muted,
    };
  }

  String returnReasonLabel(ReturnReason reason) => switch (reason) {
    ReturnReason.defective => l10n.returnReasonDefective,
    ReturnReason.wrongItem => l10n.returnReasonWrongItem,
    ReturnReason.notAsDescribed => l10n.returnReasonNotAsDescribed,
    ReturnReason.damagedInTransit => l10n.returnReasonDamagedInTransit,
    ReturnReason.changedMind => l10n.returnReasonChangedMind,
    ReturnReason.sizeIssue => l10n.returnReasonSizeIssue,
    ReturnReason.lateDelivery => l10n.returnReasonLateDelivery,
    ReturnReason.other => l10n.returnReasonOther,
  };

  String returnActionLabel(ReturnAction action) => switch (action) {
    ReturnAction.approve => l10n.returnActionApprove,
    ReturnAction.reject => l10n.returnActionReject,
    ReturnAction.markInTransit => l10n.returnActionInTransit,
    ReturnAction.receive => l10n.returnActionReceive,
    ReturnAction.exchange => l10n.returnActionExchange,
    ReturnAction.exchangeDelivered => l10n.returnActionExchangeDelivered,
  };

  IconData returnActionIcon(ReturnAction action) => switch (action) {
    ReturnAction.approve => Icons.check_circle_outline_rounded,
    ReturnAction.reject => Icons.block_rounded,
    ReturnAction.markInTransit => Icons.local_shipping_outlined,
    ReturnAction.receive => Icons.inventory_outlined,
    ReturnAction.exchange => Icons.swap_horiz_rounded,
    ReturnAction.exchangeDelivered => Icons.done_all_rounded,
  };

  String returnBearerLabel(ReturnCostBearer bearer) => switch (bearer) {
    ReturnCostBearer.customer => l10n.returnBearerCustomer,
    ReturnCostBearer.seller => l10n.returnBearerSeller,
    ReturnCostBearer.platform => l10n.returnBearerPlatform,
  };

  String returnTabLabel(ReturnQueueTab tab) => switch (tab) {
    ReturnQueueTab.open => l10n.returnsTabOpen,
    ReturnQueueTab.awaitingRefund => l10n.returnsTabAwaiting,
    ReturnQueueTab.closed => l10n.returnsTabClosed,
  };

  String returnTabEmptyTitle(ReturnQueueTab tab) => switch (tab) {
    ReturnQueueTab.open => l10n.returnsEmptyOpen,
    ReturnQueueTab.awaitingRefund => l10n.returnsEmptyAwaiting,
    ReturnQueueTab.closed => l10n.returnsEmptyClosed,
  };
}
