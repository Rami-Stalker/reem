// Contrast guarantees for the color system, checked against WCAG 2.1.
//
// Every pair here is one the app actually draws: body text on the page,
// status text on its tinted pill, a label on a filled button. A palette change
// that makes any of them hard to read fails this test instead of shipping.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ohara/core/design_system/design_system.dart';

double _contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final hi = la > lb ? la : lb;
  final lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

/// Normal-size text (WCAG AA).
const _text = 4.5;

/// Bold labels on filled controls and badges, and large text (WCAG AA large).
const _label = 3.0;

/// Icons, rating stars and other meaningful graphics (WCAG 1.4.11).
const _graphic = 3.0;

void _expectPairs(
  String mode,
  Map<String, (Color, Color)> pairs,
  double minimum,
) {
  for (final entry in pairs.entries) {
    final (fg, bg) = entry.value;
    final ratio = _contrast(fg, bg);
    expect(
      ratio,
      greaterThanOrEqualTo(minimum),
      reason: '$mode · ${entry.key}: ${ratio.toStringAsFixed(2)}:1 '
          '(needs $minimum:1)',
    );
  }
}

void main() {
  for (final (mode, c) in [
    ('light', DsColorScheme.light),
    ('dark', DsColorScheme.dark),
  ]) {
    group('$mode palette', () {
      test('text on grounds and cards', () {
        _expectPairs(mode, {
          'onSurface / surface': (c.onSurface, c.surface),
          'onBackground / background': (c.onBackground, c.background),
          'onSurface / surfaceVariant': (c.onSurface, c.surfaceVariant),
          'onSurfaceVariant / surface': (c.onSurfaceVariant, c.surface),
          'onSurfaceVariant / background': (c.onSurfaceVariant, c.background),
          'price / surface': (c.price, c.surface),
          'price / background': (c.price, c.background),
          'discount / background': (c.discount, c.background),
          'onInverseSurface / inverseSurface': (
            c.onInverseSurface,
            c.inverseSurface,
          ),
        }, _text);
      });

      test('text on tinted containers', () {
        _expectPairs(mode, {
          'onPrimaryContainer': (c.onPrimaryContainer, c.primaryContainer),
          'onSecondaryContainer': (
            c.onSecondaryContainer,
            c.secondaryContainer,
          ),
          'onAccentContainer': (c.onAccentContainer, c.accentContainer),
          'successInk / container': (c.successInk, c.successContainer),
          'warningInk / container': (c.warningInk, c.warningContainer),
          'errorInk / container': (c.errorInk, c.errorContainer),
          'infoInk / container': (c.infoInk, c.infoContainer),
        }, _text);
      });

      test('status text straight on the page and on cards', () {
        for (final (name, ground) in [
          ('surface', c.surface),
          ('background', c.background),
        ]) {
          _expectPairs(mode, {
            'successInk / $name': (c.successInk, ground),
            'warningInk / $name': (c.warningInk, ground),
            'errorInk / $name': (c.errorInk, ground),
            'infoInk / $name': (c.infoInk, ground),
          }, _text);
        }
      });

      test('labels on filled controls and badges', () {
        _expectPairs(mode, {
          'onSecondary / secondary': (c.onSecondary, c.secondary),
          'onAccent / accent': (c.onAccent, c.accent),
          'onDiscount / discount': (c.onDiscount, c.discount),
          'onWarning / warning': (c.onWarning, c.warning),
        }, _text);
        // The rose button fill and the status fills are the brand's own
        // colors; their labels are bold, so the large-text bar applies.
        _expectPairs(mode, {
          'onPrimary / primary': (c.onPrimary, c.primary),
          'onSuccess / success': (c.onSuccess, c.success),
          'onError / error': (c.onError, c.error),
          'onInfo / info': (c.onInfo, c.info),
        }, _label);
      });

      test('icons and rating stars', () {
        _expectPairs(mode, {
          'primary / surface': (c.primary, c.surface),
          'rating / surface': (c.rating, c.surface),
          'success / surface': (c.success, c.surface),
          'error / surface': (c.error, c.surface),
          'info / surface': (c.info, c.surface),
        }, _graphic);
      });
    });
  }

  test('Material ColorScheme mirrors the design-system colors', () {
    final light = DsColors.lightScheme;
    expect(light.primary, DsColorScheme.light.primary);
    expect(light.secondary, DsColorScheme.light.secondary);
    expect(light.tertiary, DsColorScheme.light.accent);
    expect(light.surface, DsColorScheme.light.surface);
    expect(light.onErrorContainer, DsColorScheme.light.errorInk);

    final dark = DsColors.darkScheme;
    expect(dark.primary, DsColorScheme.dark.primary);
    expect(dark.surface, DsColorScheme.dark.surface);
  });
}
