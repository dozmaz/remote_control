import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'remote_control_webrtc_method_channel.dart';

abstract class RemoteControlWebrtcPlatform extends PlatformInterface {
  /// Constructs a RemoteControlWebrtcPlatform.
  RemoteControlWebrtcPlatform() : super(token: _token);

  static final Object _token = Object();

  static RemoteControlWebrtcPlatform _instance = MethodChannelRemoteControlWebrtc();

  /// The default instance of [RemoteControlWebrtcPlatform] to use.
  ///
  /// Defaults to [MethodChannelRemoteControlWebrtc].
  static RemoteControlWebrtcPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [RemoteControlWebrtcPlatform] when
  /// they register themselves.
  static set instance(RemoteControlWebrtcPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<String?> getPlatformVersion() {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }
}
