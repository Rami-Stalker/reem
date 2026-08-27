// Renders the invoice document and the shipment tracking screen to PNGs.
//
//   flutter test test/invoice_shipment_visual_preview_test.dart
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' show ImageByteFormat;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reem/core/design_system/design_system.dart';
import 'package:reem/core/localization/app_localizations.dart';
import 'package:reem/core/shared/value_objects/money.dart';
import 'package:reem/features/invoices/domain/entities/invoice.dart';
import 'package:reem/features/invoices/domain/repositories/invoices_repository.dart';
import 'package:reem/features/invoices/presentation/providers/invoices_provider.dart';
import 'package:reem/features/invoices/presentation/screens/invoice_screen.dart';
import 'package:reem/features/shipment_tracking/domain/entities/shipment_tracking.dart';
import 'package:reem/features/shipment_tracking/domain/repositories/shipment_tracking_repository.dart';
import 'package:reem/features/shipment_tracking/presentation/providers/shipment_tracking_provider.dart';
import 'package:reem/features/shipment_tracking/presentation/screens/shipment_tracking_screen.dart';
import 'package:reem/core/result/result.dart';
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

  testWidgets('renders the customer invoice', (tester) async {
    tester.view.physicalSize = const Size(830, 1750);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          invoicesRepositoryProvider.overrideWithValue(_FakeInvoices()),
        ],
        child: const _Preview(child: InvoiceScreen(invoiceId: 'x')),
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));
    await _capture(tester, 'invoice_customer');
  });

  // A separate test on purpose: Riverpod refuses to swap the overrides of a
  // ProviderScope that is already mounted, and reusing one across both
  // renders would do exactly that.
  testWidgets('renders the shipment tracking screen', (tester) async {
    tester.view.physicalSize = const Size(830, 1750);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          shipmentTrackingRepositoryProvider.overrideWithValue(_FakeTracking()),
        ],
        child: const _Preview(
          child: ShipmentTrackingScreen(trackingCode: 'RM12345678'),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));
    await _capture(tester, 'shipment_tracking');
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

// ── Fakes ───────────────────────────────────────────────────────────────────

Money _m(String v) => Money.fromJson(v);

class _FakeInvoices implements InvoicesRepository {
  @override
  Future<Result<Invoice>> byId(String invoiceId) async => Success(_invoice);

  @override
  Future<Result<List<InvoiceSummary>>> listForOrder(String orderId) async =>
      const Success([]);

  @override
  Future<Result<InvoiceSummary>> issueForOrder(String orderId) async =>
      throw UnimplementedError();
}

final _invoice = Invoice(
  id: 'i1',
  number: 'INV-2026-000148',
  kind: InvoiceKind.order,
  issuedAt: DateTime(2026, 8, 22),
  orderNumber: 'ORD-2026-004821',
  placedAt: DateTime(2026, 8, 19),
  currency: Currency.syp,
  couponCode: 'REEM10',
  recipient: const InvoiceRecipient(
    name: 'ريم الدالي',
    phone: '+963931000101',
    governorate: 'دمشق',
    city: 'دمشق',
    addressLine: 'المزة، شارع الجلاء',
  ),
  itemsSubtotal: _m('900000'),
  discountTotal: _m('50000'),
  shippingTotal: _m('20000'),
  grandTotal: _m('870000'),
  lines: [
    InvoiceLine(
      title: 'فستان سهرة مطرّز بالحرير',
      variant: 'مقاس M · وردي',
      seller: 'أتيليه رهف',
      quantity: 1,
      unitPrice: _m('600000'),
      unitDiscount: _m('50000'),
      lineTotal: _m('550000'),
    ),
    InvoiceLine(
      title: 'عطر شرقي فاخر ٥٠ مل',
      seller: 'بوتيك ريم',
      quantity: 1,
      unitPrice: _m('300000'),
      unitDiscount: _m('0'),
      lineTotal: _m('300000'),
    ),
  ],
);

class _FakeTracking implements ShipmentTrackingRepository {
  @override
  Future<Result<ShipmentTracking>> track(String trackingCode) async =>
      Success(_tracking);
}

final _tracking = ShipmentTracking(
  trackingCode: 'RM-4821-9K3',
  orderNumber: 'SUB-2026-004821-A',
  stage: ShipmentStage.outForDelivery,
  attemptCount: 1,
  isExpress: true,
  scheduledFor: DateTime(2026, 8, 23),
  events: [
    ShipmentEvent(stage: ShipmentStage.created, at: DateTime(2026, 8, 20, 10)),
    ShipmentEvent(
      stage: ShipmentStage.pickedUp,
      at: DateTime(2026, 8, 21, 9, 30),
      note: 'استلمها المندوب من أتيليه رهف',
    ),
    ShipmentEvent(
      stage: ShipmentStage.failed,
      at: DateTime(2026, 8, 21, 17),
      note: 'لم يرد أحد — سنعاود المحاولة غداً',
    ),
    ShipmentEvent(
      stage: ShipmentStage.outForDelivery,
      at: DateTime(2026, 8, 22, 8, 15),
    ),
  ],
);
