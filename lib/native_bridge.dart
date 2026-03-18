import 'package:flutter/services.dart';

class NativeBridge {
  static const _channel = MethodChannel('bo.webrtc.remote_control/native');

  // Verificar si la app es Device Owner
  static Future<bool> isDeviceOwner() async {
    try {
      final result = await _channel.invokeMethod('isDeviceOwner');
      return result as bool;
    } catch (e) {
      return false;
    }
  }

  // Verificar si AccessibilityService está habilitado
  static Future<bool> isAccessibilityEnabled() async {
    try {
      final result = await _channel.invokeMethod('isAccessibilityEnabled');
      return result as bool;
    } catch (e) {
      return false;
    }
  }

  // Abrir configuración de Accesibilidad
  static Future<void> openAccessibilitySettings() async {
    await _channel.invokeMethod('openAccessibilitySettings');
  }

  // Solicitar permiso de MediaProjection
  static Future<bool> requestMediaProjection() async {
    try {
      final result = await _channel.invokeMethod('requestMediaProjection');
      return result as bool;
    } catch (e) {
      return false;
    }
  }

  // Iniciar servicio de captura de pantalla
  static Future<bool> startScreenCapture() async {
    try {
      final result = await _channel.invokeMethod('startScreenCapture');
      return result as bool;
    } catch (e) {
      print('Error al iniciar captura: $e');
      return false;
    }
  }

  // Detener servicio de captura de pantalla
  static Future<bool> stopScreenCapture() async {
    try {
      final result = await _channel.invokeMethod('stopScreenCapture');
      return result as bool;
    } catch (e) {
      return false;
    }
  }

  // Liberar MediaProjection explícitamente (sin detener servicio)
  static Future<bool> releaseMediaProjection() async {
    try {
      final result = await _channel.invokeMethod('releaseMediaProjection');
      return result as bool;
    } catch (e) {
      return false;
    }
  }

  // Verificar si el servicio está corriendo
  static Future<bool> isScreenCaptureRunning() async {
    try {
      final result = await _channel.invokeMethod('isScreenCaptureRunning');
      return result as bool;
    } catch (e) {
      return false;
    }
  }

  // Simular toque en coordenadas específicas
  static Future<bool> simulateTouch(double x, double y) async {
    try {
      final result = await _channel.invokeMethod('simulateTouch', {
        'x': x,
        'y': y,
      });
      return result as bool;
    } catch (e) {
      return false;
    }
  }

  // Simular swipe/deslizamiento
  static Future<bool> simulateSwipe(
    double x1,
    double y1,
    double x2,
    double y2, {
    int duration = 300,
  }) async {
    try {
      final result = await _channel.invokeMethod('simulateSwipe', {
        'x1': x1,
        'y1': y1,
        'x2': x2,
        'y2': y2,
        'duration': duration,
      });
      return result as bool;
    } catch (e) {
      return false;
    }
  }

  // Presionar botón Atrás
  static Future<bool> pressBack() async {
    try {
      final result = await _channel.invokeMethod('pressBack');
      return result as bool;
    } catch (e) {
      return false;
    }
  }

  // Presionar botón Home
  static Future<bool> pressHome() async {
    try {
      final result = await _channel.invokeMethod('pressHome');
      return result as bool;
    } catch (e) {
      return false;
    }
  }

  // Presionar botón Recientes
  static Future<bool> pressRecents() async {
    try {
      final result = await _channel.invokeMethod('pressRecents');
      return result as bool;
    } catch (e) {
      return false;
    }
  }

  // Cambiar configuraciones del sistema (requiere Device Owner)
  static Future<void> changeSetting(String key, dynamic value) async {
    await _channel.invokeMethod('changeSettings', {
      'setting': key,
      'value': value.toString(),
    });
  }

  // Bloquear dispositivo
  static Future<void> lockDevice() async {
    await _channel.invokeMethod('lockDevice');
  }

  // Escribir texto en el dispositivo
  static Future<bool> inputText(String text) async {
    try {
      final result = await _channel.invokeMethod('inputText', {'text': text});
      return result == true;
    } catch (e) {
      print('❌ Error al escribir texto: $e');
      return false;
    }
  }
}

