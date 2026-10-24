import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ohara/core/media/media_upload_service.dart';
import 'package:ohara/core/presentation/providers/core_providers.dart';

final mediaUploadServiceProvider = Provider<MediaUploadService>(
  (ref) => MediaUploadService(ref.watch(dioProvider)),
);
