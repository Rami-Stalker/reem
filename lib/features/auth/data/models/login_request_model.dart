/// Identity is the phone number and nothing else.
///
/// This used to send a free-text `identifier` that the server split on `'@'`
/// to decide between an email lookup and a phone lookup. Both halves of that
/// are gone: the server no longer accepts an email as a login identifier, and
/// the field name it expects is `phone`.
class LoginRequestModel {
  const LoginRequestModel({required this.phone, required this.password});

  final String phone;
  final String password;

  Map<String, dynamic> toJson() => {'phone': phone, 'password': password};
}
