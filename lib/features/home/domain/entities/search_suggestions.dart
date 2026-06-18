import 'package:equatable/equatable.dart';

/// Drives the smart-search entry: trending queries across Reem, the user's own
/// recent searches, and personalized suggestions.
class SearchSuggestions extends Equatable {
  const SearchSuggestions({
    this.trending = const [],
    this.recent = const [],
    this.suggested = const [],
  });

  final List<String> trending;
  final List<String> recent;
  final List<String> suggested;

  bool get isEmpty =>
      trending.isEmpty && recent.isEmpty && suggested.isEmpty;

  @override
  List<Object?> get props => [trending, recent, suggested];
}
