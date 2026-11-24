import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

Future<String?> readSyncDeviceName() async {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return null;
  const channel = MethodChannel('pulse/sync_device');
  try {
    return await channel.invokeMethod<String>('name');
  } on PlatformException {
    return null;
  } on MissingPluginException {
    return null;
  }
}
