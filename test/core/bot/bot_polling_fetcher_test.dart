import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/core/bot/bot_polling_fetcher.dart';
import 'package:teledart/model.dart';
import 'package:teledart/telegram.dart';
import 'package:teledart/util.dart';

void main() {
  test('stop waits for an in-flight getUpdates request', () async {
    final request = Completer<List<Update>>();
    final fetcher = BotPollingFetcher(
      Telegram('unused'),
      fetchUpdates: (_, _) => request.future,
    );
    await fetcher.start();
    var stopped = false;
    final stopping = fetcher.stop().then((_) => stopped = true);
    await Future<void>.delayed(Duration.zero);
    expect(stopped, isFalse);
    request.complete([]);
    await stopping;
    expect(stopped, isTrue);
  });

  test(
    'persistent 409 reports a competing instance after bounded retries',
    () async {
      var attempts = 0;
      final conflict = Completer<void>();
      final fetcher = BotPollingFetcher(
        Telegram('unused'),
        fetchUpdates: (_, _) {
          attempts++;
          return Future.error(HttpClientException(409, 'Conflict', null));
        },
        conflictRetries: 2,
        conflictRetryDelay: Duration.zero,
        onConflict: conflict.complete,
      );
      await fetcher.start();
      await conflict.future.timeout(const Duration(seconds: 1));
      await fetcher.stop();
      expect(attempts, 2);
    },
  );

  test('repeated polling failures are reported', () async {
    var attempts = 0;
    final failed = Completer<void>();
    final fetcher = BotPollingFetcher(
      Telegram('unused'),
      fetchUpdates: (_, _) {
        attempts++;
        return Future.error(const FormatException('invalid response'));
      },
      onFailure: failed.complete,
    );
    await fetcher.start();
    await failed.future.timeout(const Duration(seconds: 6));
    await fetcher.stop();
    expect(attempts, 3);
  });
}
