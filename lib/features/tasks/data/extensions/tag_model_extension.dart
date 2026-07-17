import 'package:drift/drift.dart';
import 'package:life_os/core/database/database.dart';
import 'package:life_os/features/tasks/domain/tag_model.dart';

/// Extension для преобразования Drift TagModel -> domain Tag
extension TagDataToDomain on TagModel {
  Tag toDomain() {
    return Tag(id: id, name: name, colorHex: colorHex);
  }
}

/// Extension для преобразования domain Tag -> Drift TagsCompanion
extension TagToDrift on Tag {
  /// Используется для обновлений (включает id)
  TagsCompanion toDrift() {
    return TagsCompanion(
      id: Value(id),
      name: Value(name),
      colorHex: Value(colorHex),
    );
  }

  /// Используется для вставки — пропускает id, чтобы БД сгенерировала его
  TagsCompanion toInsertCompanion() {
    return TagsCompanion(name: Value(name), colorHex: Value(colorHex));
  }
}
