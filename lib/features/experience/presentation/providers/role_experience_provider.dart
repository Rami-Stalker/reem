import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/experience/role_experience.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../../../core/providers/core_providers.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

final roleExperienceProvider = Provider<AppRoleExperience>((ref) {
  final role = ref.watch(
    authNotifierProvider.select((state) => state.user?.role),
  );
  return AppRoleExperience.forUserRole(role);
});

final roleExperienceSnapshotProvider = FutureProvider<Map<String, dynamic>>((
  ref,
) async {
  final dio = ref.watch(dioProvider);
  final response = await dio.get<dynamic>(ApiEndpoints.experienceMe);
  final data = response.data;
  if (data is Map<String, dynamic>) return data;
  if (data is Map) return Map<String, dynamic>.from(data);
  return const <String, dynamic>{};
});
