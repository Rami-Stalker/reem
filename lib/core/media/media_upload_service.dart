import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:reem/core/errors/app_exception.dart';
import 'package:reem/core/errors/error_mapper.dart';
import 'package:reem/core/media/media_asset.dart';
import 'package:reem/core/network/api_endpoints.dart';

/// Picks a file and hands it to the API.
///
/// Two responsibilities kept together because they are one action from the
/// woman's side — she taps "add a photo" and expects a photo to appear. The
/// picker and the upload are separated in the API below only so a retry can
/// re-send bytes she already chose rather than making her find them again.
class MediaUploadService {
  MediaUploadService(this._dio, {ImagePicker? picker})
    : _picker = picker ?? ImagePicker();

  final Dio _dio;
  final ImagePicker _picker;

  /// Ask for one image from the camera or the gallery.
  ///
  /// Resized and re-encoded on the device before it ever reaches the network.
  /// A modern phone camera produces 4000×3000 at 6 MB; nothing in this app
  /// renders larger than a full-width card, and on a Syrian mobile connection
  /// the difference between 6 MB and 400 KB is the difference between an
  /// upload that finishes and one she cancels.
  Future<XFile?> pickImage({required ImageSource source}) {
    return _picker.pickImage(
      source: source,
      maxWidth: 2048,
      maxHeight: 2048,
      imageQuality: 85,
      requestFullMetadata: false,
    );
  }

  /// Several at once, for a product gallery.
  Future<List<XFile>> pickImages() {
    return _picker.pickMultiImage(
      maxWidth: 2048,
      maxHeight: 2048,
      imageQuality: 85,
      requestFullMetadata: false,
    );
  }

  Future<XFile?> pickVideo({required ImageSource source}) {
    return _picker.pickVideo(
      source: source,
      maxDuration: const Duration(minutes: 2),
    );
  }

  /// A file from storage rather than the camera roll — a commercial register
  /// her accountant sent as a PDF, a certificate saved from an email.
  ///
  /// Deliberately narrow: the same four types the server's sniffer accepts for
  /// a document purpose. `allowedExtensions` is a courtesy that keeps the OS
  /// browser tidy and nothing more — the file is still sniffed server-side,
  /// because an extension is a claim, not evidence.
  Future<XFile?> pickDocument() async {
    final file = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: const ['pdf', 'jpg', 'jpeg', 'png', 'webp'],
    );
    // `xFile` rather than the raw bytes: on Android the picker returns a
    // content URI that is not a readable path, and this wrapper knows how to
    // read one. It also keeps the rest of the pipeline on a single type.
    return file?.xFile;
  }

  /// Send one picked file. [onProgress] reports 0.0–1.0.
  ///
  /// Bytes are sent rather than streamed from the path: the picker's temporary
  /// file can be cleared by the OS mid-flight, and a retry that finds the file
  /// gone is worse than the memory a single photograph costs. [bytes] lets a
  /// caller that already read them for a preview hand them over instead of
  /// decoding the same file twice.
  Future<MediaAsset> upload(
    XFile file, {
    required MediaPurpose purpose,
    Uint8List? bytes,
    void Function(double progress)? onProgress,
    CancelToken? cancelToken,
  }) async {
    try {
      final payload = bytes ?? await file.readAsBytes();
      final form = FormData.fromMap({
        'purpose': purpose.wire,
        'file': MultipartFile.fromBytes(payload, filename: _filename(file)),
      });

      final response = await _dio.post<dynamic>(
        ApiEndpoints.mediaUploads,
        data: form,
        cancelToken: cancelToken,
        options: Options(
          // A photograph over a Syrian mobile connection is not a 30-second
          // request. The default client timeout would abandon uploads that
          // were going to succeed.
          sendTimeout: const Duration(minutes: 3),
          receiveTimeout: const Duration(minutes: 3),
        ),
        onSendProgress: (sent, total) {
          if (total > 0) onProgress?.call(sent / total);
        },
      );

      final data = response.data;
      if (data is! Map) {
        throw const ServerException('Upload returned an unexpected response.');
      }
      return MediaAsset.fromJson(Map<String, dynamic>.from(data));
    } on DioException catch (error) {
      throw ErrorMapper.fromDio(error);
    }
  }

  /// The picker hands back a cache path, not a name she chose. The server
  /// stores this only to help a reviewer recognise a document — it never
  /// builds a path from it — but sending something meaningless is still worse
  /// than sending nothing.
  String _filename(XFile file) {
    final name = file.name.trim();
    return name.isEmpty ? 'upload' : name;
  }
}
