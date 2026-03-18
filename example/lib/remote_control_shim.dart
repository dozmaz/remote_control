// Shim opcional para el plugin usando MethodChannel
import 'package:flutter/services.dart';

class RemoteControlShim {
  static const MethodChannel _channel = MethodChannel('remote_control');

  static Future<bool> init(Map<String, dynamic> params) async {
    final res = await _channel.invokeMethod<bool>('init', params);
    return res ?? false;
  }

  static Future<bool> sendCommand(String command, [Map<String, dynamic>? params]) async {
    final res = await _channel.invokeMethod<bool>('sendCommand', {'command': command, 'params': params});
    return res ?? false;
  }
}


