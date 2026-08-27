import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:reem/core/result/result.dart';
import 'package:reem/features/settings/domain/entities/address_entity.dart';
import 'package:reem/features/settings/presentation/providers/settings_provider.dart';

/// Her saved addresses, for the checkout picker.
///
/// A `FutureProvider` rather than a notifier because nothing on this screen
/// mutates the list — she picks one, or types a new one and asks for it to be
/// saved, and the save happens server-side as part of placing the order. An
/// empty list on failure is deliberate: a book that will not load must fall
/// back to the form, never to a screen she cannot check out from.
final savedAddressesProvider = FutureProvider.autoDispose<List<AddressEntity>>((
  ref,
) async {
  final result = await ref.watch(settingsRepositoryProvider).getAddresses();
  return switch (result) {
    Success(:final data) => data,
    Error() => const <AddressEntity>[],
  };
});

/// The one checkout opens with: her default, or the most recent.
AddressEntity? preselect(List<AddressEntity> addresses) {
  if (addresses.isEmpty) return null;
  for (final address in addresses) {
    if (address.isDefault) return address;
  }
  return addresses.first;
}
