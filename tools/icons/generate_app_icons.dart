// Regenerates every launcher icon on every platform from one painted source.
//
//   flutter test tools/icons/generate_app_icons.dart
//
// There is no checked-in 1024px artwork that the densities were once exported
// from and have since drifted away from: the mark is *painted*, in the brand's
// own tokens, at whatever size each slot needs. Changing the icon means
// changing this file and running it again.
//
// What it writes:
//   android/app/src/main/res/mipmap-*/ic_launcher.png             legacy, pre-26
//   android/app/src/main/res/mipmap-*/ic_launcher_foreground.png  adaptive
//   android/app/src/main/res/mipmap-*/ic_launcher_background.png  adaptive
//   android/app/src/main/res/mipmap-*/ic_launcher_monochrome.png  themed, 13+
//   ios/Runner/Assets.xcassets/AppIcon.appiconset/*.png           every slot
//   web/icons/*.png, web/favicon.png
//   docs/brand/app-icon-1024.png, docs/brand/play-store-512.png
//
// iOS PNGs are written without an alpha channel. App Store validation rejects
// an icon that carries one, even when every pixel in it is opaque, so those
// slots go through a small RGB encoder rather than Flutter's RGBA `toByteData`.
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ohara/core/design_system/foundation/tokens/ds_colors.dart';

/// The wordmark is "Ohara"; a launcher icon has room for one letter of it.
/// Playfair's high-contrast serif is the display face of the design system,
/// and its `R` stays legible down to the 48px mdpi slot where a script or an
/// isolated Arabic glyph would silt up.
const String _glyph = 'R';

const Color _glyphColor = DsColors.primary50; // warm near-white, not pure
const Color _accentColor = DsColors.gold300; // champagne rule under the letter

/// Android's adaptive canvas is 108dp with only the middle 72dp guaranteed
/// visible — a launcher may mask it to a circle, a squircle or a teardrop.
const int _adaptiveDp = 108;

/// Density buckets, as a multiplier on the dp size.
const Map<String, double> _densities = {
  'mdpi': 1.0,
  'hdpi': 1.5,
  'xhdpi': 2.0,
  'xxhdpi': 3.0,
  'xxxhdpi': 4.0,
};

/// Where the `R` actually puts ink, as a fraction of its font size.
///
/// Measured rather than assumed. A font's line box is not its glyph: Playfair
/// reserves descent the `R` never touches and side bearings it never fills, so
/// centring by `TextPainter.size` leaves the letter visibly high and off to
/// one side. Measured once, at a probe size, and scaled to every slot.
late final Rect _ink;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await _loadFonts();
    _ink = await _measureInk();
  });

  test('regenerates every launcher icon', () async {
    // Android — legacy square, then the three adaptive layers.
    for (final entry in _densities.entries) {
      final dir = 'android/app/src/main/res/mipmap-${entry.key}';
      final legacy = (48 * entry.value).round();
      final adaptive = (_adaptiveDp * entry.value).round();

      await _writeRgba('$dir/ic_launcher.png', legacy, _paintFullIcon);
      await _writeRgba(
        '$dir/ic_launcher_background.png',
        adaptive,
        _paintBackground,
      );
      await _writeRgba(
        '$dir/ic_launcher_foreground.png',
        adaptive,
        _paintAdaptiveForeground,
      );
      await _writeRgba(
        '$dir/ic_launcher_monochrome.png',
        adaptive,
        _paintAdaptiveMonochrome,
      );
    }

    // iOS — one PNG per slot named in the asset catalogue, alpha stripped.
    const catalogue = 'ios/Runner/Assets.xcassets/AppIcon.appiconset';
    final manifest =
        jsonDecode(File('$catalogue/Contents.json').readAsStringSync())
            as Map<String, dynamic>;
    final slots = <String, int>{};
    for (final image in manifest['images'] as List<dynamic>) {
      final entry = image as Map<String, dynamic>;
      final filename = entry['filename'] as String?;
      if (filename == null) continue;
      final points = double.parse((entry['size'] as String).split('x').first);
      final scale = double.parse(
        (entry['scale'] as String).replaceAll('x', ''),
      );
      slots[filename] = (points * scale).round();
    }
    for (final slot in slots.entries) {
      await _writeRgb('$catalogue/${slot.key}', slot.value, _paintFullIcon);
    }

    // Web — the PWA slots plus the browser tab.
    await _writeRgba('web/icons/Icon-192.png', 192, _paintFullIcon);
    await _writeRgba('web/icons/Icon-512.png', 512, _paintFullIcon);
    await _writeRgba('web/icons/Icon-maskable-192.png', 192, _paintMaskable);
    await _writeRgba('web/icons/Icon-maskable-512.png', 512, _paintMaskable);
    await _writeRgba('web/favicon.png', 64, _paintFullIcon);

    // Store artwork. Apple wants 1024 without alpha; Google wants 512 with it.
    await _writeRgb('docs/brand/app-icon-1024.png', 1024, _paintFullIcon);
    await _writeRgba('docs/brand/play-store-512.png', 512, _paintFullIcon);

    // A sheet to look at, alongside the repository's other visual previews.
    // Untracked, like everything under build/.
    await _writePreviewSheet('build/visual/app_icon_preview.png');
  });
}

// ---------------------------------------------------------------------------
// Painting
// ---------------------------------------------------------------------------

/// The full square icon: brand ground with the mark sized for a legacy slot,
/// where nothing is masked away and the art may run to the edge.
void _paintFullIcon(Canvas canvas, double size) {
  _paintBackground(canvas, size);
  _paintMark(canvas, _centredBox(size, 0.56), _glyphColor, _accentColor);
}

/// A maskable web icon is cropped to its middle 80%, so the mark shrinks to
/// survive the crop — the same bargain Android's adaptive canvas drives.
void _paintMaskable(Canvas canvas, double size) {
  _paintBackground(canvas, size);
  _paintMark(canvas, _centredBox(size, 0.44), _glyphColor, _accentColor);
}

/// Adaptive foreground: the mark alone on transparency, kept inside the 72dp
/// circle every launcher shape is guaranteed to show.
void _paintAdaptiveForeground(Canvas canvas, double size) {
  _paintMark(canvas, _centredBox(size, 0.40), _glyphColor, _accentColor);
}

/// Themed icons (Android 13+): the launcher tints a silhouette with the user's
/// wallpaper palette, so the mark is drawn in flat white and the rule is
/// dropped — a two-tone mark would come back as one tone anyway.
void _paintAdaptiveMonochrome(Canvas canvas, double size) {
  _paintMark(canvas, _centredBox(size, 0.40), Colors.white, null);
}

/// Rose gradient, deepening through the brand ramp toward the bottom-right
/// where it picks up the mauve end of the palette, with a soft highlight in
/// the opposite corner so the ground reads as lit rather than flat.
void _paintBackground(Canvas canvas, double size) {
  final square = Rect.fromLTWH(0, 0, size, size);
  canvas.drawRect(
    square,
    Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          DsColors.primary300,
          DsColors.primary500,
          DsColors.primary700,
          DsColors.primary900,
        ],
        stops: [0.0, 0.38, 0.74, 1.0],
      ).createShader(square),
  );
  canvas.drawRect(
    square,
    Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.6, -0.7),
        radius: 1.05,
        colors: [
          Colors.white.withValues(alpha: 0.28),
          Colors.white.withValues(alpha: 0.0),
        ],
        stops: const [0.0, 0.7],
      ).createShader(square),
  );
}

/// The mark: one Playfair letter with a champagne rule beneath it, composed as
/// a group whose *ink* — not its line box — fills [box], so the letter lands in
/// the optical centre of every slot at every size.
void _paintMark(Canvas canvas, Rect box, Color glyph, Color? accent) {
  final ruleHeight = accent == null ? 0.0 : box.height * 0.070;
  final gap = accent == null ? 0.0 : box.height * 0.105;

  final letterHeight = box.height - gap - ruleHeight;
  final fontSize = letterHeight / _ink.height;
  final painter = _glyphPainter(fontSize, glyph);

  // `_ink` is in font-size units: scaling it gives where the ink will land
  // relative to the paint origin, which is what the origin must cancel out.
  final inkWidth = _ink.width * fontSize;
  final origin = Offset(
    box.center.dx - inkWidth / 2 - _ink.left * fontSize,
    box.top - _ink.top * fontSize,
  );
  painter.paint(canvas, origin);

  if (accent != null) {
    final ruleWidth = inkWidth * 0.86;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          box.center.dx - ruleWidth / 2,
          box.bottom - ruleHeight,
          ruleWidth,
          ruleHeight,
        ),
        Radius.circular(ruleHeight / 2),
      ),
      Paint()..color = accent,
    );
  }
}

TextPainter _glyphPainter(double fontSize, Color color) => TextPainter(
  text: TextSpan(
    text: _glyph,
    style: TextStyle(
      fontFamily: 'PlayfairDisplay',
      fontSize: fontSize,
      height: 1.0,
      fontWeight: FontWeight.w600,
      fontVariations: const [FontVariation('wght', 620)],
      color: color,
    ),
  ),
  textDirection: TextDirection.ltr,
)..layout();

/// Rasterises the glyph once and scans for the outermost opaque pixel on each
/// side, returning those bounds divided by the font size.
Future<Rect> _measureInk() async {
  const probe = 512.0;
  final painter = _glyphPainter(probe, Colors.white);
  final width = painter.width.ceil();
  final height = painter.height.ceil();

  final recorder = ui.PictureRecorder();
  painter.paint(Canvas(recorder), Offset.zero);
  final image = await recorder.endRecording().toImage(width, height);
  final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  final pixels = data!.buffer.asUint8List();
  image.dispose();

  var left = width, top = height, right = 0, bottom = 0;
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      if (pixels[(y * width + x) * 4 + 3] <= 8) continue; // ignore the fringe
      if (x < left) left = x;
      if (x > right) right = x;
      if (y < top) top = y;
      if (y > bottom) bottom = y;
    }
  }

  return Rect.fromLTRB(
    left / probe,
    top / probe,
    (right + 1) / probe,
    (bottom + 1) / probe,
  );
}

Rect _centredBox(double size, double fraction) => Rect.fromCenter(
  center: Offset(size / 2, size / 2),
  width: size * fraction,
  height: size * fraction,
);

// ---------------------------------------------------------------------------
// Preview sheet
// ---------------------------------------------------------------------------

/// A contact sheet: the mark at the sizes a phone actually draws it, and the
/// adaptive layers under the three masks a launcher actually applies. Neither
/// is visible in the flat PNGs — a 48px slot and a circular crop are where an
/// icon fails, so they are what there is to look at.
Future<void> _writePreviewSheet(String path) async {
  const width = 1180.0;
  const height = 760.0;
  const darkTop = 470.0;

  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);

  canvas.drawRect(
    const Rect.fromLTWH(0, 0, width, height),
    Paint()..color = const Color(0xFFF7F2F4),
  );
  canvas.drawRect(
    const Rect.fromLTWH(0, darkTop, width, height - darkTop),
    Paint()..color = const Color(0xFF17111A),
  );

  // The master, rounded the way iOS masks it.
  _sheetIcon(canvas, const Rect.fromLTWH(64, 78, 320, 320), _squircle);
  _sheetLabel(canvas, 'master · squircle', const Offset(64, 414), false);

  // Real sizes, sitting on a common baseline.
  var x = 470.0;
  for (final size in [192.0, 96.0, 72.0, 48.0]) {
    final box = Rect.fromLTWH(x, 398 - size, size, size);
    _sheetIcon(canvas, box, _squircle);
    _sheetLabel(canvas, '${size.toInt()}px', Offset(x, 414), false);
    x += size + 56;
  }

  // Adaptive, masked as each launcher family does it: the 108dp canvas cropped
  // to its guaranteed 72dp centre, then clipped to the shape.
  var maskX = 64.0;
  const masks = {
    'circle': _circle,
    'squircle': _squircle,
    'rounded square': _roundedSquare,
  };
  for (final mask in masks.entries) {
    final box = Rect.fromLTWH(maskX, darkTop + 52, 168, 168);
    // The layers are drawn into a 108-unit box centred on the mask, so the
    // outer 18 units on every side fall outside the clip — which is exactly
    // what a launcher throws away.
    final canvasBox = Rect.fromCenter(
      center: box.center,
      width: box.width * _adaptiveDp / 72,
      height: box.height * _adaptiveDp / 72,
    );
    canvas.save();
    canvas.clipPath(mask.value(box));
    canvas.translate(canvasBox.left, canvasBox.top);
    canvas.scale(canvasBox.width / _adaptiveDp);
    _paintBackground(canvas, _adaptiveDp.toDouble());
    _paintAdaptiveForeground(canvas, _adaptiveDp.toDouble());
    canvas.restore();

    _sheetLabel(canvas, mask.key, Offset(maskX, darkTop + 240), true);
    maskX += 224;
  }

  // The themed silhouette, as Android 13+ tints it.
  final themed = Rect.fromLTWH(maskX + 64, darkTop + 52, 168, 168);
  canvas.save();
  canvas.clipPath(_circle(themed));
  canvas.drawRect(themed, Paint()..color = const Color(0xFF4A3B57));
  final themedCanvas = Rect.fromCenter(
    center: themed.center,
    width: themed.width * _adaptiveDp / 72,
    height: themed.height * _adaptiveDp / 72,
  );
  canvas.translate(themedCanvas.left, themedCanvas.top);
  canvas.scale(themedCanvas.width / _adaptiveDp);
  _paintAdaptiveMonochrome(canvas, _adaptiveDp.toDouble());
  canvas.restore();
  _sheetLabel(canvas, 'themed (13+)', Offset(maskX + 64, darkTop + 240), true);

  final image = await recorder.endRecording().toImage(
    width.toInt(),
    height.toInt(),
  );
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  _write(path, data!.buffer.asUint8List());
  image.dispose();
}

/// Painted at the box's own pixel size, never at unit size under a scale: the
/// text engine lays a glyph out for the font size it is given, and a font size
/// below 1.0 scaled up afterwards comes back mispositioned and coarse.
void _sheetIcon(Canvas canvas, Rect box, Path Function(Rect) mask) {
  canvas.save();
  canvas.clipPath(mask(box));
  canvas.translate(box.left, box.top);
  _paintFullIcon(canvas, box.width);
  canvas.restore();
}

void _sheetLabel(Canvas canvas, String text, Offset at, bool onDark) {
  TextPainter(
    text: TextSpan(
      text: text,
      style: TextStyle(
        fontFamily: 'Cairo',
        fontSize: 19,
        color: onDark ? const Color(0xFF9C8FA6) : const Color(0xFF7A6A73),
      ),
    ),
    textDirection: TextDirection.ltr,
  )
    ..layout()
    ..paint(canvas, at);
}

Path _circle(Rect box) => Path()..addOval(box);

/// Close enough to the iOS/Pixel superellipse for a preview.
Path _squircle(Rect box) => Path()
  ..addRRect(
    RRect.fromRectAndRadius(box, Radius.circular(box.width * 0.225)),
  );

Path _roundedSquare(Rect box) => Path()
  ..addRRect(
    RRect.fromRectAndRadius(box, Radius.circular(box.width * 0.12)),
  );

// ---------------------------------------------------------------------------
// Rasterising and encoding
// ---------------------------------------------------------------------------

typedef _Painter = void Function(Canvas canvas, double size);

Future<ui.Image> _raster(int size, _Painter paint) async {
  final recorder = ui.PictureRecorder();
  paint(Canvas(recorder), size.toDouble());
  return recorder.endRecording().toImage(size, size);
}

Future<void> _writeRgba(String path, int size, _Painter paint) async {
  final image = await _raster(size, paint);
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  _write(path, data!.buffer.asUint8List());
  image.dispose();
}

Future<void> _writeRgb(String path, int size, _Painter paint) async {
  final image = await _raster(size, paint);
  final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  _write(path, _encodePngRgb(data!.buffer.asUint8List(), size, size));
  image.dispose();
}

void _write(String path, Uint8List bytes) {
  final file = File(path);
  file.parent.createSync(recursive: true);
  file.writeAsBytesSync(bytes);
}

/// Minimal truecolour (no alpha) PNG encoder.
///
/// Flutter only encodes RGBA, and App Store validation refuses an icon with an
/// alpha channel, so the iOS and marketing slots are re-encoded here: drop the
/// alpha byte, prepend the zero filter to each scanline, deflate, and wrap the
/// result in the three chunks a decoder needs.
Uint8List _encodePngRgb(Uint8List rgba, int width, int height) {
  final stride = width * 3;
  final raw = Uint8List(height * (1 + stride));
  var out = 0;

  for (var y = 0; y < height; y++) {
    // Filter type 0 — the scanline is stored as it is.
    //
    // PNG's predictors (Sub, Up, Paeth) usually earn their keep on a smooth
    // gradient. Not much here: Skia dithers its gradients, and dither noise is
    // exactly what a predictor cannot predict. Measured on the 1024px icon,
    // Paeth saves 4% and per-row predictor selection 5% — a few kilobytes on
    // an icon set, against an encoder twice this size. Left unfiltered.
    raw[out++] = 0;
    var src = y * width * 4;
    for (var x = 0; x < width; x++) {
      raw[out++] = rgba[src];
      raw[out++] = rgba[src + 1];
      raw[out++] = rgba[src + 2];
      src += 4;
    }
  }

  final header = BytesBuilder()
    ..add(_be32(width))
    ..add(_be32(height))
    ..add([8, 2, 0, 0, 0]); // 8-bit, truecolour, no interlace

  final png = BytesBuilder()
    ..add(const [137, 80, 78, 71, 13, 10, 26, 10])
    ..add(_chunk('IHDR', header.takeBytes()))
    ..add(
      _chunk('IDAT', Uint8List.fromList(ZLibCodec(level: 9).encode(raw))),
    )
    ..add(_chunk('IEND', Uint8List(0)));
  return png.takeBytes();
}

Uint8List _chunk(String type, Uint8List data) {
  final typed = Uint8List.fromList([...ascii.encode(type), ...data]);
  return Uint8List.fromList([
    ..._be32(data.length),
    ...typed,
    ..._be32(_crc32(typed)),
  ]);
}

List<int> _be32(int value) => [
  (value >> 24) & 0xFF,
  (value >> 16) & 0xFF,
  (value >> 8) & 0xFF,
  value & 0xFF,
];

final List<int> _crcTable = List<int>.generate(256, (n) {
  var c = n;
  for (var k = 0; k < 8; k++) {
    c = (c & 1) != 0 ? 0xEDB88320 ^ (c >> 1) : c >> 1;
  }
  return c;
});

int _crc32(Uint8List bytes) {
  var c = 0xFFFFFFFF;
  for (final byte in bytes) {
    c = _crcTable[(c ^ byte) & 0xFF] ^ (c >> 8);
  }
  return c ^ 0xFFFFFFFF;
}

// ---------------------------------------------------------------------------

Future<void> _loadFonts() async {
  const families = {
    'Cairo': 'assets/fonts/Cairo-VariableFont.ttf',
    'PlayfairDisplay': 'assets/fonts/PlayfairDisplay-VariableFont.ttf',
  };
  for (final entry in families.entries) {
    final loader = FontLoader(entry.key)
      ..addFont(
        File(entry.value).readAsBytes().then((b) => ByteData.view(b.buffer)),
      );
    await loader.load();
  }
}
