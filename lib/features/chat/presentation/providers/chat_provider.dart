import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import 'package:reem/core/presentation/providers/core_providers.dart';
import 'package:reem/features/auth/presentation/providers/auth_provider.dart';
import 'package:reem/features/chat/data/datasources/chat_remote_datasource.dart';
import 'package:reem/features/chat/data/datasources/impl/chat_remote_datasource_impl.dart';
import 'package:reem/features/chat/data/repositories/chat_repository_impl.dart';
import 'package:reem/features/chat/data/services/chat_realtime_service.dart';
import 'package:reem/features/chat/domain/repositories/chat_repository.dart';
import 'package:reem/features/chat/domain/usecases/get_messages_usecase.dart';
import 'package:reem/features/chat/domain/usecases/get_thread_usecase.dart';
import 'package:reem/features/chat/domain/usecases/get_threads_usecase.dart';
import 'package:reem/features/chat/domain/usecases/mark_chat_read_usecase.dart';
import 'package:reem/features/chat/domain/usecases/send_message_usecase.dart';
import 'package:reem/features/chat/domain/usecases/start_conversation_usecase.dart';
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
  // Back from the background: reconnect now instead of at whatever backoff
  // step the retries reached while the phone was asleep.
  final lifecycle = AppLifecycleListener(onResume: service.reconnectNow);
  ref.onDispose(() {
    lifecycle.dispose();
    service.disconnect();
  });
  return service;
});

final getThreadsUseCaseProvider = Provider(
  (ref) => GetThreadsUseCase(ref.watch(chatRepositoryProvider)),
);

final getThreadUseCaseProvider = Provider(
  (ref) => GetThreadUseCase(ref.watch(chatRepositoryProvider)),
);

final startConversationUseCaseProvider = Provider(
  (ref) => StartConversationUseCase(ref.watch(chatRepositoryProvider)),
);

final getMessagesUseCaseProvider = Provider(
  (ref) => GetMessagesUseCase(ref.watch(chatRepositoryProvider)),
);

final sendMessageUseCaseProvider = Provider(
  (ref) => SendMessageUseCase(ref.watch(chatRepositoryProvider)),
);

final markChatReadUseCaseProvider = Provider(
  (ref) => MarkChatReadUseCase(ref.watch(chatRepositoryProvider)),
);

/// The signed-in account's id — what decides which messages are hers.
final chatCurrentUserIdProvider = Provider<String?>(
  (ref) => ref.watch(authNotifierProvider.select((s) => s.user?.id)),
);

final chatNotifierProvider =
    StateNotifierProvider<ChatNotifier, ChatState>((ref) {
  return ChatNotifier(
    getThreadsUseCase: ref.watch(getThreadsUseCaseProvider),
    startConversationUseCase: ref.watch(startConversationUseCaseProvider),
    currentUserId: ref.watch(chatCurrentUserIdProvider),
  );
});

/// The conversation header, keyed by chat id. `autoDispose` so leaving a
/// conversation forgets it — the peer's presence is stale the moment she does.
final chatThreadNotifierProvider = StateNotifierProvider.autoDispose
    .family<ChatThreadNotifier, ChatThreadState, String>(
  (ref, chatId) => ChatThreadNotifier(
    getThreadUseCase: ref.watch(getThreadUseCaseProvider),
  )..load(chatId),
);

/// One conversation's messages, keyed by chat id — see [ChatMessagesNotifier]
/// for why it is no longer one instance shared by every conversation.
/// `autoDispose`: leaving the conversation (and its media gallery) forgets it.
final chatMessagesNotifierProvider = StateNotifierProvider.autoDispose
    .family<ChatMessagesNotifier, ChatMessagesState, String>((ref, chatId) {
  return ChatMessagesNotifier(
    chatId: chatId,
    getMessagesUseCase: ref.watch(getMessagesUseCaseProvider),
    sendMessageUseCase: ref.watch(sendMessageUseCaseProvider),
    markChatReadUseCase: ref.watch(markChatReadUseCaseProvider),
    currentUserId: ref.watch(chatCurrentUserIdProvider),
  );
});
