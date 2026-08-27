import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:reem/core/design_system/design_system.dart';
import 'package:reem/core/experience/role_experience.dart';
import 'package:reem/core/localization/l10n_extension.dart';
import 'package:reem/features/experience/presentation/providers/role_experience_provider.dart';

class ExperienceSurfaceScreen extends ConsumerWidget {
  const ExperienceSurfaceScreen({super.key, required this.surface, this.title});

  final ExperienceSurface surface;
  final String? title;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final experience = ref.watch(roleExperienceProvider);
    final role = experience.role;
    final identity = experience.visualIdentity;
    final sections = experience.sectionsFor(surface).toList(growable: false);
    final menuGroups = experience.visibleMenuGroups.toList(growable: false);
    final surfaceTitle = title ?? _titleFor(context, experience, surface);

    return ReemScrollPage(
      background: switch (role) {
        ExperienceRole.seller => const SellerAtelierBackground(),
        ExperienceRole.admin => const AdminChromeBackground(),
        ExperienceRole.buyer => const CustomerBackdrop(),
      },
      backgroundColor: switch (role) {
        ExperienceRole.seller => context.atelier.background,
        ExperienceRole.admin => AdminExperience.background,
        ExperienceRole.buyer => CustomerExperience.pearl,
      },
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
              role: role,
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
                    role: role,
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
              child: _RoleMenuGroups(
                groups: menuGroups,
                identity: identity,
                role: role,
              ),
            ),
          ),
        const SliverToBoxAdapter(child: SizedBox(height: 140)),
      ],
    );
  }

  String _titleFor(
    BuildContext context,
    AppRoleExperience experience,
    ExperienceSurface surface,
  ) {
    final l10n = context.l10n;
    return switch (surface) {
      ExperienceSurface.activity => l10n.surfaceActivity,
      ExperienceSurface.customers => l10n.surfaceCustomers,
      ExperienceSurface.marketing => l10n.surfaceMarketing,
      ExperienceSurface.analytics => l10n.sellerAnalytics,
      ExperienceSurface.settings => l10n.settings,
      _ => experience.title,
    };
  }
}

class _RoleMenuGroups extends StatelessWidget {
  const _RoleMenuGroups({
    required this.groups,
    required this.identity,
    required this.role,
  });

  final List<RoleMenuGroup> groups;
  final RoleVisualIdentity identity;
  final ExperienceRole role;

  @override
  Widget build(BuildContext context) {
    final colors = context.dsColors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.l10n.sellerQuickActions,
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
                    child: _RoleMenuGroupCard(
                      group: group,
                      identity: identity,
                      role: role,
                    ),
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
  const _RoleMenuGroupCard({
    required this.group,
    required this.identity,
    required this.role,
  });

  final RoleMenuGroup group;
  final RoleVisualIdentity identity;
  final ExperienceRole role;

  @override
  Widget build(BuildContext context) {
    final colors = context.dsColors;
    final seller = role == ExperienceRole.seller;
    final admin = role == ExperienceRole.admin;
    return Container(
      padding: const EdgeInsets.all(DsSpacing.md),
      decoration: BoxDecoration(
        color: seller
            ? context.atelier.surface
            : admin
                ? AdminExperience.surface
                : colors.surface,
        borderRadius: seller
            ? DsRadius.borderMd
            : admin
                ? DsRadius.borderSm
                : DsRadius.borderXl,
        border: Border.all(
          color: seller
              ? context.atelier.line
              : admin
                  ? AdminExperience.line
                  : colors.glassBorder,
        ),
        boxShadow: seller
            ? context.atelier.shadow
            : admin
                ? AdminExperience.shadow
                : context.softShadow,
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
    required this.role,
  });

  final String title;
  final String subtitle;
  final RoleVisualIdentity identity;
  final ExperienceRole role;

  @override
  Widget build(BuildContext context) {
    final colors = context.dsColors;
    final seller = role == ExperienceRole.seller;
    final admin = role == ExperienceRole.admin;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(DsSpacing.lg),
      decoration: BoxDecoration(
        gradient: seller
            ? context.atelier.headerGradient
            : admin
                ? const LinearGradient(
                    colors: [AdminExperience.nav, AdminExperience.primary],
                  )
                : identity.gradient,
        borderRadius: seller
            ? DsRadius.borderMd
            : admin
                ? DsRadius.borderSm
                : DsRadius.borderXxl,
        boxShadow: seller
            ? context.atelier.shadow
            : admin
                ? AdminExperience.shadow
                : context.softShadow,
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
    required this.role,
    this.onTap,
  });

  final RoleSurfaceSection section;
  final RoleVisualIdentity identity;
  final ExperienceRole role;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.dsColors;
    final seller = role == ExperienceRole.seller;
    final admin = role == ExperienceRole.admin;
    final card = Container(
      padding: const EdgeInsets.all(DsSpacing.md),
      decoration: BoxDecoration(
        color: seller
            ? context.atelier.surface
            : admin
                ? AdminExperience.surface
                : colors.surface,
        borderRadius: seller
            ? DsRadius.borderMd
            : admin
                ? DsRadius.borderSm
                : DsRadius.borderXl,
        border: Border.all(
          color: seller
              ? context.atelier.line
              : admin
                  ? AdminExperience.line
                  : colors.glassBorder,
        ),
        boxShadow: seller
            ? context.atelier.shadow
            : admin
                ? AdminExperience.shadow
                : context.softShadow,
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
                  color: (seller
                          ? context.atelier.primary
                          : admin
                              ? AdminExperience.primary
                              : identity.primary)
                      .withValues(alpha: 0.12),
                  borderRadius:
                      seller || admin ? DsRadius.borderSm : DsRadius.borderMd,
                ),
                child: Icon(
                  section.icon,
                  color: seller
                      ? context.atelier.primary
                      : admin
                          ? AdminExperience.primary
                          : identity.primary,
                ),
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
