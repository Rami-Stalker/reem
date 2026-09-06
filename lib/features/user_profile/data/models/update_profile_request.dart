/// Partial profile update — only the provided fields are sent to the server.
class UpdateProfileRequest {
  final String? name;
  final String? bio;
  final String? imageUrl;
  final String? location;

  /// Her recovery address. Empty string clears it; null leaves it alone.
  final String? email;

  const UpdateProfileRequest({
    this.name,
    this.bio,
    this.imageUrl,
    this.location,
    this.email,
  });

  Map<String, dynamic> toJson() => {
        if (name != null) 'name': name,
        if (bio != null) 'bio': bio,
        if (imageUrl != null) 'image_url': imageUrl,
        if (location != null) 'location': location,
        if (email != null) 'email': email,
      };
}
