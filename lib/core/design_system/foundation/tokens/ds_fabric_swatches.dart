import 'package:flutter/material.dart';

/// The colour a garment colour *word* stands for.
///
/// The stylist speaks in a closed vocabulary of colour keys (`olive`,
/// `burgundy`, `blush`…) and shows a look's palette as those words. A word is
/// slower to read than a dot of the colour itself, so this is the one place
/// the keys meet real swatches. They describe fabric, not the interface, which
/// is why they do not change with the theme.
abstract final class DsFabricSwatches {
  static const Map<String, Color> _byKey = {
    'black': Color(0xFF1C1A1D),
    'white': Color(0xFFFAF7F2),
    'beige': Color(0xFFD9C3A5),
    'navy': Color(0xFF1F2B4D),
    'blue': Color(0xFF3F6FB5),
    'blush': Color(0xFFF2B8C6),
    'red': Color(0xFFC62E3A),
    'burgundy': Color(0xFF6E1F31),
    'green': Color(0xFF2F7D57),
    'olive': Color(0xFF6B6B3A),
    'caramel': Color(0xFFB57A43),
    'brown': Color(0xFF6A4630),
    'grey': Color(0xFF8E8C91),
    'gold': Color(0xFFD4AF37),
    'silver': Color(0xFFC0C2C7),
    'purple': Color(0xFF6D3F8F),
    'yellow': Color(0xFFE9C53F),
    'orange': Color(0xFFE07A35),
  };

  /// Null for a key with no swatch — the caller shows the word alone.
  static Color? forKey(String key) => _byKey[key];
}
