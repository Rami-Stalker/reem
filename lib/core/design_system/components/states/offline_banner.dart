import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:reem/core/design_system/foundation/theme/extensions/color_extension.dart';
import 'package:reem/core/design_system/foundation/theme/extensions/typography_extension.dart';
import 'package:reem/core/design_system/foundation/tokens/ds_gaps.dart';
import 'package:reem/core/design_system/foundation/tokens/ds_motion.dart';
import 'package:reem/core/design_system/foundation/tokens/ds_sizes.dart';
import 'package:reem/core/design_system/foundation/tokens/ds_spacing.dart';
import 'package:reem/core/localization/l10n_extension.dart';
import 'package:reem/core/network/connection_status.dart';

/// A slim strip that appears when the handset loses its connection.
///
/// It exists because the response cache serves the last known answer when a
/// request fails. That is the right behaviour — a catalogue from ten minutes
/// ago beats an error card — but only if she is told. Without this the app
/// silently shows old prices and looks like it is working normally, which is
/// the one failure mode a commerce app cannot afford.
///
/// It says nothing at all while the connection is up, so it costs a screen
/// nothing in the normal case.
class OfflineBanner extends ConsumerWidget {
  const OfflineBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Anything other than a delivered `false` counts as online: while the
    // first read is in flight, and if the platform channel errors, the app is
    // treated as connected so the banner never flashes on a cold start.
    final online = switch (ref.watch(connectionStatusProvider)) {
      AsyncData(:final value) => value,
      _ => true,
    };
    final colors = context.dsColors;

    return AnimatedSize(
      duration: DsMotion.normal,
      curve: DsMotion.gentle,
      alignment: Alignment.topCenter,
      child: online
          ? const SizedBox(width: double.infinity)
          : Material(
              color: colors.warningContainer,
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: DsSpacing.listRowPadding,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.cloud_off_rounded,
                        size: DsSizes.iconXs,
                        color: colors.warning,
                      ),
                      DsGaps.hXs,
                      Flexible(
                        child: Text(
                          context.l10n.offlineShowingSaved,
                          textAlign: TextAlign.center,
                          style: context.dsText.caption.semibold
                              .tint(colors.onSurface),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}
