import '../../../../core/shared/entities/post.dart';
import '../../../../core/shared/entities/story.dart';
import '../../../../core/shared/models/post_model.dart';
import '../../../../core/shared/models/story_model.dart';
import '../../../../core/shared/models/user_model.dart';
import '../../../../core/shared/entities/product_media.dart';
import '../../../../core/shared/models/product_media_model.dart';
import '../../../../core/shared/models/product_model.dart';

List<Story> stories = [
  StoryModel(
    id: '1',
    isViewed: true,
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
    isViewed: true,
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
