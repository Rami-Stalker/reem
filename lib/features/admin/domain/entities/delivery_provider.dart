import 'package:equatable/equatable.dart';

/// A delivery company the platform can hand parcels to, as an admin sees it.
///
/// Reem manages orders; a carrier manages the journey. This screen therefore
/// has no drivers, no routes and no fleet in it — the questions it answers are
/// operational ones: which companies are on, where each of them delivers, which
/// wins when two cover the same governorate, and whether the platform can
/// actually reach them right now.
///
/// Credentials are never part of this. The server tells the console which
/// environment variables a carrier needs and whether each is set; the values
/// stay on the server, and the app has no way to ask for them.
class DeliveryProviderAccount extends Equatable {
  const DeliveryProviderAccount({
    required this.id,
    required this.code,
    required this.adapter,
    required this.displayName,
    required this.kind,
    required this.isEnabled,
    required this.isDefault,
    required this.priority,
    required this.governorates,
    required this.credentials,
    required this.adapterAvailable,
    required this.webhookUrl,
    this.supportsQuote = false,
    this.supportsCancel = false,
    this.supportsTracking = false,
    this.supportsWebhook = false,
    this.lastError,
    this.lastErrorAt,
    this.lastHealthyAt,
  });

  final String id;

  /// This contract's name — it is what the carrier's callback URL carries.
  final String code;

  /// Which adapter class speaks to it. Two companies can share one adapter.
  final String adapter;

  final String displayName;

  /// `INTERNAL` (the platform's own couriers), `EXTERNAL_API`, or `MANUAL`.
  final String kind;

  final bool isEnabled;
  final bool isDefault;

  /// Lower wins where several carriers cover the same destination.
  final int priority;

  /// Empty means the carrier delivers everywhere.
  final List<String> governorates;

  final bool supportsQuote;
  final bool supportsCancel;
  final bool supportsTracking;
  final bool supportsWebhook;

  final List<DeliveryProviderCredential> credentials;

  /// False when a row names an adapter this build does not ship — a deploy
  /// mismatch, and the reason the row cannot be enabled.
  final bool adapterAvailable;

  final String webhookUrl;

  final String? lastError;
  final DateTime? lastErrorAt;
  final DateTime? lastHealthyAt;

  bool get isInternal => kind == 'INTERNAL';

  /// Whether every credential this carrier names is present on the server.
  bool get hasEveryCredential =>
      credentials.every((credential) => credential.isSet);

  @override
  List<Object?> get props => [id, code, isEnabled, priority, lastError];
}

/// One secret a carrier needs, named but never shown.
class DeliveryProviderCredential extends Equatable {
  const DeliveryProviderCredential({
    required this.field,
    required this.envKey,
    required this.isSet,
  });

  /// What the adapter calls it: `apiKey`, `webhookSecret`, …
  final String field;

  /// The environment variable that holds it on the server.
  final String envKey;

  /// Whether that variable is actually set. The value itself never leaves the
  /// server.
  final bool isSet;

  @override
  List<Object?> get props => [field, envKey, isSet];
}

/// One parcel handed to one carrier, for the operations queue.
class DeliveryDispatchRow extends Equatable {
  const DeliveryDispatchRow({
    required this.id,
    required this.provider,
    required this.orderNumber,
    required this.trackingCode,
    required this.status,
    this.trackingNumber,
    this.lastError,
    this.createdAt,
  });

  final String id;
  final String provider;
  final String orderNumber;
  final String trackingCode;
  final String status;
  final String? trackingNumber;

  /// Why the carrier never took it. A row with this set is a parcel packed and
  /// standing still — the queue this screen exists to empty.
  final String? lastError;

  final DateTime? createdAt;

  bool get needsRetry => lastError != null && trackingNumber == null;

  @override
  List<Object?> get props => [id, status, lastError];
}
