import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import 'package:reem/core/presentation/providers/core_providers.dart';
import 'package:reem/features/chat/data/datasources/chat_remote_datasource.dart';
import 'package:reem/features/chat/data/datasources/impl/chat_remote_datasource_impl.dart';
import 'package:reem/features/chat/data/repositories/chat_repository_impl.dart';
import 'package:reem/features/chat/data/services/chat_realtime_service.dart';
import 'package:reem/features/chat/domain/repositories/chat_repository.dart';
import 'package:reem/features/chat/domain/usecases/get_messages_usecase.dart';
import 'package:reem/features/chat/domain/usecases/get_threads_usecase.dart';
import 'package:reem/features/chat/domain/usecases/send_message_usecase.dart';
import 'package:reem/features/chat/presentation/providers/chat_notifier.dart';
import 'package:reem/features/chat/presentation/providers/chat_state.dart';

final chatRemoteDataSourceProvider = Provider<ChatRemoteDataSource>(
  (ref) => ChatRemoteDataSourceImpl(ref.watch(dioProvider)),
);

final chatRepositoryProvider = Provider<ChatRepository>(
  (ref) => ChatRepositoryImpl(remote: ref.watch(chatRemoteDataSourceProvider)),
);

final chatRealtimeServiceProvider = Provider<ChatRealtimeService>((ref) {
  final service = ChatRealtimeService(ref.watch(secureStorageProvider));
  ref.onDispose(() {
    service.disconnect();
  });
  return service;
});

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
