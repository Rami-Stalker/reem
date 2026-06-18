import 'package:flutter/widgets.dart';

import 'role_experience.dart';

class RoleFeatureGate extends StatelessWidget {
  const RoleFeatureGate({
    super.key,
    required this.experience,
    required this.feature,
    required this.child,
    this.fallback = const SizedBox.shrink(),
  });

  final AppRoleExperience experience;
  final ExperienceFeature feature;
  final Widget child;
  final Widget fallback;

  @override
  Widget build(BuildContext context) {
    if (!experience.hasFeature(feature)) return fallback;
    return child;
  }
}

class RolePermissionGate extends StatelessWidget {
  const RolePermissionGate({
    super.key,
    required this.experience,
    required this.permission,
    required this.child,
    this.fallback = const SizedBox.shrink(),
  });

  final AppRoleExperience experience;
  final String permission;
  final Widget child;
  final Widget fallback;

  @override
  Widget build(BuildContext context) {
    if (!experience.can(permission)) return fallback;
    return child;
  }
}
