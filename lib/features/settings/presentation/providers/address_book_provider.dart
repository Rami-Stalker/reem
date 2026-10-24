import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import 'package:ohara/core/result/result.dart';
import 'package:ohara/features/checkout/domain/entities/checkout.dart';
import 'package:ohara/features/checkout/presentation/providers/checkout_providers.dart';
import 'package:ohara/features/settings/presentation/providers/address_book_notifier.dart';
import 'package:ohara/features/settings/presentation/providers/settings_provider.dart';

final addressBookProvider =
    StateNotifierProvider<AddressBookNotifier, AddressBookState>(
      (ref) => AddressBookNotifier(ref.watch(settingsRepositoryProvider))..load(),
    );

/// The governorates the platform actually delivers to, for the address form.
///
/// The same list checkout prices against, read from the same public endpoint —
/// a free-text governorate is how an address gets saved that no courier can be
/// assigned to and no delivery fee can be quoted for.
final deliveryGovernoratesProvider = FutureProvider<List<Governorate>>((
  ref,
) async {
  final result = await ref.watch(checkoutRepositoryProvider).getGovernorates();
  return switch (result) {
    Success(:final data) => data,
    Error() => const <Governorate>[],
  };
});
