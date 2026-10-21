// Sending a photograph into a conversation.
//
// What this pins is the difference between the screen as it was and as it is.
// It used to ask her to type a URL, and its "voice note" button posted a
// message pointing at `voice://pending-<timestamp>` — a real message in a real
// conversation, referring to nothing. The flow now picks, uploads, and sends
// what the server actually stored, and refuses cleanly when it cannot.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:reem/core/config/app_env.dart';
import 'package:reem/core/design_system/design_system.dart';
import 'package:reem/core/errors/failure.dart';
import 'package:reem/core/localization/app_localizations.dart';
import 'package:reem/core/media/authorized_media_image.dart';
import 'package:reem/core/media/media_asset.dart';
import 'package:reem/core/media/media_limits.dart';
import 'package:reem/core/media/media_providers.dart';
import 'package:reem/core/media/media_upload_service.dart';
import 'package:reem/core/media/voice_recorder_service.dart';
import 'package:reem/core/result/result.dart';
import 'package:reem/core/storage/secure_storage_service.dart';
import 'package:reem/features/chat/data/services/chat_realtime_service.dart';
import 'package:reem/features/chat/domain/entities/chat_message_entity.dart';
import 'package:reem/features/chat/domain/entities/chat_thread_entity.dart';
import 'package:reem/features/chat/domain/repositories/chat_repository.dart';
import 'package:reem/features/chat/presentation/providers/chat_provider.dart';
import 'package:reem/features/chat/presentation/screens/chat_details_screen.dart';
import 'package:reem/features/chat/presentation/widgets/chat_input.dart';
import 'package:reem/features/chat/presentation/widgets/file_message_bubble.dart';
import 'package:reem/features/chat/presentation/widgets/image_message_bubble.dart';
import 'package:reem/features/chat/presentation/widgets/voice_message_bubble.dart';
import 'package:reem/l10n/app_localizations.dart' as gen;
import 'package:reem/l10n/app_localizations_ar.dart';

final _ar = AppLocalizationsAr();

/// A real 1×1 PNG, so `Image.memory` and the decoder are happy.
final Uint8List _png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAC'
  'hwGA60e6kgAAAABJRU5ErkJggg==',
);

/// Enough of a PDF for the picker's guess; the server does the real sniffing.
final Uint8List _pdf = Uint8List.fromList('%PDF-1.7'.codeUnits);

const _privateUrl =
    'http://host/media/3f4a9c1e-1b2d-4e5f-8a90-abcdef012345/file';

void main() {
  // The conversation's chrome still carries mock avatar URLs, and a widget
  // test answers every network image with a 400 — which surfaces as a test
  // failure rather than the broken-image glyph it would be on a device.
  // Serving a real pixel instead keeps the assertions about the code under
  // test rather than about the sandbox's network.
  setUpAll(() => HttpOverrides.global = _AlwaysAPixel());
  tearDownAll(() => HttpOverrides.global = null);

  group('private media URLs', () {
    test('an authorised media path is recognised', () {
      // This decides whether the bearer token is attached. Get it wrong and
      // every photograph in every conversation is a broken box.
      expect(
        AuthorizedMediaImage.isPrivate(
          '${AppEnv.baseUrl}/media/3f4a9c1e-1b2d-4e5f-8a90-abcdef012345/file',
        ),
        isTrue,
      );
    });

    test('the same path on another host gets no token', () {
      // A chat attachment URL is text the sender wrote. Matching on the path
      // alone would send the reader's session to whoever wrote it.
      expect(
        AuthorizedMediaImage.isPrivate(
          'https://attacker.example/media/3f4a9c1e-1b2d-4e5f-8a90-abcdef012345/file',
        ),
        isFalse,
      );
    });

    test('a public upload and an external link are not', () {
      expect(
        AuthorizedMediaImage.isPrivate('http://host/media/files/2026/08/a.png'),
        isFalse,
      );
      expect(
        AuthorizedMediaImage.isPrivate('https://images.unsplash.com/photo-1'),
        isFalse,
      );
    });
  });

  group('ImageMessageBubble', () {
    testWidgets('draws the attachment, not a like count', (tester) async {
      await tester.pumpWidget(
        const _Harness(
          child: ImageMessageBubble(
            image: 'https://images.unsplash.com/photo-1',
            width: 1200,
            height: 800,
          ),
        ),
      );
      await tester.pump();

      // The mock this replaced painted "2.4k ♥" over every photograph.
      expect(find.text('2.4k'), findsNothing);
      expect(find.byIcon(Icons.favorite_rounded), findsNothing);

      final ratio = tester.widget<AspectRatio>(find.byType(AspectRatio));
      expect(ratio.aspectRatio, closeTo(1.5, 0.001));
    });

    testWidgets('falls back to a portrait shape when dimensions are unknown', (
      tester,
    ) async {
      await tester.pumpWidget(
        const _Harness(
          child: ImageMessageBubble(image: 'https://example.com/a.jpg'),
        ),
      );
      await tester.pump();

      final ratio = tester.widget<AspectRatio>(find.byType(AspectRatio));
      expect(ratio.aspectRatio, closeTo(3 / 4, 0.001));
    });
  });

  group('sending a photograph', () {
    testWidgets('picks, uploads as chat media, and sends what was stored', (
      tester,
    ) async {
      final uploads = _FakeUploadService()
        ..picked = XFile.fromData(_png, path: 'dress.png')
        ..result = const MediaAsset(
          id: 'asset-1',
          url: _privateUrl,
          type: 'image',
          mimeType: 'image/png',
          byteSize: 4096,
          width: 1200,
          height: 900,
        );
      final chat = _FakeChatRepository();

      await tester.pumpWidget(_chatHarness(uploads: uploads, chat: chat));
      await _settle(tester);

      await _attachFromGallery(tester);

      // Uploaded under the chat purpose — which is what makes the server store
      // it privately and admit only this conversation's participants.
      expect(uploads.purposes, [MediaPurpose.chat]);

      final sent = chat.sent!;
      expect(sent['kind'], 'IMAGE');
      final attachment =
          (sent['attachments'] as List).first as Map<String, dynamic>;
      expect(attachment['url'], _privateUrl);
      expect(attachment['mime_type'], 'image/png');
      expect(attachment['size_bytes'], 4096);
      expect(attachment['width'], 1200);
      expect(attachment['height'], 900);
    });

    testWidgets('an over-sized photograph never reaches the network', (
      tester,
    ) async {
      final uploads = _FakeUploadService()
        ..picked = XFile.fromData(
          Uint8List(MediaLimits.imageBytes + 1),
          path: 'huge.png',
        );
      final chat = _FakeChatRepository();

      await tester.pumpWidget(_chatHarness(uploads: uploads, chat: chat));
      await _settle(tester);

      await _attachFromGallery(tester);

      expect(uploads.purposes, isEmpty);
      expect(chat.sent, isNull);
    });

    testWidgets('a failed upload sends nothing and says so', (tester) async {
      final uploads = _FakeUploadService()
        ..picked = XFile.fromData(_png, path: 'dress.png')
        ..failUpload = true;
      final chat = _FakeChatRepository();

      await tester.pumpWidget(_chatHarness(uploads: uploads, chat: chat));
      await _settle(tester);

      await _attachFromGallery(tester);

      // The message is not sent half-formed: no attachment, no message.
      expect(chat.sent, isNull);
      expect(find.text(_ar.chatAttachmentFailed), findsOneWidget);
    });

    testWidgets('the sheet offers exactly the sources that are implemented', (
      tester,
    ) async {
      await tester.pumpWidget(
        _chatHarness(
          uploads: _FakeUploadService(),
          chat: _FakeChatRepository(),
        ),
      );
      await _settle(tester);

      await tester.tap(find.text(_ar.chatShareImage));
      await _settle(tester);

      expect(find.text(_ar.mediaFromCamera), findsOneWidget);
      expect(find.text(_ar.mediaFromGallery), findsOneWidget);
      expect(find.text(_ar.chatFromFiles), findsOneWidget);
      // Three, and only three. The mock offered a location option backed by
      // nothing; recording is real but lives on the composer's own row, which
      // is why this counts the sheet's own tiles rather than hunting for a
      // microphone icon anywhere in the tree.
      expect(
        find.descendant(
          of: find.byType(BottomSheet),
          matching: find.byType(ListTile),
        ),
        findsNWidgets(3),
      );
      expect(find.byIcon(Icons.location_on_rounded), findsNothing);
    });
  });

  group('sending a document', () {
    testWidgets('a PDF is sent as a FILE message, named and sized', (
      tester,
    ) async {
      final uploads = _FakeUploadService()
        ..picked = XFile.fromData(_pdf, path: 'invoice.pdf')
        ..result = const MediaAsset(
          id: 'asset-3',
          url: _privateUrl,
          // The server's word, from sniffing the bytes.
          type: 'document',
          mimeType: 'application/pdf',
          byteSize: 204800,
        );
      final chat = _FakeChatRepository();

      await tester.pumpWidget(_chatHarness(uploads: uploads, chat: chat));
      await _settle(tester);

      await _attachFrom(tester, _ar.chatFromFiles);

      expect(uploads.purposes, [MediaPurpose.chat]);
      final sent = chat.sent!;
      // Not IMAGE: a bubble that tried to draw this would render a broken
      // frame, and the gallery would list it as a photograph.
      expect(sent['kind'], 'FILE');
      final attachment =
          (sent['attachments'] as List).first as Map<String, dynamic>;
      expect(attachment['kind'], 'FILE');
      expect(attachment['file_name'], 'invoice.pdf');
      expect(attachment['size_bytes'], 204800);
      expect(attachment['mime_type'], 'application/pdf');
    });

    testWidgets('a scan is held to the document ceiling, not the image one', (
      tester,
    ) async {
      // Larger than an image may be, smaller than a document may be. Holding a
      // scan to the photograph limit would refuse the invoice she was asked
      // for.
      final uploads = _FakeUploadService()
        ..picked = XFile.fromData(
          Uint8List(MediaLimits.imageBytes + 1024),
          path: 'register.pdf',
        )
        ..result = const MediaAsset(
          id: 'asset-4',
          url: _privateUrl,
          type: 'document',
          mimeType: 'application/pdf',
          byteSize: 1024,
        );
      final chat = _FakeChatRepository();

      await tester.pumpWidget(_chatHarness(uploads: uploads, chat: chat));
      await _settle(tester);

      await _attachFrom(tester, _ar.chatFromFiles);

      expect(uploads.purposes, [MediaPurpose.chat]);
      expect(chat.sent, isNotNull);
    });
  });

  group('FileMessageBubble', () {
    testWidgets('names the document and its size without fetching it', (
      tester,
    ) async {
      await tester.pumpWidget(
        const _Harness(
          child: FileMessageBubble(
            url: _privateUrl,
            attachmentId: 'att-1',
            fileName: 'invoice.pdf',
            sizeBytes: 2097152,
          ),
        ),
      );
      await tester.pump();

      expect(find.text('invoice.pdf'), findsOneWidget);
      expect(find.text(_ar.fileSizeMegabytes('2.0')), findsOneWidget);
      // Nothing is downloaded until she asks for it.
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('falls back to a generic label when the name is missing', (
      tester,
    ) async {
      await tester.pumpWidget(
        const _Harness(
          child: FileMessageBubble(url: _privateUrl, attachmentId: 'att-2'),
        ),
      );
      await tester.pump();

      expect(find.text(_ar.chatFileMessage), findsOneWidget);
    });
  });

  group('recording a voice note', () {
    testWidgets('records, uploads as chat media, and sends the duration', (
      tester,
    ) async {
      final uploads = _FakeUploadService()
        ..result = const MediaAsset(
          id: 'asset-2',
          url: _privateUrl,
          type: 'audio',
          mimeType: 'audio/mp4',
          byteSize: 20480,
        );
      final chat = _FakeChatRepository();
      final recorder = _FakeRecorder();

      await tester.pumpWidget(
        _chatHarness(uploads: uploads, chat: chat, recorder: recorder),
      );
      await _settle(tester);

      await _startRecording(tester);
      expect(recorder.started, isTrue);

      // Past the bar's one-second floor, below which a recording is a slip of
      // the thumb rather than a message. Asserted on the timer she can see, so
      // this test states the precondition it depends on instead of trusting an
      // arithmetic of pumps.
      await tester.pump(const Duration(seconds: 2));
      expect(find.text('0:02'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.send_rounded).last);
      await _settle(tester);

      expect(uploads.purposes, [MediaPurpose.chat]);
      final sent = chat.sent!;
      expect(sent['kind'], 'VOICE');
      final attachment =
          (sent['attachments'] as List).first as Map<String, dynamic>;
      expect(attachment['kind'], 'VOICE');
      expect(attachment['url'], _privateUrl);
      expect(attachment['mime_type'], 'audio/mp4');
      // Measured on the handset, not read back from the container.
      expect(attachment['duration_ms'], greaterThanOrEqualTo(1000));
    });

    testWidgets('a recording under a second is discarded, not sent', (
      tester,
    ) async {
      final uploads = _FakeUploadService();
      final chat = _FakeChatRepository();
      final recorder = _FakeRecorder();

      await tester.pumpWidget(
        _chatHarness(uploads: uploads, chat: chat, recorder: recorder),
      );
      await _settle(tester);

      await _startRecording(tester);
      // Still reading zero seconds — the same thing she would see. Without
      // this the test would depend on how much fake time `_startRecording`
      // happens to consume before the ticker begins.
      expect(find.text('0:00'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.send_rounded).last);
      await _settle(tester);

      expect(uploads.purposes, isEmpty);
      expect(chat.sent, isNull);
    });

    testWidgets('a refused microphone permission never starts a recording', (
      tester,
    ) async {
      final recorder = _FakeRecorder()..permitted = false;
      final chat = _FakeChatRepository();

      await tester.pumpWidget(
        _chatHarness(
          uploads: _FakeUploadService(),
          chat: chat,
          recorder: recorder,
        ),
      );
      await _settle(tester);

      await _startRecording(tester);

      expect(recorder.started, isFalse);
      expect(find.text(_ar.voicePermissionDenied), findsOneWidget);
      // And the composer comes back rather than leaving her in a dead bar.
      expect(find.byType(ChatInput), findsOneWidget);
    });

    testWidgets('discarding a recording sends nothing and deletes the file', (
      tester,
    ) async {
      final uploads = _FakeUploadService();
      final chat = _FakeChatRepository();
      final recorder = _FakeRecorder();

      await tester.pumpWidget(
        _chatHarness(uploads: uploads, chat: chat, recorder: recorder),
      );
      await _settle(tester);

      await _startRecording(tester);
      await tester.pump(const Duration(seconds: 2));
      await tester.tap(find.byIcon(Icons.delete_outline_rounded));
      await _settle(tester);

      expect(recorder.cancelled, isTrue);
      expect(uploads.purposes, isEmpty);
      expect(chat.sent, isNull);
    });
  });

  group('VoiceMessageBubble', () {
    testWidgets('shows the length it was told before playing anything', (
      tester,
    ) async {
      await tester.pumpWidget(
        const _Harness(
          child: VoiceMessageBubble(
            url: _privateUrl,
            duration: Duration(seconds: 95),
          ),
        ),
      );
      await tester.pump();

      // 1:35, from the sender's own measurement — no fetch, no decode.
      expect(find.text('1:35'), findsOneWidget);
      expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);
    });
  });
}

// ── Harness ─────────────────────────────────────────────────────────────────

class _AlwaysAPixel extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) => _PixelClient();
}

class _PixelClient implements HttpClient {
  @override
  bool autoUncompress = true;

  @override
  Future<HttpClientRequest> getUrl(Uri url) async => _PixelRequest(url);

  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) async =>
      _PixelRequest(url);

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _PixelRequest implements HttpClientRequest {
  _PixelRequest(this.uri);

  @override
  final Uri uri;

  @override
  final HttpHeaders headers = _EmptyHeaders();

  @override
  Future<HttpClientResponse> close() async => _PixelResponse();

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _PixelResponse implements HttpClientResponse {
  @override
  int get statusCode => HttpStatus.ok;

  @override
  int get contentLength => _png.length;

  @override
  HttpClientResponseCompressionState get compressionState =>
      HttpClientResponseCompressionState.notCompressed;

  @override
  final HttpHeaders headers = _EmptyHeaders();

  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int> event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) => Stream<List<int>>.value(_png).listen(
    onData,
    onError: onError,
    onDone: onDone,
    cancelOnError: cancelOnError,
  );

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _EmptyHeaders implements HttpHeaders {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

/// Bounded pumps, never `pumpAndSettle`: the conversation carries a decorative
/// gradient orb that animates forever, so nothing on this screen ever settles.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 12; i++) {
    await tester.pump(const Duration(milliseconds: 60));
  }
}

Future<void> _attachFrom(WidgetTester tester, String option) async {
  await tester.tap(find.text(_ar.chatShareImage));
  await _settle(tester);
  await tester.tap(find.text(option));
  await _settle(tester);
}

Future<void> _attachFromGallery(WidgetTester tester) async {
  // The empty state's own invitation, rather than the collapsed action row
  // behind the input's toggle — same callback, one fewer tap to arrange.
  await tester.tap(find.text(_ar.chatShareImage));
  await _settle(tester);
  await tester.tap(find.text(_ar.mediaFromGallery));
  await _settle(tester);
}

Future<void> _startRecording(WidgetTester tester) async {
  // The voice action lives in the composer's collapsed panel, behind the `+`.
  await tester.tap(find.byTooltip(_ar.chatAttachments));
  await _settle(tester);
  await tester.tap(find.byIcon(Icons.mic_rounded));
  // Zero-duration frames: they flush the microtasks that start the recorder
  // without advancing the clock, so a test that means to record for 400 ms
  // is not handed a second of setup time first.
  for (var i = 0; i < 8; i++) {
    await tester.pump(Duration.zero);
  }
}

Widget _chatHarness({
  required MediaUploadService uploads,
  required ChatRepository chat,
  VoiceRecorderService? recorder,
}) => _Harness(
  // A builder rather than a list of overrides: naming their type would mean
  // importing it from riverpod's core package, which is not a dependency here.
  scope: (app) => ProviderScope(
    overrides: [
      mediaUploadServiceProvider.overrideWithValue(uploads),
      chatRepositoryProvider.overrideWithValue(chat),
      chatRealtimeServiceProvider.overrideWithValue(_silentRealtime()),
      if (recorder != null)
        voiceRecorderServiceProvider.overrideWithValue(recorder),
    ],
    child: app,
  ),
  child: const ChatDetailsScreen(chatId: 'chat-1'),
);

class _Harness extends StatelessWidget {
  const _Harness({required this.child, this.scope});

  final Widget child;
  final Widget Function(Widget app)? scope;

  @override
  Widget build(BuildContext context) {
    final app = MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      locale: const Locale('ar'),
      supportedLocales: L10nSetup.supportedLocales,
      localizationsDelegates: const [
        gen.AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: Scaffold(body: child),
    );
    return scope?.call(app) ?? ProviderScope(child: app);
  }
}

/// Never opens a socket. The real one reaches for secure storage and a WebSocket
/// on the first frame, neither of which exists here.
_SilentRealtime _silentRealtime() {
  final service = _SilentRealtime();
  addTearDown(service.close);
  return service;
}

class _SilentRealtime extends ChatRealtimeService {
  _SilentRealtime() : super(SecureStorageService());

  final _controller = StreamController<Map<String, dynamic>>.broadcast();

  @override
  Stream<Map<String, dynamic>> get events => _controller.stream;

  @override
  Future<void> connect() async {}

  @override
  void join(String chatId) {}

  @override
  void leave(String chatId) {}

  @override
  void typing(String chatId, bool isTyping) {}

  @override
  void markRead(String chatId, {String? messageId}) {}

  @override
  void send(Map<String, dynamic> payload) {}

  @override
  Future<void> disconnect() async {}

  /// The base service holds no stream of its own, so there is nothing to
  /// override here — but a broadcast controller that is never closed keeps
  /// the test isolate's event loop alive between cases. Closed by whoever
  /// built it.
  Future<void> close() => _controller.close();
}

class _FakeUploadService extends MediaUploadService {
  _FakeUploadService() : super(Dio());

  XFile? picked;
  MediaAsset? result;
  bool failUpload = false;

  /// Every purpose an upload was attempted under, so a test can assert that a
  /// chat photograph is not filed as a product image.
  final purposes = <MediaPurpose>[];

  @override
  Future<XFile?> pickImage({required ImageSource source}) async => picked;

  @override
  Future<XFile?> pickDocument() async => picked;

  @override
  Future<MediaAsset> upload(
    XFile file, {
    required MediaPurpose purpose,
    Uint8List? bytes,
    void Function(double progress)? onProgress,
    CancelToken? cancelToken,
  }) async {
    purposes.add(purpose);
    if (failUpload) throw Exception('network');
    return result!;
  }
}

/// Stands in for the microphone. Subclassed rather than mocked so a signature
/// change on the real service breaks this file at compile time.
class _FakeRecorder extends VoiceRecorderService {
  bool permitted = true;
  bool started = false;
  bool cancelled = false;

  @override
  Future<bool> hasPermission() async => permitted;

  @override
  Stream<double> get levels => const Stream<double>.empty();

  @override
  Future<void> start() async {
    started = true;
  }

  @override
  Future<String?> stop() async => started ? '/tmp/voice-1.m4a' : null;

  @override
  Future<void> cancel() async {
    cancelled = true;
  }

  @override
  Future<void> dispose() async {}
}

class _FakeChatRepository implements ChatRepository {
  Map<String, dynamic>? sent;

  @override
  Future<Result<List<ChatMessageEntity>>> getMessages(String chatId) async =>
      const Success([]);

  @override
  Future<Result<ChatMessageEntity>> sendMessage({
    required String chatId,
    required String content,
    String kind = 'TEXT',
    List<Map<String, dynamic>> attachments = const [],
    String? clientId,
  }) async {
    sent = {
      'content': content,
      'kind': kind,
      'attachments': attachments,
      'client_id': clientId,
    };
    return Success(
      ChatMessageEntity(
        id: 'm-1',
        chatId: chatId,
        senderId: 'me',
        content: content,
        sentAt: DateTime.utc(2026, 8, 25),
        isMine: true,
        kind: kind.toLowerCase(),
        clientId: clientId,
      ),
    );
  }

  @override
  Future<Result<List<ChatThreadEntity>>> getThreads({String? query}) async =>
      const Success([]);

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      Future.value(const Error<Never>(ServerFailure('not used in this test')));
}
