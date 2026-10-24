import 'package:dio/dio.dart';
import 'package:ohara/core/network/api_endpoints.dart';
import 'package:ohara/core/security/device_proof_signer.dart';

/// Attaches a device proof to the requests that are worth proving.
///
/// Not every request: signing costs an Ed25519 operation and a round of JSON,
/// and on a mid-range Android handset doing that on every product-list scroll
/// would be paid by the user for nothing.
///
/// The rule is the server's, not a judgement call: **every route it guards
/// with `@RequireStepUp` needs a fresh proof**, because AAL2 *is* a fresh
/// proof and AAL3 is that plus a second factor. A step-up route missing from
/// this list is not slower or less safe — it is unreachable, refused with
/// `DEVICE_PROOF_REQUIRED` no matter what the woman types, and
/// `runWithStepUp` cannot recover from that one by design. Submitting a seller
/// application was in exactly that state until this list was corrected.
class DeviceProofInterceptor extends Interceptor {
  DeviceProofInterceptor(this._signer);

  final DeviceProofSigner _signer;

  /// Paths that carry a proof. Kept as prefixes because `/auth/devices/:id`
  /// has an id in it.
  static const _provenPaths = <String>[
    // Issuing or rotating a session — the proof binds the session to this
    // handset. `authOtpLoginVerify` is the door everybody actually comes
    // through; `authOtpVerify` is the older sibling and is not the same path.
    ApiEndpoints.authLogin,
    ApiEndpoints.authRegister,
    ApiEndpoints.authRefresh,
    ApiEndpoints.authOtpVerify,
    ApiEndpoints.authOtpLoginVerify,

    // Everything the server guards with step-up.
    ApiEndpoints.authLogoutAll,
    ApiEndpoints.authDevices,
    ApiEndpoints.authAccount,
    ApiEndpoints.authRecoveryCodes,
    ApiEndpoints.authSellerVerification,
    ApiEndpoints.addresses,
  ];

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    if (!_needsProof(options.path)) return handler.next(options);

    try {
      final url = options.uri;
      final authorization = options.headers['Authorization'];
      final accessToken = authorization is String &&
              authorization.startsWith('Bearer ')
          ? authorization.substring('Bearer '.length)
          : null;

      final proof = await _signer.sign(
        method: options.method,
        url: url,
        accessToken: accessToken,
      );
      if (proof != null) {
        options.headers['X-Reem-Device-Proof'] = proof;
      }
    } catch (_) {
      // A signing failure — a Keystore regression, a corrupted key — must
      // degrade to "no proof" and let the server decide, never to a hard
      // failure. The alternative is an app that cannot sign in at all on one
      // unlucky device model.
    }

    handler.next(options);
  }

  bool _needsProof(String path) =>
      _provenPaths.any((proven) => path.startsWith(proven));
}
