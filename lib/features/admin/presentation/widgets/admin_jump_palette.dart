import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:reem/core/design_system/design_system.dart';
import 'package:reem/core/experience/experience_labels.dart';
import 'package:reem/core/experience/role_experience.dart';
import 'package:reem/core/localization/l10n_extension.dart';
import 'package:reem/l10n/app_localizations.dart';

/// One place the jump palette can take her.
@immutable
class AdminJumpDestination {
  const AdminJumpDestination({
    required this.label,
    required this.icon,
    required this.path,
    this.alias = '',
  });

  final String label;
  final IconData icon;
  final String path;

  /// A second name to match on — the destination's English identifier, so
  /// «finance» finds المالية on a keyboard that is not switched to Arabic.
  final String alias;
}

/// The console's destinations this operator may open, in rail order.
///
/// The same rule as the shell's rail: an empty permission set is "we were not
/// told", not "she may do nothing", and the server answers 403 for anything
/// she genuinely may not do.
List<AdminJumpDestination> adminJumpDestinations(
  Set<String> permissions,
  AppLocalizations l10n,
) {
  final unknown = permissions.isEmpty;
  return [
    for (final item in AppRoleExperience.admin.navigation)
      if (item.permission == null ||
          unknown ||
          permissions.contains(item.permission))
        AdminJumpDestination(
          label: item.labelOf(l10n),
          icon: item.icon,
          path: item.path,
          alias: item.label,
        ),
  ];
}

/// Opens the palette: type a few letters of any section, press Enter, arrive.
///
/// Sixteen destinations in a rail are sixteen things to read; a field is one.
/// It goes through `go` like the rail does, so arriving here and arriving by
/// the rail leave the same history behind.
Future<void> showAdminJumpPalette(
  BuildContext context,
  List<AdminJumpDestination> destinations,
) {
  final router = GoRouter.of(context);
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: DsColors.mediaScrim,
    transitionDuration: DsReducedMotion.duration(DsMotion.normal),
    transitionBuilder: (context, animation, _, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: DsMotion.emphasized,
      );
      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween(
            begin: const Offset(0, -0.04),
            end: Offset.zero,
          ).animate(curved),
          child: child,
        ),
      );
    },
    pageBuilder: (dialogContext, _, _) => _JumpPalette(
      destinations: destinations,
      onChoose: (destination) {
        Navigator.of(dialogContext).pop();
        router.go(destination.path);
      },
    ),
  );
}

class _JumpPalette extends StatefulWidget {
  const _JumpPalette({required this.destinations, required this.onChoose});

  final List<AdminJumpDestination> destinations;
  final ValueChanged<AdminJumpDestination> onChoose;

  @override
  State<_JumpPalette> createState() => _JumpPaletteState();
}

class _JumpPaletteState extends State<_JumpPalette> {
  String _query = '';

  List<AdminJumpDestination> get _matches {
    final query = _fold(_query);
    if (query.isEmpty) return widget.destinations;
    return widget.destinations
        .where(
          (d) =>
              _fold(d.label).contains(query) || _fold(d.alias).contains(query),
        )
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.console;
    final l10n = context.l10n;
    final matches = _matches;
    final rtl = Directionality.of(context) == TextDirection.rtl;

    return SafeArea(
      child: Align(
        alignment: Alignment.topCenter,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            DsSpacing.md,
            DsSpacing.massive,
            DsSpacing.md,
            DsSpacing.md,
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: DsSizes.maxContentWidth),
            child: Material(
              color: palette.surface,
              borderRadius: DsRadius.borderXxl,
              clipBehavior: Clip.antiAlias,
              elevation: 0,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: DsRadius.borderXxl,
                  border: Border.all(color: palette.line),
                  boxShadow: palette.shadow,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: DsSpacing.paddingMd,
                      child: TextField(
                        autofocus: true,
                        textInputAction: TextInputAction.go,
                        style: context.dsText.bodyLarge.tint(palette.ink),
                        decoration: InputDecoration(
                          hintText: l10n.adminCourtJumpHint,
                          prefixIcon: Icon(
                            Icons.travel_explore_rounded,
                            color: palette.primary,
                          ),
                        ),
                        onChanged: (value) => setState(() => _query = value),
                        onSubmitted: (_) {
                          if (matches.isNotEmpty) {
                            widget.onChoose(matches.first);
                          }
                        },
                      ),
                    ),
                    Divider(height: DsSizes.dividerThickness, color: palette.line),
                    Flexible(
                      child: matches.isEmpty
                          ? Padding(
                              padding: DsSpacing.paddingXl,
                              child: Text(
                                l10n.adminCourtJumpEmpty,
                                textAlign: TextAlign.center,
                                style: context.dsText.body.tint(palette.muted),
                              ),
                            )
                          : ListView.builder(
                              shrinkWrap: true,
                              padding: const EdgeInsets.symmetric(
                                vertical: DsSpacing.xs,
                              ),
                              itemCount: matches.length,
                              itemBuilder: (context, index) {
                                final destination = matches[index];
                                // The first match is what Enter opens, so it
                                // is the one drawn as chosen.
                                final chosen = index == 0 && _query.isNotEmpty;
                                return ListTile(
                                  dense: true,
                                  selected: chosen,
                                  selectedTileColor: palette.primarySoft,
                                  leading: Icon(
                                    destination.icon,
                                    color: palette.primary,
                                  ),
                                  title: Text(
                                    destination.label,
                                    style: context.dsText.bodyStrong.tint(
                                      palette.ink,
                                    ),
                                  ),
                                  trailing: Icon(
                                    rtl
                                        ? Icons.north_west_rounded
                                        : Icons.north_east_rounded,
                                    size: DsSizes.iconXs,
                                    color: palette.muted,
                                  ),
                                  onTap: () => widget.onChoose(destination),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Folds a name for matching: case, Arabic diacritics and the letters people
/// type interchangeably (أ إ آ ا, ة ه, ى ي) all compare equal, so «الاشراف»
/// finds «الإشراف».
String _fold(String value) {
  final lower = value.toLowerCase().trim();
  final buffer = StringBuffer();
  for (final rune in lower.runes) {
    // Tashkeel and the tatweel carry no meaning for a search.
    if ((rune >= 0x064B && rune <= 0x065F) || rune == 0x0640) continue;
    buffer.writeCharCode(switch (rune) {
      0x0623 || 0x0625 || 0x0622 => 0x0627,
      0x0629 => 0x0647,
      0x0649 => 0x064A,
      _ => rune,
    });
  }
  return buffer.toString();
}
