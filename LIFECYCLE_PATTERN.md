# Patrón de Lifecycle Robusto - RemoteControl

## 📋 Resumen

Este documento describe el patrón de lifecycle implementado en la clase `RemoteControl` para manejar de forma robusta el ciclo de vida del `StreamController` y evitar errores de estado.

## 🎯 Problema Resuelto

**Error anterior:**
```
Bad state: Cannot add new events after calling close
```

Este error ocurría cuando se intentaba enviar comandos a través del `StreamController` después de que se había cerrado, especialmente durante el proceso de `dispose()`.

## 🔧 Solución Implementada

### 1. **Control de Estado con Flag `_isDisposed`**

```dart
bool _isDisposed = false;
```

Este flag indica si la instancia ha sido disposed, evitando operaciones después de la destrucción.

### 2. **StreamController Nullable y Recreable**

```dart
StreamController<Map<String, dynamic>>? _commandController;
```

El controller ahora es nullable, permitiendo su recreación cuando sea necesario.

### 3. **Método `_ensureCommandController()`**

```dart
void _ensureCommandController() {
  if (_commandController == null || _commandController!.isClosed) {
    _commandController = StreamController<Map<String, dynamic>>.broadcast();
    print('🔄 StreamController recreado');
  }
}
```

Este método verifica el estado del controller y lo recrea si está cerrado o no existe.

### 4. **Envío Seguro de Comandos**

```dart
void _sendCommandToApp(String cmd, dynamic params) {
  if (_isDisposed) {
    print('⚠️ No se puede enviar comando: instancia disposed');
    return;
  }

  _ensureCommandController();

  if (_commandController != null && !_commandController!.isClosed) {
    _commandController!.add({
      'cmd': cmd,
      'params': params,
    });
    print('✅ Comando enviado a la app: $cmd');
  } else {
    print('❌ No se pudo enviar comando, controller no disponible');
  }
}
```

## 🔄 Ciclo de Vida

### **Inicialización**
```dart
final remoteControl = RemoteControl(
  serverUrl: 'http://example.com',
  deviceMac: 'XX:XX:XX:XX:XX:XX',
  token: 'token',
);
// - Inicializa el StreamController automáticamente
// - Marca _isDisposed = false
// - Listo para conectar
```

### **Conexión**
```dart
await remoteControl.connect();
// - Resetea _isDisposed si fue disposed anteriormente
// - Asegura que el StreamController esté disponible
// - Establece la conexión WebSocket
// - Puede llamarse múltiples veces sin problemas
```

### **Uso Normal**
```dart
remoteControl.onCustomCommand.listen((command) {
  // Manejar comandos de la app
});
// - El controller se recrea automáticamente si es necesario
```

### **Reconexión**
```dart
await remoteControl.reconnect();
// - Resetea el flag _isDisposed si fue disposed anteriormente
// - Cierra conexiones actuales
// - Recrea el StreamController
// - Reconecta el WebSocket
// ✅ PUEDE usarse incluso después de dispose()
```

### **Dispose**
```dart
await remoteControl.dispose();
// 1. Marca _isDisposed = true
// 2. Cierra WebSocket
// 3. Cierra StreamController de forma segura
// 4. Detiene screen capture
```

## ✅ Ventajas del Patrón

1. **Prevención de Errores**: Verifica el estado antes de agregar eventos
2. **Recreación Automática**: El controller se recrea cuando es necesario
3. **Reconexión Segura**: Permite reconectar sin crear una nueva instancia
4. **Logging Detallado**: Muestra claramente qué está sucediendo
5. **Manejo de Errores**: Try-catch en todas las operaciones críticas

## 🚀 Uso Recomendado

### Caso 1: App de Larga Duración
```dart
final remoteControl = RemoteControl(...);
await remoteControl.connect();

// Escuchar comandos
remoteControl.onCustomCommand.listen((cmd) {
  print('Comando recibido: ${cmd['cmd']}');
});

// Si se desconecta, reconectar
if (!remoteControl.isConnected) {
  await remoteControl.reconnect();
}

// Al finalizar
await remoteControl.dispose();
```

### Caso 2: Reconexión Automática
```dart
void setupAutoReconnect(RemoteControl remoteControl) {
  Timer.periodic(Duration(seconds: 30), (timer) async {
    if (!remoteControl.isConnected) {
      try {
        await remoteControl.reconnect();
        print('✅ Reconectado exitosamente');
      } catch (e) {
        print('❌ Error al reconectar: $e');
      }
    }
  });
}
```

### Caso 3: Reconexión después de Dispose
```dart
final remoteControl = RemoteControl(...);
await remoteControl.connect();

// Usar la conexión
// ...

// Dispose cuando sea necesario
await remoteControl.dispose();
print('Conexión cerrada');

// Más tarde, reconectar la MISMA instancia (sin crear una nueva)
try {
  await remoteControl.reconnect();
  print('✅ Reconectado después de dispose');
} catch (e) {
  print('❌ Error: $e');
}
```

## 🐛 Debugging

Los logs del lifecycle usan emojis para fácil identificación:

- 🔄 StreamController recreado
- ✅ Operación exitosa
- ⚠️ Advertencia (operación rechazada pero controlada)
- ❌ Error (excepción capturada)
- 🗑️ Dispose en progreso
- 🔌 Operación de conexión

## 📝 Notas Importantes

1. **No llamar `dispose()` múltiples veces**: El método verifica esto automáticamente
2. **Usar `reconnect()` después de dispose**: `reconnect()` resetea automáticamente el estado disposed
3. **El StreamController se recrea automáticamente**: No es necesario verificar manualmente
4. **Alternativa a crear nueva instancia**: Usa `reconnect()` en lugar de crear una nueva instancia de RemoteControl

## 🔍 Testing

Para probar el lifecycle:

```dart
test('StreamController lifecycle', () async {
  final remoteControl = RemoteControl(...);
  
  // Conectar
  await remoteControl.connect();
  
  // Enviar comando
  remoteControl.onCustomCommand.listen((cmd) {
    expect(cmd['cmd'], 'test');
  });
  
  // Simular comando del servidor
  // ...
  
  // Dispose
  await remoteControl.dispose();
  
  // Verificar que no se pueden enviar más comandos
  // El método _sendCommandToApp debería rechazar la operación
});
```
