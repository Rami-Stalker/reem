class CommissionStatusTotal {
  const CommissionStatusTotal({
    required this.gross,
    required this.commission,
    required this.platformFees,
    required this.net,
    required this.count,
  });

  final double gross;
  final double commission;
  final double platformFees;
  final double net;
  final int count;

  factory CommissionStatusTotal.fromJson(Map<String, dynamic> json) {
    return CommissionStatusTotal(
      gross: (json['gross'] as num?)?.toDouble() ?? 0,
      commission: (json['commission'] as num?)?.toDouble() ?? 0,
      platformFees: (json['platform_fees'] as num?)?.toDouble() ?? 0,
      net: (json['net'] as num?)?.toDouble() ?? 0,
      count: json['count'] as int? ?? 0,
    );
  }
}

class CommissionLedgerItem {
  const CommissionLedgerItem({
    required this.id,
    required this.gross,
    required this.commission,
    required this.platformFee,
    required this.net,
    required this.status,
    required this.createdAt,
  });

  final String id;
  final double gross;
  final double commission;
  final double platformFee;
  final double net;
  final String status;
  final DateTime createdAt;

  factory CommissionLedgerItem.fromJson(Map<String, dynamic> json) {
    return CommissionLedgerItem(
      id: json['id'] as String? ?? '',
      gross: (json['gross'] as num?)?.toDouble() ?? 0,
      commission: (json['commission'] as num?)?.toDouble() ?? 0,
      platformFee: (json['platform_fee'] as num?)?.toDouble() ?? 0,
      net: (json['net'] as num?)?.toDouble() ?? 0,
      status: json['status'] as String? ?? 'pending',
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}

class SellerCommissionEarnings {
  const SellerCommissionEarnings({
    required this.totals,
    required this.lifetimePaid,
    required this.recentTransactions,
  });

  final Map<String, CommissionStatusTotal> totals;
  final double lifetimePaid;
  final List<CommissionLedgerItem> recentTransactions;

  double get availableNet => totals['earned']?.net ?? 0;
  double get pendingNet => totals['pending']?.net ?? 0;
  double get reversedNet => totals['reversed']?.net ?? 0;

  factory SellerCommissionEarnings.fromJson(Map<String, dynamic> json) {
    final totalsJson = json['totals'] is Map
        ? Map<String, dynamic>.from(json['totals'] as Map)
        : <String, dynamic>{};
    return SellerCommissionEarnings(
      totals: totalsJson.map(
        (key, value) => MapEntry(
          key,
          CommissionStatusTotal.fromJson(Map<String, dynamic>.from(value as Map)),
        ),
      ),
      lifetimePaid: (json['lifetime_paid'] as num?)?.toDouble() ?? 0,
      recentTransactions: (json['recent_transactions'] as List? ?? [])
          .whereType<Map>()
          .map((item) => CommissionLedgerItem.fromJson(
                Map<String, dynamic>.from(item),
              ))
          .toList(),
    );
  }
}
