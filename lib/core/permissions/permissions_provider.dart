import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:reem/core/shared/entities/user.dart';
import 'package:reem/features/auth/presentation/providers/auth_provider.dart';
import 'permissions.dart';

/// Reactive capabilities for the signed-in user. Rebuilds when the role changes.
final permissionsProvider = Provider<Permissions>((ref) {
  final role = ref.watch(
    authNotifierProvider.select((s) => s.user?.role ?? UserRole.customer),
  );
  return Permissions(role);
});
