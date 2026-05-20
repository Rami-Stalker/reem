class StoryModel {
  final String name;
  final String image;
  final bool isAdd;

  StoryModel({
    required this.name,
    required this.image,
    this.isAdd = false,
  });
}