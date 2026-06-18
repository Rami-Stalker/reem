import 'package:equatable/equatable.dart';

/// Order status buckets surfaced on the profile, mirroring the spec
/// (pending / processing / delivered / cancelled).
class OrdersOverview extends Equatable {
  const OrdersOverview({
    this.pending = 0,
    this.processing = 0,
    this.delivered = 0,
    this.cancelled = 0,
  });

  final int pending;
  final int processing;
  final int delivered;
  final int cancelled;

  int get total => pending + processing + delivered + cancelled;
  int get active => pending + processing;

  @override
  List<Object?> get props => [pending, processing, delivered, cancelled];
}
