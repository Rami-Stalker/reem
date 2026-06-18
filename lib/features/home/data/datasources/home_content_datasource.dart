import '../../domain/entities/home_content.dart';

/// Boundary for the home merchandising content. Today this is fulfilled by
/// [HomeContentMockDataSource]; swapping to a network implementation
/// (`HomeContentRemoteDataSourceImpl` parsing JSON models) is a one-line change
/// in `home_content_provider.dart` — nothing above this interface changes.
abstract interface class HomeContentDataSource {
  Future<HomeContent> getHomeContent();
}
