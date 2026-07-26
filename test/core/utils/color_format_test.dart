import 'package:flutter/painting.dart';
import 'package:life_os/core/utils/color_format.dart';
import 'package:test/test.dart';

void main() {
  group('parseHexColor', () {
    test('parses 6-digit hex without #', () {
      final color = parseHexColor('FF0000');
      expect(color, const Color(0xFFFF0000));
    });

    test('parses 6-digit hex with #', () {
      final color = parseHexColor('#00FF00');
      expect(color, const Color(0xFF00FF00));
    });

    test('parses 8-digit hex without alpha', () {
      final color = parseHexColor('336699');
      expect(color, const Color(0xFF336699));
    });
  });
}
