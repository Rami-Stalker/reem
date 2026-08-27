/// Client-side size ceilings, mirroring the server's defaults.
///
/// A courtesy, not a policy: the server is the only authority, and it refuses
/// an oversized file whatever this file says. The point is *when* the refusal
/// arrives. Without a local check a woman on a Syrian mobile connection spends
/// four minutes pushing a 40 MB scan up a narrow uplink to be told at the end
/// that it was too large — and on a metered plan she has paid for it too.
///
/// Kept deliberately in step with `backend/src/config/configuration.ts`
/// (`MEDIA_MAX_*_BYTES`). If a deployment raises the server's ceiling, this one
/// is merely conservative; if it lowers it, the server still refuses correctly.
abstract final class MediaLimits {
  static const int imageBytes = 12 * 1024 * 1024;
  static const int videoBytes = 64 * 1024 * 1024;
  static const int documentBytes = 16 * 1024 * 1024;

  /// The ceiling that applies to a file, chosen by extension because that is
  /// all the client knows before the server sniffs it. Erring high is right:
  /// a wrong guess here must never reject something the server would accept.
  static int forFile(String name, {required bool video}) {
    if (video) return videoBytes;
    return name.toLowerCase().endsWith('.pdf') ? documentBytes : imageBytes;
  }

  static int forKind(String kind) => switch (kind) {
    'video' => videoBytes,
    'document' => documentBytes,
    _ => imageBytes,
  };

  /// Rounded for a human. `13.4 MB` reads; `14050816 bytes` does not.
  static String megabytes(int bytes) =>
      (bytes / (1024 * 1024)).toStringAsFixed(1);
}
