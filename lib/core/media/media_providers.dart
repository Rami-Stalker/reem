import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reem/core/media/media_upload_service.dart';
import 'package:reem/core/presentation/providers/core_providers.dart';

final mediaUploadServiceProvider = Provider<MediaUploadService>(
  (ref) => MediaUploadService(ref.watch(dioProvider)),
);
