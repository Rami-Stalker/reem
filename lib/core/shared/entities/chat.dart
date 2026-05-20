import 'package:equatable/equatable.dart';
import 'user.dart';

class Chat extends Equatable {
  final String id;
  final User sender;
  final User receiver;
  final String message;
  final bool isSeen;
  final DateTime createdAt;

  const Chat({
    required this.id,
    required this.sender,
    required this.receiver,
    required this.message,
    required this.isSeen,
    required this.createdAt,
  });

  @override
  List<Object?> get props => [
        id,
        sender,
        receiver,
        message,
        isSeen,
        createdAt,
      ];
}