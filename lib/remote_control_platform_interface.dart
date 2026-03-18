import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'remote_control_method_channel.dart';

abstract class RemoteControlPlatform extends PlatformInterface {
  /// Constructs a RemoteControlPlatform.
  RemoteControlPlatform() : super(token: _token);

  static final Object _token = Object();

  static RemoteControlPlatform _instance = MethodChannelRemoteControl();

  /// The default instance of [RemoteControlPlatform] to use.
  ///
  /// Defaults to [MethodChannelRemoteControl].
  static RemoteControlPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [RemoteControlPlatform] when
  /// they register themselves.
  static set instance(RemoteControlPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<String?> getPlatformVersion() {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }
}
