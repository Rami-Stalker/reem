import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:reem/core/network/network_info.dart';
import 'package:reem/core/providers/core_providers.dart';
import 'package:reem/core/result/result.dart';

import '../../data/datasources/impl/wallet_remote_datasource_impl.dart';
import '../../data/datasources/wallet_remote_datasource.dart';
import '../../data/repositories/wallet_repository_impl.dart';
import '../../domain/entities/wallet_transaction.dart';
import '../../domain/repositories/wallet_repository.dart';

final walletRemoteDataSourceProvider = Provider<WalletRemoteDataSource>(
  (ref) => WalletRemoteDataSourceImpl(ref.watch(dioProvider)),
);

final walletRepositoryProvider = Provider<WalletRepository>(
  (ref) => WalletRepositoryImpl(ref.watch(walletRemoteDataSourceProvider)),
);

final walletNotifierProvider =
    StateNotifierProvider.autoDispose<WalletNotifier, WalletState>(
      (ref) => WalletNotifier(
        repository: ref.watch(walletRepositoryProvider),
        networkInfo: ref.watch(networkInfoProvider),
      )..load(),
    );

/// A problem the client itself detected, as a code rather than a sentence.
///
/// The notifier has no `BuildContext` and so no localisation; emitting a code
/// lets the screen render it in Arabic through `l10n` instead of the English
/// strings that leaked into some older notifiers.
enum WalletIssue {
  offline,
  pointsMultipleOfTen,
  notEnoughPoints;
}

class WalletState {
  const WalletState({
    this.summary,
    this.isLoading = false,
    this.isRefreshing = false,
    this.isConverting = false,
    this.issue,
    this.serverError,
    this.convertedPoints,
  });

  final WalletSummary? summary;
  final bool isLoading;
  final bool isRefreshing;
  final bool isConverting;

  /// A client-side problem, to be localised by the screen.
  final WalletIssue? issue;

  /// A message from the server, already in the API's language.
  final String? serverError;

  /// Set after a successful conversion so the screen can confirm it.
  final int? convertedPoints;

  bool get hasError => issue != null || serverError != null;

  WalletState copyWith({
    WalletSummary? summary,
    bool? isLoading,
    bool? isRefreshing,
    bool? isConverting,
    WalletIssue? issue,
    String? serverError,
    int? convertedPoints,
    bool clearIssue = false,
    bool clearServerError = false,
    bool clearConverted = false,
  }) {
    return WalletState(
      summary: summary ?? this.summary,
      isLoading: isLoading ?? this.isLoading,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      isConverting: isConverting ?? this.isConverting,
      issue: clearIssue ? null : (issue ?? this.issue),
      serverError: clearServerError ? null : (serverError ?? this.serverError),
      convertedPoints:
          clearConverted ? null : (convertedPoints ?? this.convertedPoints),
    );
  }
}

class WalletNotifier extends StateNotifier<WalletState> {
  WalletNotifier({
    required WalletRepository repository,
    required NetworkInfo networkInfo,
  }) : _repository = repository,
       _networkInfo = networkInfo,
       super(const WalletState());

  final WalletRepository _repository;
  final NetworkInfo _networkInfo;

  /// Q43 — points convert in tens.
  static const int pointsStep = 10;

  Future<void> load({bool refresh = false}) async {
    if (!await _networkInfo.isConnected) {
      state = state.copyWith(
        isLoading: false,
        isRefreshing: false,
        issue: WalletIssue.offline,
      );
      return;
    }

    state = state.copyWith(
      isLoading: !refresh && state.summary == null,
      isRefreshing: refresh,
      clearIssue: true,
      clearServerError: true,
    );

    final result = await _repository.load(take: 30);
    switch (result) {
      case Success(:final data):
        state = state.copyWith(
          summary: data,
          isLoading: false,
          isRefreshing: false,
        );
      case Error(:final failure):
        state = state.copyWith(
          isLoading: false,
          isRefreshing: false,
          serverError: failure.message,
        );
    }
  }

  Future<void> refresh() => load(refresh: true);

  /// Q43 — «كل 10 نقاط = 5,000 ل.س رصيد».
  ///
  /// The multiple-of-ten rule is checked here as well as on the server: it is
  /// a rule she should learn from the interface rather than from a rejected
  /// request.
  Future<void> convertPoints(int points) async {
    if (points <= 0 || points % pointsStep != 0) {
      state = state.copyWith(issue: WalletIssue.pointsMultipleOfTen);
      return;
    }
    if (!await _networkInfo.isConnected) {
      state = state.copyWith(issue: WalletIssue.offline);
      return;
    }

    state = state.copyWith(
      isConverting: true,
      clearIssue: true,
      clearServerError: true,
      clearConverted: true,
    );

    final result = await _repository.convertPoints(points);
    switch (result) {
      case Success(:final data):
        state = state.copyWith(
          summary: data,
          isConverting: false,
          convertedPoints: points,
        );
      case Error(:final failure):
        state = state.copyWith(
          isConverting: false,
          serverError: failure.message,
        );
    }
  }

  /// Clears a one-shot message once the screen has shown it.
  void acknowledge() {
    state = state.copyWith(
      clearIssue: true,
      clearServerError: true,
      clearConverted: true,
    );
  }
}
