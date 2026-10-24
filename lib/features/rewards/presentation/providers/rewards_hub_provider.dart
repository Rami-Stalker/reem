import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:ohara/core/network/network_info.dart';
import 'package:ohara/core/presentation/providers/core_providers.dart';
import 'package:ohara/core/result/result.dart';
import 'package:ohara/features/rewards/data/datasources/impl/rewards_remote_datasource_impl.dart';
import 'package:ohara/features/rewards/data/datasources/rewards_remote_datasource.dart';
import 'package:ohara/features/rewards/data/repositories/rewards_repository_impl.dart';
import 'package:ohara/features/rewards/domain/entities/rewards_hub.dart';
import 'package:ohara/features/rewards/domain/repositories/rewards_repository.dart';
import 'package:ohara/features/rewards/domain/usecases/rewards_usecases.dart';
import 'package:ohara/features/rewards/presentation/providers/rewards_message.dart';

final rewardsRemoteDataSourceProvider = Provider<RewardsRemoteDataSource>(
  (ref) => RewardsRemoteDataSourceImpl(ref.watch(dioProvider)),
);

final rewardsRepositoryProvider = Provider<RewardsRepository>(
  (ref) => RewardsRepositoryImpl(ref.watch(rewardsRemoteDataSourceProvider)),
);

final loadRewardsHubUseCaseProvider = Provider(
  (ref) => LoadRewardsHubUseCase(ref.watch(rewardsRepositoryProvider)),
);

final applyReferralCodeUseCaseProvider = Provider(
  (ref) => ApplyReferralCodeUseCase(ref.watch(rewardsRepositoryProvider)),
);

final redeemLoyaltyRewardUseCaseProvider = Provider(
  (ref) => RedeemLoyaltyRewardUseCase(ref.watch(rewardsRepositoryProvider)),
);

final redeemCashbackUseCaseProvider = Provider(
  (ref) => RedeemCashbackUseCase(ref.watch(rewardsRepositoryProvider)),
);

final rewardsHubNotifierProvider =
    StateNotifierProvider.autoDispose<RewardsHubNotifier, RewardsHubState>(
  (ref) => RewardsHubNotifier(
    loadHub: ref.watch(loadRewardsHubUseCaseProvider),
    applyReferralCode: ref.watch(applyReferralCodeUseCaseProvider),
    redeemReward: ref.watch(redeemLoyaltyRewardUseCaseProvider),
    redeemCashback: ref.watch(redeemCashbackUseCaseProvider),
    networkInfo: ref.watch(networkInfoProvider),
  )..load(),
);

class RewardsHubState {
  const RewardsHubState({
    this.hub,
    this.isLoading = false,
    this.isRefreshing = false,
    this.isApplyingCode = false,
    this.isRedeemingCashback = false,
    this.busyRewardId,
    this.error,
    this.success,
    this.errorMessage,
    this.successMessage,
  });

  final RewardsHub? hub;
  final bool isLoading;
  final bool isRefreshing;
  final bool isApplyingCode;
  final bool isRedeemingCashback;
  final String? busyRewardId;
  /// A message the *server* supplied, already in her language.
  final String? error;
  final String? success;

  /// A message *we* supplied. Named rather than spelled out, because a
  /// notifier has no context to localise with — the screen resolves it.
  final RewardsMessage? errorMessage;
  final RewardsMessage? successMessage;

  RewardsHubState copyWith({
    RewardsHub? hub,
    bool? isLoading,
    bool? isRefreshing,
    bool? isApplyingCode,
    bool? isRedeemingCashback,
    String? busyRewardId,
    String? error,
    String? success,
    RewardsMessage? errorMessage,
    RewardsMessage? successMessage,
    bool clearBusyReward = false,
    bool clearError = false,
    bool clearSuccess = false,
  }) {
    return RewardsHubState(
      hub: hub ?? this.hub,
      isLoading: isLoading ?? this.isLoading,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      isApplyingCode: isApplyingCode ?? this.isApplyingCode,
      isRedeemingCashback:
          isRedeemingCashback ?? this.isRedeemingCashback,
      busyRewardId: clearBusyReward ? null : (busyRewardId ?? this.busyRewardId),
      error: clearError ? null : (error ?? this.error),
      success: clearSuccess ? null : (success ?? this.success),
      errorMessage:
          clearError ? null : (errorMessage ?? this.errorMessage),
      successMessage:
          clearSuccess ? null : (successMessage ?? this.successMessage),
    );
  }
}

class RewardsHubNotifier extends StateNotifier<RewardsHubState> {
  RewardsHubNotifier({
    required LoadRewardsHubUseCase loadHub,
    required ApplyReferralCodeUseCase applyReferralCode,
    required RedeemLoyaltyRewardUseCase redeemReward,
    required RedeemCashbackUseCase redeemCashback,
    required NetworkInfo networkInfo,
  })  : _loadHub = loadHub,
        _applyReferralCode = applyReferralCode,
        _redeemReward = redeemReward,
        _redeemCashback = redeemCashback,
        _networkInfo = networkInfo,
        super(const RewardsHubState());

  final LoadRewardsHubUseCase _loadHub;
  final ApplyReferralCodeUseCase _applyReferralCode;
  final RedeemLoyaltyRewardUseCase _redeemReward;
  final RedeemCashbackUseCase _redeemCashback;
  final NetworkInfo _networkInfo;

  Future<void> load({bool refresh = false}) async {
    if (!await _networkInfo.isConnected) {
      state = state.copyWith(
        isLoading: false,
        isRefreshing: false,
        errorMessage: RewardsMessage.offlineHint,
        clearSuccess: true,
      );
      return;
    }

    state = state.copyWith(
      isLoading: !refresh && state.hub == null,
      isRefreshing: refresh,
      clearError: true,
      clearSuccess: true,
    );
    final result = await _loadHub();
    if (result case Success(:final data)) {
      state = state.copyWith(
        hub: data,
        isLoading: false,
        isRefreshing: false,
      );
    } else if (result case Error(:final failure)) {
      state = state.copyWith(
        isLoading: false,
        isRefreshing: false,
        error: failure.message,
      );
    }
  }

  Future<void> applyCode(String code) async {
    final normalized = code.trim();
    if (normalized.length < 4) {
      state = state.copyWith(errorMessage: RewardsMessage.codeInvalid);
      return;
    }
    if (!await _networkInfo.isConnected) {
      state = state.copyWith(errorMessage: RewardsMessage.offlineRetry);
      return;
    }

    state = state.copyWith(
      isApplyingCode: true,
      clearError: true,
      clearSuccess: true,
    );
    final result = await _applyReferralCode(normalized);
    if (result case Success(:final data)) {
      state = state.copyWith(
        hub: data,
        isApplyingCode: false,
        successMessage: RewardsMessage.codeApplied,
      );
    } else if (result case Error(:final failure)) {
      state = state.copyWith(isApplyingCode: false, error: failure.message);
    }
  }

  Future<void> redeemReward(LoyaltyRewardItem reward) async {
    if (!reward.canRedeem(state.hub?.points ?? 0)) {
      state = state.copyWith(errorMessage: RewardsMessage.notEnoughPoints);
      return;
    }
    if (!await _networkInfo.isConnected) {
      state = state.copyWith(errorMessage: RewardsMessage.offlineRetry);
      return;
    }

    state = state.copyWith(
      busyRewardId: reward.id,
      clearError: true,
      clearSuccess: true,
    );
    final result = await _redeemReward(reward.id);
    if (result case Success(:final data)) {
      state = state.copyWith(
        hub: data,
        clearBusyReward: true,
        successMessage: RewardsMessage.redeemed,
      );
    } else if (result case Error(:final failure)) {
      state = state.copyWith(clearBusyReward: true, error: failure.message);
    }
  }

  Future<void> redeemCashback() async {
    final available = state.hub?.cashback.available ?? 0;
    if (available <= 0) {
      state = state.copyWith(errorMessage: RewardsMessage.noCashback);
      return;
    }
    if (!await _networkInfo.isConnected) {
      state = state.copyWith(errorMessage: RewardsMessage.offlineRetry);
      return;
    }

    state = state.copyWith(
      isRedeemingCashback: true,
      clearError: true,
      clearSuccess: true,
    );
    final result = await _redeemCashback();
    if (result case Success(:final data)) {
      state = state.copyWith(
        hub: data,
        isRedeemingCashback: false,
        successMessage: RewardsMessage.cashbackConverted,
      );
    } else if (result case Error(:final failure)) {
      state = state.copyWith(
        isRedeemingCashback: false,
        error: failure.message,
      );
    }
  }
}
