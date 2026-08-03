import 'dart:ui';

Color parseHexColor(String hex) {
  final buffer = StringBuffer();
  if (hex.length == 6 || hex.length == 7) buffer.write('ff');
  buffer.write(hex.replaceFirst('#', ''));
  return Color(int.parse(buffer.toString(), radix: 16));
}

extension ColorToHexExtension on Color {
  String toHex({bool includeAlpha = false}) {
    final int val = toARGB32();
    if (includeAlpha) {
      return '#${val.toRadixString(16).padLeft(8, '0').toUpperCase()}';
    }
    return '#${(val & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';
  }
}

// Использование:
// String hex = Colors.blue.toHex(); // '#2196F3'
