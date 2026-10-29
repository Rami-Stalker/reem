// Renders the conversation inbox and its states to PNGs, and asserts that the
// rows carry real thread data.
//
// The screen this replaced was a static mock: four hard-coded boutiques with
// Unsplash portraits and `onTap: () {}`. Nothing in the suite noticed, because
// nothing ever built it. These tests build it against a fake repository, so a
// row that stops reading its thread — or a token that does not exist — fails
// here rather than on somebody's phone.
//
//   flutter test test/chat_inbox_visual_preview_test.dart
import 'dart:io';
import 'dart:ui' show ImageByteFormat;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:ohara/core/design_system/design_system.dart';
import 'package:ohara/core/errors/failure.dart';
import 'package:ohara/core/localization/app_localizations.dart';
import 'package:ohara/core/result/result.dart';
import 'package:ohara/features/chat/domain/entities/chat_message_entity.dart';
import 'package:ohara/features/chat/domain/entities/chat_start_request.dart';
import 'package:ohara/features/chat/domain/entities/chat_thread_entity.dart';
import 'package:ohara/features/chat/domain/repositories/chat_repository.dart';
import 'package:ohara/features/chat/presentation/providers/chat_provider.dart';
import 'package:ohara/features/chat/presentation/screens/chat_details_screen.dart';
import 'package:ohara/features/chat/presentation/screens/chats_screen.dart';
import 'package:ohara/l10n/app_localizations.dart' as gen;

final _captureKey = GlobalKey();

final _now = DateTime(2026, 8, 31, 15, 30);

final _threads = <ChatThreadEntity>[
  ChatThreadEntity(
    id: 't1',
    title: 'أتيليه لجين',
    avatarUrl: '',
    peerId: 's1',
    peerName: 'أتيليه لجين',
    lastMessage: 'طلبكِ جاهز للشحن غداً صباحاً',
    unreadCount: 3,
    updatedAt: _now.subtract(const Duration(minutes: 8)),
    context: ChatContext.order,
    sellerOrderId: 'so-1',
    isOnline: true,
  ),
  ChatThreadEntity(
    id: 't2',
    title: 'فستان سهرة مطرّز',
    avatarUrl: '',
    peerId: 's2',
    peerName: 'بوتيك الوردة',
    lastMessage: 'نعم، المقاس M متوفر بلونين',
    unreadCount: 0,
    updatedAt: _now.subtract(const Duration(hours: 5)),
    context: ChatContext.product,
    productId: 'p-1',
    lastSeenAt: _now.subtract(const Duration(hours: 2)),
  ),
  ChatThreadEntity(
    id: 't3',
    title: 'دار نور',
    avatarUrl: '',
    peerId: 's3',
    peerName: 'دار نور',
    // A conversation nobody has written in yet — opened from a product page
    // and then left. It must not render as a blank row.
    lastMessage: '',
    unreadCount: 0,
    updatedAt: _now.subtract(const Duration(days: 3)),
  ),
];

void _stubPlatformChannels() {
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  messenger.setMockMethodCallHandler(
    const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
    (call) async => call.method == 'readAll' ? <String, String>{} : null,
  );
}

Future<void> _loadFonts() async {
  for (final entry in const {
    'Cairo': 'assets/fonts/Cairo-VariableFont.ttf',
    'PlayfairDisplay': 'assets/fonts/PlayfairDisplay-VariableFont.ttf',
  }.entries) {
    final loader = FontLoader(entry.key)
      ..addFont(
        File(entry.value).readAsBytes().then((b) => ByteData.view(b.buffer)),
      );
    await loader.load();
  }
}

ChatMessageEntity _msg(
  String id,
  String text, {
  required bool mine,
  required DateTime at,
  bool read = false,
}) => ChatMessageEntity(
  id: id,
  chatId: 't1',
  senderId: mine ? 'me' : 's1',
  content: text,
  sentAt: at,
  isMine: mine,
  deliveredAt: mine ? at : null,
  readAt: mine && read ? at : null,
);

final _conversation = <ChatMessageEntity>[
  _msg(
    'm1',
    'مرحباً، هل الفستان المطرّز متوفر بالمقاس M؟',
    mine: true,
    at: _now.subtract(const Duration(days: 1, hours: 2)),
    read: true,
  ),
  _msg(
    'm2',
    'أهلاً بكِ! نعم متوفر، وعندنا منه لونان: خمري وكحلي.',
    mine: false,
    at: _now.subtract(const Duration(days: 1, hours: 1, minutes: 50)),
  ),
  _msg(
    'm3',
    'رائع، سآخذ الخمري',
    mine: true,
    at: _now.subtract(const Duration(minutes: 40)),
    read: true,
  ),
  _msg(
    'm4',
    'وهل يمكن تقصيره قليلاً؟',
    mine: true,
    at: _now.subtract(const Duration(minutes: 39)),
    read: true,
  ),
  _msg(
    'm5',
    'طبعاً، التقصير مجاني.',
    mine: false,
    at: _now.subtract(const Duration(minutes: 12)),
  ),
  _msg(
    'm6',
    'طلبكِ جاهز للشحن غداً صباحاً 🌸',
    mine: false,
    at: _now.subtract(const Duration(minutes: 8)),
  ),
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    _stubPlatformChannels();
    await _loadFonts();
  });

  for (final mode in [ThemeMode.light, ThemeMode.dark]) {
    testWidgets('renders the conversation inbox in ${mode.name}', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1125, 2436);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        _Preview(themeMode: mode, repository: _FakeChats(_threads)),
      );
      await _settle(tester);

      // Every row must come from the repository. If these names are missing,
      // the screen has drifted back to showing something it invented.
      //
      // The **peer name**, not the thread's `title`. `title` is the subject a
      // conversation was opened about, and for an order chat the server sends
      // "Order #REEM-…" — so a tile that preferred it turned the inbox into a
      // column of English order numbers with nobody's name on any of them.
      // `ChatTile` was fixed to show the person; this assertion was left
      // behind asserting the fault, and has been failing ever since.
      //
      // «أتيليه لجين» is online, so her name is also under her portrait on
      // the «متّصلات الآن» rail: once on the rail, once on her row.
      expect(find.text('أتيليه لجين'), findsNWidgets(2));
      expect(find.text('بوتيك الوردة'), findsOneWidget);
      expect(find.text('نعم، المقاس M متوفر بلونين'), findsOneWidget);

      // The unread count is the thread's, not a decoration.
      expect(find.text('3'), findsOneWidget);

      // A product thread says so, so two conversations with one boutique are
      // told apart before she opens either.
      expect(find.text('بخصوص طلب'), findsOneWidget);
      expect(find.text('بخصوص منتج'), findsOneWidget);

      // An empty conversation says it is empty rather than rendering nothing.
      expect(find.text('ما في رسايل لسّا'), findsOneWidget);

      await _capture(tester, 'chat_inbox_${mode.name}');
    });
  }

  for (final mode in [ThemeMode.light, ThemeMode.dark]) {
    testWidgets('renders a conversation in ${mode.name}', (tester) async {
      tester.view.physicalSize = const Size(1125, 2436);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        _Preview(
          themeMode: mode,
          repository: _FakeChats(_threads, messages: _conversation),
          screen: const ChatDetailsScreen(chatId: 't1'),
        ),
      );
      await _settle(tester);

      // Every message is on screen, in its own words.
      expect(find.text('رائع، سآخذ الخمري'), findsOneWidget);
      expect(find.text('طبعاً، التقصير مجاني.'), findsOneWidget);

      await _capture(tester, 'chat_conversation_${mode.name}');
    });
  }

  testWidgets('an empty conversation offers a first question', (tester) async {
    tester.view.physicalSize = const Size(1125, 2436);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      _Preview(
        themeMode: ThemeMode.light,
        repository: _FakeChats(_threads),
        screen: const ChatDetailsScreen(chatId: 't1'),
      ),
    );
    await _settle(tester);

    expect(find.text('القطعة متوفرة؟'), findsOneWidget);

    await _capture(tester, 'chat_conversation_empty');
  });

  testWidgets('an inbox with no conversations offers a way to start one', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1125, 2436);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      _Preview(themeMode: ThemeMode.light, repository: _FakeChats(const [])),
    );
    await _settle(tester);

    expect(find.text('ما في محادثات لسّا'), findsOneWidget);
    // A dead end here is how the old build felt: the empty state has to point
    // at the boutiques, because that is where a conversation actually starts.
    expect(find.text('اتفرّجي عالمتاجر'), findsOneWidget);

    await _capture(tester, 'chat_inbox_empty');
  });

  testWidgets('a failed load offers a retry rather than an empty list', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1125, 2436);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      _Preview(
        themeMode: ThemeMode.light,
        repository: _FakeChats(const [], fails: true),
      ),
    );
    await _settle(tester);

    expect(find.text('ما قدرنا نحمّل المحادثات'), findsOneWidget);
    expect(find.text('جرّبي مرة تانية'), findsWidgets);

    await _capture(tester, 'chat_inbox_error');
  });
}

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  for (var i = 0; i < 12; i++) {
    await tester.pump(const Duration(milliseconds: 120));
  }
}

Future<void> _capture(WidgetTester tester, String name) async {
  await tester.runAsync(() async {
    final boundary =
        _captureKey.currentContext!.findRenderObject()!
            as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 2);
    final data = await image.toByteData(format: ImageByteFormat.png);
    final dir = Directory('build/visual')..createSync(recursive: true);
    final file = File('${dir.path}/$name.png')
      ..writeAsBytesSync(data!.buffer.asUint8List());
    // ignore: avoid_print
    print('wrote ${file.path}');
  });
}

class _Preview extends StatelessWidget {
  _Preview({
    required this.themeMode,
    required this.repository,
    this.screen = const ChatsScreen(),
  });

  final ThemeMode themeMode;
  final ChatRepository repository;
  final Widget screen;

  late final GoRouter _router = GoRouter(
    initialLocation: '/chats',
    routes: [
      GoRoute(
        path: '/chats',
        builder: (_, _) => RepaintBoundary(key: _captureKey, child: screen),
      ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      overrides: [chatRepositoryProvider.overrideWithValue(repository)],
      child: MaterialApp.router(
        debugShowCheckedModeBanner: false,
        themeMode: themeMode,
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        locale: const Locale('ar'),
        supportedLocales: L10nSetup.supportedLocales,
        localizationsDelegates: const [
          gen.AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        routerConfig: _router,
      ),
    );
  }
}

class _FakeChats implements ChatRepository {
  const _FakeChats(
    this.threads, {
    this.fails = false,
    this.messages = const [],
  });

  final List<ChatThreadEntity> threads;
  final bool fails;
  final List<ChatMessageEntity> messages;

  @override
  Future<Result<List<ChatThreadEntity>>> getThreads({String? query}) async {
    if (fails) return const Error(NetworkFailure('لا يوجد اتصال'));
    final term = query?.trim() ?? '';
    if (term.isEmpty) return Success(threads);
    return Success(threads.where((t) => t.title.contains(term)).toList());
  }

  @override
  Future<Result<ChatThreadEntity>> getThread(String chatId) async =>
      Success(threads.firstWhere((t) => t.id == chatId));

  @override
  Future<Result<ChatThreadEntity>> startConversation(
    ChatStartRequest request,
  ) async => Success(threads.first);

  @override
  Future<Result<List<ChatMessageEntity>>> getMessages(
    String chatId, {
    DateTime? before,
    int limit = 50,
    String? currentUserId,
  }) async => Success(messages);

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      Future.value(const Error<Never>(ServerFailure('not used in this test')));
}
