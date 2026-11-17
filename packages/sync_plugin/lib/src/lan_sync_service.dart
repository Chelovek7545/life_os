import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:math';
import 'package:basic_utils/basic_utils.dart';
import 'package:crypto/crypto.dart';
import 'package:plugin_runtime/plugin_runtime.dart';
import 'package:uuid/uuid.dart';
import 'local_sync_contracts.dart';
import 'sync_models.dart';

String localSyncDeviceName() {
  final host = Platform.localHostname.trim();
  final name = host.isEmpty || host == 'localhost'
      ? Platform.operatingSystem
      : host;
  return name.length > 80 ? name.substring(0, 80) : name;
}

Future<SyncTlsMaterial> generateSyncTlsIdentity(String deviceId) =>
    Isolate.run(() {
      final pair = CryptoUtils.generateRSAKeyPair(keySize: 2048);
      final private = pair.privateKey as RSAPrivateKey;
      final csr = X509Utils.generateRsaCsrPem(
        {'CN': deviceId},
        private,
        pair.publicKey as RSAPublicKey,
      );
      final cert = X509Utils.generateSelfSignedCertificate(
        private,
        csr,
        3650,
        cA: false,
        extKeyUsage: [ExtendedKeyUsage.SERVER_AUTH],
        notBefore: DateTime.now().toUtc().subtract(const Duration(minutes: 5)),
      );
      return SyncTlsMaterial(
        deviceId,
        cert,
        CryptoUtils.encodeRSAPrivateKeyToPem(private),
      );
    });

String _hash(String value) => sha256.convert(utf8.encode(value)).toString();
String _randomSecret() => base64UrlEncode(
  List<int>.generate(32, (_) => Random.secure().nextInt(256)),
);
String _fingerprint(String pem) => sha256
    .convert(
      base64Decode(
        pem
            .split('\n')
            .where((l) => !l.startsWith('-----'))
            .join()
            .replaceAll(RegExp(r'\s'), ''),
      ),
    )
    .toString();
bool _isLan(String host) {
  final ip = InternetAddress.tryParse(host);
  if (ip == null) return false;
  if (ip.isLoopback || ip.isLinkLocal) return true;
  final b = ip.rawAddress;
  return ip.type == InternetAddressType.IPv4
      ? b[0] == 10 ||
            (b[0] == 172 && b[1] >= 16 && b[1] <= 31) ||
            (b[0] == 192 && b[1] == 168)
      : (b[0] & 0xfe) == 0xfc;
}

Uri _endpoint(String text) {
  final u = Uri.parse(text);
  if (u.scheme != 'https' ||
      !_isLan(u.host) ||
      u.userInfo.isNotEmpty ||
      u.hasQuery ||
      u.hasFragment ||
      (u.path != '/' && u.path.isNotEmpty) ||
      u.port < 1 ||
      u.port > 65535) {
    throw const LocalSyncException(
      'Нужен HTTPS-адрес устройства в локальной сети.',
    );
  }
  return u.replace(path: '/');
}

String _pin(Object? value) {
  if (value is! String || !RegExp(r'^[0-9a-f]{64}$').hasMatch(value)) {
    throw const FormatException('Invalid certificate fingerprint.');
  }
  return value;
}

String _id(Object? value) {
  if (value is! String || value.isEmpty || value.length > 128) {
    throw const FormatException('Invalid device ID.');
  }
  return value;
}

class _Peer {
  _Peer(this.id, this.name, this.endpoint, this.pin, this.token);
  final String id, name, endpoint, pin, token;
  LocalSyncPeer get summary =>
      LocalSyncPeer(id: id, name: name, endpoint: endpoint, fingerprint: pin);
  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'endpoint': endpoint,
    'pin': pin,
    'token': token,
  };
  factory _Peer.fromJson(Map<String, dynamic> m) {
    final token = m['token'] as String;
    if (token.length < 40 || token.length > 128) {
      throw const FormatException('Invalid peer key.');
    }
    final name = m['name'] as String;
    if (name.isEmpty || name.length > 80) {
      throw const FormatException('Invalid peer name.');
    }
    return _Peer(
      _id(m['id']),
      name,
      _endpoint(m['endpoint'] as String).toString(),
      _pin(m['pin']),
      token,
    );
  }
}

class LanSyncService implements AppPlugin, LocalSyncControl {
  LanSyncService({
    required this.data,
    required this.secrets,
    this.deviceName = 'Устройство',
    this.options = const LanSyncOptions(),
  });
  final LocalSyncData data;
  final SyncSecretStore secrets;
  final String deviceName;
  final LanSyncOptions options;
  @override
  String get id => 'sync.local';
  @override
  Set<String> get dependencies => const {};
  bool _active = false, _busy = false, _enrolled = false;
  int _generation = 0;
  @override
  int get generation => _generation;
  SyncTlsMaterial? _material;
  Future<void>? _loading;
  Future<void>? _starting, _stopping;
  Map<String, _Peer> _peers = {};
  HttpServer? _server;
  StreamSubscription<HttpRequest>? _subscription;
  final _clients = <HttpClient>{};
  final _inflight = <Future<void>>{};
  StreamController<LocalSyncState> _states = StreamController.broadcast();
  LocalSyncState _state = LocalSyncState();
  String? _advertised, _invitation, _inviteHash, _error;
  DateTime? _inviteDeadline, _lastSync;
  _Peer? _pending;
  String? _approvalId;
  Completer<String>? _approval;
  int _conflictCount = 0, _pendingCount = 0;
  @override
  LocalSyncState get state => _state;
  @override
  Stream<LocalSyncState> get states => _states.stream;
  void _emit() {
    _state = LocalSyncState(
      listening: _server != null,
      busy: _busy,
      enrolled: _enrolled,
      endpoint: _advertised,
      deviceId: _material?.deviceId,
      invitation: _invitation,
      awaitingApproval: _pending == null
          ? null
          : LocalSyncPeer(
              id: _approvalId!,
              name: _pending!.name,
              endpoint: _pending!.endpoint,
              fingerprint: _pending!.pin,
            ),
      error: _error,
      lastSync: _lastSync,
      peers: _peers.values.map((p) => p.summary),
      conflictCount: _conflictCount,
      pendingCount: _pendingCount,
    );
    if (!_states.isClosed) _states.add(_state);
  }

  void _live(int generation) {
    if (!_active || generation != _generation) {
      throw const LocalSyncException('Синхронизация остановлена.');
    }
  }

  Future<void> _refresh() async {
    _enrolled = await data.existingIdentity() != null;
    if (_enrolled) {
      _conflictCount = (await data.conflicts()).length;
      _pendingCount = (await data.pendingRevisions()).length;
    }
    _emit();
  }

  Future<T> _accept<T>(Future<T> Function(int) action, {bool busy = true}) {
    final generation = _generation;
    _live(generation);
    if (busy && _busy) {
      throw const LocalSyncException('Дождитесь завершения текущего обмена.');
    }
    if (busy) _busy = true;
    _error = null;
    _emit();
    final f = Future<T>(() => action(generation));
    late Future<void> tracked;
    tracked = f
        .then<void>((_) {}, onError: (Object _, StackTrace _) {})
        .whenComplete(() => _inflight.remove(tracked));
    _inflight.add(tracked);
    return f
        .catchError((Object error, StackTrace stack) {
          if (_active && generation == _generation) {
            _error = error is LocalSyncException
                ? error.message
                : 'Обмен не завершён. Проверьте адрес, соединение и доверие устройства.';
          }
          Error.throwWithStackTrace(error, stack);
        })
        .whenComplete(() {
          if (generation == _generation) {
            if (busy) _busy = false;
            _emit();
          }
        });
  }

  @override
  Future<void> start() {
    if (_stopping != null) return _stopping!.then((_) => start());
    return _starting ??= _start().whenComplete(() => _starting = null);
  }

  Future<void> _start() async {
    if (_active) return;
    _generation++;
    _active = true;
    _busy = false;
    _error = null;
    if (_states.isClosed) _states = StreamController.broadcast();
    final generation = _generation;
    try {
      await _load(_generation);
    } catch (_) {
      if (!_active || generation != _generation) return;
      _error =
          'Не удалось открыть защищённое хранилище. Сетевой обмен отключён.';
    }
    if (!_active || generation != _generation) return;
    await _refresh();
  }

  Future<void> _load(int generation) async {
    if (_material != null) return;
    try {
      await (_loading ??= () async {
        final text = await secrets.read();
        _live(generation);
        final existing = await data.existingIdentity();
        _live(generation);
        if (text == null) {
          final id = existing?.deviceId ?? const Uuid().v4();
          _material =
              await (options.identityFactory ?? generateSyncTlsIdentity)(id);
          _live(generation);
          if (_material!.deviceId != id) {
            throw const FormatException('Wrong TLS identity.');
          }
          await _save({}, generation);
        } else {
          final m = jsonDecode(text) as Map<String, dynamic>;
          if (m['version'] != 1) {
            throw const FormatException('Unknown credential version.');
          }
          final id = _id(m['deviceId']);
          if (existing != null && existing.deviceId != id) {
            throw const LocalSyncException(
              'Ключ устройства не соответствует базе. Требуется повторная настройка.',
            );
          }
          _material = SyncTlsMaterial(
            id,
            m['certificate'] as String,
            m['key'] as String,
          );
          _peers = {
            for (final raw in m['peers'] as List)
              _id((raw as Map<String, dynamic>)['id']): _Peer.fromJson(raw),
          };
        }
        _emit();
      }());
    } catch (_) {
      _material = null;
      _loading = null;
      _peers = {};
      rethrow;
    }
  }

  Future<void> _save(Map<String, _Peer> peers, int generation) async {
    _live(generation);
    final m = _material!;
    await secrets.write(
      jsonEncode({
        'version': 1,
        'deviceId': m.deviceId,
        'certificate': m.certificatePem,
        'key': m.privateKeyPem,
        'peers': peers.values.map((p) => p.toJson()).toList(),
      }),
    );
    _live(generation);
    _peers = peers;
    _emit();
  }

  @override
  Future<List<String>> addresses() async => [
    for (final n in await NetworkInterface.list(type: InternetAddressType.IPv4))
      for (final a in n.addresses)
        if (_isLan(a.address)) a.address,
  ];
  @override
  Future<void> createSpace() => _accept((g) async {
    await _load(g);
    _live(g);
    final existing = await data.existingIdentity();
    _live(g);
    if (existing == null) {
      await data.enroll(
        const Uuid().v4(),
        _material!.deviceId,
        requireEmpty: false,
      );
    }
    await _refresh();
  });
  SecurityContext _context() {
    final context = SecurityContext(withTrustedRoots: false)
      ..minimumTlsProtocolVersion = TlsProtocolVersion.tls1_2
      ..useCertificateChainBytes(utf8.encode(_material!.certificatePem))
      ..usePrivateKeyBytes(utf8.encode(_material!.privateKeyPem));
    return context;
  }

  Future<void> _listen(String host, int generation) async {
    if (!_isLan(host)) {
      throw const LocalSyncException(
        'Выберите локальный IP-адрес этого устройства.',
      );
    }
    await _load(generation);
    _live(generation);
    if (_server == null) {
      final server = await HttpServer.bindSecure(
        options.bindAddress,
        options.port,
        _context(),
      );
      if (!_active || generation != _generation) {
        await server.close(force: true);
        _live(generation);
      }
      server.idleTimeout = options.timeout;
      _server = server;
      _subscription = server.listen(
        (request) {
          if (!_active || _inflight.length >= 8) {
            request.response.statusCode = 503;
            unawaited(request.response.close());
            return;
          }
          late Future<void> tracked;
          tracked = _handle(
            request,
            generation,
          ).whenComplete(() => _inflight.remove(tracked));
          _inflight.add(tracked);
        },
        onError: (Object _) {
          _error = 'Не удалось принять соединение.';
          _emit();
        },
      );
    }
    _advertised = Uri(
      scheme: 'https',
      host: host,
      port: _server!.port,
      path: '/',
    ).toString();
    _emit();
  }

  @override
  Future<void> listen(String host) => _accept((g) => _listen(host, g));
  Future<void> _closeListener() async {
    _inviteHash = null;
    _invitation = null;
    _inviteDeadline = null;
    if (_approval != null && !_approval!.isCompleted) {
      _approval!.completeError(
        const LocalSyncException('Приглашение закрыто.'),
      );
    }
    _pending = null;
    _approval = null;
    final server = _server;
    _server = null;
    _advertised = null;
    try {
      await _subscription?.cancel();
    } finally {
      _subscription = null;
      await server?.close(force: true);
    }
    _emit();
  }

  @override
  Future<void> closeListener() => _accept((_) => _closeListener(), busy: false);
  @override
  Future<void> invite(String host) => _accept((g) async {
    if (await data.existingIdentity() == null) {
      throw const LocalSyncException(
        'Сначала создайте пространство синхронизации.',
      );
    }
    _live(g);
    await _listen(host, g);
    if (_pending != null) {
      throw const LocalSyncException(
        'Сначала подтвердите или отклоните запрос устройства.',
      );
    }
    final identity = (await data.existingIdentity())!;
    final secret = _randomSecret();
    _inviteHash = _hash(secret);
    _inviteDeadline = DateTime.now().add(const Duration(minutes: 5));
    _invitation = base64UrlEncode(
      utf8.encode(
        jsonEncode({
          'protocol': 1,
          'endpoint': _advertised,
          'fingerprint': _fingerprint(_material!.certificatePem),
          'deviceId': identity.deviceId,
          'datasetId': identity.datasetId,
          'secret': secret,
          'expires': _inviteDeadline!.toUtc().toIso8601String(),
        }),
      ),
    );
    _emit();
  });
  @override
  Future<void> join(String invitation, String host) => _accept((g) async {
    if (invitation.length > 16384) {
      throw const FormatException('Invitation too large.');
    }
    final m =
        jsonDecode(
              utf8.decode(
                base64Url.decode(base64Url.normalize(invitation.trim())),
              ),
            )
            as Map<String, dynamic>;
    if (m['protocol'] != 1 ||
        !DateTime.parse(m['expires'] as String).isAfter(DateTime.now())) {
      throw const LocalSyncException(
        'Приглашение истекло или не поддерживается.',
      );
    }
    final uri = _endpoint(m['endpoint'] as String);
    final pin = _pin(m['fingerprint']);
    final remoteId = _id(m['deviceId']);
    final dataset = _id(m['datasetId']);
    final secret = m['secret'] as String;
    if (secret.length < 40 || secret.length > 128) {
      throw const FormatException('Invalid invitation.');
    }
    final existing = await data.existingIdentity();
    if (existing != null && existing.datasetId != dataset) {
      throw const LocalSyncException(
        'Устройство уже принадлежит другому пространству. Данные не изменены.',
      );
    }
    if (existing == null && !await data.canJoin()) {
      throw const LocalSyncException(
        'Для подключения нужна пустая база. Существующие данные не изменены.',
      );
    }
    _live(g);
    await _listen(host, g);
    if (remoteId == _material!.deviceId) {
      throw const LocalSyncException(
        'Нельзя подключить устройство к самому себе.',
      );
    }
    final response = await _post(
      uri,
      pin,
      '/v1/pair',
      {
        'protocol': 1,
        'secret': secret,
        'datasetId': dataset,
        'deviceId': _material!.deviceId,
        'name': deviceName,
        'endpoint': _advertised,
        'pin': _fingerprint(_material!.certificatePem),
      },
      g,
      timeout: options.pairingTimeout + const Duration(seconds: 5),
    );
    _live(g);
    if (response['deviceId'] != remoteId || response['datasetId'] != dataset) {
      throw const FormatException('Pairing identity mismatch.');
    }
    final peer = _Peer.fromJson({
      'id': remoteId,
      'name': response['name'],
      'endpoint': uri.toString(),
      'pin': pin,
      'token': response['token'],
    });
    // Save trust first. If enrollment fails, a retry cannot export a populated
    // independent database: every session still verifies the database identity.
    await _save({..._peers, peer.id: peer}, g);
    _live(g);
    await data.enroll(
      dataset,
      _material!.deviceId,
      requireEmpty: existing == null,
    );
    await _refresh();
  });
  @override
  Future<void> approve(String id) => _accept((g) async {
    final pending = _pending;
    final approval = _approval;
    if (pending == null ||
        _approvalId != id ||
        approval == null ||
        approval.isCompleted) {
      throw const LocalSyncException('Запрос уже закрыт.');
    }
    await _save({..._peers, pending.id: pending}, g);
    _live(g);
    if (!approval.isCompleted) approval.complete(pending.token);
  });
  @override
  Future<void> reject(String id) => _accept((_) async {
    if (_pending == null || _approvalId != id) {
      throw const LocalSyncException('Запрос уже закрыт.');
    }
    if (_approval != null && !_approval!.isCompleted) {
      _approval!.completeError(
        const LocalSyncException('Подключение отклонено.'),
      );
    }
  });
  @override
  Future<void> revoke(String id) => _accept((g) async {
    await _load(g);
    final peers = Map<String, _Peer>.of(_peers)..remove(id);
    await _save(peers, g);
  });
  void _trusted(_Peer peer, int generation) {
    _live(generation);
    if (_peers[peer.id]?.token != peer.token) {
      throw const LocalSyncException('Доступ устройства отозван.');
    }
  }

  @override
  Future<void> synchronize(String id) => _accept((g) async {
    await _load(g);
    final peer = _peers[id];
    if (peer == null) {
      throw const LocalSyncException('Устройство не подключено.');
    }
    final identity = await data.existingIdentity();
    if (identity == null || identity.deviceId != _material!.deviceId) {
      throw const LocalSyncException(
        'Сначала завершите подключение пространства.',
      );
    }
    final remote = _RemoteStore(this, peer, g, identity);
    await remote.hello();
    _trusted(peer, g);
    await SyncEngine().exchange(
      _GuardedStore(data.store, () => _trusted(peer, g)),
      remote,
    );
    _trusted(peer, g);
    _lastSync = DateTime.now();
    await _refresh();
  });
  @override
  Future<Map<String, List<SyncRevision>>> conflicts() => data.conflicts();
  @override
  Future<Map<String, String>> entityNames({bool liveOnly = false}) =>
      data.entityNames(liveOnly: liveOnly);
  @override
  Future<List<LocalSyncPending>> pending() => data.pendingRepairs();
  @override
  Future<void> repair(
    SyncRevision revision,
    String payload,
    Set<String> expected,
  ) => _accept((g) async {
    _live(g);
    await data.repair(revision, payload, expected);
    await _refresh();
  });
  @override
  Future<void> resolve(SyncRevision chosen, Set<String> expected) =>
      _accept((g) async {
        _live(g);
        await data.resolve(chosen, expected);
        await _refresh();
      });

  Future<Map<String, dynamic>> _read(Stream<List<int>> stream) async {
    final bytes = <int>[];
    await for (final chunk in stream.timeout(options.timeout)) {
      if (bytes.length + chunk.length > 6 * 1024 * 1024) {
        throw const FormatException('Message too large.');
      }
      bytes.addAll(chunk);
    }
    return jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> _post(
    Uri uri,
    String pin,
    String path,
    Map<String, Object?> body,
    int generation, {
    String? token,
    String? deviceId,
    Duration? timeout,
  }) async {
    _live(generation);
    final client = HttpClient(context: SecurityContext(withTrustedRoots: false))
      ..connectionTimeout = options.timeout
      ..autoUncompress = false
      ..badCertificateCallback = (cert, _, _) =>
          sha256.convert(cert.der).toString() == pin;
    _clients.add(client);
    try {
      return await (() async {
        final request = await client.postUrl(uri.replace(path: path));
        _live(generation);
        request.followRedirects = false;
        request.headers.contentType = ContentType.json;
        if (token != null) {
          request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
          request.headers.set('X-Life-Device', deviceId!);
        }
        request.write(jsonEncode(body));
        final response = await request.close();
        if (response.statusCode != 200) {
          throw const LocalSyncException(
            'Устройство отклонило запрос. Проверьте приглашение и доступ.',
          );
        }
        final cert = response.certificate;
        if (cert == null || sha256.convert(cert.der).toString() != pin) {
          throw const LocalSyncException('Сертификат устройства изменился.');
        }
        return await _read(response);
      }()).timeout(timeout ?? options.timeout);
    } finally {
      _clients.remove(client);
      client.close(force: true);
    }
  }

  Future<void> _handle(HttpRequest request, int generation) async {
    try {
      _live(generation);
      if (request.method != 'POST' ||
          request.headers.contentType?.mimeType != 'application/json') {
        throw const FormatException('Invalid request.');
      }
      final body = await _read(request).timeout(options.timeout);
      _live(generation);
      if (body['protocol'] != 1) {
        throw const FormatException('Unsupported protocol.');
      }
      final identity = await data.existingIdentity();
      _live(generation);
      if (identity == null) {
        throw const LocalSyncException('Пространство не настроено.');
      }
      Map<String, Object?> result;
      if (request.uri.path == '/v1/pair') {
        if (_inviteHash == null ||
            _inviteDeadline == null ||
            !DateTime.now().isBefore(_inviteDeadline!) ||
            body['secret'] is! String ||
            _hash(body['secret'] as String) != _inviteHash ||
            body['datasetId'] != identity.datasetId ||
            _pending != null) {
          throw const LocalSyncException(
            'Приглашение истекло или уже использовано.',
          );
        }
        final peerId = _id(body['deviceId']);
        if (peerId == identity.deviceId || _peers.containsKey(peerId)) {
          throw const LocalSyncException('Это устройство уже подключено.');
        }
        final pending = _Peer.fromJson({
          'id': peerId,
          'name': body['name'],
          'endpoint': body['endpoint'],
          'pin': body['pin'],
          'token': _randomSecret(),
        });
        final approval = Completer<String>();
        _approvalId = const Uuid().v4();
        _pending = pending;
        _approval = approval;
        _inviteHash = null;
        _invitation = null;
        _emit();
        try {
          final token = await approval.future.timeout(options.pairingTimeout);
          _live(generation);
          result = {
            'deviceId': identity.deviceId,
            'datasetId': identity.datasetId,
            'name': deviceName,
            'token': token,
          };
        } finally {
          if (identical(_approval, approval)) {
            _pending = null;
            _approval = null;
            _emit();
          }
        }
      } else {
        final peer = _peers[request.headers.value('X-Life-Device')];
        final auth = request.headers.value(HttpHeaders.authorizationHeader);
        if (peer == null ||
            auth == null ||
            _hash(auth) != _hash('Bearer ${peer.token}')) {
          throw const LocalSyncException('Устройство не авторизовано.');
        }
        _trusted(peer, generation);
        if (body['datasetId'] != identity.datasetId) {
          throw const LocalSyncException(
            'Устройства принадлежат разным пространствам.',
          );
        }
        switch (request.uri.path) {
          case '/v1/hello':
            result = {
              'deviceId': identity.deviceId,
              'datasetId': identity.datasetId,
              'schema': 3,
            };
          case '/v1/cursor':
            if (body['deviceId'] != peer.id) {
              throw const FormatException('Wrong cursor owner.');
            }
            result = {'cursor': await data.store.receivedCursor(peer.id)};
          case '/v1/pull':
            result = _encodeBatch(
              await data.store.readFeed(
                after: body['after'] as int,
                limit: 100,
              ),
            );
          case '/v1/push':
            final batch = _decodeBatch(body['batch'] as Map<String, dynamic>);
            if (batch.source.deviceId != peer.id ||
                batch.source.datasetId != identity.datasetId) {
              throw const FormatException('Wrong batch source.');
            }
            _trusted(peer, generation);
            await data.store.receive(batch);
            _lastSync = DateTime.now();
            await _refresh();
            result = {'cursor': batch.cursor};
          default:
            throw const FormatException('Unknown request.');
        }
        _trusted(peer, generation);
      }
      request.response.headers.contentType = ContentType.json;
      request.response.write(jsonEncode(result));
      await request.response.close();
    } catch (_) {
      try {
        request.response.statusCode = 400;
        request.response.write('{"error":"request_rejected"}');
        await request.response.close();
      } catch (_) {}
    }
  }

  @override
  Future<void> stop() =>
      _stopping ??= _stop().whenComplete(() => _stopping = null);
  Future<void> _stop() async {
    if (!_active && _starting == null) return;
    _active = false;
    _generation++;
    _busy = false;
    for (final client in _clients.toList()) {
      client.close(force: true);
    }
    final failures = <String, Object>{};
    Future<void> close(String name, Future<void> Function() action) async {
      try {
        await action();
      } catch (error) {
        failures[name] = error;
      }
    }

    await close('listener', _closeListener);
    await close('startup', () async {
      await _starting;
    });
    await close('operations', () => Future.wait(_inflight.toList()));
    _material = null;
    _loading = null;
    _peers = {};
    _error = null;
    _emit();
    await close('states', _states.close);
    if (failures.isNotEmpty) throw PluginLifecycleException(failures);
  }
}

Map<String, Object?> _encodeBatch(SyncBatch b) => {
  'datasetId': b.source.datasetId,
  'deviceId': b.source.deviceId,
  'after': b.after,
  'entries': [
    for (final e in b.entries)
      {'sequence': e.sequence, 'revision': jsonDecode(e.revision.encode())},
  ],
};
SyncBatch _decodeBatch(Map<String, dynamic> m) {
  final entries = m['entries'] as List;
  if (entries.length > 100) throw const FormatException('Batch too large.');
  return SyncBatch(
    SyncIdentity(_id(m['datasetId']), _id(m['deviceId'])),
    m['after'] as int,
    entries.map((raw) {
      final e = raw as Map<String, dynamic>;
      return SyncEntry(
        e['sequence'] as int,
        SyncRevision.decode(jsonEncode(e['revision'])),
      );
    }),
  );
}

class _GuardedStore implements SyncStore {
  _GuardedStore(this.inner, this.check);
  final SyncStore inner;
  final void Function() check;
  @override
  Future<SyncIdentity> identity() {
    check();
    return inner.identity();
  }

  @override
  Future<SyncBatch> readFeed({int after = 0, int limit = 100}) {
    check();
    return inner.readFeed(after: after, limit: limit);
  }

  @override
  Future<int> receivedCursor(String deviceId) {
    check();
    return inner.receivedCursor(deviceId);
  }

  @override
  Future<void> receive(SyncBatch batch) {
    check();
    return inner.receive(batch);
  }
}

class _RemoteStore implements SyncStore {
  _RemoteStore(this.service, this.peer, this.generation, this.local);
  final LanSyncService service;
  final _Peer peer;
  final int generation;
  final SyncIdentity local;
  Future<Map<String, dynamic>> _call(String path, Map<String, Object?> body) {
    service._trusted(peer, generation);
    return service._post(
      _endpoint(peer.endpoint),
      peer.pin,
      path,
      {'protocol': 1, 'datasetId': local.datasetId, ...body},
      generation,
      token: peer.token,
      deviceId: local.deviceId,
    );
  }

  Future<void> hello() async {
    final result = await _call('/v1/hello', {});
    if (result['deviceId'] != peer.id ||
        result['datasetId'] != local.datasetId ||
        result['schema'] != 3) {
      throw const LocalSyncException(
        'Версии приложения или пространство не совпадают.',
      );
    }
  }

  @override
  Future<SyncIdentity> identity() async =>
      SyncIdentity(local.datasetId, peer.id);
  @override
  Future<SyncBatch> readFeed({int after = 0, int limit = 100}) async {
    final batch = _decodeBatch(await _call('/v1/pull', {'after': after}));
    if (batch.source.deviceId != peer.id ||
        batch.source.datasetId != local.datasetId ||
        batch.after != after) {
      throw const FormatException('Wrong feed identity.');
    }
    return batch;
  }

  @override
  Future<int> receivedCursor(String deviceId) async =>
      (await _call('/v1/cursor', {'deviceId': deviceId}))['cursor'] as int;
  @override
  Future<void> receive(SyncBatch batch) async {
    final result = await _call('/v1/push', {'batch': _encodeBatch(batch)});
    if (result['cursor'] != batch.cursor) {
      throw const FormatException('Wrong acknowledgement.');
    }
  }
}
