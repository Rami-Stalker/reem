// Renders the wallet surfaces to PNGs so the design can be eyeballed without
// booting the app. Not an assertion test — it writes `build/visual/*.png`.
//
//   flutter test test/wallet_visual_preview_test.dart
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' show ImageByteFormat;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reem/core/design_system/design_system.dart';
import 'package:reem/core/localization/app_localizations.dart';
import 'package:reem/core/shared/value_objects/money.dart';
import 'package:reem/features/wallet/domain/entities/wallet_transaction.dart';
import 'package:reem/features/wallet/presentation/widgets/wallet_balance_card.dart';
import 'package:reem/features/wallet/presentation/widgets/wallet_transaction_tile.dart';
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

  testWidgets('renders the wallet in both themes', (tester) async {
    tester.view.physicalSize = const Size(1125, 1900);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    for (final mode in [ThemeMode.light, ThemeMode.dark]) {
      await tester.pumpWidget(_Preview(themeMode: mode));
      await tester.pump(const Duration(milliseconds: 300));
      await _capture(tester, 'wallet_${mode.name}');
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
                    WalletBalanceCard(balance: _balance),
                    const SizedBox(height: DsSpacing.xl),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: DsSpacing.lg,
                      ),
                      child: Column(
                        children: [
                          for (final tx in _transactions) ...[
                            WalletTransactionTile(transaction: tx),
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

final _balance = Money.fromJson('300000');

WalletTransaction _tx(
  String id,
  WalletMovementSource source,
  String amount,
  String balanceAfter,
  String reason,
) {
  return WalletTransaction(
    id: id,
    source: source,
    amount: Money.fromJson(amount),
    balanceAfter: Money.fromJson(balanceAfter),
    reason: reason,
    createdAt: DateTime(2026, 8, 20, 14, 30),
  );
}

final _transactions = <WalletTransaction>[
  _tx(
    '1',
    WalletMovementSource.pointsConversion,
    '50000',
    '300000',
    'تحويل ١٠٠ نقطة ولاء',
  ),
  _tx(
    '2',
    WalletMovementSource.orderPayment,
    '-120000',
    '250000',
    'دفع من المحفظة — طلب ORD-4821',
  ),
  _tx(
    '3',
    WalletMovementSource.returnRefund,
    '250000',
    '370000',
    'تسوية نزاع DSP-000012',
  ),
  _tx(
    '4',
    WalletMovementSource.campaignGift,
    '120000',
    '120000',
    'هدية ترحيبية بمناسبة الإطلاق',
  ),
];
