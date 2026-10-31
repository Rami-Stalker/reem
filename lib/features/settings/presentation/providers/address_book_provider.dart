import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import 'package:ohara/core/result/result.dart';
import 'package:ohara/features/auth/presentation/providers/auth_provider.dart';
import 'package:ohara/features/checkout/domain/entities/checkout.dart';
import 'package:ohara/features/checkout/presentation/providers/checkout_providers.dart';
import 'package:ohara/features/settings/presentation/providers/address_book_notifier.dart';
import 'package:ohara/features/settings/presentation/providers/settings_provider.dart';

/// Rebuilt whenever the signed-in account changes.
///
/// It used to be built once for the life of the app. Opened before signing in
/// (or under another account), it kept that first answer — an error, an empty
/// book, or the previous woman's addresses — until the app was restarted. A
/// guest has no book, so nothing is asked of the server for one.
final addressBookProvider =
    StateNotifierProvider<AddressBookNotifier, AddressBookState>((ref) {
      final userId = ref.watch(authNotifierProvider.select((s) => s.user?.id));
      final notifier = AddressBookNotifier(ref.watch(settingsRepositoryProvider));
      if (userId != null) notifier.load();
      return notifier;
    });

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
