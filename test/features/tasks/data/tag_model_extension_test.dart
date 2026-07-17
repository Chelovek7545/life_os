import 'package:life_os/core/database/database.dart';
import 'package:life_os/features/tasks/data/extensions/tag_model_extension.dart';
import 'package:life_os/features/tasks/domain/tag_model.dart';
import 'package:test/test.dart';

void main() {
  group('TagDataToDomain', () {
    test('toDomain converts TagModel to Tag', () {
      final model = TagModel(id: 5, name: 'urgent', colorHex: 0xFF0000);

      final tag = model.toDomain();

      expect(tag.id, 5);
      expect(tag.name, 'urgent');
      expect(tag.colorHex, 0xFF0000);
    });
  });

  group('TagToDrift', () {
    test('toDrift converts Tag to TagsCompanion with id', () {
      final tag = Tag(id: 3, name: 'work', colorHex: 0x00FF00);

      final companion = tag.toDrift();

      expect(companion.id.value, 3);
      expect(companion.name.value, 'work');
      expect(companion.colorHex.value, 0x00FF00);
    });

    test('toInsertCompanion creates companion without id', () {
      final tag = Tag(id: 99, name: 'new', colorHex: 0x0000FF);

      final companion = tag.toInsertCompanion();

      expect(companion.id, isTrue);
      expect(companion.name.value, 'new');
      expect(companion.colorHex.value, 0x0000FF);
    });
  });
}
