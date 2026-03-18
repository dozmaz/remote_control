import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'remote_control_platform_interface.dart';

/// An implementation of [RemoteControlPlatform] that uses method channels.
class MethodChannelRemoteControl extends RemoteControlPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('remote_control');

  @override
  Future<String?> getPlatformVersion() async {
    final version = await methodChannel.invokeMethod<String>('getPlatformVersion');
    return version;
  }
}
