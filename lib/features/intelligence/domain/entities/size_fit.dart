import 'package:meta/meta.dart';

/// How often one size of a product was kept by the women who received it.
///
/// Computed on the server from returns marked as a size problem. [keptRate]
/// is null when too few of that size have sold to say anything honest, and
/// the page then says nothing about it.
@immutable
class SizeFit {
  const SizeFit({required this.size, this.keptRate});

  /// Normalised the way [normaliseSize] does, so it can be matched to a
  /// variant's own spelling.
  final String size;

  /// 0–1, or null below the server's sample floor.
  final double? keptRate;

  /// The rate as a whole percentage, for copy.
  int? get keptPercent => keptRate == null ? null : (keptRate! * 100).round();
}

/// One spelling per size: `" m "` and `"M"` are one size, and so are `2XL`
/// and `XXL`. Mirrors the server's `normaliseSize` in `kernel/size-fit.ts`;
/// the two must agree or a variant would never find its rate.
String? normaliseSize(Object? raw) {
  if (raw is! String && raw is! num) return null;
  final size = raw.toString().trim().toUpperCase().replaceAll(
    RegExp(r'\s+'),
    ' ',
  );
  if (size.isEmpty) return null;
  final multiX = RegExp(r'^([2-3])XL$').firstMatch(size);
  return multiX == null ? size : '${'X' * int.parse(multiX[1]!)}L';
}

/// The fit for [size] in [fits], if the server had anything to say about it.
SizeFit? fitForSize(List<SizeFit> fits, Object? size) {
  final wanted = normaliseSize(size);
  if (wanted == null) return null;
  for (final fit in fits) {
    if (fit.size == wanted && fit.keptRate != null) return fit;
  }
  return null;
}
