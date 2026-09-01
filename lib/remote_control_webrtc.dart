
import 'remote_control_webrtc_platform_interface.dart';

class RemoteControlWebrtc {
  Future<String?> getPlatformVersion() {
    return RemoteControlWebrtcPlatform.instance.getPlatformVersion();
  }
}
