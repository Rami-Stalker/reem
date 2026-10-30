import 'dart:async';
import 'dart:math' as math;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart' hide Path;
import 'package:ohara/core/design_system/design_system.dart';
import 'package:ohara/core/localization/l10n_extension.dart';
import 'package:ohara/core/location/device_location.dart';
import 'package:ohara/core/location/geocoding_service.dart';
import 'package:ohara/core/location/picked_place.dart';
import 'package:ohara/core/location/presentation/map_pin.dart';
import 'package:ohara/core/location/presentation/map_tiles.dart';
import 'package:ohara/core/location/syria_governorates.dart';
import 'package:ohara/core/platform/app_haptics.dart';
import 'package:url_launcher/url_launcher.dart';

/// Opens the full-screen map and returns where she put the pin, or null if
/// she backed out.
///
/// [initialPoint] reopens a pin she already dropped; without one the map
/// starts on [initialGovernorate] and then flies to her own position.
Future<PickedPlace?> showLocationPicker(
  BuildContext context, {
  LatLng? initialPoint,
  String? initialGovernorate,
  String? placeLabel,
  String? confirmLabel,
}) {
  return Navigator.of(context, rootNavigator: true).push<PickedPlace>(
    PageRouteBuilder<PickedPlace>(
      transitionDuration: DsMotion.slow,
      reverseTransitionDuration: DsMotion.moderate,
      pageBuilder: (_, _, _) => LocationPickerScreen(
        initialPoint: initialPoint,
        initialGovernorate: initialGovernorate,
        placeLabel: placeLabel,
        confirmLabel: confirmLabel,
      ),
      transitionsBuilder: (context, animation, _, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: DsMotion.gentle,
          reverseCurve: DsMotion.standard,
        );
        return FadeTransition(
          opacity: curved,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.94, end: 1).animate(curved),
            child: child,
          ),
        );
      },
    ),
  );
}

enum _MapLayer { streets, satellite }

/// The map itself: a pin fixed in the middle and a world that moves under it.
///
/// A fixed pin rather than a draggable marker because a finger on a phone
/// covers the very spot it is trying to place — moving the map keeps the
/// target visible the whole time, which is why every ride-hailing app ended
/// up here. When the map comes to rest the pin drops, the phone ticks, and
/// the address underneath is read out on the card below.
class LocationPickerScreen extends ConsumerStatefulWidget {
  const LocationPickerScreen({
    super.key,
    this.initialPoint,
    this.initialGovernorate,
    this.placeLabel,
    this.confirmLabel,
  });

  final LatLng? initialPoint;
  final String? initialGovernorate;

  /// The card's overline — «موقع التوصيل» by default, «موقع المحل» for a shop.
  final String? placeLabel;
  final String? confirmLabel;

  @override
  ConsumerState<LocationPickerScreen> createState() =>
      _LocationPickerScreenState();
}

class _LocationPickerScreenState extends ConsumerState<LocationPickerScreen>
    with TickerProviderStateMixin {
  static const double _minZoom = 5.5;
  static const double _maxZoom = 19;
  static const double _streetZoom = 17.2;

  /// Below this a pin covers a neighbourhood, not a door: confirming first
  /// brings her closer instead.
  static const double _doorZoom = 15;

  /// Generous around the borders so a village on the edge can still sit in
  /// the middle of the screen, tight enough that she cannot lose the country.
  static final _syriaBounds = LatLngBounds(
    const LatLng(31.4, 34.6),
    const LatLng(37.6, 42.6),
  );

  final _map = MapController();

  late final AnimationController _fly = AnimationController(vsync: this)
    ..addListener(_onFlyTick);
  late final AnimationController _spin = AnimationController(
    vsync: this,
    duration: DsMotion.slow,
  )..addListener(_onSpinTick);

  /// 0 resting on the map, 1 lifted while it moves.
  late final AnimationController _lift = AnimationController(
    vsync: this,
    duration: DsMotion.fast,
  );
  late final AnimationController _ripple = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2200),
  )..repeat();

  // Fly-to state, read by [_onFlyTick].
  LatLng _flyFrom = SyriaGovernorates.defaultCenter;
  LatLng _flyTarget = SyriaGovernorates.defaultCenter;
  double _flyFromZoom = 12;
  double _flyToZoom = 12;
  double _flyArc = 0;
  double _spinFrom = 0;

  bool _mapReady = false;
  bool _moving = false;
  bool _touched = false;
  int _pointers = 0;
  Timer? _settleTimer;
  double _rotation = 0;
  bool _closeEnough = false;

  PickedPlace? _place;
  bool _reading = false;
  CancelToken? _readToken;
  LatLng? _lastReadPoint;

  DeviceLocationFix? _fix;
  bool _locating = false;

  _MapLayer _layer = _MapLayer.streets;

  final _query = TextEditingController();
  final _searchFocus = FocusNode();
  Timer? _searchDebounce;
  CancelToken? _searchToken;
  List<PlaceSuggestion> _results = const [];
  bool _searching = false;
  bool _searched = false;

  double _cardHeight = 260;

  late final LatLng _initialCenter;
  late final double _initialZoom;

  @override
  void initState() {
    super.initState();
    final known = SyriaGovernorates.byName(widget.initialGovernorate);
    if (widget.initialPoint != null) {
      _initialCenter = widget.initialPoint!;
      _initialZoom = _streetZoom;
    } else if (known != null) {
      _initialCenter = known.center;
      _initialZoom = known.zoom;
    } else {
      _initialCenter = SyriaGovernorates.defaultCenter;
      _initialZoom = 12;
    }
    _searchFocus.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _settleTimer?.cancel();
    _searchDebounce?.cancel();
    _readToken?.cancel();
    _searchToken?.cancel();
    _fly.dispose();
    _spin.dispose();
    _lift.dispose();
    _ripple.dispose();
    _pulse.dispose();
    _query.dispose();
    _searchFocus.dispose();
    _map.dispose();
    super.dispose();
  }

  bool get _reduceMotion => MediaQuery.disableAnimationsOf(context);

  String get _language => context.isArabic ? 'ar' : 'en';

  // ── Camera ──────────────────────────────────────────────────────────────

  void _onMapReady() {
    _mapReady = true;
    if (widget.initialPoint != null) {
      _read(widget.initialPoint!);
    } else {
      _openNearHer();
    }
  }

  /// No pin yet: start where the phone last was, then ask for a real fix.
  Future<void> _openNearHer() async {
    final last = await DeviceLocation.lastKnown();
    if (!mounted) return;
    if (last != null && _syriaBounds.contains(last)) {
      _map.move(last, 15.5);
    }
    final found = await _locate(quiet: true);
    if (!found && mounted) await _read(_map.camera.center);
  }

  /// A flight rather than a jump: it rises with the distance and settles on
  /// the target, so she can see where she has been taken.
  void _flyTo(LatLng target, double zoom) {
    if (!_mapReady) return;
    final camera = _map.camera;
    zoom = zoom.clamp(_minZoom, _maxZoom);
    if (_reduceMotion) {
      _map.move(target, zoom);
      return;
    }
    final km = const Distance().as(LengthUnit.Kilometer, camera.center, target);
    _flyFrom = camera.center;
    _flyTarget = target;
    _flyFromZoom = camera.zoom;
    _flyToZoom = zoom;
    // A street away: a glide. Another governorate: up, across, and down.
    _flyArc = km < 0.8
        ? 0
        : (math.log(km + 1) / math.ln10 * 1.35).clamp(0, 4.2);
    _fly
      ..duration = Duration(milliseconds: (650 + _flyArc * 230).round())
      ..forward(from: 0);
  }

  void _onFlyTick() {
    final t = DsMotion.silk.transform(_fly.value);
    final lat = _lerp(_flyFrom.latitude, _flyTarget.latitude, t);
    final lng = _lerp(_flyFrom.longitude, _flyTarget.longitude, t);
    final zoom =
        _lerp(_flyFromZoom, _flyToZoom, t) - _flyArc * math.sin(math.pi * t);
    _map.move(LatLng(lat, lng), zoom.clamp(_minZoom, _maxZoom), id: 'fly');
  }

  void _resetNorth() {
    AppHaptics.light();
    if (_reduceMotion) {
      _map.rotate(0);
      return;
    }
    // The short way round: 350° is ten degrees from north, not 350.
    var from = _map.camera.rotation % 360;
    if (from > 180) from -= 360;
    _spinFrom = from;
    _spin.forward(from: 0);
  }

  void _onSpinTick() {
    final t = DsMotion.gentle.transform(_spin.value);
    _map.rotate(_spinFrom * (1 - t));
  }

  void _zoomBy(double delta) {
    AppHaptics.light();
    final camera = _map.camera;
    _flyTo(camera.center, camera.zoom + delta);
  }

  static double _lerp(double a, double b, double t) => a + (b - a) * t;

  // ── The pin ─────────────────────────────────────────────────────────────

  void _onPositionChanged(MapCamera camera, bool hasGesture) {
    if ((camera.rotation - _rotation).abs() > 0.5) {
      setState(() => _rotation = camera.rotation);
    }
    final closeEnough = camera.zoom >= _doorZoom;
    if (closeEnough != _closeEnough) {
      setState(() => _closeEnough = closeEnough);
    }
    if (hasGesture && !_touched) setState(() => _touched = true);
    _liftPin();
    // While a finger is still down the map has not been let go of yet.
    if (_pointers == 0) _scheduleSettle();
  }

  void _liftPin() {
    _settleTimer?.cancel();
    if (_moving) return;
    _readToken?.cancel();
    setState(() {
      _moving = true;
      _reading = false;
    });
    _lift.animateTo(1, duration: DsMotion.fast, curve: DsMotion.emphasized);
  }

  void _scheduleSettle() {
    _settleTimer?.cancel();
    _settleTimer = Timer(const Duration(milliseconds: 380), _settle);
  }

  void _settle() {
    if (!mounted || !_moving) return;
    setState(() => _moving = false);
    // The spring overshoots below zero: the pin presses into the map and
    // springs back, which is what makes it feel set down rather than shown.
    _lift.animateTo(
      0,
      duration: _reduceMotion ? Duration.zero : DsMotion.slower,
      curve: DsMotion.softSpring,
    );
    if (!_reduceMotion) _ripple.forward(from: 0);
    AppHaptics.selection();
    _read(_map.camera.center);
  }

  Future<void> _read(LatLng point) async {
    final last = _lastReadPoint;
    if (last != null &&
        _place != null &&
        const Distance().as(LengthUnit.Meter, last, point) < 4) {
      setState(() => _place = _withPoint(_place!, point));
      return;
    }

    _readToken?.cancel();
    final token = _readToken = CancelToken();
    setState(() => _reading = true);

    final place = await ref
        .read(geocodingServiceProvider)
        .reverse(point, language: _language, cancelToken: token);
    if (!mounted || token.isCancelled) return;
    setState(() {
      _place = place;
      _reading = false;
      _lastReadPoint = point;
    });
  }

  static PickedPlace _withPoint(PickedPlace place, LatLng point) => PickedPlace(
    point: point,
    governorate: place.governorate,
    city: place.city,
    district: place.district,
    neighbourhood: place.neighbourhood,
    road: place.road,
    houseNumber: place.houseNumber,
    displayName: place.displayName,
    isRural: place.isRural,
    countryCode: place.countryCode,
  );

  // ── Her position ────────────────────────────────────────────────────────

  /// Returns whether a fix was found. [quiet] is the automatic attempt on
  /// opening: a refusal there is her answer, not an error to show her.
  Future<bool> _locate({bool quiet = false}) async {
    if (_locating) return false;
    if (!quiet) AppHaptics.light();
    setState(() => _locating = true);
    final result = await DeviceLocation.current();
    if (!mounted) return false;
    setState(() => _locating = false);

    switch (result) {
      case DeviceLocationFix():
        setState(() => _fix = result);
        _flyTo(result.point, _streetZoom);
        return true;
      case DeviceLocationError(:final failure):
        final l10n = context.l10n;
        if (quiet && failure == DeviceLocationFailure.denied) return false;
        final canFix =
            failure == DeviceLocationFailure.serviceDisabled ||
            failure == DeviceLocationFailure.deniedForever;
        DsSnackbar.show(
          context,
          message: switch (failure) {
            DeviceLocationFailure.serviceDisabled => l10n.mapPickerLocationOff,
            DeviceLocationFailure.denied ||
            DeviceLocationFailure.deniedForever => l10n.mapPickerLocationDenied,
            DeviceLocationFailure.unavailable =>
              l10n.mapPickerLocationUnavailable,
          },
          type: DsSnackbarType.warning,
          actionLabel: canFix ? l10n.mapPickerOpenSettings : null,
          onAction: canFix
              ? () => DeviceLocation.openSettingsFor(failure)
              : null,
        );
        return false;
    }
  }

  // ── Search ──────────────────────────────────────────────────────────────

  void _onQueryChanged(String value) {
    setState(() {});
    _searchDebounce?.cancel();
    _searchToken?.cancel();
    if (value.trim().length < 2) {
      setState(() {
        _results = const [];
        _searching = false;
        _searched = false;
      });
      return;
    }
    _searchDebounce = Timer(const Duration(milliseconds: 450), () async {
      final token = _searchToken = CancelToken();
      setState(() => _searching = true);
      final results = await ref
          .read(geocodingServiceProvider)
          .search(
            value,
            near: _mapReady ? _map.camera.center : null,
            language: _language,
            cancelToken: token,
          );
      if (!mounted || token.isCancelled) return;
      setState(() {
        _results = results;
        _searching = false;
        _searched = true;
      });
    });
  }

  void _clearSearch() {
    _query.clear();
    _onQueryChanged('');
  }

  void _choose(PlaceSuggestion suggestion) {
    AppHaptics.selection();
    _searchFocus.unfocus();
    setState(() {
      _results = const [];
      _searched = false;
      _touched = true;
    });
    _query.text = suggestion.title;
    _flyTo(suggestion.point, _streetZoom);
  }

  void _jumpTo(SyriaGovernorate governorate) {
    AppHaptics.selection();
    setState(() => _touched = true);
    _flyTo(governorate.center, governorate.zoom);
  }

  // ── Done ────────────────────────────────────────────────────────────────

  bool get _canConfirm =>
      _mapReady && !_moving && !_reading && !(_place?.isOutsideSyria ?? false);

  void _confirm() {
    if (!_closeEnough) {
      // A pin dropped on the whole city would send the courier to its middle.
      AppHaptics.light();
      _flyTo(_map.camera.center, _streetZoom);
      return;
    }
    AppHaptics.confirm();
    final center = _map.camera.center;
    final place = _place == null
        ? PickedPlace(point: center)
        : _withPoint(_place!, center);
    Navigator.of(context).pop(place);
  }

  // ── Layout ──────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final colors = context.dsColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final showResults =
        _searchFocus.hasFocus && (_results.isNotEmpty || _searched);

    return Scaffold(
      backgroundColor: colors.background,
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          // The map stops under the card's rounded top, so its centre — the
          // pin — is the centre of what she can see.
          Positioned.fill(
            bottom: math.max(0, _cardHeight - DsRadius.sheet),
            child: Stack(
              fit: StackFit.expand,
              children: [
                _buildMap(isDark),
                const _TopScrim(),
                IgnorePointer(child: _buildPin()),
                PositionedDirectional(
                  end: DsSpacing.md,
                  bottom: DsRadius.sheet + DsSpacing.md,
                  child: _buildControls(),
                ),
                PositionedDirectional(
                  start: DsSpacing.md,
                  bottom: DsRadius.sheet + DsSpacing.xs,
                  child: _Attribution(satellite: _layer == _MapLayer.satellite),
                ),
              ],
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _MeasureSize(
              onChange: (size) {
                if ((size.height - _cardHeight).abs() > 1) {
                  setState(() => _cardHeight = size.height);
                }
              },
              child: _PlaceCard(
                place: _place,
                reading: _reading || _moving,
                moving: _moving,
                fix: _fix,
                placeLabel: widget.placeLabel,
                confirmLabel: _closeEnough
                    ? widget.confirmLabel
                    : context.l10n.mapPickerZoomCloser,
                confirmIcon: _closeEnough
                    ? Icons.check_rounded
                    : Icons.zoom_in_rounded,
                onConfirm: _canConfirm ? _confirm : null,
              ),
            ),
          ),
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                DsSpacing.md,
                DsSpacing.sm,
                DsSpacing.md,
                0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      _MapButton(
                        icon: Icons.arrow_back_rounded,
                        tooltip: MaterialLocalizations.of(
                          context,
                        ).backButtonTooltip,
                        onTap: () => Navigator.of(context).maybePop(),
                        directional: true,
                      ),
                      DsGaps.hSm,
                      Expanded(child: _buildSearchField()),
                    ],
                  ),
                  AnimatedSize(
                    duration: DsMotion.moderate,
                    curve: DsMotion.gentle,
                    alignment: Alignment.topCenter,
                    child: showResults
                        // Part of the search box as far as taps go: without
                        // this, the pointer-down on a result counts as a tap
                        // outside the field, the field lets go of focus, and
                        // the list vanishes before the result is chosen.
                        ? TextFieldTapRegion(
                            child: _SearchResults(
                              results: _results,
                              onTap: _choose,
                            ),
                          )
                        : _GovernorateStrip(
                            selected: _place?.governorate,
                            onTap: _jumpTo,
                          ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMap(bool isDark) {
    final colors = context.dsColors;
    final satellite = _layer == _MapLayer.satellite;
    final fix = _fix;

    return FlutterMap(
      mapController: _map,
      options: MapOptions(
        initialCenter: _initialCenter,
        initialZoom: _initialZoom,
        minZoom: _minZoom,
        maxZoom: _maxZoom,
        backgroundColor: isDark
            ? DsColors.surfaceDark
            : DsColors.backgroundSecondary,
        cameraConstraint: CameraConstraint.containCenter(bounds: _syriaBounds),
        onMapReady: _onMapReady,
        onPositionChanged: _onPositionChanged,
        onPointerDown: (_, _) {
          _pointers++;
          if (_searchFocus.hasFocus) _searchFocus.unfocus();
          if (_fly.isAnimating) _fly.stop();
          _liftPin();
        },
        onPointerUp: (_, _) {
          _pointers = math.max(0, _pointers - 1);
          if (_pointers == 0) _scheduleSettle();
        },
        onPointerCancel: (_, _) {
          _pointers = math.max(0, _pointers - 1);
          if (_pointers == 0) _scheduleSettle();
        },
      ),
      children: [
        ...MapTiles.layers(context, satellite: satellite, dark: isDark),
        if (fix != null) ...[
          CircleLayer(
            circles: [
              CircleMarker(
                point: fix.point,
                radius: fix.accuracyMeters.clamp(8, 400),
                useRadiusInMeter: true,
                color: colors.info.withValues(alpha: 0.12),
                borderColor: colors.info.withValues(alpha: 0.35),
                borderStrokeWidth: 1,
              ),
            ],
          ),
          MarkerLayer(
            markers: [
              Marker(
                point: fix.point,
                width: 72,
                height: 72,
                child: _YouAreHere(pulse: _pulse, color: colors.info),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildPin() {
    final l10n = context.l10n;
    final bubble = _locating
        ? l10n.mapPickerLocating
        : (!_touched ? l10n.mapPickerMoveHint : null);

    return Center(
      child: SizedBox(
        width: 260,
        height: MapPin.height * 2 + 110,
        child: AnimatedBuilder(
          animation: Listenable.merge([_lift, _ripple]),
          builder: (context, _) {
            final lift = _lift.value;
            return Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                // Where the tip will land: a shadow that tightens as the pin
                // comes down, and a ring that spreads when it touches.
                PinGroundShadow(lift: lift.clamp(0, 1)),
                if (_ripple.isAnimating)
                  PinRipple(
                    progress: _ripple.value,
                    color: context.dsColors.primary,
                  ),
                Transform.translate(
                  offset: Offset(0, -MapPin.height / 2 - lift * 22),
                  child: Transform.scale(
                    // Squashes a little on landing, from the overshoot.
                    scaleY: 1 + math.min(0, lift) * 0.6,
                    scaleX: 1 - math.min(0, lift) * 0.4,
                    alignment: Alignment.bottomCenter,
                    child: MapPin(busy: _reading || _locating),
                  ),
                ),
                Positioned(
                  top: 0,
                  child: AnimatedSwitcher(
                    duration: DsMotion.moderate,
                    switchInCurve: DsMotion.softSpring,
                    transitionBuilder: (child, animation) => FadeTransition(
                      opacity: animation,
                      child: ScaleTransition(scale: animation, child: child),
                    ),
                    child: bubble == null || _moving
                        ? const SizedBox.shrink()
                        : _PinBubble(key: ValueKey(bubble), text: bubble),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildControls() {
    final l10n = context.l10n;
    final satellite = _layer == _MapLayer.satellite;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedSwitcher(
          duration: DsMotion.moderate,
          transitionBuilder: (child, animation) =>
              ScaleTransition(scale: animation, child: child),
          child: _rotation.abs() % 360 > 1
              ? Padding(
                  padding: const EdgeInsets.only(bottom: DsSpacing.sm),
                  child: _MapButton(
                    tooltip: l10n.mapPickerResetNorth,
                    onTap: _resetNorth,
                    child: Transform.rotate(
                      angle: -_rotation * math.pi / 180,
                      child: const _CompassNeedle(),
                    ),
                  ),
                )
              : const SizedBox.shrink(),
        ),
        _MapButton(
          icon: satellite ? Icons.map_rounded : Icons.satellite_alt_rounded,
          tooltip: satellite ? l10n.mapPickerStreets : l10n.mapPickerSatellite,
          onTap: () {
            AppHaptics.selection();
            setState(
              () =>
                  _layer = satellite ? _MapLayer.streets : _MapLayer.satellite,
            );
          },
        ),
        DsGaps.vSm,
        _ZoomPair(
          onZoomIn: () => _zoomBy(1),
          onZoomOut: () => _zoomBy(-1),
          zoomInLabel: l10n.mapPickerZoomIn,
          zoomOutLabel: l10n.mapPickerZoomOut,
        ),
        DsGaps.vSm,
        _MapButton(
          icon: _fix == null
              ? Icons.my_location_rounded
              : Icons.gps_fixed_rounded,
          tooltip: l10n.mapPickerMyLocation,
          prominent: true,
          busy: _locating,
          onTap: _locate,
        ),
      ],
    );
  }

  Widget _buildSearchField() {
    final colors = context.dsColors;
    return _Glass(
      radius: DsRadius.pill,
      child: SizedBox(
        height: DsSizes.controlMd + 4,
        child: TextField(
          controller: _query,
          focusNode: _searchFocus,
          onChanged: _onQueryChanged,
          textInputAction: TextInputAction.search,
          onSubmitted: (_) {
            if (_results.isNotEmpty) _choose(_results.first);
          },
          style: context.dsText.body,
          decoration: InputDecoration(
            isDense: true,
            filled: false,
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: DsSpacing.sm),
            hintText: context.l10n.mapPickerSearchHint,
            hintStyle: context.dsText.bodyMuted,
            prefixIcon: Icon(
              Icons.search_rounded,
              color: colors.primary,
              size: DsSizes.iconSm,
            ),
            suffixIcon: _searching
                ? Padding(
                    padding: const EdgeInsets.all(DsSpacing.sm + 2),
                    child: SizedBox.square(
                      dimension: DsSizes.iconXs,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: colors.primary,
                      ),
                    ),
                  )
                : _query.text.isEmpty
                ? null
                : IconButton(
                    icon: Icon(
                      Icons.close_rounded,
                      size: DsSizes.iconSm,
                      color: colors.onSurfaceVariant,
                    ),
                    onPressed: _clearSearch,
                  ),
          ),
        ),
      ),
    );
  }
}

// ── Pieces ────────────────────────────────────────────────────────────────

/// Frosted surface the controls sit on, so they read over any map.
class _Glass extends StatelessWidget {
  const _Glass({required this.child, this.radius = DsRadius.xl});

  final Widget child;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final colors = context.dsColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final shape = BorderRadius.circular(radius);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: shape,
        boxShadow: context.shadowMedium,
      ),
      child: ClipRRect(
        borderRadius: shape,
        child: Material(
          color: (isDark ? colors.surfaceElevated : colors.surface).withValues(
            alpha: 0.94,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: shape,
            side: BorderSide(color: colors.border.withValues(alpha: 0.6)),
          ),
          child: child,
        ),
      ),
    );
  }
}

class _MapButton extends StatelessWidget {
  const _MapButton({
    required this.tooltip,
    required this.onTap,
    this.icon,
    this.child,
    this.prominent = false,
    this.busy = false,
    this.directional = false,
  });

  final IconData? icon;
  final Widget? child;
  final String tooltip;
  final VoidCallback onTap;
  final bool prominent;
  final bool busy;

  /// Mirrors in right-to-left, like a back arrow should.
  final bool directional;

  @override
  Widget build(BuildContext context) {
    final colors = context.dsColors;
    final size = prominent ? DsSizes.fabSize : DsSizes.controlMd + 4;
    final fg = prominent ? DsColors.onMedia : colors.onSurface;

    Widget glyph =
        child ??
        Icon(
          icon,
          size: prominent ? DsSizes.iconMd : DsSizes.iconSm,
          color: fg,
        );
    if (directional && context.isRtl) {
      glyph = Transform.flip(flipX: true, child: glyph);
    }

    final content = SizedBox.square(
      dimension: size,
      child: Center(
        child: AnimatedSwitcher(
          duration: DsMotion.normal,
          child: busy
              ? SizedBox.square(
                  key: const ValueKey('busy'),
                  dimension: DsSizes.iconSm,
                  child: CircularProgressIndicator(strokeWidth: 2.4, color: fg),
                )
              : KeyedSubtree(key: ValueKey(icon), child: glyph),
        ),
      ),
    );

    final button = prominent
        ? DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: context.primaryGradient,
              boxShadow: context.glowShadow(
                colors.primary,
                blur: 20,
                alpha: 0.4,
              ),
            ),
            child: Material(
              type: MaterialType.transparency,
              shape: const CircleBorder(),
              clipBehavior: Clip.antiAlias,
              child: InkWell(onTap: busy ? null : onTap, child: content),
            ),
          )
        : _Glass(
            radius: DsRadius.pill,
            child: InkWell(onTap: onTap, child: content),
          );

    return Tooltip(
      message: tooltip,
      child: Semantics(button: true, label: tooltip, child: button),
    );
  }
}

class _ZoomPair extends StatelessWidget {
  const _ZoomPair({
    required this.onZoomIn,
    required this.onZoomOut,
    required this.zoomInLabel,
    required this.zoomOutLabel,
  });

  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;
  final String zoomInLabel;
  final String zoomOutLabel;

  @override
  Widget build(BuildContext context) {
    final colors = context.dsColors;
    Widget half(IconData icon, String label, VoidCallback onTap) => Tooltip(
      message: label,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          width: DsSizes.controlMd + 4,
          height: DsSizes.controlMd,
          child: Icon(icon, size: DsSizes.iconSm, color: colors.onSurface),
        ),
      ),
    );
    return _Glass(
      radius: DsRadius.xxl,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          half(Icons.add_rounded, zoomInLabel, onZoomIn),
          Container(width: 22, height: 1, color: colors.divider),
          half(Icons.remove_rounded, zoomOutLabel, onZoomOut),
        ],
      ),
    );
  }
}

class _CompassNeedle extends StatelessWidget {
  const _CompassNeedle();

  @override
  Widget build(BuildContext context) {
    final colors = context.dsColors;
    return CustomPaint(
      size: const Size(14, 26),
      painter: _NeedlePainter(north: colors.error, south: colors.outline),
    );
  }
}

class _NeedlePainter extends CustomPainter {
  _NeedlePainter({required this.north, required this.south});

  final Color north;
  final Color south;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final top = Path()
      ..moveTo(w / 2, 0)
      ..lineTo(w, h / 2)
      ..lineTo(0, h / 2)
      ..close();
    final bottom = Path()
      ..moveTo(0, h / 2)
      ..lineTo(w, h / 2)
      ..lineTo(w / 2, h)
      ..close();
    canvas
      ..drawPath(top, Paint()..color = north)
      ..drawPath(bottom, Paint()..color = south);
  }

  @override
  bool shouldRepaint(_NeedlePainter old) =>
      old.north != north || old.south != south;
}

/// Her own position: a dot that breathes, the way every map has taught her.
class _YouAreHere extends StatelessWidget {
  const _YouAreHere({required this.pulse, required this.color});

  final Animation<double> pulse;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: pulse,
      builder: (context, _) {
        final t = Curves.easeOut.transform(pulse.value);
        return Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 20 + 52 * t,
              height: 20 + 52 * t,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color.withValues(alpha: 0.28 * (1 - t)),
              ),
            ),
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.25),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(4),
              child: DecoratedBox(
                decoration: BoxDecoration(shape: BoxShape.circle, color: color),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _PinBubble extends StatelessWidget {
  const _PinBubble({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = context.dsColors;
    return Container(
      constraints: const BoxConstraints(maxWidth: 250),
      padding: const EdgeInsets.symmetric(
        horizontal: DsSpacing.md,
        vertical: DsSpacing.xs + 2,
      ),
      decoration: BoxDecoration(
        color: colors.inverseSurface.withValues(alpha: 0.92),
        borderRadius: DsRadius.borderPill,
        boxShadow: context.shadowSoft,
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: context.dsText.caption.semibold.tint(colors.onInverseSurface),
      ),
    );
  }
}

/// A soft wash behind the search bar so it reads over a busy map.
class _TopScrim extends StatelessWidget {
  const _TopScrim();

  @override
  Widget build(BuildContext context) {
    final colors = context.dsColors;
    return IgnorePointer(
      child: Align(
        alignment: Alignment.topCenter,
        child: Container(
          height: 150,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                colors.background.withValues(alpha: 0.55),
                colors.background.withValues(alpha: 0),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The fourteen governorates, one tap from each other.
class _GovernorateStrip extends StatelessWidget {
  const _GovernorateStrip({required this.selected, required this.onTap});

  final String? selected;
  final ValueChanged<SyriaGovernorate> onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.dsColors;
    final current = SyriaGovernorates.byName(selected);
    return Padding(
      padding: const EdgeInsets.only(top: DsSpacing.sm),
      child: SizedBox(
        height: DsSizes.chipHeight,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          clipBehavior: Clip.none,
          padding: const EdgeInsets.symmetric(horizontal: DsSpacing.xxs),
          itemCount: SyriaGovernorates.all.length,
          separatorBuilder: (_, _) => DsGaps.hXs,
          itemBuilder: (context, index) {
            final governorate = SyriaGovernorates.all[index];
            final on = governorate.name == current?.name;
            return AnimatedContainer(
              duration: DsMotion.moderate,
              curve: DsMotion.gentle,
              decoration: BoxDecoration(
                borderRadius: DsRadius.borderPill,
                gradient: on ? context.primaryGradient : null,
                boxShadow: on
                    ? context.glowShadow(colors.primary, blur: 14, alpha: 0.3)
                    : context.shadowXs,
              ),
              child: Material(
                color: on
                    ? Colors.transparent
                    : colors.surface.withValues(alpha: 0.94),
                shape: StadiumBorder(
                  side: BorderSide(
                    color: on ? Colors.transparent : colors.border,
                  ),
                ),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: () => onTap(governorate),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: DsSpacing.md,
                    ),
                    child: Center(
                      child: Text(
                        governorate.name,
                        style: context.dsText.labelStrong.tint(
                          on ? DsColors.onMedia : colors.onSurface,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _SearchResults extends StatelessWidget {
  const _SearchResults({required this.results, required this.onTap});

  final List<PlaceSuggestion> results;
  final ValueChanged<PlaceSuggestion> onTap;

  static IconData _iconOf(String? kind) => switch (kind) {
    'amenity' => Icons.local_cafe_rounded,
    'shop' => Icons.storefront_rounded,
    'highway' => Icons.signpost_rounded,
    'building' => Icons.apartment_rounded,
    'tourism' || 'historic' => Icons.account_balance_rounded,
    'leisure' => Icons.park_rounded,
    'place' || 'boundary' => Icons.location_city_rounded,
    _ => Icons.place_rounded,
  };

  @override
  Widget build(BuildContext context) {
    final colors = context.dsColors;
    return Padding(
      padding: const EdgeInsets.only(top: DsSpacing.sm),
      child: _Glass(
        radius: DsRadius.card,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 340),
          child: results.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(DsSpacing.lg),
                  child: Row(
                    children: [
                      Icon(
                        Icons.travel_explore_rounded,
                        color: colors.onSurfaceVariant,
                      ),
                      DsGaps.hSm,
                      Expanded(
                        child: Text(
                          context.l10n.mapPickerNoResults,
                          style: context.dsText.bodyMuted,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.separated(
                  shrinkWrap: true,
                  padding: const EdgeInsets.symmetric(vertical: DsSpacing.xs),
                  itemCount: results.length,
                  separatorBuilder: (_, _) => Divider(
                    height: 1,
                    indent: DsSpacing.massive,
                    color: colors.divider,
                  ),
                  itemBuilder: (context, index) {
                    final result = results[index];
                    return InkWell(
                      onTap: () => onTap(result),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: DsSpacing.md,
                          vertical: DsSpacing.sm,
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: DsSizes.avatarSm,
                              height: DsSizes.avatarSm,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: colors.primaryContainer,
                              ),
                              child: Icon(
                                _iconOf(result.kind),
                                size: DsSizes.iconXs,
                                color: colors.primary,
                              ),
                            ),
                            DsGaps.hSm,
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    result.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: context.dsText.body.semibold,
                                  ),
                                  if (result.subtitle.isNotEmpty)
                                    Text(
                                      result.subtitle,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: context.dsText.caption,
                                    ),
                                ],
                              ),
                            ),
                            Icon(
                              context.isRtl
                                  ? Icons.north_east_rounded
                                  : Icons.north_west_rounded,
                              size: DsSizes.iconXs,
                              color: colors.onSurfaceVariant,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ),
    );
  }
}

/// The address under the pin, and the button that keeps it.
class _PlaceCard extends StatelessWidget {
  const _PlaceCard({
    required this.place,
    required this.reading,
    required this.moving,
    required this.fix,
    required this.onConfirm,
    this.placeLabel,
    this.confirmLabel,
    this.confirmIcon = Icons.check_rounded,
  });

  final PickedPlace? place;
  final bool reading;
  final bool moving;
  final DeviceLocationFix? fix;
  final VoidCallback? onConfirm;
  final String? placeLabel;
  final String? confirmLabel;
  final IconData confirmIcon;

  @override
  Widget build(BuildContext context) {
    final colors = context.dsColors;
    final l10n = context.l10n;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final place = this.place;
    final unnamed = place != null && place.headline.isEmpty;

    // Her own fix close to the pin: the halo's radius is worth saying.
    final accuracy =
        fix != null &&
            place != null &&
            const Distance().as(LengthUnit.Meter, fix!.point, place.point) < 40
        ? fix!.accuracyMeters.round()
        : null;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? colors.surfaceElevated : colors.surface,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(DsRadius.sheet),
        ),
        boxShadow: context.shadowOverlay,
      ),
      padding: EdgeInsets.fromLTRB(
        DsSpacing.lg,
        DsSpacing.sm,
        DsSpacing.lg,
        DsSpacing.lg + MediaQuery.paddingOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: DsSizes.sheetHandleWidth,
              height: DsSizes.sheetHandleHeight,
              decoration: BoxDecoration(
                color: colors.outline.withValues(alpha: 0.5),
                borderRadius: DsRadius.borderPill,
              ),
            ),
          ),
          DsGaps.vMd,
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AnimatedContainer(
                duration: DsMotion.moderate,
                width: DsSizes.avatarMd,
                height: DsSizes.avatarMd,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: reading ? null : context.primaryGradient,
                  color: reading ? colors.primaryContainer : null,
                  boxShadow: reading
                      ? null
                      : context.glowShadow(
                          colors.primary,
                          blur: 16,
                          alpha: 0.3,
                        ),
                ),
                child: AnimatedSwitcher(
                  duration: DsMotion.normal,
                  child: Icon(
                    reading
                        ? Icons.travel_explore_rounded
                        : (place?.isRural ?? false)
                        ? Icons.landscape_rounded
                        : Icons.home_work_rounded,
                    key: ValueKey('$reading-${place?.isRural}'),
                    size: DsSizes.iconSm,
                    color: reading ? colors.primary : DsColors.onMedia,
                  ),
                ),
              ),
              DsGaps.hSm,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      (placeLabel ?? l10n.mapPickerDeliveryHere).toUpperCase(),
                      style: context.dsText.overline.tint(colors.primary),
                    ),
                    DsGaps.vXxxs,
                    AnimatedSwitcher(
                      duration: DsMotion.moderate,
                      switchInCurve: DsMotion.gentle,
                      transitionBuilder: (child, animation) => FadeTransition(
                        opacity: animation,
                        child: SlideTransition(
                          position: Tween<Offset>(
                            begin: const Offset(0, 0.25),
                            end: Offset.zero,
                          ).animate(animation),
                          child: child,
                        ),
                      ),
                      layoutBuilder: (current, previous) => Stack(
                        alignment: AlignmentDirectional.topStart,
                        children: [...previous, ?current],
                      ),
                      child: reading || place == null
                          ? _ReadingLines(
                              key: const ValueKey('reading'),
                              label: moving
                                  ? l10n.mapPickerMoveHint
                                  : l10n.mapPickerReading,
                            )
                          : Column(
                              key: ValueKey(place.coordinatesLabel),
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  unnamed
                                      ? l10n.mapPickerUnknownPlace
                                      : place.headline,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: context.dsText.cardTitle.semibold,
                                ),
                                Text(
                                  unnamed
                                      ? l10n.mapPickerUnknownPlaceHint
                                      : place.subtitle,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: context.dsText.bodySmall.tint(
                                    colors.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          DsGaps.vSm,
          Wrap(
            spacing: DsSpacing.xs,
            runSpacing: DsSpacing.xs,
            children: [
              if (place != null)
                _InfoChip(
                  icon: Icons.gps_fixed_rounded,
                  // Coordinates read left to right in any language.
                  label: place.coordinatesLabel,
                  ltr: true,
                ),
              if (accuracy != null)
                _InfoChip(
                  icon: Icons.radar_rounded,
                  label: l10n.mapPickerAccuracy(accuracy),
                  tone: colors.info,
                ),
              if (place?.isRural ?? false)
                _InfoChip(
                  icon: Icons.agriculture_rounded,
                  label: l10n.mapPickerRural,
                  tone: colors.success,
                ),
            ],
          ),
          AnimatedSize(
            duration: DsMotion.moderate,
            curve: DsMotion.gentle,
            child: (place?.isOutsideSyria ?? false) && !reading
                ? Padding(
                    padding: const EdgeInsets.only(top: DsSpacing.sm),
                    child: Container(
                      padding: const EdgeInsets.all(DsSpacing.sm),
                      decoration: BoxDecoration(
                        color: colors.errorContainer,
                        borderRadius: DsRadius.borderLg,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.public_off_rounded,
                            size: DsSizes.iconSm,
                            color: colors.error,
                          ),
                          DsGaps.hXs,
                          Expanded(
                            child: Text(
                              l10n.mapPickerOutsideSyria,
                              style: context.dsText.bodySmall.tint(
                                colors.errorInk,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : const SizedBox(width: double.infinity),
          ),
          DsGaps.vMd,
          PrimaryButton(
            label: confirmLabel ?? l10n.mapPickerConfirm,
            icon: confirmIcon,
            onPressed: onConfirm,
          ),
        ],
      ),
    );
  }
}

class _ReadingLines extends StatelessWidget {
  const _ReadingLines({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          maxLines: 2,
          style: context.dsText.cardTitle.semibold.tint(
            context.dsColors.onSurfaceVariant,
          ),
        ),
        DsGaps.vXs,
        const DsShimmer(child: DsSkeleton.line(width: 180)),
      ],
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({
    required this.icon,
    required this.label,
    this.tone,
    this.ltr = false,
  });

  final IconData icon;
  final String label;
  final Color? tone;
  final bool ltr;

  @override
  Widget build(BuildContext context) {
    final colors = context.dsColors;
    final color = tone ?? colors.onSurfaceVariant;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: DsSpacing.sm,
        vertical: DsSpacing.xxs + 1,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.09),
        borderRadius: DsRadius.borderPill,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: DsSizes.iconXxs + 1, color: color),
          DsGaps.hXxs,
          Text(
            label,
            textDirection: ltr ? TextDirection.ltr : null,
            style: context.dsText.caption.semibold.tabular.tint(color),
          ),
        ],
      ),
    );
  }
}

/// The credit the map's licence asks for, small and out of the way.
class _Attribution extends StatelessWidget {
  const _Attribution({required this.satellite});

  final bool satellite;

  @override
  Widget build(BuildContext context) {
    final colors = context.dsColors;
    return GestureDetector(
      onTap: () => launchUrl(
        Uri.parse('https://www.openstreetmap.org/copyright'),
        mode: LaunchMode.externalApplication,
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: colors.surface.withValues(alpha: 0.7),
          borderRadius: DsRadius.borderXs,
        ),
        child: Text(
          MapTiles.attribution(satellite: satellite),
          textDirection: TextDirection.ltr,
          style: context.dsText.micro.tint(colors.onSurfaceVariant),
        ),
      ),
    );
  }
}

/// Reports its child's size after layout — the card grows with a two-line
/// address, and the map above it has to give that room back.
class _MeasureSize extends SingleChildRenderObjectWidget {
  const _MeasureSize({required this.onChange, required super.child});

  final ValueChanged<Size> onChange;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderMeasureSize(onChange);

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderMeasureSize renderObject,
  ) => renderObject.onChange = onChange;
}

class _RenderMeasureSize extends RenderProxyBox {
  _RenderMeasureSize(this.onChange);

  ValueChanged<Size> onChange;
  Size? _last;

  @override
  void performLayout() {
    super.performLayout();
    final current = size;
    if (current == _last) return;
    _last = current;
    WidgetsBinding.instance.addPostFrameCallback((_) => onChange(current));
  }
}
