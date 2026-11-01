// «التفاصيل» on a product page: each specification under its Arabic name.
//
// The section used to print the stored keys, so an Arabic product read
// «material: حرير» and «sleeve_length: كم طويل».
//
//   flutter test test/product_detail_body_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ohara/core/design_system/design_system.dart';
import 'package:ohara/core/localization/app_localizations.dart';
import 'package:ohara/core/shared/entities/category.dart';
import 'package:ohara/core/shared/entities/product.dart';
import 'package:ohara/features/product_details/presentation/widgets/product_detail_body.dart';
import 'package:ohara/l10n/app_localizations.dart' as gen;

Product _product({
  Map<String, dynamic> attributes = const {},
  Map<String, String> labels = const {},
}) => Product(
  id: 'p1',
  slug: 'silk',
  title: 'فستان',
  description: '',
  category: const Category(
    id: 'c1',
    slug: 'dresses',
    nameAr: 'فساتين',
    nameEn: 'Dresses',
  ),
  createdAt: DateTime(2026),
  attributes: attributes,
  attributeLabels: labels,
);

Future<void> _pump(WidgetTester tester, Product product) => tester.pumpWidget(
  MaterialApp(
    theme: AppTheme.light,
    locale: const Locale('ar'),
    supportedLocales: L10nSetup.supportedLocales,
    localizationsDelegates: const [
      gen.AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    home: Scaffold(body: ProductDetailBody(product: product)),
  ),
);

void main() {
  testWidgets('the category schema names each specification', (tester) async {
    await _pump(
      tester,
      _product(
        attributes: {'sleeve_length': 'كم طويل', 'material': 'حرير'},
        labels: {'material': 'الخامة', 'sleeve_length': 'طول الكم'},
      ),
    );
    expect(find.text('الخامة'), findsOneWidget);
    expect(find.text('طول الكم'), findsOneWidget);
    expect(find.text('material'), findsNothing);
    expect(find.text('sleeve_length'), findsNothing);
    // The schema's order, not the order the keys were stored in.
    final label = tester.getTopLeft(find.text('الخامة')).dy;
    expect(label, lessThan(tester.getTopLeft(find.text('طول الكم')).dy));
  });

  testWidgets('without titles, the common keys still read in Arabic', (
    tester,
  ) async {
    await _pump(
      tester,
      _product(attributes: {'material': 'حرير', 'skin_type': 'جافة'}),
    );
    expect(find.text('الخامة'), findsOneWidget);
    expect(find.text('نوع البشرة'), findsOneWidget);
    expect(find.text('material'), findsNothing);
  });

  testWidgets('lists and yes/no values read as words', (tester) async {
    await _pump(
      tester,
      _product(
        attributes: {
          'color': ['أسود', 'كحلي'],
          'lined': true,
        },
        labels: {'lined': 'مبطّن'},
      ),
    );
    expect(find.text('أسود، كحلي'), findsOneWidget);
    expect(find.text('نعم'), findsOneWidget);
  });
}
