import 'package:equatable/equatable.dart';

import 'package:ohara/core/shared/entities/post.dart';
import 'package:ohara/core/shared/entities/product.dart';
import 'package:ohara/core/shared/entities/user.dart';

/// The top hits for one phrase across everything a woman can look for.
///
/// Search used to mean products. The server has answered boutiques, shoppers
/// and posts from the same folded key since the Arabic search work — `GET
/// /search` returns all four — and the app only ever asked for the first.
class UnifiedSearch extends Equatable {
  const UnifiedSearch({
    this.products = const [],
    this.boutiques = const [],
    this.shoppers = const [],
    this.posts = const [],
  });

  final List<Product> products;
  final List<User> boutiques;

  /// Only women whose page is open — the server never lists a private one.
  final List<User> shoppers;
  final List<Post> posts;

  bool get isEmpty =>
      products.isEmpty &&
      boutiques.isEmpty &&
      shoppers.isEmpty &&
      posts.isEmpty;

  @override
  List<Object?> get props => [products, boutiques, shoppers, posts];
}
