// The buy bar when the piece cannot be bought.
//
// The reason used to sit in the price's slot — a third of the bar, one line,
// an ellipsis — so the shopper read «هالقطعة مو…» beside a dead button and
// could not tell what was wrong. Pinned: the whole reason is shown, by kind,
// with what she can still do.
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ohara/core/design_system/design_system.dart';
import 'package:ohara/core/localization/app_localizations.dart';
import 'package:ohara/core/shared/entities/category.dart';
import 'package:ohara/core/shared/entities/product.dart';
import 'package:ohara/core/shared/entities/product_variant.dart';
import 'package:ohara/core/shared/entities/seller_offer.dart';
import 'package:ohara/core/shared/entities/user.dart';
import 'package:ohara/core/shared/value_objects/money.dart';
import 'package:ohara/features/product_details/presentation/widgets/product_buy_bar.dart';
import 'package:ohara/l10n/app_localizations.dart' as gen;

final _ar = gen.lookupAppLocalizations(const Locale('ar'));

final _seller = User(
  id: 's1',
  username: 'atelier',
  name: 'أتيليه الورد',
  phone: '+963900000000',
  createdAt: DateTime(2026, 1, 1),
);

SellerOffer _offer({int stock = 4, OfferStatus status = OfferStatus.active}) =>
    SellerOffer(
      id: 'o1',
      seller: _seller,
      price: Money.fromJson('420000'),
      stock: stock,
      status: status,
    );

Product _product(List<SellerOffer> offers) => Product(
  id: 'p1',
  slug: 'dress',
  title: 'فستان',
  description: '',
  category: const Category(
    id: 'c1',
    slug: 'dresses',
    nameAr: 'فساتين',
    nameEn: 'Dresses',
  ),
  offers: offers,
  createdAt: DateTime(2026, 1, 1),
);

Future<void> _pump(
  WidgetTester tester, {
  SellerOffer? offer,
  OfferVariant? variant,
}) async {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
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
          bottomNavigationBar: ProductBuyBar(
            product: _product([?offer]),
            offer: offer,
            variant: variant,
            quantity: 1,
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('sold out: the whole reason, and the way to be told', (
    tester,
  ) async {
    await _pump(tester, offer: _offer(stock: 0, status: OfferStatus.outOfStock));
    expect(find.text(_ar.productUnavailableSoldOut), findsOneWidget);
    expect(find.text(_ar.productUnavailableSoldOutBody), findsOneWidget);
    expect(find.text(_ar.productNotifyWhenBack), findsOneWidget);
    expect(find.text(_ar.addToCart), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('paused by the boutique says so', (tester) async {
    await _pump(tester, offer: _offer(status: OfferStatus.paused));
    expect(find.text(_ar.productUnavailablePaused), findsOneWidget);
  });

  testWidgets('nobody selling it says so', (tester) async {
    await _pump(tester);
    expect(find.text(_ar.productUnavailableNoSeller), findsOneWidget);
    expect(find.text(_ar.productNotifyWhenBack), findsOneWidget);
  });

  testWidgets('only the chosen option is gone: pick another, no alert', (
    tester,
  ) async {
    await _pump(
      tester,
      offer: _offer(),
      variant: OfferVariant(
        id: 'v1',
        variantId: 'pv1',
        name: 'L',
        price: Money.fromJson('420000'),
        stock: 0,
      ),
    );
    expect(find.text(_ar.productUnavailableVariant), findsOneWidget);
    expect(find.text(_ar.productNotifyWhenBack), findsNothing);
  });

  testWidgets('a buyable piece still shows its price and the cart', (
    tester,
  ) async {
    await _pump(tester, offer: _offer());
    expect(find.text(_ar.addToCart), findsOneWidget);
    expect(find.text(_ar.productUnavailableSoldOut), findsNothing);
  });
}
