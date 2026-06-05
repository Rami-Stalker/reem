import 'package:reem/core/shared/entities/comment.dart';
import '../../../../core/shared/entities/post.dart';
import '../../../../core/shared/entities/story.dart';
import '../../../../core/shared/models/post_model.dart';
import '../../../../core/shared/models/story_model.dart';
import '../../../../core/shared/models/user_model.dart';
import '../../../../core/shared/entities/product_media.dart';
import '../../../../core/shared/models/product_media_model.dart';
import '../../../../core/shared/models/product_model.dart';
import '../../../../core/shared/models/comment_model.dart';

List<Story> stories = [
  StoryModel(
    id: '1',
    isViewed: false,
    media: ProductMediaModel(
      url: 'https://images.unsplash.com/photo-1494790108377-be9c29b29330',
      type: MediaType.image,
    ),
    user: UserModel(
      id: '1',
      name: 'sara',
      username: 'SaraAlenna',
      email: 'saras@example.com',
      createdAt: DateTime.now(),
    ),
    createdAt: DateTime.now(),
    expiresAt: DateTime.now().add(Duration(hours: 24)),
  ),
  StoryModel(
    id: '1',
    isViewed: false,
    media: ProductMediaModel(
      url: 'https://images.unsplash.com/photo-1494790108377-be9c29b29330',
      type: MediaType.image,
    ),
    user: UserModel(
      id: '1',
      name: 'sara',
      username: 'SaraAlenna',
      email: 'adleb@example.com',
      createdAt: DateTime.now(),
    ),
    createdAt: DateTime.now(),
    expiresAt: DateTime.now().add(Duration(hours: 24)),
  ),
];

List<Post> posts = [
  PostModel(
    id: "1",
    author: UserModel(
      id: "u1",
      name: "Sara Alenna",
      username: 'SaraAlenna',
      email: 'saras@example.com',
      imageUrl: 'https://images.unsplash.com/photo-1494790108377-be9c29b29330',
      createdAt: DateTime.now(),
    ),
    likesCount: 128,
    commentsCount: 32,
    createdAt: DateTime.now(),
    caption: 'رهيييب',
    category: CategoryType.clothing,
    isLiked: false,
    product: ProductModel(
      id: '3',
      seller: UserModel(
        id: '1',
        name: 'sara',
        username: 'saraname',
        email: 'sara@gmial.com',
        createdAt: DateTime.now(),
      ),
      title: 'dd',
      description: 'ff',
      price: 123,
      media: [
        ProductMediaModel(
        url: 'https://images.unsplash.com/photo-1494790108377-be9c29b29330',
        type: MediaType.image,
      ),
      ],
      isAvailable: false,
      isFeatured: true,
      viewsCount: 33,
      likesCount: 12,
      createdAt: DateTime.now(),
    ),
    sharesCount: 76,
  ),
  PostModel(
    id: "1",
    author: UserModel(
      id: "u1",
      name: "Sara Alenna",
      username: 'SaraAlenna',
      email: 'saras@example.com',
      imageUrl: 'https://images.unsplash.com/photo-1494790108377-be9c29b29330',
      createdAt: DateTime.now(),
    ),
    likesCount: 128,
    commentsCount: 32,
    createdAt: DateTime.now(),
    caption: 'رهيييب',
    category: CategoryType.clothing,
    isLiked: false,
    product: ProductModel(
      id: '3',
      seller: UserModel(
        id: '1',
        name: 'sara',
        username: 'saraname',
        email: 'sara@gmial.com',
        createdAt: DateTime.now(),
      ),
      title: 'dd',
      description: 'ff',
      price: 123,
      media: [
        ProductMediaModel(
        url: 'https://images.unsplash.com/photo-1494790108377-be9c29b29330',
        type: MediaType.image,
      ),
      ],
      isAvailable: false,
      isFeatured: true,
      viewsCount: 33,
      likesCount: 12,
      createdAt: DateTime.now(),
    ),
    sharesCount: 76,
  ),
  PostModel(
    id: "1",
    author: UserModel(
      id: "u1",
      name: "Sara Alenna",
      username: 'SaraAlenna',
      email: 'saras@example.com',
      imageUrl: 'https://images.unsplash.com/photo-1494790108377-be9c29b29330',
      createdAt: DateTime.now(),
    ),
    likesCount: 128,
    commentsCount: 32,
    createdAt: DateTime.now(),
    caption: 'رهيييب',
    category: CategoryType.clothing,
    isLiked: false,
    product: ProductModel(
      id: '3',
      seller: UserModel(
        id: '1',
        name: 'sara',
        username: 'saraname',
        email: 'sara@gmial.com',
        createdAt: DateTime.now(),
      ),
      title: 'dd',
      description: 'ff',
      price: 123,
      media: [
        ProductMediaModel(
        url: 'https://images.unsplash.com/photo-1494790108377-be9c29b29330',
        type: MediaType.image,
      ),
      ],
      isAvailable: false,
      isFeatured: true,
      viewsCount: 33,
      likesCount: 12,
      createdAt: DateTime.now(),
    ),
    sharesCount: 76,
  ),
];

/// Helper class to store comment data for dummy data
class CommentData {
  final String id;
  final String postId;
  final String userId;
  final String content;
  final DateTime createdAt;

  CommentData({
    required this.id,
    required this.postId,
    required this.userId,
    required this.content,
    required this.createdAt,
  });
}

/// List of comment data for dummy purposes
List<CommentData> comments = [
  CommentData(
    id: 'c1',
    postId: '1',
    userId: 'u2',
    content: 'Beautiful! Where can I buy this? 😍',
    createdAt: DateTime.now().subtract(const Duration(hours: 1)),
  ),
  CommentData(
    id: 'c2',
    postId: '1',
    userId: 'u3',
    content: 'Love this so much! 💕',
    createdAt: DateTime.now().subtract(const Duration(hours: 2)),
  ),
  CommentData(
    id: 'c3',
    postId: '1',
    userId: 'u4',
    content: 'This is exactly what I was looking for!',
    createdAt: DateTime.now().subtract(const Duration(hours: 3)),
  ),
  CommentData(
    id: 'c4',
    postId: '1',
    userId: 'u5',
    content: 'Amazing quality! Highly recommend ✨',
    createdAt: DateTime.now().subtract(const Duration(hours: 4)),
  ),
  CommentData(
    id: 'c5',
    postId: '1',
    userId: 'u6',
    content: 'Just ordered mine! Can\'t wait 🎉',
    createdAt: DateTime.now().subtract(const Duration(hours: 5)),
  ),
];

/// Get comments for a specific post
List<Comment> getCommentsForPost(String postId) {
  final userMap = <String, UserModel>{
    'u2': UserModel(
      id: 'u2',
      name: 'Layla Ahmed',
      username: 'layla_ahmed',
      email: 'layla@example.com',
      imageUrl: 'https://images.unsplash.com/photo-1494790108377-be9c29b29330',
      createdAt: DateTime.now().subtract(const Duration(days: 30)),
    ),
    'u3': UserModel(
      id: 'u3',
      name: 'Nour Hassan',
      username: 'nour_hassan',
      email: 'nour@example.com',
      imageUrl: 'https://images.unsplash.com/photo-1517841905240-472988babdf9',
      createdAt: DateTime.now().subtract(const Duration(days: 60)),
    ),
    'u4': UserModel(
      id: 'u4',
      name: 'Mariam Ali',
      username: 'mariam_ali',
      email: 'mariam@example.com',
      imageUrl: 'https://images.unsplash.com/photo-1524504388940-b1c1722653e1',
      createdAt: DateTime.now().subtract(const Duration(days: 90)),
    ),
    'u5': UserModel(
      id: 'u5',
      name: 'Hana Mahmoud',
      username: 'hana_mahmoud',
      email: 'hana@example.com',
      imageUrl: 'https://images.unsplash.com/photo-1534528741775-53994a69da53',
      createdAt: DateTime.now().subtract(const Duration(days: 120)),
    ),
    'u6': UserModel(
      id: 'u6',
      name: 'Salma Ibrahim',
      username: 'salma_ibrahim',
      email: 'salma@example.com',
      imageUrl: 'https://images.unsplash.com/photo-1506794778202-cad84cf45f1d',
      createdAt: DateTime.now().subtract(const Duration(days: 150)),
    ),
  };

  return comments
      .where((c) => c.postId == postId)
      .map((c) => CommentModel(
            id: c.id,
            user: userMap[c.userId] ??
                UserModel(
                  id: c.userId,
                  name: 'User',
                  username: 'user',
                  email: 'user@example.com',
                  createdAt: DateTime.now(),
                ),
            content: c.content,
            createdAt: c.createdAt,
            likesCount: (c.id.codeUnitAt(1) * 7) % 50, // Random likes for demo
          ))
      .toList();
}
