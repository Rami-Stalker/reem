import 'package:reem/core/network/api_endpoints.dart';
import 'package:reem/core/network/base_remote_datasource.dart';
import 'package:reem/features/intelligence/data/datasources/intelligence_remote_datasource.dart';
import 'package:reem/features/intelligence/domain/entities/intelligence_note.dart';
import 'package:reem/features/intelligence/domain/entities/size_fit.dart';

final class IntelligenceRemoteDataSourceImpl extends BaseRemoteDataSource
    implements IntelligenceRemoteDataSource {
  const IntelligenceRemoteDataSourceImpl(super.dio);

  @override
  Future<List<IntelligenceNote>> notes(String productId) async {
    final json = await getJson(ApiEndpoints.intelligenceNotes(productId));
    final rows = json['notes'];
    if (rows is! List) return const [];

    return rows.whereType<Map<String, dynamic>>().map((row) {
      final evidence = row['evidence'];
      return IntelligenceNote(
        code: row['code'] as String? ?? '',
        tone: NoteTone.parse(row['tone'] as String?),
        ar: row['ar'] as String? ?? '',
        evidence: evidence is Map<String, dynamic> ? evidence : const {},
      );
    }).where((note) => note.ar.isNotEmpty).toList(growable: false);
  }

  @override
  Future<List<SizeFit>> sizeFit(String productId) async {
    final json = await getJson(ApiEndpoints.intelligenceFit(productId));
    final rows = json['sizes'];
    if (rows is! List) return const [];

    final fits = <SizeFit>[];
    for (final row in rows.whereType<Map<String, dynamic>>()) {
      final size = normaliseSize(row['size']);
      if (size == null) continue;
      final rate = row['kept_rate'];
      fits.add(
        SizeFit(
          size: size,
          keptRate: rate is num ? rate.toDouble().clamp(0, 1) : null,
        ),
      );
    }
    return List.unmodifiable(fits);
  }
}
