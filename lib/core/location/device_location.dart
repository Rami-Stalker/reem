import 'dart:async';

import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

/// Why the phone could not say where it is — each one is a different thing
/// to tell her, and a different place to send her.
enum DeviceLocationFailure {
  /// Location is switched off for the whole phone.
  serviceDisabled,

  /// She said no this time; asking again is allowed.
  denied,

  /// She said no for good; only the system settings can undo it.
  deniedForever,

  /// The phone tried and found nothing in time — indoors, usually.
  unavailable,
}

/// A fix, or the reason there is none.
sealed class DeviceLocationResult {
  const DeviceLocationResult();
}

final class DeviceLocationFix extends DeviceLocationResult {
  const DeviceLocationFix(this.point, this.accuracyMeters);

  final LatLng point;

  /// The radius the phone is confident about, drawn as a halo on the map.
  final double accuracyMeters;
}

final class DeviceLocationError extends DeviceLocationResult {
  const DeviceLocationError(this.failure);

  final DeviceLocationFailure failure;
}

/// The picker's one entry point into `geolocator`.
///
/// Permission is asked for here, when she taps «موقعي الحالي», and never
/// earlier: a location prompt on a checkout screen she has not touched reads
/// as tracking.
abstract final class DeviceLocation {
  /// The last fix the phone already has, without waking the GPS — enough to
  /// open the map somewhere near her while the real fix arrives.
  static Future<LatLng?> lastKnown() async {
    try {
      final permission = await Geolocator.checkPermission();
      if (permission != LocationPermission.always &&
          permission != LocationPermission.whileInUse) {
        return null;
      }
      final position = await Geolocator.getLastKnownPosition();
      return position == null
          ? null
          : LatLng(position.latitude, position.longitude);
    } on Object {
      return null;
    }
  }

  static Future<DeviceLocationResult> current() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        return const DeviceLocationError(DeviceLocationFailure.serviceDisabled);
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever) {
        return const DeviceLocationError(DeviceLocationFailure.deniedForever);
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.unableToDetermine) {
        return const DeviceLocationError(DeviceLocationFailure.denied);
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );
      return DeviceLocationFix(
        LatLng(position.latitude, position.longitude),
        position.accuracy,
      );
    } on TimeoutException {
      return _fallbackToLastKnown();
    } on LocationServiceDisabledException {
      return const DeviceLocationError(DeviceLocationFailure.serviceDisabled);
    } on PermissionDeniedException {
      return const DeviceLocationError(DeviceLocationFailure.denied);
    } on Object {
      return _fallbackToLastKnown();
    }
  }

  static Future<DeviceLocationResult> _fallbackToLastKnown() async {
    try {
      final last = await Geolocator.getLastKnownPosition();
      if (last != null) {
        return DeviceLocationFix(
          LatLng(last.latitude, last.longitude),
          last.accuracy,
        );
      }
    } on Object {
      // Nothing better to offer.
    }
    return const DeviceLocationError(DeviceLocationFailure.unavailable);
  }

  static Future<void> openSettingsFor(DeviceLocationFailure failure) async {
    try {
      if (failure == DeviceLocationFailure.serviceDisabled) {
        await Geolocator.openLocationSettings();
      } else {
        await Geolocator.openAppSettings();
      }
    } on Object {
      // A platform without a settings page; the message already explained.
    }
  }
}
