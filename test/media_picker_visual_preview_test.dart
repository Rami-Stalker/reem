// Renders the upload picker to PNGs so its design can be eyeballed without a
// device and a live server. Not an assertion test — it writes
// `build/visual/media_picker_*.png`.
//
// It captures the resting state: the add tile, the avatar's camera badge, and
// the copy around them. The states that only exist mid-network — a tile
// uploading, a tile that failed and offers a retry — are pinned by
// `media_upload_test.dart` instead, because holding one open long enough to
// photograph leaves an animation running that no teardown is happy about.
//
//   flutter test test/media_picker_visual_preview_test.dart
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' show ImageByteFormat;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reem/core/design_system/design_system.dart';
import 'package:reem/core/localization/app_localizations.dart';
import 'package:reem/core/localization/l10n_extension.dart';
import 'package:reem/core/media/media_asset.dart';
import 'package:reem/core/media/media_providers.dart';
import 'package:reem/core/media/media_upload_service.dart';
import 'package:reem/l10n/app_localizations.dart' as gen;

final _captureKey = GlobalKey();

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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(_loadFonts);

  testWidgets('renders the upload picker in both themes', (tester) async {
    tester.view.physicalSize = const Size(1125, 1500);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    for (final mode in [ThemeMode.light, ThemeMode.dark]) {
      await tester.pumpWidget(_Preview(themeMode: mode));
      await tester.pump(const Duration(milliseconds: 300));
      await _capture(tester, 'media_picker_${mode.name}');
    }
  });
}

/// `runAsync` is not optional. `toImage` waits on the real engine, and awaiting
/// it inside the test's fake-async zone wedges that zone: the capture succeeds,
/// and then the *next* `pumpWidget` never returns — a hang with no error and
/// nothing pointing at this line. The other preview tests here do the same.
Future<void> _capture(WidgetTester tester, String name) async {
  await tester.runAsync(() async {
    final boundary =
        _captureKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
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
  const _Preview({required this.themeMode});

  final ThemeMode themeMode;

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      overrides: [
        mediaUploadServiceProvider.overrideWithValue(_InertUploadService()),
      ],
      child: MaterialApp(
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
        home: RepaintBoundary(
          key: _captureKey,
          child: Builder(
            builder: (context) => Scaffold(
              backgroundColor: context.dsColors.background,
              body: ListView(
                padding: const EdgeInsets.all(DsSpacing.lg),
                children: [
                  const SizedBox(height: DsSpacing.xl),
                  Center(
                    child: DsAvatarPicker(imageUrl: null, onChanged: (_) {}),
                  ),
                  const SizedBox(height: DsSpacing.xxl),
                  DsMediaField(
                    label: context.l10n.mediaProductGallery,
                    helperText: context.l10n.mediaGalleryHint(8),
                    onChanged: (_) {},
                  ),
                  const SizedBox(height: DsSpacing.xxl),
                  DsMediaField(
                    label: context.l10n.mediaStoryLabel,
                    purpose: MediaPurpose.story,
                    maxItems: 1,
                    onChanged: (_) {},
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The picker is never opened in this preview; the override exists only so the
/// widgets build without a Dio pointed at anything real.
class _InertUploadService extends MediaUploadService {
  _InertUploadService() : super(Dio());
}
