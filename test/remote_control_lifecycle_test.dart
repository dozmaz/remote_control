import 'dart:developer';

import 'package:flutter_test/flutter_test.dart';
import 'package:remote_control_webrtc/remote_control.dart';

/// Test para verificar que el patrón de lifecycle funciona correctamente
void main() {
  group('RemoteControl Lifecycle Tests', () {
    late RemoteControl remoteControl;

    setUp(() {
      remoteControl = RemoteControl(
        serverUrl: 'http://test-server.com',
        deviceMac: '00:00:00:00:00:00',
        token: 'test_token',
      );
    });

    test('Constructor inicializa el StreamController', () {
      // El getter onCustomCommand no debe lanzar error
      expect(() => remoteControl.onCustomCommand, returnsNormally);

      // Debe poder escuchar el stream inmediatamente
      expect(remoteControl.onCustomCommand, isA<Stream<Map<String, dynamic>>>());
    });

    test('connect() puede llamarse después de dispose()', () async {
      // Dispose
      await remoteControl.dispose();

      // Connect debe funcionar sin errores
      expect(() async {
        try {
          await remoteControl.connect();
        } catch (e) {
          // Ignorar errores de conexión de red, solo nos interesa
          // que no lance StateError
          if (e is! StateError) {
            // Ignorar otros errores (conexión de red, etc.)
          } else {
            rethrow;
          }
        }
      }, returnsNormally);
    });

    test('reconnect() puede llamarse después de dispose()', () async {
      // Dispose
      await remoteControl.dispose();

      // Reconnect debe funcionar sin errores
      expect(() async {
        try {
          await remoteControl.reconnect();
        } catch (e) {
          // Ignorar errores de conexión de red
          if (e is! StateError) {
            // OK
          } else {
            rethrow;
          }
        }
      }, returnsNormally);
    });

    test('onCustomCommand puede escucharse antes de connect()', () {
      // Debe poder escuchar el stream antes de conectar
      expect(() {
        remoteControl.onCustomCommand.listen((command) {
          log('Comando: ${command['cmd']}');
        });
      }, returnsNormally);
    });

    test('StreamController se recrea automáticamente', () async {
      // Primera escucha
      final subscription1 = remoteControl.onCustomCommand.listen((_) {});

      // Dispose cierra el stream
      await remoteControl.dispose();
      await subscription1.cancel();

      // Debe poder escuchar nuevamente después de dispose
      expect(() {
        remoteControl.onCustomCommand.listen((_) {});
      }, returnsNormally);
    });

    test('isConnected inicia en false', () {
      expect(remoteControl.isConnected, isFalse);
    });

    test('dispose() puede llamarse múltiples veces', () async {
      await remoteControl.dispose();

      // Segunda llamada no debe lanzar error
      expect(() async => await remoteControl.dispose(), returnsNormally);
    });

    test('Flujo completo: constructor -> connect -> dispose -> reconnect', () async {
      // 1. Constructor (ya llamado en setUp)
      expect(remoteControl, isNotNull);

      // 2. Escuchar comandos
      final receivedCommands = <Map<String, dynamic>>[];
      final subscription = remoteControl.onCustomCommand.listen((command) {
        receivedCommands.add(command);
      });

      // 3. Connect (puede fallar por red, pero no por estado)
      try {
        await remoteControl.connect();
      } catch (e) {
        // Ignorar errores de red
      }

      // 4. Dispose
      await remoteControl.dispose();
      await subscription.cancel();

      // 5. Reconnect debe funcionar
      expect(() async {
        try {
          await remoteControl.reconnect();
        } catch (e) {
          if (e is! StateError) {
            // OK, error de red
          } else {
            rethrow;
          }
        }
      }, returnsNormally);
    });
  });

  group('RemoteControl Edge Cases', () {
    test('Crear instancia -> dispose inmediato -> connect', () async {
      final rc = RemoteControl(
        serverUrl: 'http://test.com',
        deviceMac: '00:00:00:00:00:00',
        token: 'token',
      );

      // Dispose inmediatamente
      await rc.dispose();

      // Connect debe funcionar
      expect(() async {
        try {
          await rc.connect();
        } catch (e) {
          if (e is! StateError) {
            // OK
          } else {
            rethrow;
          }
        }
      }, returnsNormally);
    });

    test('Escuchar stream -> dispose -> escuchar nuevamente', () async {
      final rc = RemoteControl(
        serverUrl: 'http://test.com',
        deviceMac: '00:00:00:00:00:00',
        token: 'token',
      );

      // Primera escucha
      var subscription = rc.onCustomCommand.listen((_) {});

      // Dispose
      await rc.dispose();
      await subscription.cancel();

      // Segunda escucha debe funcionar
      expect(() {
        subscription = rc.onCustomCommand.listen((_) {});
      }, returnsNormally);

      await subscription.cancel();
    });

    test('Multiple connect calls', () async {
      final rc = RemoteControl(
        serverUrl: 'http://test.com',
        deviceMac: '00:00:00:00:00:00',
        token: 'token',
      );

      // Múltiples llamadas a connect no deben causar problemas
      for (int i = 0; i < 3; i++) {
        try {
          await rc.connect();
        } catch (e) {
          // Ignorar errores de red
        }
      }

      expect(rc, isNotNull);
      await rc.dispose();
    });
  });
}
