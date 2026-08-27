import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'package:reem/core/errors/app_exception.dart';
import 'package:reem/core/errors/error_mapper.dart';
import 'package:reem/core/presentation/providers/core_providers.dart';

/// Fetches an attachment and hands it to whatever app opens that kind of file.
///
/// The indirection is not optional. Chat media lives behind an authorised
/// endpoint, and handing that URL to the OS browser gets a 401 — the browser
/// has no session and no way to be given one. So the app downloads the bytes
/// with its own client, writes them somewhere the system can read, and opens
/// *that*.
///
/// Downloads through Dio rather than a bare HTTP client so the auth and
/// device-proof interceptors apply exactly as they do everywhere else.
class MediaFileOpener {
  MediaFileOpener(this._dio);

  final Dio _dio;

  /// Fetch [url] if it is not already on disk, then open it.
  ///
  /// [fileName] is what she called it; it becomes the name on disk so the
  /// app that opens it shows something recognisable rather than a uuid.
  Future<void> open({
    required String url,
    required String cacheKey,
    String? fileName,
    void Function(double progress)? onProgress,
  }) async {
    final file = await _cachedFile(cacheKey, fileName);

    // Downloaded once. Tapping an invoice twice should not cost her the
    // bytes twice, which on a metered connection is a real charge.
    if (!await file.exists() || await file.length() == 0) {
      await _download(url, file, onProgress);
    }

    final result = await OpenFilex.open(file.path);
    if (result.type != ResultType.done) {
      // No installed app claims this type, or the OS refused. Saying so beats
      // a tap that appears to do nothing at all.
      throw ServerException(result.message, code: result.type.name);
    }
  }

  Future<void> _download(
    String url,
    File file,
    void Function(double progress)? onProgress,
  ) async {
    try {
      await file.parent.create(recursive: true);
      await _dio.download(
        url,
        file.path,
        onReceiveProgress: (received, total) {
          if (total > 0) onProgress?.call(received / total);
        },
      );
    } on DioException catch (error) {
      // A half-written file would be treated as cached on the next tap and
      // opened as a corrupt document.
      if (await file.exists()) await file.delete();
      throw ErrorMapper.fromDio(error);
    }
  }

  /// A stable path per attachment, under the cache directory the OS is free
  /// to reclaim — these are copies, and the server still has the original.
  Future<File> _cachedFile(String cacheKey, String? fileName) async {
    final directory = await getTemporaryDirectory();
    final safeName = _sanitise(fileName) ?? 'attachment';
    return File(p.join(directory.path, 'reem-attachments', cacheKey, safeName));
  }

  /// Her filename decides what the opening app displays, and nothing else. It
  /// is still stripped of anything that could climb out of the folder it is
  /// written into — the name arrived over the network.
  String? _sanitise(String? name) {
    final trimmed = name?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    final base = p.basename(trimmed).replaceAll(RegExp(r'[^\w\-. ]'), '_');
    return base.isEmpty || base == '.' || base == '..' ? null : base;
  }
}

final mediaFileOpenerProvider = Provider<MediaFileOpener>(
  (ref) => MediaFileOpener(ref.watch(dioProvider)),
);
