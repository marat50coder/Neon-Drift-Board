import 'dart:io';
import 'dart:math' as math;
import 'package:image/image.dart' as img;

// Generates launcher icon assets from the source Icon.png:
//  - assets/app_icon/icon.png         : full-bleed square (legacy)
//  - assets/app_icon/foreground.png   : zoomed 1.5x so it fills the adaptive
//                                        safe-zone edge-to-edge (no empty edges)
void main() {
  final srcFile = File('../../assets/Neon_Drift_Board_additional_assets/Icon.png');
  final src = img.decodePng(srcFile.readAsBytesSync())!;
  final outDir = Directory('../../assets/app_icon');
  if (!outDir.existsSync()) outDir.createSync(recursive: true);

  // Full-bleed square icon (1024) for legacy launchers.
  final full = img.copyResize(src, width: 1024, height: 1024,
      interpolation: img.Interpolation.cubic);
  File('${outDir.path}/icon.png').writeAsBytesSync(img.encodePng(full));

  // Adaptive foreground: 1024 canvas, source scaled to ~1.5x and centre-cropped
  // so the visible content still reaches the edges after the launcher applies
  // its safe-zone shrink -> guarantees no empty borders.
  const canvas = 1024;
  const zoom = 1.5;
  final scaled = img.copyResize(src,
      width: (canvas * zoom).round(),
      height: (canvas * zoom).round(),
      interpolation: img.Interpolation.cubic);
  final fg = img.Image(width: canvas, height: canvas, numChannels: 4);
  final dx = ((scaled.width - canvas) / 2).round();
  final dy = ((scaled.height - canvas) / 2).round();
  for (var y = 0; y < canvas; y++) {
    for (var x = 0; x < canvas; x++) {
      final sx = math.min(scaled.width - 1, x + dx);
      final sy = math.min(scaled.height - 1, y + dy);
      fg.setPixel(x, y, scaled.getPixel(sx, sy));
    }
  }
  File('${outDir.path}/foreground.png').writeAsBytesSync(img.encodePng(fg));

  stdout.writeln('Icons generated in assets/app_icon/');
}
