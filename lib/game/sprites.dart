import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

/// Describes a sprite sheet laid out as an even [cols] x [rows] grid.
class SheetSpec {
  final String key;
  final int cols;
  final int rows;
  const SheetSpec(this.key, this.cols, this.rows);

  int get count => cols * rows;

  Rect cell(int index, ui.Image image) {
    final i = index % count;
    final cw = image.width / cols;
    final ch = image.height / rows;
    final cx = (i % cols) * cw;
    final cy = (i ~/ cols) * ch;
    // Inset a couple of pixels so a sprite never picks up the neighbouring
    // cell's edge (sheets are not always perfectly padded).
    final insetX = (cw * 0.02).clamp(2.0, 8.0);
    final insetY = (ch * 0.02).clamp(2.0, 8.0);
    return Rect.fromLTWH(
      cx + insetX,
      cy + insetY,
      cw - insetX * 2,
      ch - insetY * 2,
    );
  }
}

/// Registry + loader of all bitmap assets, decoded once into [ui.Image].
class Sprites {
  Sprites._();
  static final Sprites I = Sprites._();

  static const String _gp = 'assets/Neon_Drift_Board_gameplay_assets/';
  static const String _add = 'assets/Neon_Drift_Board_additional_assets/';

  // Sprite sheets (even grids).
  static const boards = SheetSpec('boards', 10, 1);
  static const spheres = SheetSpec('spheres', 4, 2);
  static const crystals = SheetSpec('crystals', 6, 2);
  static const boostPads = SheetSpec('boost', 6, 4);
  static const gates = SheetSpec('gates', 7, 3);
  static const ramps = SheetSpec('ramps', 5, 2);
  static const turbo = SheetSpec('turbo', 6, 3);
  static const trails = SheetSpec('trails', 10, 2);
  static const police = SheetSpec('police', 6, 3);
  static const routes = SheetSpec('routes', 9, 4);
  static const decor = SheetSpec('decor', 8, 5);

  static const Map<String, String> _assets = {
    'boards': '${_gp}hoverboards_asset.webp',
    'spheres': '${_gp}energy_sphere_asset.webp',
    'crystals': '${_gp}collectible_crystal_asset.webp',
    'boost': '${_gp}Boost_Pads_asset.webp',
    'gates': '${_gp}Energy_Gates_asset.webp',
    'ramps': '${_gp}Jump_Ramps_asset.webp',
    'turbo': '${_gp}Turbo_Effects_asset.webp',
    'trails': '${_gp}trails_hoverboard_asset.webp',
    'police': '${_gp}Police_Alert_Effects_asset.webp',
    'routes': '${_gp}Route_Indicators_asset.webp',
    'decor': '${_gp}decorative_effects_asset.webp',
    'logo': '${_add}Game_Name.webp',
    'bg1': '${_gp}bg_location_1_asset.webp',
    'bg2': '${_gp}bg_location_2_asset.webp',
    'bg3': '${_gp}bg_location_3_asset.webp',
    'bg4': '${_gp}bg_location_4_asset.webp',
    'bg5': '${_gp}bg_location_5_asset.webp',
    'bg6': '${_gp}bg_location_6_asset.webp',
    'bg7': '${_gp}bg_location_7_asset.webp',
    'bg8': '${_gp}bg_location_8_asset.webp',
  };

  final Map<String, ui.Image> _cache = {};
  bool _loaded = false;
  bool get loaded => _loaded;

  ui.Image? img(String key) => _cache[key];

  String bgKey(int districtIndex) => 'bg${(districtIndex % 8) + 1}';

  Future<void> preload({void Function(double fraction)? onProgress}) async {
    if (_loaded) {
      onProgress?.call(1);
      return;
    }
    final entries = _assets.entries.toList();
    for (var i = 0; i < entries.length; i++) {
      final e = entries[i];
      try {
        final data = await rootBundle.load(e.value);
        final image = await _decode(data.buffer.asUint8List());
        _cache[e.key] = image;
      } catch (_) {
        // Missing asset should never hard-crash the loader.
      }
      onProgress?.call((i + 1) / entries.length);
    }
    _loaded = true;
  }

  Future<ui.Image> _decode(Uint8List bytes) async {
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    return frame.image;
  }
}

/// Paints a single cell of a sprite sheet, contained inside the widget box.
class SpriteView extends StatelessWidget {
  final SheetSpec sheet;
  final int index;
  final double? width;
  final double? height;
  final BoxFit fit;
  final double quarterTurns;

  const SpriteView({
    super.key,
    required this.sheet,
    required this.index,
    this.width,
    this.height,
    this.fit = BoxFit.contain,
    this.quarterTurns = 0,
  });

  @override
  Widget build(BuildContext context) {
    final image = Sprites.I.img(sheet.key);
    if (image == null) {
      return SizedBox(width: width, height: height);
    }
    // Resolve a concrete size so the sprite is always painted, even when the
    // widget is dropped into a Stack/Expanded without explicit dimensions.
    return LayoutBuilder(
      builder: (context, c) {
        var w = width ?? c.maxWidth;
        var h = height ?? c.maxHeight;
        if (!w.isFinite || w <= 0) w = (h.isFinite && h > 0) ? h : 48;
        if (!h.isFinite || h <= 0) h = (w.isFinite && w > 0) ? w : 48;
        return SizedBox(
          width: w,
          height: h,
          child: CustomPaint(
            painter: _CellPainter(
                image, sheet.cell(index, image), fit, quarterTurns),
          ),
        );
      },
    );
  }
}

class _CellPainter extends CustomPainter {
  final ui.Image image;
  final Rect src;
  final BoxFit fit;
  final double quarterTurns;
  _CellPainter(this.image, this.src, this.fit, this.quarterTurns);

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    canvas.save();
    canvas.translate(size.width / 2, size.height / 2);
    canvas.rotate(quarterTurns * 1.5707963267948966);
    final rotated = quarterTurns.round().isOdd;
    final box = rotated ? Size(size.height, size.width) : size;
    final fitted = applyBoxFit(fit, src.size, box);
    final dst = Rect.fromCenter(
      center: Offset.zero,
      width: fitted.destination.width,
      height: fitted.destination.height,
    );
    final paint = Paint()
      ..isAntiAlias = true
      ..filterQuality = FilterQuality.medium;
    canvas.drawImageRect(image, src, dst, paint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _CellPainter old) =>
      old.image != image || old.src != src || old.quarterTurns != quarterTurns;
}
