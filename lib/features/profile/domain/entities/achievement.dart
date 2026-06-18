import 'package:equatable/equatable.dart';
import 'package:flutter/widgets.dart';

/// A gamified profile badge. The app owns the catalogue (icon + copy); the
/// backend only needs to say which are [earned].
class Achievement extends Equatable {
  const Achievement({
    required this.id,
    required this.label,
    required this.description,
    required this.icon,
    this.earned = false,
  });

  final String id;
  final String label;
  final String description;
  final IconData icon;
  final bool earned;

  @override
  List<Object?> get props => [id, label, description, icon, earned];
}
