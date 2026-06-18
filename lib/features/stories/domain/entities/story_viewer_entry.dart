import 'package:equatable/equatable.dart';
import 'package:reem/core/shared/entities/user.dart';

class StoryViewerEntry extends Equatable {
  final User user;
  final DateTime viewedAt;
  final String? reaction;

  const StoryViewerEntry({
    required this.user,
    required this.viewedAt,
    this.reaction,
  });

  @override
  List<Object?> get props => [user, viewedAt, reaction];
}
