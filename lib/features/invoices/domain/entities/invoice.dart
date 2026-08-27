import 'package:equatable/equatable.dart';

import 'package:reem/core/shared/value_objects/money.dart';

/// Q51 — «الاثنين»: one invoice for the whole order, one per seller.
enum InvoiceKind {
  /// The customer's copy: everything she paid, across every seller.
  order,

  /// A seller's copy: their own parcel, carrying the commission.
  sellerOrder;

  static InvoiceKind fromWire(String? value) => switch (value) {
    'SELLER_ORDER' => InvoiceKind.sellerOrder,
    _ => InvoiceKind.order,
  };
}

/// One line, read from the order item that was snapshotted at checkout.
class InvoiceLine extends Equatable {
  const InvoiceLine({
    required this.title,
    required this.quantity,
    required this.unitPrice,
    required this.unitDiscount,
    required this.lineTotal,
    this.variant,
    this.seller,
  });

  final String title;
  final String? variant;
  final String? seller;
  final int quantity;
  final Money unitPrice;
  final Money unitDiscount;
  final Money lineTotal;

  bool get isDiscounted => !unitDiscount.isZero;

  @override
  List<Object?> get props => [title, variant, quantity, lineTotal];
}

/// Where the parcel was sent — a snapshot taken at checkout, never a live join.
class InvoiceRecipient extends Equatable {
  const InvoiceRecipient({
    required this.name,
    required this.phone,
    required this.governorate,
    required this.city,
    required this.addressLine,
  });

  final String name;
  final String phone;
  final String governorate;
  final String city;
  final String addressLine;

  String get fullAddress => [
    addressLine,
    city,
    governorate,
  ].where((part) => part.isNotEmpty).join('، ');

  @override
  List<Object?> get props => [name, phone, addressLine];
}

/// A charge, as a document.
///
/// Q55 P1 answered «لا» to needing a tax invoice, so this is a commercial
/// record — what was charged and by whom — with no VAT line and no fiscal
/// numbering. Building either would show the customer obligations the
/// platform does not have.
class Invoice extends Equatable {
  const Invoice({
    required this.id,
    required this.number,
    required this.kind,
    required this.issuedAt,
    required this.orderNumber,
    required this.currency,
    required this.itemsSubtotal,
    required this.discountTotal,
    required this.shippingTotal,
    required this.grandTotal,
    this.sellerOrderNumber,
    this.placedAt,
    this.recipient,
    this.couponCode,
    this.commissionAmount,
    this.sellerNet,
    this.lines = const [],
  });

  final String id;
  final String number;
  final InvoiceKind kind;
  final DateTime issuedAt;

  final String orderNumber;
  final String? sellerOrderNumber;
  final DateTime? placedAt;
  final InvoiceRecipient? recipient;
  final String? couponCode;

  final Currency currency;
  final Money itemsSubtotal;
  final Money discountTotal;
  final Money shippingTotal;
  final Money grandTotal;

  /// Present only on a seller's copy. What the platform took (Q50) is between
  /// the platform and the seller; on the customer's document it would only
  /// obscure the figure she actually paid.
  final Money? commissionAmount;
  final Money? sellerNet;

  final List<InvoiceLine> lines;

  bool get isSellerCopy => kind == InvoiceKind.sellerOrder;
  bool get hasDiscount => !discountTotal.isZero;
  bool get showsCommission => commissionAmount != null;

  @override
  List<Object?> get props => [id, number, kind, grandTotal];
}

/// A row in the list of documents raised against one order.
class InvoiceSummary extends Equatable {
  const InvoiceSummary({
    required this.id,
    required this.number,
    required this.kind,
    required this.issuedAt,
    required this.grandTotal,
  });

  final String id;
  final String number;
  final InvoiceKind kind;
  final DateTime issuedAt;
  final Money grandTotal;

  @override
  List<Object?> get props => [id, number, kind];
}
