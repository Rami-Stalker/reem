import 'package:ohara/core/result/result.dart';

import 'package:ohara/features/chat/domain/entities/chat_message_entity.dart';
import 'package:ohara/features/chat/domain/repositories/chat_repository.dart';

class SendMessageUseCase {
  const SendMessageUseCase(this._repository);
  final ChatRepository _repository;

  Future<Result<ChatMessageEntity>> call({
    required String chatId,
    required String content,
    String kind = 'TEXT',
    List<Map<String, dynamic>> attachments = const [],
    String? clientId,
    String? currentUserId,
    String? productId,
    String? orderId,
  }) => _repository.sendMessage(
    chatId: chatId,
    content: content,
    kind: kind,
    attachments: attachments,
    clientId: clientId,
    currentUserId: currentUserId,
    productId: productId,
    orderId: orderId,
  );
}
