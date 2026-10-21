import 'package:reem/core/result/result.dart';

import 'package:reem/features/chat/domain/entities/chat_message_entity.dart';
import 'package:reem/features/chat/domain/repositories/chat_repository.dart';

class SendMessageUseCase {
  const SendMessageUseCase(this._repository);
  final ChatRepository _repository;

  Future<Result<ChatMessageEntity>> call({
    required String chatId,
    required String content,
    String kind = 'TEXT',
    List<Map<String, dynamic>> attachments = const [],
    String? clientId,
  }) =>
      _repository.sendMessage(
        chatId: chatId,
        content: content,
        kind: kind,
        attachments: attachments,
        clientId: clientId,
      );
}
