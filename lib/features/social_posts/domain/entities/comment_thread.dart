import 'package:equatable/equatable.dart';

/// What a comment thread hangs off.
enum CommentThreadKind { post, product }

/// The address of one comment thread.
///
/// A post and a product speak the same comment contract — the server answers
/// `/products/:id/comments` in exactly the shape of `/posts/:id/comments` — so
/// the sheet, the notifier and the tile are shared, and only the address
/// differs. Keying the notifier on this rather than on a bare id also keeps a
/// post and a product from ever reading one another's thread.
class CommentThread extends Equatable {
  const CommentThread.post(this.id) : kind = CommentThreadKind.post;
  const CommentThread.product(this.id) : kind = CommentThreadKind.product;

  final CommentThreadKind kind;
  final String id;

  @override
  List<Object?> get props => [kind, id];
}
