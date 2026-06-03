import 'package:equatable/equatable.dart';

class OrderEntity extends Equatable {
  const OrderEntity({
    required this.id,
    required this.status,
    required this.total,
    required this.itemsCount,
    required this.createdAt,
  });

  final String id;
  final String status;
  final double total;
  final int itemsCount;
  final DateTime createdAt;

  @override
  List<Object?> get props => [id, status, total, itemsCount, createdAt];
}
