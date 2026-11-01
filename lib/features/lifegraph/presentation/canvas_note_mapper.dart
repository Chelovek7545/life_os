import 'package:flutter/widgets.dart';
import 'package:notes_api/notes_api.dart';
import 'package:life_os/core/ui/graph/graph_view.dart' as gv;
import '../domain/canvas_note.dart';

extension CanvasNoteToView on CanvasNote {
  gv.GraphNote toView({String? text, bool readOnly = false}) => gv.GraphNote(
    id: id,
    index: index,
    text: text ?? document.text,
    source: document.source,
    isReadOnly: readOnly,
    position: Offset(x, y),
    size: Size(width, height),
  );
}

extension GraphNoteToRecord on gv.GraphNote {
  CanvasNote toRecord() => CanvasNote(
    document: NoteDocument(id: id, text: text, source: source),
    x: position.dx,
    y: position.dy,
    width: size.width,
    height: size.height,
    index: index,
  );
}
