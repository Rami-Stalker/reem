import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/core_providers.dart';
import 'media_upload_service.dart';

final mediaUploadServiceProvider = Provider<MediaUploadService>(
  (ref) => MediaUploadService(ref.watch(dioProvider)),
);
