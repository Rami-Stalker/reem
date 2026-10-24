// Renders the courier's round to a PNG.
//
//   flutter test test/courier_visual_preview_test.dart
import 'dart:io';
import 'dart:ui' show ImageByteFormat;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reem/core/design_system/design_system.dart';
import 'package:reem/core/localization/app_localizations.dart';
import 'package:reem/core/result/result.dart';
import 'package:reem/core/shared/value_objects/money.dart';
import 'package:reem/features/courier/domain/entities/courier_assignment.dart';
import 'package:reem/features/courier/domain/repositories/courier_repository.dart';
import 'package:reem/features/courier/presentation/providers/courier_provider.dart';
import 'package:reem/features/courier/presentation/screens/courier_day_screen.dart';
import 'package:reem/features/shipment_tracking/domain/entities/shipment_tracking.dart';
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
  // Material's icon font ships with the SDK, not the app, so a widget test
  // draws every icon as a box unless it is loaded by hand.
  final root = Platform.environment['FLUTTER_ROOT'];
  final icons = File(
    '$root/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
  );
  if (root != null && icons.existsSync()) {
    final loader = FontLoader('MaterialIcons')
      ..addFont(icons.readAsBytes().then((b) => ByteData.view(b.buffer)));
    await loader.load();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(_loadFonts);

  testWidgets('renders the courier round', (tester) async {
    tester.view.physicalSize = const Size(830, 1900);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          courierRepositoryProvider.overrideWithValue(_FakeCourier()),
        ],
        child: const _Preview(child: CourierDayScreen()),
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));

    await tester.runAsync(() async {
      final boundary =
          _captureKey.currentContext!.findRenderObject()!
              as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 2);
      final data = await image.toByteData(format: ImageByteFormat.png);
      final dir = Directory('build/visual')..createSync(recursive: true);
      final file = File('${dir.path}/courier_round.png')
        ..writeAsBytesSync(data!.buffer.asUint8List());
      // ignore: avoid_print
      print('wrote ${file.path}');
    });
  });
}

class _Preview extends StatelessWidget {
  const _Preview({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
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
      home: RepaintBoundary(key: _captureKey, child: child),
    );
  }
}

// ── Fake ────────────────────────────────────────────────────────────────────

class _FakeCourier implements CourierRepository {
  @override
  Future<Result<List<CourierAssignment>>> today() async => Success(_round);

  @override
  Future<Result<void>> pickUp(String id) async => const Success(null);
  @override
  Future<Result<void>> startDelivery(String id) async => const Success(null);
  @override
  Future<Result<void>> deliver(
    String id, {
    String? collected,
    String? proofImageUrl,
    String? recipientNote,
  }) async => const Success(null);
  @override
  Future<Result<void>> fail(
    String id,
    DeliveryFailureReason reason, {
    String? note,
  }) async => const Success(null);
}

Money _m(String v) => Money.fromJson(v);

final _round = <CourierAssignment>[
  // Express, out for delivery, cash to collect, and a note.
  CourierAssignment(
    id: '1',
    trackingCode: 'RM-4821-9K3',
    orderNumber: 'SUB-2026-004821-A',
    stage: ShipmentStage.outForDelivery,
    recipient: const CourierRecipient(
      name: 'ريم الدالي',
      phone: '+963931000101',
    ),
    address: const CourierAddress(
      governorate: 'دمشق',
      city: 'دمشق',
      addressLine: 'المزة، شارع الجلاء',
      landmark: 'قرب صيدلية النور',
    ),
    codAmount: _m('615000'),
    deliveryInstructions: 'اتصل قبل الوصول بعشر دقائق',
    isExpress: true,
    attemptCount: 1,
  ),
  // Just picked up, prepaid.
  CourierAssignment(
    id: '2',
    trackingCode: 'RM-4822-2P7',
    orderNumber: 'SUB-2026-004822-B',
    stage: ShipmentStage.pickedUp,
    recipient: const CourierRecipient(
      name: 'مها العلي',
      phone: '+963932000201',
    ),
    address: const CourierAddress(
      governorate: 'ريف دمشق',
      city: 'جرمانا',
      addressLine: 'شارع المدارس',
    ),
    attemptCount: 0,
  ),
  // Waiting to be collected from the seller.
  CourierAssignment(
    id: '3',
    trackingCode: 'RM-4823-8T1',
    orderNumber: 'SUB-2026-004823-C',
    stage: ShipmentStage.assigned,
    recipient: const CourierRecipient(
      name: 'لينا حسن',
      phone: '+963933000301',
    ),
    address: const CourierAddress(
      governorate: 'دمشق',
      city: 'دمشق',
      addressLine: 'أبو رمانة، شارع الجلاء',
    ),
    codAmount: _m('240000'),
    attemptCount: 0,
  ),
  // Done this morning.
  CourierAssignment(
    id: '4',
    trackingCode: 'RM-4820-5M9',
    orderNumber: 'SUB-2026-004820-D',
    stage: ShipmentStage.delivered,
    recipient: const CourierRecipient(
      name: 'سارة منصور',
      phone: '+963934000401',
    ),
    address: const CourierAddress(
      governorate: 'دمشق',
      city: 'دمشق',
      addressLine: 'الشعلان',
    ),
    codAmount: _m('180000'),
    collectedAmount: _m('180000'),
    attemptCount: 0,
    deliveredAt: DateTime(2026, 8, 22, 9, 40),
  ),
];
