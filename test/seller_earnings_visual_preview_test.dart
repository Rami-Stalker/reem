// Renders the seller earnings surfaces to PNGs.
//
//   flutter test test/seller_earnings_visual_preview_test.dart
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
import 'package:reem/features/seller_earnings/domain/entities/seller_earnings.dart';
import 'package:reem/features/seller_earnings/presentation/widgets/earnings_balance_cards.dart';
import 'package:reem/features/seller_earnings/presentation/widgets/earnings_movement_tile.dart';
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

  testWidgets('renders seller earnings in both themes', (tester) async {
    tester.view.physicalSize = const Size(1125, 2000);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    for (final mode in [ThemeMode.light, ThemeMode.dark]) {
      await tester.pumpWidget(_Preview(themeMode: mode));
      await tester.pump(const Duration(milliseconds: 300));
      await _capture(tester, 'seller_earnings_${mode.name}');
    }
  });
}

class _Preview extends StatelessWidget {
  const _Preview({required this.themeMode});

  final ThemeMode themeMode;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
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
            body: Stack(
              children: [
                const Positioned.fill(child: CustomerBackdrop()),
                ListView(
                  padding: const EdgeInsets.symmetric(vertical: DsSpacing.xl),
                  children: [
                    EarningsBalanceCards(earnings: _earnings),
                    const SizedBox(height: DsSpacing.xl),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: DsSpacing.lg,
                      ),
                      child: Column(
                        children: [
                          for (final m in _earnings.movements) ...[
                            EarningsMovementTile(movement: m),
                            const SizedBox(height: DsSpacing.xs),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
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

EarningsMovement _move(
  String id,
  EarningsMovementType type,
  EarningsAccount account,
  String amount, {
  bool isTransfer = false,
}) {
  return EarningsMovement(
    id: id,
    type: type,
    account: account,
    description: '',
    amount: Money.fromJson(amount),
    isTransfer: isTransfer,
    occurredAt: DateTime(2026, 8, 20, 14, 30),
  );
}

final _earnings = SellerEarnings(
  heldInEscrow: Money.fromJson('150000'),
  availableForPayout: Money.fromJson('500000'),
  frozenInDisputes: Money.fromJson('200000'),
  lifetimePaid: Money.fromJson('4250000'),
  lifetimeCommission: Money.fromJson('750000'),
  lifetimeGross: Money.fromJson('5000000'),
  movements: [
    _move(
      '1',
      EarningsMovementType.disputeHeld,
      EarningsAccount.disputeHeld,
      '200000',
      isTransfer: true,
    ),
    _move(
      '2',
      EarningsMovementType.escrowReleased,
      EarningsAccount.payable,
      '500000',
      isTransfer: true,
    ),
    _move(
      '3',
      EarningsMovementType.commissionEarned,
      EarningsAccount.escrow,
      '850000',
    ),
    _move(
      '4',
      EarningsMovementType.payoutPaid,
      EarningsAccount.payable,
      '-1200000',
    ),
  ],
);
