import 'dart:math' as math;
import 'dart:typed_data';

typedef SyncTextPart = ({String text, bool changed});
typedef SyncTextLine = ({int? number, List<SyncTextPart> parts});
typedef SyncTextExcerpt = ({List<SyncTextLine> lines, bool shortened});

List<SyncTextExcerpt> syncTextDifferences(List<String?> values) {
  final lines = [for (final value in values) value?.split('\n') ?? <String>[]];
  if (lines.every((items) => items.length <= 1)) {
    final present = values.nonNulls.toList();
    final start = _prefixLength(present);
    final end = _suffixLength(present, start);
    return [
      for (final value in values)
        if (value == null || value.isEmpty)
          (lines: const [], shortened: false)
        else
          _singleLine(value, start, end),
    ];
  }

  final changes = [for (final _ in lines) <int>{}];
  final reference = values.indexWhere((value) => value != null);
  for (var index = 0; index < lines.length; index++) {
    if (index != reference && values[index] != null) {
      _markChangedLines(
        lines[reference],
        lines[index],
        changes[reference],
        changes[index],
      );
    }
  }
  if (values.contains(null)) {
    for (var index = 0; index < lines.length; index++) {
      changes[index].addAll(Iterable<int>.generate(lines[index].length));
    }
  }
  return [
    for (var index = 0; index < lines.length; index++)
      _excerpt(lines[index], changes[index]),
  ];
}

int _prefixLength(List<String> strings) {
  if (strings.length < 2) return 0;
  final first = strings.first;
  final limit = strings.map((text) => text.length).reduce(math.min);
  var prefix = 0;
  while (prefix < limit &&
      strings
          .skip(1)
          .every(
            (text) => text.codeUnitAt(prefix) == first.codeUnitAt(prefix),
          )) {
    prefix++;
  }
  return prefix;
}

int _suffixLength(List<String> strings, int prefix) {
  if (strings.length < 2) return 0;
  final first = strings.first;
  final limit = strings.map((text) => text.length - prefix).reduce(math.min);
  var suffix = 0;
  while (suffix < limit &&
      strings
          .skip(1)
          .every(
            (text) =>
                text.codeUnitAt(text.length - suffix - 1) ==
                first.codeUnitAt(first.length - suffix - 1),
          )) {
    suffix++;
  }
  return suffix;
}

SyncTextExcerpt _singleLine(String text, int prefix, int suffix) {
  const context = 54;
  const limit = 1100;
  final changedEnd = text.length - suffix;
  final left = _clip(text.substring(math.max(0, prefix - context), prefix));
  final changed = _clip(text.substring(prefix, changedEnd), limit: limit);
  final right = text.substring(
    changedEnd,
    math.min(text.length, changedEnd + context),
  );
  return (
    shortened:
        prefix > context || suffix > context || changedEnd - prefix > limit,
    lines: [
      (
        number: null,
        parts: [
          (text: prefix > context ? '…$left' : left, changed: false),
          (text: changed, changed: true),
          (text: suffix > context ? '$right…' : right, changed: false),
        ],
      ),
    ],
  );
}

String _clip(String text, {int limit = 500}) =>
    text.length > limit ? '${text.substring(0, limit)}…' : text;

SyncTextExcerpt _excerpt(List<String> lines, Set<int> changes) {
  const limit = 56;
  final visible = <int>{};
  for (final line in changes) {
    if (line > 0) visible.add(line - 1);
    visible.add(line);
    if (line < lines.length - 1) visible.add(line + 1);
  }
  if (visible.isEmpty) {
    visible.addAll(Iterable.generate(math.min(3, lines.length)));
  }
  final indexes = visible.toList()..sort();
  final result = <SyncTextLine>[];
  int? previous;
  for (final index in indexes.take(limit)) {
    if (previous != null && previous + 1 != index) {
      result.add((number: null, parts: [(text: '…', changed: false)]));
    }
    result.add((
      number: index + 1,
      parts: [(text: _clip(lines[index]), changed: changes.contains(index))],
    ));
    previous = index;
  }
  return (
    lines: result,
    shortened:
        indexes.length > limit ||
        visible.length < lines.length ||
        indexes.take(limit).any((index) => lines[index].length > 500),
  );
}

void _markChangedLines(
  List<String> left,
  List<String> right,
  Set<int> leftChanges,
  Set<int> rightChanges,
) {
  var start = 0;
  var leftEnd = left.length;
  var rightEnd = right.length;
  while (start < leftEnd && start < rightEnd && left[start] == right[start]) {
    start++;
  }
  while (leftEnd > start &&
      rightEnd > start &&
      left[leftEnd - 1] == right[rightEnd - 1]) {
    leftEnd--;
    rightEnd--;
  }
  final height = leftEnd - start;
  final width = rightEnd - start;
  if (height == 0 || width == 0 || height * width > 200000) {
    leftChanges.addAll(
      Iterable<int>.generate(height, (index) => start + index),
    );
    rightChanges.addAll(
      Iterable<int>.generate(width, (index) => start + index),
    );
    return;
  }

  final stride = width + 1;
  final lengths = Uint16List((height + 1) * stride);
  for (var row = height - 1; row >= 0; row--) {
    for (var column = width - 1; column >= 0; column--) {
      final index = row * stride + column;
      lengths[index] = left[row + start] == right[column + start]
          ? lengths[index + stride + 1] + 1
          : math.max(lengths[index + 1], lengths[index + stride]);
    }
  }
  var row = 0;
  var column = 0;
  while (row < height && column < width) {
    final index = row * stride + column;
    if (left[row + start] == right[column + start]) {
      row++;
      column++;
    } else if (lengths[index + stride] >= lengths[index + 1]) {
      leftChanges.add(start + row++);
    } else {
      rightChanges.add(start + column++);
    }
  }
  while (row < height) {
    leftChanges.add(start + row++);
  }
  while (column < width) {
    rightChanges.add(start + column++);
  }
}
