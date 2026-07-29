import 'dart:io';
import 'package:image/image.dart' as img;

// Converts all .webp files under assets/ to .png in tools/imgconv/out/
// preserving a flattened name, and prints their dimensions.
void main() async {
  final assetsDir = Directory('../../assets');
  final outDir = Directory('out');
  if (!outDir.existsSync()) outDir.createSync(recursive: true);

  final files = assetsDir
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.toLowerCase().endsWith('.webp'))
      .toList();

  for (final f in files) {
    final bytes = f.readAsBytesSync();
    final decoded = img.decodeWebP(bytes);
    if (decoded == null) {
      stderr.writeln('FAILED: ${f.path}');
      continue;
    }
    final base = f.uri.pathSegments.last.replaceAll('.webp', '.png');
    final outPath = '${outDir.path}/$base';
    File(outPath).writeAsBytesSync(img.encodePng(decoded));
    stdout.writeln('${base}\t${decoded.width}x${decoded.height}');
  }
  stdout.writeln('DONE');
}
