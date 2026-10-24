// The upload picker's behaviour, driven through a fake upload service.
//
// What is worth pinning here is not the layout — it is the bookkeeping around
// a network that fails. A photograph that uploaded must appear in the URLs the
// form posts; one that did not must not, must stay on screen as something she
// can retry, and must hold the form's submit button until it settles. Every
// one of those has a silent failure mode where the product publishes without
// the picture she is looking at.
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:ohara/core/design_system/design_system.dart';
import 'package:ohara/core/localization/app_localizations.dart';
import 'package:ohara/core/media/media_asset.dart';
import 'package:ohara/core/media/media_limits.dart';
import 'package:ohara/core/media/media_providers.dart';
import 'package:ohara/core/media/media_upload_service.dart';
import 'package:ohara/l10n/app_localizations.dart' as gen;

/// A real 1×1 PNG. `Image.memory` decodes it for the tile preview, so bytes
/// that merely look like a file would fail inside the paint phase.
final Uint8List _png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAC'
  'hwGA60e6kgAAAABJRU5ErkJggg==',
);

/// Enough of a PDF for the tile to name it; the server does the real sniffing.
final Uint8List _pdf = Uint8List.fromList('%PDF-1.7'.codeUnits);

MediaAsset _asset(String url) => MediaAsset(
  id: url,
  url: url,
  type: 'image',
  mimeType: 'image/png',
  byteSize: _png.length,
  width: 1,
  height: 1,
);

void main() {
  group('MediaAsset', () {
    test('decodes the server payload', () {
      final asset = MediaAsset.fromJson(const {
        'id': 'a1',
        'url': 'http://10.0.2.2:3000/media/files/2026/08/a.png',
        'type': 'image',
        'mime_type': 'image/png',
        'byte_size': 2048,
        'width': 120,
        'height': 80,
      });

      expect(asset.url, endsWith('2026/08/a.png'));
      expect(asset.isVideo, isFalse);
      expect(asset.aspectRatio, closeTo(1.5, 0.001));
    });

    test('survives a payload with no dimensions, as video uploads have', () {
      final asset = MediaAsset.fromJson(const {
        'id': 'v1',
        'url': 'http://host/media/files/2026/08/a.mp4',
        'type': 'video',
        'mime_type': 'video/mp4',
        'byte_size': 900,
      });

      expect(asset.isVideo, isTrue);
      expect(asset.aspectRatio, isNull);
    });

    test('purpose wire values match the server enum', () {
      // The server derives who may read an upload from this string. A rename
      // on either side silently turns a verification document public.
      expect(MediaPurpose.verification.wire, 'verification');
      expect(MediaPurpose.storeLogo.wire, 'store_logo');
      expect(MediaPurpose.product.wire, 'product');
    });
  });

  group('DsMediaField', () {
    testWidgets('seeds a tile per existing photograph', (tester) async {
      final service = _FakeUploadService();
      await tester.pumpWidget(
        _Harness(
          service: service,
          field: DsMediaField(
            initialUrls: const ['http://host/media/files/2026/08/a.png'],
            onChanged: (_) {},
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(InkWell), findsWidgets);
      // One seeded tile plus the add tile.
      expect(find.byIcon(Icons.add_photo_alternate_outlined), findsOneWidget);
      expect(find.byIcon(Icons.close_rounded), findsOneWidget);
    });

    testWidgets('a successful pick reports the uploaded URL', (tester) async {
      final service = _FakeUploadService()
        ..picked = [XFile.fromData(_png, name: 'dress.png')]
        ..result = _asset('http://host/media/files/2026/08/dress.png');

      List<String> reported = const [];
      await tester.pumpWidget(
        _Harness(
          service: service,
          field: DsMediaField(
            maxItems: 3,
            onChanged: (urls) => reported = urls,
          ),
        ),
      );

      await _pickFromGallery(tester);

      expect(reported, ['http://host/media/files/2026/08/dress.png']);
      expect(service.uploads, 1);
    });

    testWidgets('a failed upload keeps the tile, and retry re-sends it', (
      tester,
    ) async {
      final service = _FakeUploadService()
        ..picked = [XFile.fromData(_png, name: 'dress.png')]
        ..failNextUpload = true;

      List<String> reported = const ['sentinel'];
      await tester.pumpWidget(
        _Harness(
          service: service,
          field: DsMediaField(
            maxItems: 3,
            onChanged: (urls) => reported = urls,
          ),
        ),
      );

      await _pickFromGallery(tester);

      // Nothing was reported, but the tile is still there — she has not lost
      // the photograph, and the retry affordance is on it.
      expect(reported, isEmpty);
      expect(find.byIcon(Icons.refresh_rounded), findsOneWidget);

      service
        ..failNextUpload = false
        ..result = _asset('http://host/media/files/2026/08/dress.png');

      await tester.tap(find.byIcon(Icons.refresh_rounded));
      await tester.pumpAndSettle();

      expect(reported, ['http://host/media/files/2026/08/dress.png']);
      // Twice: the retry re-sent the bytes she already chose rather than
      // sending her back to the picker.
      expect(service.uploads, 2);
      expect(service.pickCalls, 1);
    });

    testWidgets('removing a tile drops its URL', (tester) async {
      final service = _FakeUploadService()
        ..picked = [XFile.fromData(_png, name: 'dress.png')]
        ..result = _asset('http://host/media/files/2026/08/dress.png');

      List<String> reported = const [];
      await tester.pumpWidget(
        _Harness(
          service: service,
          field: DsMediaField(
            maxItems: 3,
            onChanged: (urls) => reported = urls,
          ),
        ),
      );

      await _pickFromGallery(tester);
      expect(reported, hasLength(1));

      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pumpAndSettle();

      expect(reported, isEmpty);
    });

    testWidgets('reports while bytes are in flight, and again when they settle', (
      tester,
    ) async {
      // The form's submit button hangs off this. Without the closing `false`
      // it would stay disabled forever; without the opening `true` a product
      // would publish while its photographs were still uploading.
      final service = _FakeUploadService()
        ..picked = [XFile.fromData(_png, name: 'dress.png')]
        ..result = _asset('http://host/media/files/2026/08/dress.png')
        ..holdUpload = true;

      final busyLog = <bool>[];
      await tester.pumpWidget(
        _Harness(
          service: service,
          field: DsMediaField(
            maxItems: 3,
            onChanged: (_) {},
            onUploadingChanged: busyLog.add,
          ),
        ),
      );

      await _openSheetAndChooseGallery(tester);
      await tester.pump();
      await tester.pump();

      expect(busyLog, [true]);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      service.release();
      await tester.pumpAndSettle();

      expect(busyLog, [true, false]);
    });

    testWidgets('a documents field offers the file browser as a third source', (
      tester,
    ) async {
      final service = _FakeUploadService()
        // `path`, not just `name`: on mobile and desktop `XFile.name` is the
        // basename of the path and the `name` argument is ignored, which is
        // also how the real file picker's XFile behaves.
        ..picked = [XFile.fromData(_pdf, path: 'register.pdf')]
        ..result = MediaAsset(
          id: 'doc-1',
          url: 'http://host/media/aaaa/file',
          type: 'document',
          mimeType: 'application/pdf',
          byteSize: _pdf.length,
        );

      List<String> reported = const [];
      await tester.pumpWidget(
        _Harness(
          service: service,
          field: DsMediaField(
            documents: true,
            purpose: MediaPurpose.verification,
            maxItems: 3,
            onChanged: (urls) => reported = urls,
          ),
        ),
      );

      await tester.tap(find.byIcon(Icons.add_photo_alternate_outlined));
      await tester.pumpAndSettle();
      // Camera, gallery, files — the third only exists in documents mode.
      expect(find.byIcon(Icons.folder_open_outlined), findsOneWidget);

      await tester.tap(find.byIcon(Icons.folder_open_outlined));
      await tester.pumpAndSettle();

      expect(service.documentPicks, 1);
      expect(reported, ['http://host/media/aaaa/file']);
      // A PDF has no thumbnail; the tile shows its name instead.
      expect(find.text('register.pdf'), findsOneWidget);
      expect(find.byIcon(Icons.picture_as_pdf_rounded), findsOneWidget);
    });

    testWidgets('a plain gallery never offers the file browser', (
      tester,
    ) async {
      await tester.pumpWidget(
        _Harness(
          service: _FakeUploadService(),
          field: DsMediaField(maxItems: 3, onChanged: (_) {}),
        ),
      );

      await tester.tap(find.byIcon(Icons.add_photo_alternate_outlined));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.folder_open_outlined), findsNothing);
    });

    testWidgets('an over-sized file is refused before a byte is uploaded', (
      tester,
    ) async {
      // The server would refuse it too — after every byte has crossed a narrow,
      // metered connection. Refusing here costs her nothing.
      final service = _FakeUploadService()
        ..picked = [
          XFile.fromData(
            Uint8List(MediaLimits.imageBytes + 1),
            name: 'huge.png',
          ),
        ];

      List<String> reported = const ['sentinel'];
      await tester.pumpWidget(
        _Harness(
          service: service,
          field: DsMediaField(
            maxItems: 3,
            onChanged: (urls) => reported = urls,
          ),
        ),
      );

      await _pickFromGallery(tester);

      expect(service.uploads, 0);
      // Never reported: no tile was ever created, so there was nothing to
      // report. The sentinel proves `onChanged` was not called with an empty
      // list either, which would have looked like a removal.
      expect(reported, ['sentinel']);
      expect(find.byIcon(Icons.close_rounded), findsNothing);
    });

    testWidgets('the add tile disappears once the gallery is full', (
      tester,
    ) async {
      final service = _FakeUploadService()
        ..picked = [XFile.fromData(_png, name: 'a.png')]
        ..result = _asset('http://host/media/files/2026/08/a.png');

      await tester.pumpWidget(
        _Harness(
          service: service,
          field: DsMediaField(maxItems: 1, onChanged: (_) {}),
        ),
      );

      expect(find.byIcon(Icons.add_photo_alternate_outlined), findsOneWidget);
      await _pickFromGallery(tester);
      expect(find.byIcon(Icons.add_photo_alternate_outlined), findsNothing);
    });
  });
}

// ── Harness ─────────────────────────────────────────────────────────────────

Future<void> _openSheetAndChooseGallery(WidgetTester tester) async {
  await tester.tap(find.byIcon(Icons.add_photo_alternate_outlined));
  await tester.pumpAndSettle();
  await tester.tap(find.byIcon(Icons.photo_library_outlined));
}

Future<void> _pickFromGallery(WidgetTester tester) async {
  await _openSheetAndChooseGallery(tester);
  await tester.pumpAndSettle();
}

class _Harness extends StatelessWidget {
  const _Harness({required this.service, required this.field});

  final MediaUploadService service;
  final Widget field;

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      overrides: [mediaUploadServiceProvider.overrideWithValue(service)],
      child: MaterialApp(
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
        home: Scaffold(
          body: Padding(padding: const EdgeInsets.all(24), child: field),
        ),
      ),
    );
  }
}

/// Stands in for the picker and the network. Subclassed rather than mocked so
/// a signature change on the real service breaks this file at compile time.
class _FakeUploadService extends MediaUploadService {
  _FakeUploadService() : super(Dio());

  List<XFile> picked = const [];
  MediaAsset? result;
  bool failNextUpload = false;
  int documentPicks = 0;

  /// Suspends the upload so a test can observe the in-flight state.
  bool holdUpload = false;

  int pickCalls = 0;
  int uploads = 0;

  Completer<void>? _gate;

  void release() {
    _gate?.complete();
    _gate = null;
  }

  @override
  Future<XFile?> pickImage({required ImageSource source}) async {
    pickCalls++;
    return picked.isEmpty ? null : picked.first;
  }

  @override
  Future<List<XFile>> pickImages() async {
    pickCalls++;
    return picked;
  }

  @override
  Future<XFile?> pickVideo({required ImageSource source}) async {
    pickCalls++;
    return picked.isEmpty ? null : picked.first;
  }

  @override
  Future<XFile?> pickDocument() async {
    pickCalls++;
    documentPicks++;
    return picked.isEmpty ? null : picked.first;
  }

  @override
  Future<MediaAsset> upload(
    XFile file, {
    required MediaPurpose purpose,
    Uint8List? bytes,
    void Function(double progress)? onProgress,
    CancelToken? cancelToken,
  }) async {
    uploads++;
    if (holdUpload) {
      final gate = Completer<void>();
      _gate = gate;
      await gate.future;
    }
    if (failNextUpload) throw Exception('network');
    return result!;
  }
}
