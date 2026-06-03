import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../../../core/providers/core_providers.dart';
import '../../data/datasources/chat_remote_datasource.dart';
import '../../data/datasources/impl/chat_remote_datasource_impl.dart';
import '../../data/repositories/chat_repository_impl.dart';
import '../../domain/repositories/chat_repository.dart';
import '../../domain/usecases/get_messages_usecase.dart';
import '../../domain/usecases/get_threads_usecase.dart';
import '../../domain/usecases/send_message_usecase.dart';
import 'chat_notifier.dart';
import 'chat_state.dart';

final chatRemoteDataSourceProvider = Provider<ChatRemoteDataSource>(
  (ref) => ChatRemoteDataSourceImpl(ref.watch(dioProvider)),
);

final chatRepositoryProvider = Provider<ChatRepository>(
  (ref) => ChatRepositoryImpl(remote: ref.watch(chatRemoteDataSourceProvider)),
);

final getThreadsUseCaseProvider = Provider(
  (ref) => GetThreadsUseCase(ref.watch(chatRepositoryProvider)),
);

final getMessagesUseCaseProvider = Provider(
  (ref) => GetMessagesUseCase(ref.watch(chatRepositoryProvider)),
);

final sendMessageUseCaseProvider = Provider(
  (ref) => SendMessageUseCase(ref.watch(chatRepositoryProvider)),
);

final chatNotifierProvider =
    StateNotifierProvider<ChatNotifier, ChatState>((ref) {
  return ChatNotifier(
    getThreadsUseCase: ref.watch(getThreadsUseCaseProvider),
  );
});

final chatMessagesNotifierProvider =
    StateNotifierProvider<ChatMessagesNotifier, ChatMessagesState>((ref) {
  return ChatMessagesNotifier(
    getMessagesUseCase: ref.watch(getMessagesUseCaseProvider),
    sendMessageUseCase: ref.watch(sendMessageUseCaseProvider),
  );
});
