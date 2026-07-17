import 'package:life_os/features/tasks/domain/tag_model.dart';
import 'package:test/test.dart';

void main() {
  group('Tag', () {
    group('constructor', () {
      test('creates tag with all fields', () {
        final tag = Tag(id: 1, name: 'work', colorHex: 0xFF0000);

        expect(tag.id, 1);
        expect(tag.name, 'work');
        expect(tag.colorHex, 0xFF0000);
      });
    });

    group('copyWith', () {
      test('returns new tag with updated id', () {
        final tag = Tag(id: 1, name: 'work', colorHex: 0xFF0000);
        final updated = tag.copyWith(id: 2);

        expect(updated.id, 2);
        expect(updated.name, 'work');
        expect(updated.colorHex, 0xFF0000);
      });

      test('returns new tag with updated name', () {
        final tag = Tag(id: 1, name: 'work', colorHex: 0xFF0000);
        final updated = tag.copyWith(name: 'personal');

        expect(updated.id, 1);
        expect(updated.name, 'personal');
        expect(updated.colorHex, 0xFF0000);
      });

      test('returns new tag with updated colorHex', () {
        final tag = Tag(id: 1, name: 'work', colorHex: 0xFF0000);
        final updated = tag.copyWith(colorHex: 0x00FF00);

        expect(updated.id, 1);
        expect(updated.name, 'work');
        expect(updated.colorHex, 0x00FF00);
      });

      test('returns same values when no args provided', () {
        final tag = Tag(id: 1, name: 'work', colorHex: 0xFF0000);
        final updated = tag.copyWith();

        expect(updated.id, 1);
        expect(updated.name, 'work');
        expect(updated.colorHex, 0xFF0000);
      });
    });

    group('equality', () {
      test('equal tags are equal', () {
        final tag1 = Tag(id: 1, name: 'work', colorHex: 0xFF0000);
        final tag2 = Tag(id: 1, name: 'work', colorHex: 0xFF0000);

        expect(tag1, tag2);
        expect(tag1.hashCode, tag2.hashCode);
      });

      test('tags with different id are not equal', () {
        final tag1 = Tag(id: 1, name: 'work', colorHex: 0xFF0000);
        final tag2 = Tag(id: 2, name: 'work', colorHex: 0xFF0000);

        expect(tag1, isNot(tag2));
      });

      test('tags with different name are not equal', () {
        final tag1 = Tag(id: 1, name: 'work', colorHex: 0xFF0000);
        final tag2 = Tag(id: 1, name: 'personal', colorHex: 0xFF0000);

        expect(tag1, isNot(tag2));
      });

      test('tags with different colorHex are not equal', () {
        final tag1 = Tag(id: 1, name: 'work', colorHex: 0xFF0000);
        final tag2 = Tag(id: 1, name: 'work', colorHex: 0x00FF00);

        expect(tag1, isNot(tag2));
      });
    });

    group('toString', () {
      test('returns formatted string', () {
        final tag = Tag(id: 1, name: 'work', colorHex: 0xFF0000);
        expect(tag.toString(), 'Tag{id: 1, name: work, colorHex: 16711680}');
      });
    });
  });
}
