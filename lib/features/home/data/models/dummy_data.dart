import 'package:reem/features/stories/data/models/story_model.dart';

import '../models/post_model.dart';
import '../models/product_model.dart';

List<StoryModel> stories = [
  StoryModel(
    name: "أنت",
    image:
        "https://images.unsplash.com/photo-1494790108377-be9c29b29330",
    isAdd: true,
  ),
  StoryModel(
    name: "جديد",
    image:
        "https://images.unsplash.com/photo-1524504388940-b1c1722653e1",
  ),
];

List<PostModel> posts = [
  PostModel(
    user: "Sara Alenna",
    userImage:
        "https://images.unsplash.com/photo-1494790108377-be9c29b29330",
    postImage:
        "https://images.unsplash.com/photo-1515886657613-9f3515b0c78f",
    caption: "إطلالة ناعمة للدّوام 💗",
    likes: 128,
    comments: 32,
    products: [
      ProductModel(
        name: "فستان",
        image:
            "https://images.unsplash.com/photo-1496747611176-843222e1e57c",
        price: 290,
      ),
    ],
  ),
];