import 'package:equatable/equatable.dart';

import 'package:ohara/core/shared/entities/product.dart';

/// A "pick up where you left off" entry — a product the customer was engaging
/// with, plus a short contextual note ("In your bag", "Back in stock").
class ContinueShoppingItem extends Equatable {
  const ContinueShoppingItem({
    required this.product,
    required this.note,
  });

  final Product product;
  final String note;

  @override
  List<Object?> get props => [product, note];
}
