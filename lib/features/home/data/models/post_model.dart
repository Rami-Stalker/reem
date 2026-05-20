import 'product_model.dart';

class PostModel {
  final String user;
  final String userImage;
  final String postImage;
  final String caption;
  final int likes;
  final int comments;
  final List<ProductModel> products;

  PostModel({
    required this.user,
    required this.userImage,
    required this.postImage,
    required this.caption,
    required this.likes,
    required this.comments,
    required this.products,
  });
}