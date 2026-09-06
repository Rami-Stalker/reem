import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:reem/core/experience/role_experience.dart';
import 'package:reem/core/network/api_endpoints.dart';
import 'package:reem/core/presentation/providers/core_providers.dart';
import 'package:reem/features/auth/presentation/providers/auth_provider.dart';

final roleExperienceProvider = Provider<AppRoleExperience>((ref) {
  final role = ref.watch(
    authNotifierProvider.select((state) => state.user?.role),
  );
  return AppRoleExperience.forUserRole(role);
});

/// The permission set the server resolved for whoever is signed in.
///
/// Read by every surface that decides what to *offer* — the admin navigation,
/// the row actions in the console. It is empty for a guest and for anyone the
/// server did not send permissions for, which renders the plainest console
/// rather than an unguarded one.
final currentPermissionsProvider = Provider<Set<String>>((ref) {
  return ref.watch(
        authNotifierProvider.select((state) => state.user?.permissions),
      ) ??
      const <String>{};
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
