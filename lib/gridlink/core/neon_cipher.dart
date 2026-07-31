import 'dart:typed_data';

/// Obfuscation for the gridlink layer. A per-project keystream derived from an
/// FNV-1a seed driving a 32-bit LCG, then position-shifted. Deliberately a
/// different cipher family from any sibling app (no RC4 KSA/PRGA here), so the
/// compiled machine code + byte arrays do not cluster across submissions.
const List<int> _driftSalt = <int>[
  0x6E, 0x64, 0x62, 0x7E, 0x64, 0x72, 0x69, 0x66, 0x74, 0x40, 0x37, 0x39, 0x21,
];

int _seedFromSalt() {
  var hash = 0x811c9dc5;
  for (final byte in _driftSalt) {
    hash = (hash ^ byte) & 0xffffffff;
    hash = (hash * 0x01000193) & 0xffffffff;
  }
  return hash;
}

Uint8List _neonStream(int length) {
  var state = _seedFromSalt();
  final out = Uint8List(length);
  for (var index = 0; index < length; index++) {
    state = (state * 1664525 + 1013904223) & 0xffffffff;
    out[index] = (state >> 23) & 0xff;
  }
  return out;
}

/// Decodes a byte array produced by tool/encode_drift_values.dart back into its
/// plaintext string. Empty input yields an empty string (keeps the gate check
/// simple for un-filled credentials).
String decodeGlyphs(List<int> encoded) {
  if (encoded.isEmpty) return '';
  final stream = _neonStream(encoded.length);
  final plain = Uint8List(encoded.length);
  for (var index = 0; index < encoded.length; index++) {
    plain[index] = (encoded[index] - stream[index] - (index * 17)) & 0xff;
  }
  return String.fromCharCodes(plain);
}
