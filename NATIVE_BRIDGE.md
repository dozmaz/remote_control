# NATIVE_BRIDGE — Documentación de `lib/native_bridge.dart`

Última actualización: 2026-03-18

Resumen
-------
`lib/native_bridge.dart` expone una API en Dart que comunica con la implementación nativa (Android) mediante un `MethodChannel`. Su objetivo principal es ofrecer utilidades para:

- Captura de pantalla (MediaProjection)
- Control de entrada (simular toques, swipes, escribir texto)
- Operaciones privilegiadas (Device Owner)
- Abrir ajustes del sistema (p. ej. pantalla de accesibilidad)

Este documento describe los métodos públicos, el formato esperado de los mensajes, los permisos Android típicos requeridos, ejemplos de uso y un test unitario simulado.

Canal (MethodChannel)
---------------------
- Nombre usado en Dart (actual): `bo.webrtc.remote_control/native`
- Nota: la implementación nativa debe registrar exactamente el mismo nombre de channel. Si renombraste el package Dart (por ejemplo a `remote_control_webrtc`), decide si mantienes el channel actual por compatibilidad o si lo actualizas a `bo.webrtc.remote_control_webrtc/native` y sincronizas el código nativo.

Métodos públicos
----------------
Todos los métodos invocan `_channel.invokeMethod(...)` y, salvo excepción, devuelven un valor seguro (`bool` o `void`). El comportamiento esperado (según el código fuente `lib/native_bridge.dart`) es:

- `Future<bool> isDeviceOwner()`
  - Método nativo: `isDeviceOwner`
  - Retorna true si la app es Device Owner. En caso de error devuelve `false`.

- `Future<bool> isAccessibilityEnabled()`
  - Método nativo: `isAccessibilityEnabled`
  - Retorna true si el AccessibilityService del plugin está habilitado. `false` en error.

- `Future<void> openAccessibilitySettings()`
  - Método nativo: `openAccessibilitySettings`
  - Abre la pantalla de ajustes de accesibilidad (no retorna valor útil).

- `Future<bool> requestMediaProjection()`
  - Método nativo: `requestMediaProjection`
  - Solicita permiso de captura (MediaProjection). En Android normalmente lanza una Intent. Retorna bool o `false` en error.

- `Future<bool> startScreenCapture()`
  - Método nativo: `startScreenCapture`
  - Inicia el servicio de captura (recomendado: Foreground Service). Retorna `true` si se inició.

- `Future<bool> stopScreenCapture()`
  - Método nativo: `stopScreenCapture`
  - Detiene el servicio de captura. Retorna `true` si se detuvo correctamente.

- `Future<bool> releaseMediaProjection()`
  - Método nativo: `releaseMediaProjection`
  - Libera el recurso MediaProjection. Retorna `true` en éxito.

- `Future<bool> isScreenCaptureRunning()`
  - Método nativo: `isScreenCaptureRunning`
  - Consulta si el servicio de captura está corriendo. Retorna boolean.

- `Future<bool> simulateTouch(double x, double y)`
  - Método nativo: `simulateTouch`
  - Argumentos: `{ 'x': x, 'y': y }`
  - Simula un toque en coordenadas (requiere AccessibilityService o privilegios). Retorna boolean.

- `Future<bool> simulateSwipe(double x1, double y1, double x2, double y2, {int duration = 300})`
  - Método nativo: `simulateSwipe`
  - Argumentos: `{ 'x1','y1','x2','y2','duration' }` (duration en ms).
  - Simula un gesto de deslizamiento. Retorna boolean.

- `Future<bool> pressBack()` / `pressHome()` / `pressRecents()`
  - Métodos nativos: `pressBack`, `pressHome`, `pressRecents`
  - Simulan pulsaciones del sistema. Retornan boolean.

- `Future<void> changeSetting(String key, dynamic value)`
  - Método nativo: `changeSettings`
  - Argumentos: `{ 'setting': key, 'value': value.toString() }`
  - Cambia configuraciones del sistema (requiere Device Owner). No retorna valor útil.

- `Future<void> lockDevice()`
  - Método nativo: `lockDevice`
  - Bloquea el dispositivo (requiere Device Owner). No retorna valor útil.

- `Future<bool> inputText(String text)`
  - Método nativo: `inputText`
  - Argumentos: `{ 'text': text }`
  - Inserta texto en el campo activo (requiere AccessibilityService). Retorna boolean.

Formato y tipos
----------------
- Los argumentos pasados al `invokeMethod` deben ser JSON-serializables: `int`, `double`, `String`, `bool`, `List` y `Map` simples.
- Los valores retornados desde la plataforma deben ser también JSON-serializables (normalmente `bool` o `null`).

Expectativas del lado nativo (Android)
--------------------------------------
La implementación nativa debe registrar un `MethodChannel` con el mismo nombre y manejar los métodos descritos arriba. A continuación un snippet mínimo en Kotlin:

```kotlin
class RemoteControlPlugin: FlutterPlugin {
  private lateinit var channel: MethodChannel

  override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
    channel = MethodChannel(binding.binaryMessenger, "bo.webrtc.remote_control/native")
    channel.setMethodCallHandler { call, result ->
      when (call.method) {
        "isDeviceOwner" -> result.success(checkDeviceOwner())
        "isAccessibilityEnabled" -> result.success(isAccessibilityServiceEnabled())
        "openAccessibilitySettings" -> { openAccessibilitySettings(); result.success(null) }
        // ... implementar otros métodos ...
        else -> result.notImplemented()
      }
    }
  }
  // ... resto de la implementación ...
}
```

Notas nativas importantes:
- `requestMediaProjection` casi siempre requiere lanzar una `Intent` con `MediaProjectionManager.createScreenCaptureIntent()` y recoger el resultado en `onActivityResult` o en la API de Activity Result; esto implica un flujo asíncrono que puede necesitar eventos adicionales (EventChannel o callbacks nativos) para notificar a Dart.
- `startScreenCapture` debe iniciar un Foreground Service para evitar que Android mate la captura de pantalla en segundo plano.
- La inyección de eventos de input (toques, swipes, escribir texto) suele implementarse desde un `AccessibilityService` por motivos de seguridad y compatibilidad.

Permisos recomendados (Android)
-------------------------------
- `INTERNET` (si usas red / WebRTC)
- `FOREGROUND_SERVICE` (servicio de captura)
- `RECORD_AUDIO`, `CAMERA` (si transmites audio/video via WebRTC)
- Declaración de `AccessibilityService` en manifest:
  - `<service android:name=".YourAccessibilityService" android:permission="android.permission.BIND_ACCESSIBILITY_SERVICE" .../>`
- Para operaciones de alto privilegio: Device Owner / Device Admin (no obtenible por usuarios finales sin control del dispositivo; usar `adb dpm set-device-owner` para pruebas en dispositivos controlados).

Seguridad y buenas prácticas
----------------------------
- No implementar lógicas peligrosas sin confirmar consentimiento del usuario.
- No guardar o exponer credenciales en el código fuente.
- Loguear errores nativos y en Dart para facilitar diagnóstico.
- Considerar devolver objetos de resultado con códigos de error (en vez de solo `bool`) para debug y UX.

Ejemplo de uso (Dart)
---------------------
```dart
import 'package:remote_control_webrtc/native_bridge.dart';

Future<void> ejemplo() async {
  final isOwner = await NativeBridge.isDeviceOwner();
  final accEnabled = await NativeBridge.isAccessibilityEnabled();

  if (!accEnabled) {
    await NativeBridge.openAccessibilitySettings();
  }

  final granted = await NativeBridge.requestMediaProjection();
  if (granted) {
    final ok = await NativeBridge.startScreenCapture();
    if (ok) {
      // captura iniciada
    }
  }
}
```

Test unitario (mock del MethodChannel)
--------------------------------------
Ejemplo de test que mockea el MethodChannel usando `setMockMethodCallHandler`:

```dart
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:remote_control_webrtc/native_bridge.dart';

void main() {
  const channel = MethodChannel('bo.webrtc.remote_control/native');
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    channel.setMockMethodCallHandler((MethodCall method) async {
      switch (method.method) {
        case 'isDeviceOwner':
          return true;
        case 'isAccessibilityEnabled':
          return false;
        case 'simulateTouch':
          final args = method.arguments as Map;
          if (args['x'] != null && args['y'] != null) return true;
          return false;
        default:
          return null;
      }
    });
  });

  tearDown(() {
    channel.setMockMethodCallHandler(null);
  });

  test('isDeviceOwner returns true', () async {
    final v = await NativeBridge.isDeviceOwner();
    expect(v, isTrue);
  });

  test('simulateTouch returns true', () async {
    final ok = await NativeBridge.simulateTouch(100.0, 200.0);
    expect(ok, isTrue);
  });
}
```

Solución de problemas
---------------------
- "Method not implemented" → el nombre del channel o el método no coinciden; verifica `MethodChannel` en nativo y el `invokeMethod` en Dart.
- `requestMediaProjection` devuelve `false` → revisar flujo de intents y resultados en la Activity nativa.
- `simulateTouch` no realiza acción → confirmar que AccessibilityService está habilitado y que la implementación nativa inyecta eventos correctamente.
- En Android 11+ verificar comportamiento de servicios en background y permisos.

Cambio de nombre del channel (si renombraste el paquete)
--------------------------------------------------------
Si cambiaste el nombre del paquete Dart a `remote_control_webrtc` puedes:
- Mantener el channel original (`bo.webrtc.remote_control/native`) para compatibilidad, o
- Cambiar a `bo.webrtc.remote_control_webrtc/native` y actualizar la implementación nativa.

Añadir este archivo al repositorio
---------------------------------
Para crear y commitear el archivo desde PowerShell:

```powershell
# Crear el archivo NATIVE_BRIDGE.md (si no lo añadiste manualmente)
# Guarda el contenido en NATIVE_BRIDGE.md y luego:
git add NATIVE_BRIDGE.md
git commit -m "docs: add NATIVE_BRIDGE.md (documentación de native_bridge.dart)"
git push origin HEAD
```

¿Quieres que también inserte doc-comments (`///`) en la parte superior de `lib/native_bridge.dart` con un resumen breve? Si quieres, lo hago en un siguiente cambio.

