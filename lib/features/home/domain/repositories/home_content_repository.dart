import 'package:ohara/core/result/result.dart';
import 'package:ohara/features/home/domain/entities/home_content.dart';

/// Source of the home page's bespoke merchandising content (hero banners,
/// flash deals, featured stores, loyalty, etc.).
abstract interface class HomeContentRepository {
  Future<Result<HomeContent>> getHomeContent();
}
