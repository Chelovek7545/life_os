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
import 'sync_payload.dart';

part 'lan_discovery.dart';

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

String _requireLocalIp(String input) {
  final host = input.trim();
  if (host.isEmpty) throw LocalSyncException.missingLocalIp;
  if (!_isLan(host)) {
    throw const LocalSyncException(
      'Выберите локальный IP-адрес этого устройства.',
    );
  }
  return host;
}

Uri _endpoint(String text) {
  final u = Uri.parse(text);
  if (u.host.isEmpty && (text.trim().isEmpty || u.hasAuthority)) {
    throw const LocalSyncException(
      'Не указан IP второго устройства. Укажите его в Pulse и создайте новое приглашение.',
    );
  }
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
  _Peer(
    this.id,
    this.name,
    this.endpoint,
    this.pin,
    this.token, {
    this.invitationHash,
    this.verified = false,
  });
  final String id, name, endpoint, pin, token;
  final String? invitationHash;
  final bool verified;
  bool get confirmed => invitationHash == null;
  LocalSyncPeer get summary =>
      LocalSyncPeer(id: id, name: name, endpoint: endpoint, fingerprint: pin);
  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'endpoint': endpoint,
    'pin': pin,
    'token': token,
    if (invitationHash != null) 'invitationHash': invitationHash,
    if (verified) 'verified': true,
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
      invitationHash: m['invitationHash'] as String?,
      verified: m['verified'] == true,
    );
  }

  _Peer confirm([String? checkedName]) =>
      _Peer(id, checkedName ?? name, endpoint, pin, token, verified: true);
}

class _PeerNotAuthorized implements Exception {
  const _PeerNotAuthorized();
}

class _SyncInUse implements Exception {
  const _SyncInUse();
}

class LanSyncService implements AppPlugin, LocalSyncControl {
  LanSyncService({
    required this.data,
    required this.secrets,
    this.networkSettings,
    this.deviceName = 'Устройство',
    this.resolveDeviceName,
    this.options = const LanSyncOptions(),
    this.reconcileNotes,
    this.applyNotes,
    this.dependencies = const {},
  });
  final LocalSyncData data;
  final SyncSecretStore secrets;
  final SyncNetworkSettings? networkSettings;
  final String deviceName;
  final Future<String?> Function()? resolveDeviceName;
  String? _advertisedName;
  final LanSyncOptions options;
  final Future<bool> Function()? reconcileNotes;
  final Future<bool> Function()? applyNotes;
  @override
  String get id => 'sync.local';
  @override
  final Set<String> dependencies;
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
  String? _localAddress;
  DateTime? _inviteDeadline, _lastSync;
  LocalSyncRun? _run;
  ({String id, String peerId})? _incoming;
  Timer? _incomingTimeout;
  bool _notesNeedFolder = false;
  _Peer? _pending;
  _Peer? _approvedPeer;
  Timer? _confirmationTimer;
  bool _joining = false;
  String? _approvalId;
  Completer<String>? _approval;
  String? _datasetId, _pendingPairCode;
  LocalSyncPairReview? _pairReview;
  Completer<bool>? _pairDecision;
  _LanDiscovery? _discovery;
  int _discoveryRevision = 0;
  final _nearby = <String, _NearbyDevice>{};
  int _conflictCount = 0, _pendingCount = 0;
  @override
  LocalSyncState get state => _state;
  @override
  Stream<LocalSyncState> get states => _states.stream;
  void _emit() {
    _state = LocalSyncState(
      listening: _server != null,
      busy: _busy || _incoming != null,
      enrolled: _enrolled,
      endpoint: _advertised,
      localAddress: _localAddress,
      deviceId: _material?.deviceId,
      deviceName: _advertisedName ?? deviceName,
      invitation: _invitation,
      awaitingApproval: _pending == null || _approval?.isCompleted != false
          ? null
          : LocalSyncPeer(
              id: _approvalId!,
              name: _pending!.name,
              endpoint: _pending!.endpoint,
              fingerprint: _pending!.pin,
            ),
      error: _error,
      lastSync: _lastSync,
      run: _run,
      notesNeedFolder: _notesNeedFolder,
      joining: _joining,
      discovering: _discovery != null,
      nearby: _nearby.values.map((device) => device.peer),
      pairingCode: _pendingPairCode,
      pairReview: _pairReview,
      confirmingDevice: _peers[_approvedPeer?.id]?.confirmed == true
          ? null
          : _approvedPeer?.name,
      peers: _enrolled
          ? _peers.values.where((p) => p.verified).map((p) => p.summary)
          : const [],
      unverifiedPeers: _enrolled
          ? _peers.values
                .where((p) => p.confirmed && !p.verified)
                .map((p) => p.summary)
          : const [],
      conflictCount: _conflictCount,
      pendingCount: _pendingCount,
    );
    if (!_states.isClosed) _states.add(_state);
  }

  Future<String> _pairingName(int generation) async {
    final name = (await resolveDeviceName?.call())?.trim();
    _live(generation);
    final value = name == null || name.isEmpty ? deviceName.trim() : name;
    final end = value.length <= 80
        ? value.length
        : value.codeUnitAt(80) >= 0xDC00 && value.codeUnitAt(80) <= 0xDFFF
        ? 79
        : 80;
    return _advertisedName = end == 0 ? 'Устройство' : value.substring(0, end);
  }

  void _live(int generation) {
    if (!_active || generation != _generation) {
      throw const LocalSyncException('Синхронизация остановлена.');
    }
  }

  Future<void> _refresh() async {
    _datasetId = (await data.existingIdentity())?.datasetId;
    _enrolled = _datasetId != null;
    if (_enrolled) {
      _conflictCount = (await data.conflicts()).length;
      _pendingCount = (await data.pendingRevisions()).length;
    }
    _emit();
  }

  @override
  Future<void> setDiscoveryVisible(bool visible) async {
    final generation = _generation;
    _live(generation);
    _closeDiscovery();
    final revision = _discoveryRevision;
    if (!visible || _material == null) {
      _emit();
      return;
    }

    try {
      await _pairingName(generation);
      if (revision != _discoveryRevision) return;
      final socket = await RawDatagramSocket.bind(
        options.bindAddress,
        options.discoveryPort,
        reuseAddress: false,
      );
      if (!_active || revision != _discoveryRevision) {
        socket.close();
        return;
      }
      _discovery = _LanDiscovery(
        socket,
        options,
        advertisement: _advertisement,
        onDevice: _rememberNearby,
        expire: _expireNearby,
      )..probe();
    } on SocketException {
      // QR pairing remains available when this network blocks UDP discovery.
    }
    if (_active && revision == _discoveryRevision) _emit();
  }

  bool get _discoverable =>
      _discovery != null &&
      _server != null &&
      _datasetId != null &&
      _material != null &&
      !_busy &&
      _incoming == null &&
      _pending == null &&
      _approvedPeer == null;

  Map<String, Object?>? _advertisement() => !_discoverable
      ? null
      : {
          'id': _material!.deviceId,
          'name': _advertisedName ?? deviceName,
          'dataset': _datasetId,
          'port': _server!.port,
          'pin': _fingerprint(_material!.certificatePem),
        };

  void _rememberNearby(_NearbyDevice device) {
    final localId = _material?.deviceId;
    final id = device.peer.id;
    if (localId == null ||
        id == localId ||
        _nearby.length >= 64 && !_nearby.containsKey(id)) {
      return;
    }
    final old = _nearby[id];
    _nearby[id] = device;
    if (old == null || !old.sameDevice(device)) _emit();
  }

  void _expireNearby() {
    final count = _nearby.length;
    final now = DateTime.now();
    _nearby.removeWhere((_, device) => !device.expires.isAfter(now));
    if (count != _nearby.length) _emit();
  }

  void _closeDiscovery() {
    _discoveryRevision++;
    _discovery?.close();
    _discovery = null;
    _nearby.clear();
  }

  Future<T> _accept<T>(Future<T> Function(int) action, {bool busy = true}) {
    final generation = _generation;
    _live(generation);
    if (busy && (_busy || _incoming != null)) {
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
    _run = null;
    _notesNeedFolder = false;
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
    try {
      await _restoreNetwork(generation);
    } catch (_) {
      if (!_active || generation != _generation) return;
      _error ??= 'Не удалось восстановить приём по локальной сети.';
      _emit();
    }
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
  Future<List<String>> addresses() async {
    final provider = options.addressProvider;
    if (provider != null) return provider();
    final interfaces = await NetworkInterface.list(
      type: InternetAddressType.IPv4,
    );
    int rank(String name) {
      final label = name.toLowerCase();
      if (RegExp(
        r'vethernet|virtual|vmware|virtualbox|wsl|docker|vpn|tailscale|wireguard|hyper-v',
      ).hasMatch(label)) {
        return 2;
      }
      if (RegExp(r'wi-?fi|wlan|ethernet|^en|^eth|беспровод').hasMatch(label)) {
        return 0;
      }
      return 1;
    }

    final candidates =
        [
          for (final network in interfaces)
            for (final address in network.addresses)
              if (_isLan(address.address) && !address.isLoopback)
                (
                  address: address.address,
                  rank: address.isLinkLocal ? 3 : rank(network.name),
                ),
        ]..sort((a, b) {
          final priority = a.rank.compareTo(b.rank);
          return priority == 0 ? a.address.compareTo(b.address) : priority;
        });
    return {for (final item in candidates) item.address}.toList();
  }

  Future<void> _restoreNetwork(int generation) async {
    final preferred = await networkSettings?.read();
    final choices = (await addresses()).where(_isLan).toList();
    _live(generation);
    final peerNetworks = {
      for (final peer in _peers.values)
        Uri.parse(peer.endpoint).host.split('.').take(3).join('.'),
    };
    final automatic = choices
        .where(
          (host) => peerNetworks.contains(host.split('.').take(3).join('.')),
        )
        .firstOrNull;
    _localAddress = choices.contains(preferred?.address)
        ? preferred?.address
        : automatic ?? choices.firstOrNull;
    _emit();
    final address = _localAddress;
    if (preferred?.listening == true && _enrolled && _material != null) {
      if (address == null) {
        _error = LocalSyncException.missingLocalIp.message;
        _emit();
      } else {
        await _listen(address, generation);
      }
    }
  }

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
    _localAddress = host;
    _emit();
  }

  @override
  Future<void> listen(String host) => _accept((g) async {
    await _listen(_requireLocalIp(host), g);
    await _saveNetwork(listening: true);
  });

  Future<void> _saveNetwork({required bool listening}) async {
    await networkSettings?.write((
      address: _localAddress,
      listening: listening,
    ));
  }

  Future<void> _closeListener() async {
    if (_incoming != null) _endIncoming(LocalSyncPhase.failed);
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
    _clearApprovedPeer();
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

  void _clearApprovedPeer() {
    _confirmationTimer?.cancel();
    _confirmationTimer = null;
    _approvedPeer = null;
    _pendingPairCode = null;
  }

  Future<void> _completePair(_Peer peer) => _accept((generation) async {
    final saved = _peers[peer.id];
    if (saved != null && saved.confirmed && saved.token == peer.token) return;
    if (!identical(_approvedPeer, peer)) throw const _PeerNotAuthorized();
    _confirmationTimer?.cancel();
    try {
      await _save({..._peers, peer.id: peer.confirm()}, generation);
    } finally {
      _clearApprovedPeer();
    }
  });

  @override
  Future<void> closeListener() => _accept((_) async {
    try {
      await _saveNetwork(listening: false);
    } finally {
      await _closeListener();
    }
  });
  @override
  Future<void> invite(String host) => _accept((g) async {
    final localIp = _requireLocalIp(host);
    if (await data.existingIdentity() == null) {
      throw const LocalSyncException(
        'Сначала создайте пространство синхронизации.',
      );
    }
    _live(g);
    await _listen(localIp, g);
    await _saveNetwork(listening: true);
    if (_pending != null || _approvedPeer != null) {
      throw const LocalSyncException(
        'Сначала подтвердите или отклоните запрос устройства.',
      );
    }
    await _pairingName(g);
    final identity = (await data.existingIdentity())!;
    final secret = _randomSecret();
    _inviteHash = _hash(secret);
    _inviteDeadline = DateTime.now().add(const Duration(minutes: 5));
    _invitation = base64UrlEncode(
      utf8.encode(
        jsonEncode({
          'protocol': 1,
          'confirmPairing': true,
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
  Future<void> join(String invitation, String host) =>
      _withJoining((g) => _join(invitation, host, g));

  @override
  Future<void> joinNearby(String peerId, String host) => _withJoining((
    g,
  ) async {
    if (_peers[peerId]?.confirmed == true) {
      throw const LocalSyncException('Это устройство уже подключено.');
    }
    final device = _nearby[peerId];
    if (device == null || !device.expires.isAfter(DateTime.now())) {
      throw const LocalSyncException(
        'Устройство исчезло с радара. Откройте на нём окно синхронизации или используйте QR.',
      );
    }
    await _pairWith(
      uri: _endpoint(device.peer.endpoint),
      pin: device.peer.fingerprint,
      remoteId: device.peer.id,
      dataset: device.dataset,
      localIp: _requireLocalIp(host),
      generation: g,
      nearby: device.peer,
    );
  });

  Future<void> _withJoining(Future<void> Function(int) action) =>
      _accept((g) async {
        _joining = true;
        _emit();
        try {
          await action(g);
        } finally {
          _joining = false;
          _pairReview = null;
          _pairDecision = null;
        }
      });

  Future<void> _join(String invitation, String host, int g) async {
    final localIp = _requireLocalIp(host);
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
    final uri = _endpoint(m['endpoint'] as String? ?? '');
    final pin = _pin(m['fingerprint']);
    final remoteId = _id(m['deviceId']);
    final dataset = _id(m['datasetId']);
    final secret = m['secret'] as String;
    if (secret.length < 40 || secret.length > 128) {
      throw const FormatException('Invalid invitation.');
    }
    if (m['confirmPairing'] != true) {
      throw const LocalSyncException(
        'Обновите Pulse на обоих устройствах для сопряжения.',
      );
    }
    await _pairWith(
      uri: uri,
      pin: pin,
      remoteId: remoteId,
      dataset: dataset,
      localIp: localIp,
      generation: g,
      secret: secret,
    );
  }

  Future<void> _pairWith({
    required Uri uri,
    required String pin,
    required String remoteId,
    required String dataset,
    required String localIp,
    required int generation,
    String? secret,
    LocalSyncPeer? nearby,
  }) async {
    final g = generation;
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
    await _listen(localIp, g);
    if (remoteId == _material!.deviceId) {
      throw const LocalSyncException(
        'Нельзя подключить устройство к самому себе.',
      );
    }
    final nonce = nearby == null ? null : _randomNonce();
    final localPin = _fingerprint(_material!.certificatePem);
    final invitationHash = _hash(secret ?? nonce!);
    if (nearby != null) {
      _pairReview = (
        peer: nearby,
        code: _comparisonCode(pin, localPin, nonce!),
        canConfirm: false,
      );
      _emit();
    }
    var peer = _peers[remoteId];
    if (peer == null ||
        peer.invitationHash != invitationHash ||
        peer.endpoint != uri.toString() ||
        peer.pin != pin) {
      final response = await _post(
        uri,
        pin,
        '/v1/pair',
        {
          'protocol': 1,
          'confirmPairing': true,
          'secret': ?secret,
          'nearbyNonce': ?nonce,
          'datasetId': dataset,
          'deviceId': _material!.deviceId,
          'name': await _pairingName(g),
          'endpoint': _advertised,
          'pin': localPin,
        },
        g,
        timeout: options.pairingTimeout + const Duration(seconds: 5),
      );
      _live(g);
      if (response['deviceId'] != remoteId ||
          response['datasetId'] != dataset) {
        throw const FormatException('Pairing identity mismatch.');
      }
      if (response['confirmPairing'] != true) {
        throw const LocalSyncException(
          'Обновите Pulse на обоих устройствах для сопряжения.',
        );
      }
      peer = _Peer.fromJson({
        'id': remoteId,
        'name': response['name'],
        'endpoint': uri.toString(),
        'pin': pin,
        'token': response['token'],
        'invitationHash': invitationHash,
      });
      if (nearby != null) await _waitForPairDecision(peer, dataset, g);
      await data.enroll(
        dataset,
        _material!.deviceId,
        requireEmpty: existing == null,
      );
      _live(g);
      _enrolled = true;
      await _save({..._peers, peer.id: peer}, g);
    }
    try {
      final confirmation = await _post(
        uri,
        pin,
        '/v1/pair/confirm',
        {'protocol': 1, 'datasetId': dataset},
        g,
        token: peer.token,
        deviceId: _material!.deviceId,
      );
      if (confirmation['confirmed'] != true) {
        throw const FormatException('Pairing confirmation is missing.');
      }
    } on _PeerNotAuthorized {
      await _save(Map.of(_peers)..remove(peer.id), g);
      throw const LocalSyncException(
        'Подтверждение истекло. Создайте новое приглашение.',
      );
    }
    await _save({..._peers, peer.id: peer.confirm()}, g);
    await _saveNetwork(listening: true);
    await _refresh();
  }

  Future<void> _waitForPairDecision(_Peer peer, String dataset, int g) async {
    final decision = _pairDecision = Completer<bool>();
    final review = _pairReview!;
    _pairReview = (peer: review.peer, code: review.code, canConfirm: true);
    _emit();
    final accepted = await decision.future.timeout(
      options.pairingTimeout,
      onTimeout: () => false,
    );
    _live(g);
    if (accepted) return;
    try {
      await _post(
        _endpoint(peer.endpoint),
        peer.pin,
        '/v1/pair/cancel',
        {'protocol': 1, 'datasetId': dataset},
        g,
        token: peer.token,
        deviceId: _material!.deviceId,
        timeout: const Duration(seconds: 2),
      );
    } catch (_) {
      // The receiver also expires an approved pairing that never completes.
    }
    throw const LocalSyncException('Сопряжение отменено.');
  }

  @override
  Future<void> confirmNearby(bool accepted) async {
    _live(_generation);
    final decision = _pairDecision;
    final review = _pairReview;
    if (review == null || decision == null || decision.isCompleted) {
      throw const LocalSyncException('Запрос уже закрыт.');
    }
    _pairReview = (peer: review.peer, code: review.code, canConfirm: false);
    decision.complete(accepted);
    _emit();
  }

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
    _live(g);
    _approvedPeer = pending;
    _confirmationTimer = Timer(options.pairingTimeout, () {
      if (!identical(_approvedPeer, pending)) return;
      _clearApprovedPeer();
      _error =
          'Второе устройство не завершило подключение. Создайте новое приглашение.';
      _emit();
    });
    approval.complete(pending.token);
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
    final saved = _peers[peer.id];
    if (saved == null || !saved.confirmed || saved.token != peer.token) {
      throw const LocalSyncException('Доступ устройства отозван.');
    }
  }

  @override
  Future<void> verifyPair(String id) => _accept((g) async {
    await _load(g);
    final peer = _peers[id];
    if (peer == null || !peer.confirmed) {
      throw const LocalSyncException('Устройство не подключено.');
    }
    if (peer.verified) return;
    final identity = await _syncIdentity();
    String? name;
    try {
      name = await _RemoteStore(this, peer, g, identity).hello();
    } on _PeerNotAuthorized {
      await _removeUntrustedPeer(id, g);
    }
    _trusted(peer, g);
    await _save({..._peers, id: peer.confirm(name)}, g);
  });

  Future<SyncIdentity> _syncIdentity() async {
    final identity = await data.existingIdentity();
    if (identity == null || identity.deviceId != _material!.deviceId) {
      throw const LocalSyncException(
        'Сначала завершите подключение пространства.',
      );
    }
    return identity;
  }

  Future<Never> _removeUntrustedPeer(String id, int generation) async {
    await _save(Map.of(_peers)..remove(id), generation);
    throw const LocalSyncException(
      'Второе устройство не подтвердило доступ. Выполните сопряжение заново.',
    );
  }

  @override
  Future<void> synchronize(String id) => _accept((g) async {
    await _load(g);
    final peer = _peers[id];
    if (peer == null || !peer.verified) {
      throw const LocalSyncException('Устройство не подключено.');
    }
    final identity = await _syncIdentity();
    final remote = _RemoteStore(
      this,
      peer,
      g,
      identity,
      runId: const Uuid().v4(),
    );
    void update(LocalSyncPhase phase, [SyncTransferProgress? transfer]) {
      if (!_active || g != _generation) return;
      _run = LocalSyncRun(id, phase, transfer ?? _run?.transfer);
      _emit();
    }

    _run = LocalSyncRun(id, LocalSyncPhase.connecting);
    _notesNeedFolder = false;
    _emit();
    try {
      await remote.hello();
      _trusted(peer, g);
      await reconcileNotes?.call();
      _trusted(peer, g);
      await SyncEngine().exchange(
        _GuardedStore(data.store, () => _trusted(peer, g)),
        remote,
        onProgress: (progress) async {
          update(LocalSyncPhase.transferring, progress);
          await remote.progress(progress);
        },
      );
      _trusted(peer, g);
      update(LocalSyncPhase.applying);
      await remote.applying();
      final localNotesReady =
          await (applyNotes ?? reconcileNotes)?.call() ?? true;
      final remoteNotesReady = await remote.finish(localNotesReady);
      _trusted(peer, g);
      _notesNeedFolder = !localNotesReady || !remoteNotesReady;
      _lastSync = DateTime.now();
      await _refresh();
      update(LocalSyncPhase.complete);
    } on _PeerNotAuthorized {
      update(LocalSyncPhase.failed);
      await _removeUntrustedPeer(id, g);
    } catch (_) {
      update(LocalSyncPhase.failed);
      await remote.abort();
      rethrow;
    }
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
  Future<void> resolve(
    SyncRevision chosen,
    Set<String> expected, {
    String? mergedPayload,
  }) => _accept((g) async {
    _live(g);
    if (SyncPayload.externalEntities.contains(chosen.entityType)) {
      await reconcileNotes?.call();
      _live(g);
    }
    await data.resolve(chosen, expected, mergedPayload: mergedPayload);
    if (SyncPayload.externalEntities.contains(chosen.entityType)) {
      _live(g);
      await (applyNotes ?? reconcileNotes)?.call();
    }
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
        final cert = response.certificate;
        if (cert == null || sha256.convert(cert.der).toString() != pin) {
          throw const LocalSyncException('Сертификат устройства изменился.');
        }
        if (response.statusCode == 403 && token != null) {
          throw const _PeerNotAuthorized();
        }
        if (response.statusCode == 423) {
          throw const LocalSyncException(
            'На втором устройстве уже идёт обмен.',
          );
        }
        if (response.statusCode == 409 &&
            (path == '/v1/plan' || path == '/v1/finish')) {
          throw const LocalSyncException(
            'Не удалось прочитать или сохранить заметки или Canvas на втором устройстве.',
          );
        }
        if (response.statusCode != 200) {
          throw const LocalSyncException(
            'Устройство отклонило запрос. Проверьте приглашение и доступ.',
          );
        }
        return await _read(response);
      }()).timeout(timeout ?? options.timeout);
    } on SocketException {
      throw const LocalSyncException(
        'Устройство недоступно. Проверьте IP второго устройства, общую сеть '
        'и включён ли приём в Pulse.',
      );
    } on TimeoutException {
      throw const LocalSyncException(
        'Устройство не ответило вовремя. Проверьте его IP и подключение к сети.',
      );
    } finally {
      _clients.remove(client);
      client.close(force: true);
    }
  }

  Future<void> _beginIncoming(_Peer peer, String id, int generation) async {
    if (_busy || _incoming != null) throw const _SyncInUse();
    _incoming = (id: id, peerId: peer.id);
    _run = LocalSyncRun(peer.id, LocalSyncPhase.connecting);
    _error = null;
    _notesNeedFolder = false;
    _touchIncoming();
    try {
      if (!peer.verified) {
        await _save({..._peers, peer.id: peer.confirm()}, generation);
      }
    } catch (_) {
      if (_incoming == (id: id, peerId: peer.id)) {
        _endIncoming(LocalSyncPhase.failed);
      }
      rethrow;
    }
    _emit();
  }

  void _touchIncoming() {
    _incomingTimeout?.cancel();
    _incomingTimeout = Timer(options.timeout * 2, () {
      _endIncoming(LocalSyncPhase.failed);
    });
  }

  void _updateIncoming(LocalSyncPhase phase, [SyncTransferProgress? progress]) {
    final incoming = _incoming!;
    _run = LocalSyncRun(incoming.peerId, phase, progress ?? _run?.transfer);
    _emit();
  }

  void _endIncoming(LocalSyncPhase phase) {
    final incoming = _incoming;
    if (incoming == null) return;
    _incoming = null;
    _incomingTimeout?.cancel();
    _incomingTimeout = null;
    _run = LocalSyncRun(incoming.peerId, phase, _run?.transfer);
    _emit();
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
        final nonce = body['nearbyNonce'];
        final source = request.connectionInfo?.remoteAddress.address;
        final invited =
            nonce == null &&
            _inviteHash != null &&
            _inviteDeadline?.isAfter(DateTime.now()) == true &&
            body['secret'] is String &&
            _hash(body['secret'] as String) == _inviteHash;
        final nearby =
            nonce is String &&
            _validNonce(nonce) &&
            source != null &&
            _isLan(source) &&
            _discoverable;
        if (body['confirmPairing'] != true ||
            !(invited || nearby) ||
            body['datasetId'] != identity.datasetId ||
            _pending != null ||
            _approvedPeer != null) {
          throw const LocalSyncException(
            'Приглашение истекло или уже использовано.',
          );
        }
        final peerId = _id(body['deviceId']);
        if (peerId == identity.deviceId || _peers.containsKey(peerId)) {
          throw const LocalSyncException('Это устройство уже подключено.');
        }
        final endpoint = _endpoint(body['endpoint'] as String);
        final pending = _Peer.fromJson({
          'id': peerId,
          'name': body['name'],
          'endpoint': (nearby ? endpoint.replace(host: source) : endpoint)
              .toString(),
          'pin': body['pin'],
          'token': _randomSecret(),
        });
        final approval = Completer<String>();
        _approvalId = const Uuid().v4();
        _pending = pending;
        _approval = approval;
        _pendingPairCode = nearby
            ? _comparisonCode(
                _fingerprint(_material!.certificatePem),
                pending.pin,
                nonce,
              )
            : null;
        if (invited) {
          _inviteHash = null;
          _invitation = null;
        }
        _emit();
        try {
          final token = await approval.future.timeout(options.pairingTimeout);
          _live(generation);
          result = {
            'deviceId': identity.deviceId,
            'datasetId': identity.datasetId,
            'name': _advertisedName ?? deviceName,
            'token': token,
            'confirmPairing': true,
          };
        } finally {
          if (identical(_approval, approval)) {
            _pending = null;
            _approval = null;
            if (_approvedPeer == null) _pendingPairCode = null;
            _emit();
          }
        }
      } else {
        final id = request.headers.value('X-Life-Device');
        final path = request.uri.path;
        final cancelling = path == '/v1/pair/cancel';
        final completing = path == '/v1/pair/confirm' || cancelling;
        final approved = _approvedPeer;
        final peer = completing && approved != null && approved.id == id
            ? approved
            : _peers[id];
        final auth = request.headers.value(HttpHeaders.authorizationHeader);
        if (peer == null ||
            auth == null ||
            _hash(auth) != _hash('Bearer ${peer.token}')) {
          if (auth != null && id != null) throw const _PeerNotAuthorized();
          throw const LocalSyncException('Устройство не авторизовано.');
        }
        if (!completing) _trusted(peer, generation);
        if (body['datasetId'] != identity.datasetId) {
          throw const LocalSyncException(
            'Устройства принадлежат разным пространствам.',
          );
        }
        final runId = body['runId'] == null ? null : _id(body['runId']);
        final inSession =
            runId != null && _incoming == (id: runId, peerId: peer.id);
        if (path != '/v1/hello' && !completing) {
          if (runId != null || _incoming != null) {
            if (!inSession) throw const _SyncInUse();
            _touchIncoming();
          }
        }
        switch (path) {
          case '/v1/pair/confirm':
            await _completePair(peer);
            result = {'confirmed': true};
          case '/v1/pair/cancel':
            if (!identical(_approvedPeer, peer)) {
              throw const _PeerNotAuthorized();
            }
            _clearApprovedPeer();
            _emit();
            result = {};
          case '/v1/hello':
            final name = _advertisedName ?? await _pairingName(generation);
            if (runId != null &&
                body['schema'] == SyncRevision.supportedSchema) {
              await _beginIncoming(peer, runId, generation);
            }
            result = {
              'deviceId': identity.deviceId,
              'datasetId': identity.datasetId,
              'schema': SyncRevision.supportedSchema,
              'name': name,
              'progress': true,
            };
          case '/v1/progress':
            if (!inSession) {
              throw const FormatException('Unknown sync session.');
            }
            if (body['applying'] == true) {
              _updateIncoming(LocalSyncPhase.applying);
            } else {
              _updateIncoming(
                LocalSyncPhase.transferring,
                _decodeProgress(body),
              );
            }
            result = {};
          case '/v1/abort':
            if (!inSession) {
              throw const FormatException('Unknown sync session.');
            }
            _endIncoming(LocalSyncPhase.failed);
            result = {};
          case '/v1/cursor':
            if (body['deviceId'] != peer.id) {
              throw const FormatException('Wrong cursor owner.');
            }
            result = {'cursor': await data.store.receivedCursor(peer.id)};
          case '/v1/plan':
            await _reconcilePeerNotes(request, peer, generation);
            final plan = await data.store.planFeed(after: body['after'] as int);
            result = {
              'through': plan.through,
              'counts': _encodeProgressCounts(plan.counts),
            };
          case '/v1/pull':
            result = _encodeBatch(
              await data.store.readFeed(
                after: body['after'] as int,
                limit: body['limit'] as int? ?? 100,
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
            await _refresh();
            result = {'cursor': batch.cursor};
          case '/v1/finish':
            final ready = await _reconcilePeerNotes(
              request,
              peer,
              generation,
              apply: true,
            );
            if (!inSession || _incoming == (id: runId, peerId: peer.id)) {
              _notesNeedFolder = !ready || body['notesReady'] == false;
              _lastSync = DateTime.now();
              await _refresh();
              if (inSession && _incoming == (id: runId, peerId: peer.id)) {
                _endIncoming(LocalSyncPhase.complete);
              }
            }
            result = {'notesReady': ready};
          default:
            throw const FormatException('Unknown request.');
        }
        if (!cancelling) _trusted(peer, generation);
      }
      request.response.headers.contentType = ContentType.json;
      request.response.write(jsonEncode(result));
      await request.response.close();
    } catch (error) {
      try {
        if (request.response.statusCode != 409) {
          request.response.statusCode = switch (error) {
            _PeerNotAuthorized() => 403,
            _SyncInUse() => 423,
            _ => 400,
          };
        }
        request.response.write('{"error":"request_rejected"}');
        await request.response.close();
      } catch (_) {}
    }
  }

  Future<bool> _reconcilePeerNotes(
    HttpRequest request,
    _Peer peer,
    int generation, {
    bool apply = false,
  }) async {
    bool ready;
    try {
      final action = apply ? applyNotes ?? reconcileNotes : reconcileNotes;
      ready = await action?.call() ?? true;
    } catch (_) {
      request.response.statusCode = 409;
      rethrow;
    }
    _trusted(peer, generation);
    return ready;
  }

  @override
  Future<void> stop() =>
      _stopping ??= _stop().whenComplete(() => _stopping = null);
  Future<void> _stop() async {
    if (!_active && _starting == null) return;
    _active = false;
    _generation++;
    _busy = false;
    _closeDiscovery();
    if (_pairDecision case final decision? when !decision.isCompleted) {
      decision.complete(false);
    }
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

Map<String, int> _encodeProgressCounts(Map<SyncSection, int> counts) => {
  for (final entry in counts.entries) entry.key.name: entry.value,
};

SyncTransferProgress _decodeProgress(Map<String, dynamic> body) {
  Map<SyncSection, int> counts(Object? value) => {
    for (final entry in (value as Map<String, dynamic>).entries)
      SyncSection.values.byName(entry.key): entry.value as int,
  };
  final planned = counts(body['planned']);
  final transferred = counts(body['transferred']);
  if (planned.values.any((n) => n < 0 || n > 0x7fffffff) ||
      transferred.entries.any(
        (entry) => entry.value < 0 || entry.value > (planned[entry.key] ?? 0),
      )) {
    throw const FormatException('Invalid sync progress.');
  }
  final active = (body['active'] as List<dynamic>).cast<String>().map(
    SyncSection.values.byName,
  );
  return SyncTransferProgress(planned, transferred, active);
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
  Future<SyncFeedPlan> planFeed({required int after}) {
    check();
    return inner.planFeed(after: after);
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
  _RemoteStore(
    this.service,
    this.peer,
    this.generation,
    this.local, {
    this.runId,
  });
  final LanSyncService service;
  final _Peer peer;
  final int generation;
  final SyncIdentity local;
  final String? runId;
  bool _mirrorsProgress = false;
  Future<Map<String, dynamic>> _call(
    String path,
    Map<String, Object?> body, {
    Duration? timeout,
  }) {
    service._trusted(peer, generation);
    return service._post(
      _endpoint(peer.endpoint),
      peer.pin,
      path,
      {
        'protocol': 1,
        'datasetId': local.datasetId,
        if (runId != null) 'runId': runId,
        ...body,
      },
      generation,
      token: peer.token,
      deviceId: local.deviceId,
      timeout: timeout,
    );
  }

  Future<String?> hello() async {
    final result = await _call('/v1/hello', {
      'schema': SyncRevision.supportedSchema,
    });
    if (result['deviceId'] != peer.id ||
        result['datasetId'] != local.datasetId ||
        result['schema'] != SyncRevision.supportedSchema) {
      throw const LocalSyncException(
        'Установите одинаковую версию Pulse на обоих устройствах.',
      );
    }
    _mirrorsProgress = result['progress'] == true;
    final name = result['name'];
    return name is String && name.trim().isNotEmpty && name.length <= 80
        ? name
        : null;
  }

  Future<void> progress(SyncTransferProgress progress) async {
    if (!_mirrorsProgress) return;
    await _call('/v1/progress', {
      'planned': _encodeProgressCounts(progress.planned),
      'transferred': _encodeProgressCounts(progress.transferred),
      'active': progress.active.map((section) => section.name).toList(),
    });
  }

  Future<void> applying() async {
    if (_mirrorsProgress) await _call('/v1/progress', {'applying': true});
  }

  Future<void> abort() async {
    if (!_mirrorsProgress) return;
    try {
      await _call('/v1/abort', {}, timeout: const Duration(seconds: 2));
    } catch (_) {
      // The receiver also clears an interrupted session after a timeout.
    }
  }

  Future<bool> finish(bool localNotesReady) async =>
      (await _call('/v1/finish', {'notesReady': localNotesReady}))['notesReady']
          as bool;

  @override
  Future<SyncFeedPlan> planFeed({required int after}) async {
    final result = await _call('/v1/plan', {'after': after});
    final counts = result['counts'] as Map<String, dynamic>;
    return SyncFeedPlan(result['through'] as int, {
      for (final entry in counts.entries)
        SyncSection.values.byName(entry.key): entry.value as int,
    });
  }

  @override
  Future<SyncIdentity> identity() async =>
      SyncIdentity(local.datasetId, peer.id);
  @override
  Future<SyncBatch> readFeed({int after = 0, int limit = 100}) async {
    final batch = _decodeBatch(
      await _call('/v1/pull', {'after': after, 'limit': limit}),
    );
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
