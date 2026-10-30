import 'package:flutter_test/flutter_test.dart';
import 'package:teledart/model.dart';
import 'package:teledart/teledart.dart';

void main() {
  test(
    'wildcard message stream receives bot commands and plain text',
    () async {
      final event = Event('pulse_bot');
      final received = <String>[];
      final subscription = event
          .onMessage(entityType: '*')
          .listen((message) => received.add(message.text!));
      event.emitUpdate(
        Update.fromJson({
          'update_id': 1,
          'message': {
            'message_id': 1,
            'date': 1,
            'chat': {'id': 42, 'type': 'private'},
            'text': '/start',
            'entities': [
              {'type': 'bot_command', 'offset': 0, 'length': 6},
            ],
          },
        }),
      );
      event.emitUpdate(
        Update.fromJson({
          'update_id': 2,
          'message': {
            'message_id': 2,
            'date': 1,
            'chat': {'id': 42, 'type': 'private'},
            'text': 'Купить книгу',
          },
        }),
      );
      await Future<void>.delayed(Duration.zero);
      expect(received, ['/start', 'Купить книгу']);
      await subscription.cancel();
    },
  );
}
