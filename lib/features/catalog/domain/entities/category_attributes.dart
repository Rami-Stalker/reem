import 'package:equatable/equatable.dart';

/// One extra field a category asks a product to carry — «الخامة»، «درجة اللون».
class CategoryAttribute extends Equatable {
  const CategoryAttribute({
    required this.key,
    required this.title,
    required this.isRequired,
    this.options = const [],
  });

  /// The name the value is stored under. Never shown.
  final String key;

  /// What the seller reads. Falls back to [key] when the schema names none.
  final String title;
  final bool isRequired;

  /// A closed set of values, when the schema declares one. Empty means free
  /// text.
  final List<String> options;

  @override
  List<Object?> get props => [key, title, isRequired, options];
}

/// The extra fields a category governs (Q27 P2).
///
/// This is the thing that made a correct-looking product form fail anyway: a
/// leaf inherits its schema from the nearest ancestor that declares one, the
/// endpoint refuses a draft missing any REQUIRED key, and the form neither
/// asked for those keys nor knew they existed. The server resolves the
/// inheritance; this only has to render what comes back.
class CategoryAttributeSchema extends Equatable {
  const CategoryAttributeSchema({this.attributes = const []});

  final List<CategoryAttribute> attributes;

  bool get isEmpty => attributes.isEmpty;

  Iterable<CategoryAttribute> get required =>
      attributes.where((attribute) => attribute.isRequired);

  /// Which required keys [values] has not answered — the same test the server
  /// applies, so the form can say so before she presses save.
  List<CategoryAttribute> missingFrom(Map<String, dynamic> values) => [
    for (final attribute in required)
      if ((values[attribute.key]?.toString() ?? '').trim().isEmpty) attribute,
  ];

  /// Parses the JSON-Schema subset the catalogue actually uses:
  /// `{required: [...], properties: {key: {title, enum}}}`.
  factory CategoryAttributeSchema.fromJson(dynamic json) {
    if (json is! Map) return const CategoryAttributeSchema();
    final schema = json.cast<String, dynamic>();

    final properties = schema['properties'];
    if (properties is! Map) return const CategoryAttributeSchema();

    final required = {
      for (final key in (schema['required'] as List? ?? const []))
        if (key is String) key,
    };

    return CategoryAttributeSchema(
      attributes: [
        for (final entry in properties.entries)
          if (entry.key is String && entry.value is Map)
            CategoryAttribute(
              key: entry.key as String,
              title:
                  (entry.value as Map)['title'] as String? ??
                  entry.key as String,
              isRequired: required.contains(entry.key),
              options: [
                for (final option
                    in ((entry.value as Map)['enum'] as List? ?? const []))
                  option.toString(),
              ],
            ),
      ],
    );
  }

  @override
  List<Object?> get props => [attributes];
}
