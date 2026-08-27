// Renders the admin finance console to PNGs.
//
//   flutter test test/admin_finance_visual_preview_test.dart
import 'dart:io';
import 'dart:ui' show ImageByteFormat;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reem/core/design_system/design_system.dart';
import 'package:reem/core/localization/app_localizations.dart';
import 'package:reem/core/shared/value_objects/money.dart';
import 'package:reem/features/admin_finance/domain/entities/finance_overview.dart';
import 'package:reem/features/admin_finance/presentation/widgets/finance_position_grid.dart';
import 'package:reem/features/admin_finance/presentation/widgets/ledger_health_banner.dart';
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

  testWidgets('renders the finance console, healthy and unhealthy', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1600, 1500);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_Preview(overview: _healthy));
    await tester.pump(const Duration(milliseconds: 300));
    await _capture(tester, 'admin_finance_healthy');

    await tester.pumpWidget(_Preview(overview: _broken));
    await tester.pump(const Duration(milliseconds: 300));
    await _capture(tester, 'admin_finance_broken');
  });
}

class _Preview extends StatelessWidget {
  const _Preview({required this.overview});

  final FinanceOverview overview;

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
      home: RepaintBoundary(
        key: _captureKey,
        child: Scaffold(
          backgroundColor: AdminExperience.background,
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(DsSpacing.xl),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                LedgerHealthBanner(overview: overview),
                const SizedBox(height: DsSpacing.xl),
                FinancePositionGrid(positions: overview.positions),
              ],
            ),
          ),
        ),
      ),
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

// ── Fixtures ────────────────────────────────────────────────────────────────

Money _m(String value) => Money.fromJson(value);

FinancePositions _positions({bool undercovered = false}) {
  return FinancePositions(
    platformCash: _m(undercovered ? '400000' : '8400000'),
    gatewayReceivable: _m('1200000'),
    courierInTransit: _m('950000'),
    sellerPayable: _m('3100000'),
    sellerEscrow: _m('2450000'),
    customerWallets: _m('780000'),
    disputeHeld: _m('420000'),
    loyaltyLiability: _m('150000'),
    commissionRevenue: _m('1830000'),
    totalOwed: _m('6900000'),
    totalHeld: _m(undercovered ? '2550000' : '10550000'),
    coverage: _m(undercovered ? '-4350000' : '3650000'),
  );
}

final _healthy = FinanceOverview(
  currency: Currency.syp,
  balanced: true,
  isSound: true,
  totalDebit: _m('24680000'),
  totalCredit: _m('24680000'),
  discrepancy: _m('0'),
  positions: _positions(),
  courierCashTotal: _m('950000'),
);

final _broken = FinanceOverview(
  currency: Currency.syp,
  balanced: false,
  isSound: false,
  totalDebit: _m('24680000'),
  totalCredit: _m('24605000'),
  discrepancy: _m('75000'),
  positions: _positions(undercovered: true),
  courierCashTotal: _m('950000'),
  findings: const [
    ReconciliationFinding(
      kind: ReconciliationKind.trialBalanceOff,
      detail: 'debits 24,680,000 ل.س vs credits 24,605,000 ل.س',
    ),
    ReconciliationFinding(
      kind: ReconciliationKind.cachedBalanceDrift,
      detail:
          'SELLER_PAYABLE (3f2a…): cached 3,100,000 ل.س but its lines sum to '
          '3,025,000 ل.س',
    ),
    ReconciliationFinding(
      kind: ReconciliationKind.suspenseNotEmpty,
      detail: 'suspense holds 75,000 ل.س — something was posted without a home',
    ),
  ],
);
