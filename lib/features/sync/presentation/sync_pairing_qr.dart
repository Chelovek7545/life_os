import 'dart:async';
import 'dart:ui' as ui;

import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:sync_plugin/sync_logic.dart';
import 'package:zxing2/qrcode.dart' show QRCodeReader;
import 'package:zxing2/zxing2.dart'
    show BinaryBitmap, HybridBinarizer, RGBLuminanceSource;

const _prefix = 'pulse-sync:';

class SyncInvitationQr extends StatelessWidget {
  const SyncInvitationQr({super.key, required this.invitation});

  final String invitation;

  @override
  Widget build(BuildContext context) => Column(
    spacing: 8,
    children: [
      Text(
        'Отсканируйте QR на втором устройстве',
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.titleSmall,
      ),
      QrImageView(
        data: '$_prefix$invitation',
        size: 212,
        padding: const EdgeInsets.all(14),
        backgroundColor: Colors.white,
      ),
      const Text('Одноразовый QR действует 5 минут.'),
    ],
  );
}

class SyncPairCode extends StatelessWidget {
  const SyncPairCode(this.code, {super.key});

  final String code;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 8,
    runSpacing: 4,
    alignment: WrapAlignment.center,
    children: [
      for (final group in code.split(' '))
        Text(
          group,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontFamily: 'JetBrainsMono',
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
    ],
  );
}

bool get canScanSyncQrWithCamera =>
    !kIsWeb &&
    (defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS);

Future<String?> readSyncInvitationQr(BuildContext context) async {
  if (canScanSyncQrWithCamera) {
    return showDialog<String>(
      context: context,
      builder: (_) => const _SyncQrScanner(),
    );
  }

  final file = await openFile(
    acceptedTypeGroups: const [
      XTypeGroup(
        label: 'Изображения',
        extensions: ['png', 'jpg', 'jpeg', 'webp'],
      ),
    ],
  );
  if (file == null) return null;
  try {
    if (await file.length() > 16 * 1024 * 1024) {
      throw const FormatException('Image too large.');
    }
    final invitation = await decodeSyncInvitationImage(
      await file.readAsBytes(),
    );
    if (invitation != null) return invitation;
  } catch (_) {
    // Display one error for unreadable images and codes from other apps.
  }
  throw const LocalSyncException(
    'На изображении не найден QR сопряжения Pulse.',
  );
}

Future<String?> decodeSyncInvitationImage(Uint8List bytes) async =>
    _invitationFrom(await _decodeQr(bytes));

String? _invitationFrom(String? value) {
  if (value == null || !value.startsWith(_prefix) || value.length > 4096) {
    return null;
  }
  final invitation = value.substring(_prefix.length);
  return RegExp(r'^[A-Za-z0-9_-]+={0,2}$').hasMatch(invitation)
      ? invitation
      : null;
}

Future<String> _decodeQr(Uint8List bytes) async {
  final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
  try {
    final descriptor = await ui.ImageDescriptor.encoded(buffer);
    try {
      final portrait = descriptor.height > descriptor.width;
      final longest = portrait ? descriptor.height : descriptor.width;
      const maxSide = 2048;
      final codec = await descriptor.instantiateCodec(
        targetWidth: longest > maxSide && !portrait ? maxSide : null,
        targetHeight: longest > maxSide && portrait ? maxSide : null,
      );
      try {
        final image = (await codec.getNextFrame()).image;
        try {
          final pixels = (await image.toByteData(
            format: ui.ImageByteFormat.rawRgba,
          ))!;
          return await compute(_readPixels, (
            image.width,
            image.height,
            pixels,
          ));
        } finally {
          image.dispose();
        }
      } finally {
        codec.dispose();
      }
    } finally {
      descriptor.dispose();
    }
  } finally {
    buffer.dispose();
  }
}

String _readPixels((int, int, ByteData) input) {
  final (width, height, rgba) = input;
  final pixels = Int32List(width * height);
  for (var index = 0; index < pixels.length; index++) {
    pixels[index] = rgba.getUint32(index * 4) >> 8;
  }
  final source = RGBLuminanceSource(width, height, pixels);
  return QRCodeReader().decode(BinaryBitmap(HybridBinarizer(source))).text;
}

class _SyncQrScanner extends StatefulWidget {
  const _SyncQrScanner();

  @override
  State<_SyncQrScanner> createState() => _SyncQrScannerState();
}

class _SyncQrScannerState extends State<_SyncQrScanner> {
  final _camera = MobileScannerController(formats: [BarcodeFormat.qrCode]);
  bool _completed = false;
  bool _invalid = false;

  void _detect(BarcodeCapture capture) {
    if (_completed || !mounted || ModalRoute.of(context)?.isCurrent != true) {
      return;
    }
    for (final barcode in capture.barcodes) {
      final invitation = _invitationFrom(barcode.rawValue);
      if (invitation != null) {
        _completed = true;
        Navigator.pop(context, invitation);
        return;
      }
    }
    if (!_invalid && capture.barcodes.isNotEmpty) {
      setState(() => _invalid = true);
    }
  }

  @override
  void dispose() {
    unawaited(_camera.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Сканирование QR Pulse'),
    content: SizedBox(
      width: 330,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        spacing: 8,
        children: [
          AspectRatio(
            aspectRatio: 1.15,
            child: MobileScanner(
              controller: _camera,
              onDetect: _detect,
              errorBuilder: (_, _) => const Center(
                child: Text(
                  'Камера недоступна. Проверьте разрешение на её использование.',
                ),
              ),
            ),
          ),
          Text(
            _invalid
                ? 'Наведите камеру на QR сопряжения Pulse.'
                : 'Покажите QR со второго устройства.',
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Закрыть'),
      ),
    ],
  );
}
