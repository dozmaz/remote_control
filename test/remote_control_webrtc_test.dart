import 'package:flutter_test/flutter_test.dart';
import 'package:remote_control_webrtc/remote_control_webrtc.dart';
import 'package:remote_control_webrtc/remote_control_webrtc_platform_interface.dart';
import 'package:remote_control_webrtc/remote_control_webrtc_method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockRemoteControlWebrtcPlatform
    with MockPlatformInterfaceMixin
    implements RemoteControlWebrtcPlatform {
  @override
  Future<String?> getPlatformVersion() => Future.value('42');
}

void main() {
  final RemoteControlWebrtcPlatform initialPlatform = RemoteControlWebrtcPlatform.instance;

  test('$MethodChannelRemoteControlWebrtc is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelRemoteControlWebrtc>());
  });

  test('getPlatformVersion', () async {
    RemoteControlWebrtc remoteControlWebrtcPlugin = RemoteControlWebrtc();
    MockRemoteControlWebrtcPlatform fakePlatform = MockRemoteControlWebrtcPlatform();
    RemoteControlWebrtcPlatform.instance = fakePlatform;

    expect(await remoteControlWebrtcPlugin.getPlatformVersion(), '42');
  });
}
