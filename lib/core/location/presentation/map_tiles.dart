import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:ohara/core/config/app_env.dart';

/// The tile layers under every map in the app, in one place so the picker and
/// the small preview never disagree about what a street looks like.
abstract final class MapTiles {
  static const _userAgentPackage = 'app.ohara';

  /// The base map plus, over imagery, its roads and place names.
  static List<Widget> layers(
    BuildContext context, {
    required bool satellite,
    required bool dark,
  }) {
    if (satellite) {
      return [
        _layer(context, AppEnv.mapSatelliteTilesUrl, maxNativeZoom: 18),
        // Esri's road and place names over Syria stop at zoom 16 — above it
        // the tiles come back empty, and stretching zoom-16 names to fit
        // doubles their size into a smear. So they guide her across the city
        // and step aside at her street, where the roofs speak for themselves
        // and the card below names the spot.
        for (final url in AppEnv.mapLabelsTilesUrl.split(','))
          if (url.trim().isNotEmpty)
            _layer(
              context,
              url.trim(),
              maxNativeZoom: 16,
              maxZoom: 16.6,
              fade: false,
            ),
      ];
    }

    final darkUrl = AppEnv.mapDarkTilesUrl.trim();
    if (dark && darkUrl.isNotEmpty) return [_layer(context, darkUrl)];
    return [
      _layer(
        context,
        AppEnv.mapTilesUrl,
        // No dark tile server configured: the light streets, turned to night
        // on the phone — calmer at night than a white map in a dark app.
        tileBuilder: dark ? _night : null,
      ),
    ];
  }

  /// What the credit line must say for the layers above.
  static String attribution({required bool satellite}) => satellite
      ? '© Esri · © OpenStreetMap contributors'
      : '© OpenStreetMap contributors';

  static TileLayer _layer(
    BuildContext context,
    String url, {
    int maxNativeZoom = 19,
    double maxZoom = double.infinity,
    bool fade = true,
    TileBuilder? tileBuilder,
  }) {
    return TileLayer(
      key: ValueKey('$url-${tileBuilder != null}'),
      urlTemplate: url,
      subdomains: url.contains('{s}') ? const ['a', 'b', 'c'] : const [],
      // Only a server that serves its own @2x tiles gets asked for them:
      // simulating retina would fetch four tiles for every one, which the free
      // servers ask clients not to do.
      retinaMode: url.contains('{r}') && RetinaMode.isHighDensity(context),
      maxNativeZoom: maxNativeZoom,
      maxZoom: maxZoom,
      userAgentPackageName: _userAgentPackage,
      tileBuilder: tileBuilder,
      tileDisplay: fade
          ? const TileDisplay.fadeIn(duration: Duration(milliseconds: 220))
          : const TileDisplay.instantaneous(),
    );
  }

  /// Inverts the street map and turns its hues back the right way round, then
  /// lowers the glare: water stays blue, parks stay green, roads go dark.
  static Widget _night(BuildContext context, Widget tile, TileImage image) {
    return ColorFiltered(
      colorFilter: const ColorFilter.matrix(<double>[
        0.85, 0, 0, 0, 0, //
        0, 0.85, 0, 0, 0, //
        0, 0, 0.92, 0, 4, //
        0, 0, 0, 1, 0, //
      ]),
      child: darkModeTileBuilder(context, tile, image),
    );
  }
}
