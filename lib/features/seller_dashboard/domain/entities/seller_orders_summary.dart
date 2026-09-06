import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

import 'package:reem/core/design_system/foundation/tokens/ds_tone.dart';

class SellerOrdersSummary extends Equatable {
  const SellerOrdersSummary({
    required this.newOrders,
    required this.processing,
    required this.readyForShipment,
    required this.delivered,
    required this.cancelled,
    required this.returned,
  });

  final int newOrders;
  final int processing;
  final int readyForShipment;
  final int delivered;
  final int cancelled;
  final int returned;

  int get total =>
      newOrders + processing + readyForShipment + delivered + cancelled + returned;

  @override
  List<Object?> get props =>
      [newOrders, processing, readyForShipment, delivered, cancelled, returned];
}

enum SellerOrderStatus {
  newOrders,
  processing,
  readyForShipment,
  delivered,
  cancelled,
  returned,
}

extension SellerOrderStatusX on SellerOrderStatus {
  String get label => switch (this) {
        SellerOrderStatus.newOrders => 'New',
        SellerOrderStatus.processing => 'Processing',
        SellerOrderStatus.readyForShipment => 'Ready',
        SellerOrderStatus.delivered => 'Delivered',
        SellerOrderStatus.cancelled => 'Cancelled',
        SellerOrderStatus.returned => 'Returned',
      };

  DsTone get tone => switch (this) {
        SellerOrderStatus.newOrders => DsTone.info,
        SellerOrderStatus.processing => DsTone.caution,
        SellerOrderStatus.readyForShipment => DsTone.accent,
        SellerOrderStatus.delivered => DsTone.positive,
        SellerOrderStatus.cancelled => DsTone.critical,
        SellerOrderStatus.returned => DsTone.reversal,
      };

  IconData get icon => switch (this) {
        SellerOrderStatus.newOrders => Icons.fiber_new_rounded,
        SellerOrderStatus.processing => Icons.autorenew_rounded,
        SellerOrderStatus.readyForShipment => Icons.local_shipping_outlined,
        SellerOrderStatus.delivered => Icons.check_circle_outline_rounded,
        SellerOrderStatus.cancelled => Icons.cancel_outlined,
        SellerOrderStatus.returned => Icons.keyboard_return_rounded,
      };

  int countOf(SellerOrdersSummary summary) => switch (this) {
        SellerOrderStatus.newOrders => summary.newOrders,
        SellerOrderStatus.processing => summary.processing,
        SellerOrderStatus.readyForShipment => summary.readyForShipment,
        SellerOrderStatus.delivered => summary.delivered,
        SellerOrderStatus.cancelled => summary.cancelled,
        SellerOrderStatus.returned => summary.returned,
      };
}
