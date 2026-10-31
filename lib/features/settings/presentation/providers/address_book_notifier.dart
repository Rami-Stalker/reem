import 'package:flutter_riverpod/legacy.dart';

import 'package:ohara/core/errors/failure.dart';
import 'package:ohara/core/result/result.dart';
import 'package:ohara/features/settings/domain/entities/address_draft.dart';
import 'package:ohara/features/settings/domain/entities/address_entity.dart';
import 'package:ohara/features/settings/domain/repositories/settings_repository.dart';

/// Her address book.
///
/// Held as one list rather than a `FutureProvider` per operation because every
/// write reorders the whole book: the server sorts the default first, and
/// making one address the default un-defaults another. Re-reading the list
/// after each write is therefore not laziness — a locally patched list would
/// disagree with the server about which address is the default, which is the
/// one field checkout actually reads.
class AddressBookState {
  const AddressBookState({
    this.addresses = const [],
    this.isLoading = false,
    this.isSaving = false,
    this.failure,
  });

  final List<AddressEntity> addresses;
  final bool isLoading;

  /// A write in flight. Separate from [isLoading] so saving does not blank the
  /// list she is looking at.
  final bool isSaving;

  final Failure? failure;

  bool get isEmpty => !isLoading && addresses.isEmpty;

  AddressBookState copyWith({
    List<AddressEntity>? addresses,
    bool? isLoading,
    bool? isSaving,
    Failure? failure,
    bool clearFailure = false,
  }) {
    return AddressBookState(
      addresses: addresses ?? this.addresses,
      isLoading: isLoading ?? this.isLoading,
      isSaving: isSaving ?? this.isSaving,
      failure: clearFailure ? null : (failure ?? this.failure),
    );
  }
}

class AddressBookNotifier extends StateNotifier<AddressBookState> {
  AddressBookNotifier(this._repository) : super(const AddressBookState());

  final SettingsRepository _repository;

  Future<void> load() async {
    state = state.copyWith(isLoading: true, clearFailure: true);
    final result = await _repository.getAddresses();
    if (!mounted) return;
    state = switch (result) {
      Success(:final data) => state.copyWith(
        addresses: data,
        isLoading: false,
        clearFailure: true,
      ),
      Error(:final failure) => state.copyWith(
        isLoading: false,
        failure: failure,
      ),
    };
  }

  /// Every write funnels through here.
  ///
  /// Returns the failure rather than only storing it, because the caller is a
  /// form that has to decide whether to stay open — and because a
  /// `STEP_UP_REQUIRED` refusal is not an error to show her, it is a challenge
  /// `runWithStepUp` is about to turn into a second attempt.
  Future<Failure?> _write<T>(
    Future<Result<T>> Function() action, {
    List<AddressEntity> Function(T value)? apply,
  }) async {
    state = state.copyWith(isSaving: true, clearFailure: true);
    final result = await action();
    if (!mounted) return null;

    switch (result) {
      case Error(:final failure):
        state = state.copyWith(isSaving: false);
        return failure;
      case Success(:final data):
        // Drawn from the server's own answer straight away. The book used to
        // change only once the follow-up read came back, so when that read
        // failed — a slow line, a server waking up — the address she had just
        // saved was not there, with nothing to say why.
        if (apply != null) state = state.copyWith(addresses: apply(data));
    }

    await load();
    if (mounted) state = state.copyWith(isSaving: false);
    return null;
  }

  /// The book with [address] in it — replacing its old copy — and, when it is
  /// the default, every other one un-defaulted, the way the server does it.
  List<AddressEntity> _withAddress(AddressEntity address) {
    final others = [
      for (final existing in state.addresses)
        if (existing.id != address.id)
          address.isDefault ? existing.copyWith(isDefault: false) : existing,
    ];
    return address.isDefault ? [address, ...others] : [...others, address];
  }

  Future<Failure?> create(AddressDraft draft) =>
      _write(() => _repository.createAddress(draft), apply: _withAddress);

  Future<Failure?> update(String id, AddressDraft draft) =>
      _write(() => _repository.updateAddress(id, draft), apply: _withAddress);

  Future<Failure?> remove(String id) => _write(
    () => _repository.deleteAddress(id),
    apply: (_) => [
      for (final existing in state.addresses)
        if (existing.id != id) existing,
    ],
  );

  Future<Failure?> makeDefault(String id) =>
      _write(() => _repository.setDefaultAddress(id), apply: _withAddress);
}
