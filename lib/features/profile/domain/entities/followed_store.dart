import 'package:equatable/equatable.dart';

/// A boutique the customer follows, shown as an avatar in the profile rail.
class FollowedStore extends Equatable {
  const FollowedStore({
    required this.id,
    required this.name,
    required this.logoUrl,
    this.isVerified = false,
    this.newCount = 0,
  });

  final String id;
  final String name;
  final String logoUrl;
  final bool isVerified;

  /// New arrivals since the last visit — drives a count badge.
  final int newCount;

  @override
  List<Object?> get props => [id, name, logoUrl, isVerified, newCount];
}
