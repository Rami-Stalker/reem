import 'package:ohara/core/shared/entities/user.dart';

class RegisterRequestModel {
  final String firstName;
  final String lastName;
  final String phone;

  /// Proof that the number was verified moments ago, minted by
  /// `POST /auth/otp/login/verify`. The server refuses to create an account
  /// without it — which is what stops one person claiming every number in a
  /// contact list and locking those women out of signing up themselves.
  final String registrationTicket;

  /// Optional, and off by default. She signs in with a code on her SIM; a
  /// password is an accelerator she can add later and can never, on its own,
  /// admit a device the account has not used before.
  final String? password;
  final String country;
  final String city;
  final UserRole role;

  /// Q43/Q138 P1 — the platform is for women, enforced by self-declaration at
  /// signup. The server rejects a registration that does not carry it, so this
  /// is not optional and has no default: the attestation has to be something
  /// she actually made on the form.
  final bool declaredFemale;

  /// The exact issues of the policies she accepted on the signup form.
  ///
  /// Version ids, not a boolean: the server records one acceptance row per
  /// document against the text that was on screen, which is what lets the
  /// consent be reconstructed years later. Empty is legal and the server
  /// decides — it refuses when a required document's current version is
  /// missing, and accepts when nothing is published yet.
  final List<String> acceptedPolicyVersionIds;

  const RegisterRequestModel({
    required this.firstName,
    required this.lastName,
    required this.phone,
    required this.registrationTicket,
    this.password,
    required this.country,
    required this.city,
    required this.declaredFemale,
    this.acceptedPolicyVersionIds = const [],
    this.role = UserRole.customer,
  });

  Map<String, dynamic> toJson() => {
    'first_name': firstName,
    'last_name': lastName,
    'name': '$firstName $lastName',
    'phone': phone,
    'registration_ticket': registrationTicket,
    if (password != null && password!.isNotEmpty) 'password': password,
    'country': country,
    'city': city,
    'declared_female': declaredFemale,
    if (acceptedPolicyVersionIds.isNotEmpty)
      'accepted_policy_version_ids': acceptedPolicyVersionIds,
    'role': role.wire,
  };
}
