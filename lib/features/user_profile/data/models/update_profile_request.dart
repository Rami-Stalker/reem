/// Partial profile update — only the provided fields are sent to the server.
class UpdateProfileRequest {
  final String? name;
  final String? bio;
  final String? imageUrl;
  final String? location;

  const UpdateProfileRequest({
    this.name,
    this.bio,
    this.imageUrl,
    this.location,
  });

  Map<String, dynamic> toJson() => {
        if (name != null) 'name': name,
        if (bio != null) 'bio': bio,
        if (imageUrl != null) 'image_url': imageUrl,
        if (location != null) 'location': location,
      };
}
