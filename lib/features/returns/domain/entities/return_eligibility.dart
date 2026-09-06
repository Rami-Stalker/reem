/// What a delivered parcel can still send back, and why not where it cannot.
///
/// Read before the form is drawn, so a line she may not return is shown greyed
/// with its reason rather than accepted and then refused after she has chosen
/// a reason and typed a note.
class ReturnEligibility {
  const ReturnEligibility({
    required this.sellerOrderId,
    required this.orderNumber,
    required this.deliveredAt,
    required this.windowClosesAt,
    required this.extraWindowDays,
    required this.isWindowOpen,
    required this.lines,
  });

  final String sellerOrderId;
  final String orderNumber;
  final DateTime? deliveredAt;
  final DateTime? windowClosesAt;

  /// Days added to the policy window for this shopper. Surfaced so the screen
  /// can say why her window is longer than the policy page states, instead of
  /// silently disagreeing with it.
  final int extraWindowDays;

  final bool isWindowOpen;
  final List<ReturnEligibilityLine> lines;

  /// Whether there is anything at all to ask for.
  bool get hasReturnableLines =>
      isWindowOpen && lines.any((line) => line.isReturnable);
}

/// One line of the parcel, with the two verdicts the server reaches separately.
class ReturnEligibilityLine {
  const ReturnEligibilityLine({
    required this.orderItemId,
    required this.title,
    required this.variant,
    required this.image,
    required this.quantityOrdered,
    required this.quantityClaimed,
    required this.quantityReturnable,
    required this.onFaultAllowed,
    required this.onFaultBlocker,
    required this.changeOfMindAllowed,
    required this.changeOfMindBlocker,
  });

  final String orderItemId;
  final String title;
  final String? variant;
  final String? image;
  final int quantityOrdered;
  final int quantityClaimed;
  final int quantityReturnable;

  /// A fault claim — defective, wrong item, damaged in transit.
  final bool onFaultAllowed;
  final String? onFaultBlocker;

  /// A change of mind, which a made-to-order piece may exclude even though the
  /// same piece arriving torn still comes back.
  final bool changeOfMindAllowed;
  final String? changeOfMindBlocker;

  bool get isReturnable =>
      quantityReturnable > 0 && (onFaultAllowed || changeOfMindAllowed);

  /// Whether this line accepts the reason she has chosen.
  bool allows({required bool isFaultReason}) =>
      quantityReturnable > 0 &&
      (isFaultReason ? onFaultAllowed : changeOfMindAllowed);

  /// The reason it cannot go back under the reason she has chosen.
  String? blockerFor({required bool isFaultReason}) =>
      isFaultReason ? onFaultBlocker : changeOfMindBlocker;
}
