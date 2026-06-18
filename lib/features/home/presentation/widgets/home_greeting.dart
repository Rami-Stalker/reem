import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design_system/design_system.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

/// Warm, time-aware greeting. (Search lives in [HomeSmartSearch] directly below.)
class HomeGreeting extends ConsumerWidget {
  const HomeGreeting({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.dsColors;
    final theme = Theme.of(context);
    final user = ref.watch(authNotifierProvider.select((s) => s.user));
    final firstName =
        (user?.name.trim().split(RegExp(r'\s+')).first ?? '').isEmpty
            ? 'gorgeous'
            : user!.name.trim().split(RegExp(r'\s+')).first;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
          DsSpacing.lg, DsSpacing.sm, DsSpacing.lg, DsSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${_greeting()},',
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: c.onSurfaceVariant),
          ),
          const SizedBox(height: DsSpacing.xxs),
          DsGradientText(
            'Hello, $firstName ✨',
            style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: DsTypography.bold,
                ) ??
                const TextStyle(),
          ),
        ],
      ),
    );
  }

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }
}
