import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ohara/core/network/api_endpoints.dart';
import 'package:ohara/core/presentation/providers/core_providers.dart';

import 'package:ohara/features/commissions/data/commission_models.dart';

final sellerCommissionEarningsProvider =
    FutureProvider<SellerCommissionEarnings>((ref) async {
  final dio = ref.watch(dioProvider);
  final response = await dio.get<dynamic>(ApiEndpoints.commissionSellerEarnings);
  final data = response.data is Map
      ? Map<String, dynamic>.from(response.data as Map)
      : <String, dynamic>{};
  return SellerCommissionEarnings.fromJson(data);
});
