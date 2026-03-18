import 'package:flutter_test/flutter_test.dart';
import 'package:remote_control/remote_control.dart';
import 'package:remote_control/remote_control_platform_interface.dart';
import 'package:remote_control/remote_control_method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockRemoteControlPlatform
    with MockPlatformInterfaceMixin
    implements RemoteControlPlatform {

  @override
  Future<String?> getPlatformVersion() => Future.value('42');
}

void main() {
  final RemoteControlPlatform initialPlatform = RemoteControlPlatform.instance;

  test('$MethodChannelRemoteControl is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelRemoteControl>());
  });

  test('getPlatformVersion', () async {
    RemoteControl remoteControlPlugin = RemoteControl(
      serverUrl: 'https://example.com',
      deviceMac: 'AA:BB:CC:DD:EE:FF',
      token: 'test-token',
    );
    MockRemoteControlPlatform fakePlatform = MockRemoteControlPlatform();
    RemoteControlPlatform.instance = fakePlatform;

    expect(await remoteControlPlugin.getPlatformVersion(), '42');
  });
}
