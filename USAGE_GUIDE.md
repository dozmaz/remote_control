# Guía de Uso - RemoteControl Plugin

## 📱 Instalación

Agrega el plugin a tu `pubspec.yaml`:

```yaml
dependencies:
  remote_control:
    path: ../remote_control  # O la ruta correspondiente
```

## 🚀 Inicio Rápido

### 1. Importar el Plugin

```dart
import 'package:remote_control/remote_control.dart';
```

### 2. Crear una Instancia

```dart
final remoteControl = RemoteControl(
  serverUrl: 'http://tu-servidor.com',
  deviceMac: 'XX:XX:XX:XX:XX:XX',
  token: 'tu_token_de_autenticacion',
  // Opcional: configuración TURN server
  turnServerIP: '192.168.1.100',
  turnServerPort: 3478,
  turnServerUsername: 'usuario',
  turnServerCredential: 'password',
);
```

### 3. Conectar al Servidor

```dart
try {
  await remoteControl.connect();
  print('✅ Conectado exitosamente');
} catch (e) {
  print('❌ Error al conectar: $e');
}
```

### 4. Escuchar Comandos Personalizados

```dart
remoteControl.onCustomCommand.listen((command) {
  final cmd = command['cmd'] as String;
  final params = command['params'];
  
  print('📨 Comando recibido: $cmd');
  
  // Manejar el comando en tu app
  switch (cmd) {
    case 'openSettings':
      // Abrir configuración
      break;
    case 'showNotification':
      // Mostrar notificación
      break;
    default:
      print('Comando desconocido: $cmd');
  }
});
```

### 5. Limpiar al Finalizar

```dart
await remoteControl.dispose();
```

## 🔄 Manejo de Reconexiones

### Reconexión Simple

```dart
try {
  await remoteControl.reconnect();
  print('✅ Reconectado');
} catch (e) {
  print('❌ Error: $e');
}
```

### Reconexión Automática con Timer

```dart
class RemoteControlManager {
  RemoteControl? _remoteControl;
  Timer? _reconnectTimer;
  bool _isConnecting = false;
  
  void initialize() {
    _remoteControl = RemoteControl(
      serverUrl: 'http://tu-servidor.com',
      deviceMac: 'XX:XX:XX:XX:XX:XX',
      token: 'token',
    );
    
    _startAutoReconnect();
  }
  
  void _startAutoReconnect() {
    _reconnectTimer = Timer.periodic(Duration(seconds: 30), (timer) async {
      if (_remoteControl != null && !_remoteControl!.isConnected && !_isConnecting) {
        _isConnecting = true;
        print('🔄 Intentando reconectar...');
        try {
          await _remoteControl!.reconnect();
          print('✅ Reconectado exitosamente');
        } catch (e) {
          print('❌ Error al reconectar: $e');
        } finally {
          _isConnecting = false;
        }
      }
    });
  }
  
  void dispose() {
    _reconnectTimer?.cancel();
    _remoteControl?.dispose();
  }
}
```

### Reconexión después de Dispose

```dart
// Caso 1: Desconexión temporal
await remoteControl.dispose();
print('🛑 Desconectado');

// Esperar algún evento o condición
await Future.delayed(Duration(minutes: 5));

// Reconectar usando la MISMA instancia
await remoteControl.reconnect();
print('✅ Reconectado');
```

## 🎮 Uso en un Widget con Estado

```dart
class RemoteControlWidget extends StatefulWidget {
  @override
  _RemoteControlWidgetState createState() => _RemoteControlWidgetState();
}

class _RemoteControlWidgetState extends State<RemoteControlWidget> {
  late RemoteControl _remoteControl;
  StreamSubscription? _commandSubscription;
  bool _isConnected = false;
  bool _isConnecting = false;
  
  @override
  void initState() {
    super.initState();
    _initializeRemoteControl();
  }
  
  Future<void> _initializeRemoteControl() async {
    _remoteControl = RemoteControl(
      serverUrl: 'http://tu-servidor.com',
      deviceMac: await _getDeviceMac(),
      token: await _getToken(),
    );
    
    // Escuchar comandos
    _commandSubscription = _remoteControl.onCustomCommand.listen(
      _handleCommand,
      onError: (error) {
        print('❌ Error en stream: $error');
      },
    );
    
    // Conectar
    try {
      await _remoteControl.connect();
      setState(() {
        _isConnected = true;
      });
    } catch (e) {
      print('❌ Error al conectar: $e');
    }
  }
  
  void _handleCommand(Map<String, dynamic> command) {
    final cmd = command['cmd'] as String;
    print('📨 Comando: $cmd');
    
    // Manejar comandos aquí
    switch (cmd) {
      case 'refresh':
        setState(() {
          // Actualizar UI
        });
        break;
      case 'navigate':
        final route = command['params']['route'];
        Navigator.pushNamed(context, route);
        break;
    }
  }
  
  Future<void> _reconnect() async {
    if (_isConnecting) return;
    
    setState(() {
      _isConnecting = true;
      _isConnected = false;
    });
    
    try {
      await _remoteControl.reconnect();
      setState(() {
        _isConnected = true;
        _isConnecting = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('✅ Reconectado')),
      );
    } catch (e) {
      setState(() {
        _isConnecting = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ Error: $e')),
      );
    }
  }
  
  @override
  void dispose() {
    _commandSubscription?.cancel();
    _remoteControl.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Remote Control'),
        actions: [
          IconButton(
            icon: Icon(_isConnected ? Icons.cloud_done : Icons.cloud_off),
            onPressed: _reconnect,
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              _isConnected ? '✅ Conectado' : '❌ Desconectado',
              style: TextStyle(fontSize: 24),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: _reconnect,
              child: Text('Reconectar'),
            ),
          ],
        ),
      ),
    );
  }
  
  Future<String> _getDeviceMac() async {
    // Implementar lógica para obtener MAC
    return 'XX:XX:XX:XX:XX:XX';
  }
  
  Future<String> _getToken() async {
    // Implementar lógica para obtener token
    return 'tu_token';
  }
}
```

## 🔧 Manejo de Errores Robusto

```dart
import 'dart:math';

class RobustRemoteControl {
  RemoteControl? _remoteControl;
  int _reconnectAttempts = 0;
  static const int MAX_RECONNECT_ATTEMPTS = 5;
  
  Future<void> initialize() async {
    _remoteControl = RemoteControl(
      serverUrl: 'http://tu-servidor.com',
      deviceMac: 'XX:XX:XX:XX:XX:XX',
      token: 'token',
    );
    
    await _connectWithRetry();
  }
  
  Future<void> _connectWithRetry() async {
    while (_reconnectAttempts < MAX_RECONNECT_ATTEMPTS) {
      try {
        await _remoteControl!.connect();
        print('✅ Conectado en intento ${_reconnectAttempts + 1}');
        _reconnectAttempts = 0; // Reset contador
        return;
      } catch (e) {
        _reconnectAttempts++;
        print('❌ Intento ${_reconnectAttempts} fallido: $e');
        
        if (_reconnectAttempts < MAX_RECONNECT_ATTEMPTS) {
          // Espera exponencial: 2s, 4s, 8s, 16s, 32s
          final delay = Duration(seconds: pow(2, _reconnectAttempts).toInt());
          print('⏳ Esperando ${delay.inSeconds}s antes de reintentar...');
          await Future.delayed(delay);
        }
      }
    }
    
    throw Exception('No se pudo conectar después de $MAX_RECONNECT_ATTEMPTS intentos');
  }
  
  Future<void> reconnect() async {
    _reconnectAttempts = 0;
    await _connectWithRetry();
  }
  
  void dispose() {
    _remoteControl?.dispose();
  }
}
```

## 📋 Checklist de Integración

- [ ] Agregar el plugin a `pubspec.yaml`
- [ ] Configurar permisos en `AndroidManifest.xml`
- [ ] Habilitar servicio de accesibilidad (si es necesario)
- [ ] Obtener token de autenticación del servidor
- [ ] Obtener MAC address del dispositivo
- [ ] Crear instancia de `RemoteControl`
- [ ] Conectar al servidor con `connect()`
- [ ] Escuchar comandos con `onCustomCommand`
- [ ] Implementar manejo de reconexiones
- [ ] Llamar a `dispose()` al finalizar

## 🐛 Solución de Problemas Comunes

### Error: "No se puede conectar: instancia disposed"

**Solución:** Usa `reconnect()` en lugar de `connect()` después de llamar a `dispose()`.

```dart
await remoteControl.dispose();
// ❌ No hagas esto:
// await remoteControl.connect();

// ✅ Haz esto:
await remoteControl.reconnect();
```

### Error: "Bad state: Cannot add new events after calling close"

**Solución:** Ya está resuelto en la versión actual del plugin. El `StreamController` se recrea automáticamente.

### No se reciben comandos

**Verificar:**
1. Que la conexión WebSocket esté activa: `remoteControl.isConnected`
2. Que estés escuchando el stream: `remoteControl.onCustomCommand.listen(...)`
3. Que el servidor esté enviando comandos con el formato correcto

## 📚 API Reference

### Constructor

```dart
RemoteControl({
  required String serverUrl,        // URL del servidor WebSocket
  required String deviceMac,        // MAC address del dispositivo
  required String token,            // Token de autenticación
  String? turnServerIP,             // IP del servidor TURN (opcional)
  int? turnServerPort,              // Puerto del servidor TURN (opcional)
  String? turnServerUsername,       // Usuario TURN (opcional)
  String? turnServerCredential,     // Credencial TURN (opcional)
})
```

### Métodos

- `Future<void> connect()` - Conectar al servidor WebSocket
- `Future<void> reconnect()` - Reconectar (incluso después de dispose)
- `Future<void> dispose()` - Cerrar todas las conexiones y liberar recursos
- `bool get isConnected` - Verificar si está conectado
- `Stream<Map<String, dynamic>> get onCustomCommand` - Stream de comandos personalizados

### Comandos Recibidos

Los comandos recibidos tienen este formato:

```dart
{
  'cmd': 'nombreDelComando',
  'params': {
    // parámetros del comando
  }
}
```

## 💡 Mejores Prácticas

1. **Siempre llamar a `dispose()`** cuando ya no necesites la conexión
2. **Usar `reconnect()`** en lugar de crear nuevas instancias
3. **Implementar manejo de errores** con try-catch
4. **Monitorear el estado de conexión** con `isConnected`
5. **Cancelar suscripciones** al stream en el `dispose()` de tus widgets
6. **No crear múltiples instancias** de `RemoteControl` simultáneamente
7. **Usar reconexión automática** para apps que deben estar siempre conectadas

## 🔗 Enlaces Útiles

- [Documentación del Patrón de Lifecycle](./LIFECYCLE_PATTERN.md)
- [Changelog](./CHANGELOG.md)
- [README](./README.md)
