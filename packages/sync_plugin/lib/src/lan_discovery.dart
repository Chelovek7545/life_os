part of 'lan_sync_service.dart';

class _NearbyDevice {
  const _NearbyDevice(this.peer, this.dataset, this.expires);

  final LocalSyncPeer peer;
  final String dataset;
  final DateTime expires;

  bool sameDevice(_NearbyDevice other) =>
      peer.name == other.peer.name &&
      peer.endpoint == other.peer.endpoint &&
      peer.fingerprint == other.peer.fingerprint &&
      dataset == other.dataset;
}

class _LanDiscovery {
  _LanDiscovery(
    this.socket,
    this.options, {
    required this.advertisement,
    required this.onDevice,
    required this.expire,
  }) {
    socket.broadcastEnabled = true;
    socket.listen(_receive, onError: (Object _) {});
    _timer = Timer.periodic(const Duration(seconds: 2), (_) => probe());
  }

  final RawDatagramSocket socket;
  final LanSyncOptions options;
  final Map<String, Object?>? Function() advertisement;
  final void Function(_NearbyDevice) onDevice;
  final void Function() expire;
  late final Timer _timer;
  final _replies = <String, DateTime>{};
  String? _challenge;

  void probe() {
    expire();
    final now = DateTime.now();
    _replies.removeWhere((_, until) => !until.isAfter(now));
    _challenge = _randomNonce();
    final request = utf8.encode(
      jsonEncode({'pulseSync': 1, 'probe': _challenge}),
    );
    for (final target in options.discoveryTargets) {
      _send(request, InternetAddress(target), options.discoveryPort);
    }
  }

  void _send(List<int> data, InternetAddress address, int port) {
    try {
      socket.send(data, address, port);
    } on SocketException {
      // Another probe will run after the network interface changes.
    }
  }

  void _receive(RawSocketEvent event) {
    if (event != RawSocketEvent.read) return;
    while (true) {
      final packet = socket.receive();
      if (packet == null) return;
      if (packet.data.length > 1200 || !_isLan(packet.address.address)) {
        continue;
      }
      try {
        final message =
            jsonDecode(utf8.decode(packet.data)) as Map<String, dynamic>;
        if (message['pulseSync'] != 1) continue;
        if (message['probe'] case final String probe when _validNonce(probe)) {
          _reply(packet, probe);
        } else if (_challenge != null && message['answer'] == _challenge) {
          final port = message['port'] as int;
          final name = (message['name'] as String).trim();
          if (port < 1 || port > 65535 || name.isEmpty || name.length > 80) {
            continue;
          }
          onDevice(
            _NearbyDevice(
              LocalSyncPeer(
                id: _id(message['id']),
                name: name,
                endpoint: Uri(
                  scheme: 'https',
                  host: packet.address.address,
                  port: port,
                  path: '/',
                ).toString(),
                fingerprint: _pin(message['pin']),
              ),
              _id(message['dataset']),
              DateTime.now().add(const Duration(seconds: 7)),
            ),
          );
        }
      } on FormatException {
        // Ignore unrelated datagrams.
      } on TypeError {
        // Ignore invalid announcement fields.
      }
    }
  }

  void _reply(Datagram packet, String probe) {
    final info = advertisement();
    if (info == null) return;
    final host = packet.address.address;
    final now = DateTime.now();
    if ((_replies[host]?.isAfter(now) ?? false) || _replies.length >= 128) {
      return;
    }
    _replies[host] = now.add(const Duration(milliseconds: 750));
    _send(
      utf8.encode(jsonEncode({'pulseSync': 1, 'answer': probe, ...info})),
      packet.address,
      packet.port,
    );
  }

  void close() {
    _timer.cancel();
    socket.close();
  }
}

bool _validNonce(String value) =>
    RegExp(r'^[A-Za-z0-9_-]{43}$').hasMatch(value);

String _randomNonce() => _randomSecret().replaceAll('=', '');

String _comparisonCode(String hostPin, String guestPin, String nonce) {
  final digest = _hash('pulse-pair-v1:$hostPin:$guestPin:$nonce').toUpperCase();
  return [
    for (var index = 0; index < 16; index += 4)
      digest.substring(index, index + 4),
  ].join(' ');
}
