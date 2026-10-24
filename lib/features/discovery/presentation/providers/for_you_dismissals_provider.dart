import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ohara/core/result/result.dart';
import 'package:ohara/features/discovery/domain/usecases/discovery_usecases.dart';
import 'package:ohara/features/discovery/presentation/providers/discovery_providers.dart';

final dismissRecommendationUseCaseProvider = Provider(
  (ref) => DismissRecommendationUseCase(ref.watch(discoveryRepositoryProvider)),
);

/// The pieces she has taken out of «مختارة لكِ» in this session.
///
/// The server forgets nothing — the next load of the shelf leaves them out —
/// but the shelf already on screen, and the home rail behind it, were loaded
/// before she asked. This set is what takes them off those at once, and puts
/// them back on «تراجع».
final forYouDismissalsProvider =
    NotifierProvider<ForYouDismissals, Set<String>>(ForYouDismissals.new);

class ForYouDismissals extends Notifier<Set<String>> {
  @override
  Set<String> build() => const <String>{};

  DismissRecommendationUseCase get _useCase =>
      ref.read(dismissRecommendationUseCaseProvider);

  /// Hidden first, then sent: the card leaves the moment she chooses. A
  /// refusal from the server puts it back.
  Future<Result<void>> dismiss(String productId) async {
    state = {...state, productId};
    final result = await _useCase(productId);
    if (result is Error) state = {...state}..remove(productId);
    return result;
  }

  Future<Result<void>> restore(String productId) async {
    final result = await _useCase.undo(productId);
    if (result is Success) state = {...state}..remove(productId);
    return result;
  }
}
