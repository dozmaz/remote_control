import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'remote_control_webrtc_platform_interface.dart';

/// An implementation of [RemoteControlWebrtcPlatform] that uses method channels.
class MethodChannelRemoteControlWebrtc extends RemoteControlWebrtcPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('remote_control_webrtc');

  @override
  Future<String?> getPlatformVersion() async {
    final version = await methodChannel.invokeMethod<String>(
      'getPlatformVersion',
    );
    return version;
  }
}
