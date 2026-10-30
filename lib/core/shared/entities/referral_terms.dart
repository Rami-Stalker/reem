import 'package:equatable/equatable.dart';

/// What a shopper's invite pays each side, as the server's ledger pays it.
///
/// Numbers rather than a sentence, because the sentence depends on who reads
/// it. The app used to receive one line written to the inviter — «لكِ 500
/// نقطة ولها 250» — and pasted it into the message sent to the friend, who
/// then read the programme backwards: that *she* would get 500 and her friend
/// 250. Each screen now words its own reader's half from these.
class ReferralTerms extends Equatable {
  const ReferralTerms({
    required this.referrerPoints,
    required this.referredPoints,
    required this.referrerDiscountPercent,
    required this.referredDiscountPercent,
    this.couponValidDays,
  });

  /// Points the inviter earns once her friend's first order completes.
  final int referrerPoints;

  /// Points the friend earns once that same first order completes.
  final int referredPoints;

  /// The inviter's thank-you discount, issued when her friend's order
  /// completes.
  final int referrerDiscountPercent;

  /// The friend's welcome discount, hers from the moment she uses the code.
  final int referredDiscountPercent;

  /// How long each discount code stands before it lapses.
  final int? couponValidDays;

  @override
  List<Object?> get props => [
    referrerPoints,
    referredPoints,
    referrerDiscountPercent,
    referredDiscountPercent,
    couponValidDays,
  ];
}
