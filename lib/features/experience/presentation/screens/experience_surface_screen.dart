import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design_system/design_system.dart';
import '../../../../core/experience/role_experience.dart';
import '../providers/role_experience_provider.dart';

class ExperienceSurfaceScreen extends ConsumerWidget {
  const ExperienceSurfaceScreen({super.key, required this.surface, this.title});

  final ExperienceSurface surface;
  final String? title;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final experience = ref.watch(roleExperienceProvider);
    final identity = experience.visualIdentity;
    final sections = experience.sectionsFor(surface).toList(growable: false);
    final menuGroups = experience.visibleMenuGroups.toList(growable: false);
    final surfaceTitle = title ?? _titleFor(experience, surface);

    return ReemScrollPage(
      slivers: [
        PremiumAppBar(title: surfaceTitle),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              DsSpacing.lg,
              DsSpacing.md,
              DsSpacing.lg,
              DsSpacing.lg,
            ),
            child: _SurfaceHero(
              title: surfaceTitle,
              subtitle: experience.tagline,
              identity: identity,
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: DsSpacing.lg),
          sliver: SliverLayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.crossAxisExtent;
              final crossAxisCount = width >= 1000
                  ? 3
                  : width >= 640
                  ? 2
                  : 1;
              return SliverGrid.builder(
                itemCount: sections.length,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  crossAxisSpacing: DsSpacing.md,
                  mainAxisSpacing: DsSpacing.md,
                  mainAxisExtent: 172,
                ),
                itemBuilder: (context, index) {
                  final section = sections[index];
                  return _SurfaceSectionCard(
                    section: section,
                    identity: identity,
                    onTap: section.path == null
                        ? null
                        : () => context.go(section.path!),
                  );
                },
              );
            },
          ),
        ),
        if (menuGroups.isNotEmpty && surface != ExperienceSurface.activity)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                DsSpacing.lg,
                DsSpacing.lg,
                DsSpacing.lg,
                0,
              ),
              child: _RoleMenuGroups(groups: menuGroups, identity: identity),
            ),
          ),
        const SliverToBoxAdapter(child: SizedBox(height: 140)),
      ],
    );
  }

  String _titleFor(AppRoleExperience experience, ExperienceSurface surface) {
    return switch (surface) {
      ExperienceSurface.activity => 'Activity',
      ExperienceSurface.customers => 'Customers',
      ExperienceSurface.marketing => 'Marketing',
      ExperienceSurface.analytics => 'Analytics',
      ExperienceSurface.settings => 'Settings',
      _ => experience.title,
    };
  }
}

class _RoleMenuGroups extends StatelessWidget {
  const _RoleMenuGroups({required this.groups, required this.identity});

  final List<RoleMenuGroup> groups;
  final RoleVisualIdentity identity;

  @override
  Widget build(BuildContext context) {
    final colors = context.dsColors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick actions',
          style: TextStyle(
            fontSize: DsTypography.titleMedium,
            fontWeight: DsTypography.bold,
            color: colors.onSurface,
          ),
        ),
        const SizedBox(height: DsSpacing.sm),
        LayoutBuilder(
          builder: (context, constraints) {
            final groupWidth = constraints.maxWidth >= 760
                ? (constraints.maxWidth - DsSpacing.md) / 2
                : constraints.maxWidth;
            return Wrap(
              spacing: DsSpacing.md,
              runSpacing: DsSpacing.md,
              children: [
                for (final group in groups)
                  SizedBox(
                    width: groupWidth,
                    child: _RoleMenuGroupCard(group: group, identity: identity),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _RoleMenuGroupCard extends StatelessWidget {
  const _RoleMenuGroupCard({required this.group, required this.identity});

  final RoleMenuGroup group;
  final RoleVisualIdentity identity;

  @override
  Widget build(BuildContext context) {
    final colors = context.dsColors;
    return Container(
      padding: const EdgeInsets.all(DsSpacing.md),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: DsRadius.borderXl,
        border: Border.all(color: colors.glassBorder),
        boxShadow: context.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            group.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: DsTypography.titleSmall,
              fontWeight: DsTypography.bold,
              color: colors.onSurface,
            ),
          ),
          const SizedBox(height: DsSpacing.sm),
          Wrap(
            spacing: DsSpacing.xs,
            runSpacing: DsSpacing.xs,
            children: [
              for (final action in group.actions)
                OutlinedButton.icon(
                  onPressed: () => context.go(action.path),
                  icon: Icon(action.icon, size: 17, color: identity.primary),
                  label: Text(action.label, overflow: TextOverflow.ellipsis),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: colors.onSurface,
                    side: BorderSide(
                      color: identity.primary.withValues(alpha: 0.24),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: DsRadius.borderFull,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SurfaceHero extends StatelessWidget {
  const _SurfaceHero({
    required this.title,
    required this.subtitle,
    required this.identity,
  });

  final String title;
  final String subtitle;
  final RoleVisualIdentity identity;

  @override
  Widget build(BuildContext context) {
    final colors = context.dsColors;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(DsSpacing.lg),
      decoration: BoxDecoration(
        gradient: identity.gradient,
        borderRadius: DsRadius.borderXxl,
        boxShadow: context.softShadow,
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: DsRadius.borderLg,
            ),
            child: Icon(identity.icon, color: Colors.white, size: 28),
          ),
          const SizedBox(width: DsSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: DsTypography.titleLarge,
                    fontWeight: DsTypography.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: DsSpacing.xxs),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: DsTypography.labelMedium,
                    color: colors.onPrimary.withValues(alpha: 0.86),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SurfaceSectionCard extends StatelessWidget {
  const _SurfaceSectionCard({
    required this.section,
    required this.identity,
    this.onTap,
  });

  final RoleSurfaceSection section;
  final RoleVisualIdentity identity;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.dsColors;
    final card = Container(
      padding: const EdgeInsets.all(DsSpacing.md),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: DsRadius.borderXl,
        border: Border.all(color: colors.glassBorder),
        boxShadow: context.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: identity.primary.withValues(alpha: 0.12),
                  borderRadius: DsRadius.borderMd,
                ),
                child: Icon(section.icon, color: identity.primary),
              ),
              const Spacer(),
              if (onTap != null)
                Icon(
                  Icons.arrow_forward_rounded,
                  size: 18,
                  color: colors.onSurfaceVariant,
                ),
            ],
          ),
          const SizedBox(height: DsSpacing.md),
          Text(
            section.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: DsTypography.titleSmall,
              fontWeight: DsTypography.bold,
              color: colors.onSurface,
            ),
          ),
          const SizedBox(height: DsSpacing.xs),
          Expanded(
            child: Text(
              section.description,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: DsTypography.labelMedium,
                height: 1.3,
                color: colors.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );

    if (onTap == null) return card;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: DsRadius.borderXl,
        onTap: onTap,
        child: card,
      ),
    );
  }
}
