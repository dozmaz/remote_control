import 'dart:async';
import 'dart:convert';

import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:remote_control/native_bridge.dart';
import 'package:remote_control/test_turn.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'remote_control_platform_interface.dart';

class RemoteControl {
  Future<String?> getPlatformVersion() {
    return RemoteControlPlatform.instance.getPlatformVersion();
  }

  WebSocketChannel? _channel;
  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;
  bool _isConnected = false;
  bool _isDisposed = false;

  final String serverUrl;
  final String? turnServerIP;
  final int? turnServerPort;
  final String? turnServerUsername;
  final String? turnServerCredential;
  final String deviceMac;
  final String token;

  // Inactivity handling
  final Duration inactivityDuration;
  Timer? _inactivityTimer;
  DateTime? _lastActivity;

  // Stream para notificar comandos personalizados a la app principal
  StreamController<Map<String, dynamic>>? _commandController;

  Stream<Map<String, dynamic>> get onCustomCommand {
    _ensureCommandController();
    return _commandController!.stream;
  }

  // Asegurar que el controller existe y está abierto
  void _ensureCommandController() {
    if (_commandController == null || _commandController!.isClosed) {
      _commandController = StreamController<Map<String, dynamic>>.broadcast();
      print('🔄 StreamController recreado');
    }
  }


  RemoteControl({
    required this.serverUrl,
    required this.deviceMac,
    required this.token,
    this.turnServerIP,
    this.turnServerPort,
    this.turnServerUsername,
    this.turnServerCredential,
    this.inactivityDuration = const Duration(minutes: 1),
  }) {
    // Inicializar el StreamController inmediatamente
    _ensureCommandController();
    print('🎯 RemoteControl inicializado (inactivityDuration=${inactivityDuration.inMinutes}m)');
  }

  bool get isConnected => _isConnected;

  // Marcar actividad y resetear timer
  void _markActivity() {
    _lastActivity = DateTime.now();
    // Reiniciar timer
    _startInactivityTimer();
  }

  void _startInactivityTimer() {
    _inactivityTimer?.cancel();
    _inactivityTimer = Timer(inactivityDuration, () async {
      await _handleInactivityTimeout();
    });
    // Debug
    //print('⏱️ Inactivity timer started (${inactivityDuration.inSeconds}s)');
  }

  void _cancelInactivityTimer() {
    _inactivityTimer?.cancel();
    _inactivityTimer = null;
  }

  Future<void> _handleInactivityTimeout() async {
    print('⏳ Inactividad detectada (${inactivityDuration.inMinutes}m). Cerrando conexión...');

    // Notificar a la app principal
    try {
      _sendCommandToApp('inactivityTimeout', {
        'reason': 'no_interaction',
        'durationMinutes': inactivityDuration.inMinutes,
        'lastActivity': _lastActivity?.toIso8601String(),
      });
    } catch (e) {
      print('⚠️ Error notificando inactivity a app: $e');
    }

    // Intentar limpiar recursos WebRTC
    try {
      await stopScreenCapture();
    } catch (e) {
      print('⚠️ Error al detener screen capture en inactivity: $e');
    }

    // Cerrar WebSocket
    try {
      _channel?.sink.close();
      _isConnected = false;
      print('✅ WebSocket cerrado por inactividad');
    } catch (e) {
      print('⚠️ Error cerrando websocket por inactividad: $e');
    }

    // Cancelar timer (por si acaso)
    _cancelInactivityTimer();
  }

  // Conectar WebSocket
  Future<void> connect() async {
    // Si fue disposed, resetear automáticamente para permitir primera conexión
    if (_isDisposed) {
      print('🔄 Reseteando estado disposed para conexión');
      _isDisposed = false;
    }

    try {
      // Asegurar que el command controller esté disponible
      _ensureCommandController();

      final wsUrl = serverUrl.replaceFirst('http', 'ws');
      final uri = Uri.parse('$wsUrl/remote/$deviceMac?token=$token&type=device');

      print('🔌 Intentando conectar a: $uri');
      _channel = WebSocketChannel.connect(uri);

      _channel!.stream.listen(
        (message) {
          if (!_isDisposed) {
            _markActivity();
            _handleMessage(jsonDecode(message));
          }
        },
        onDone: () {
          _isConnected = false;
          print('❌ WebSocket desconectado');
        },
        onError: (error) {
          _isConnected = false;
          print('❌ Error WebSocket: $error');
        },
      );

      // Esperar un momento para verificar la conexión
      await Future.delayed(const Duration(milliseconds: 500));
      _isConnected = true;
      print('✅ WebSocket conectado exitosamente');

      // Iniciar timer de inactividad al conectar
      _markActivity();
    } catch (e) {
      print('❌ Error al conectar WebSocket: $e');
      _isConnected = false;
      rethrow;
    }
  }

  // Manejar mensajes del servidor
  void _handleMessage(Map<String, dynamic> message) async {
    print('📨 Mensaje recibido: ${message['type']}');

    _markActivity();

    switch (message['type']) {
      case 'command':
        await _handleCommand(message);
        break;
      case 'webrtc-answer':
        // El dispositivo Android es el offeror, solo recibe respuestas
        await _handleWebRTCAnswer(message['sdp']);
        break;
      case 'ice-candidate':
        await _addIceCandidate(message['candidate']);
        break;
      default:
        print('⚠️  Tipo de mensaje no manejado: ${message['type']}');
    }
  }

  // Iniciar streaming con WebRTC
  Future<void> startScreenCapture() async {
    try {
      // Marcar actividad (inicio explícito)
      _markActivity();

      // Verificar si ya está corriendo el servicio
      final isRunning = await NativeBridge.isScreenCaptureRunning();
      if (!isRunning) {
        // Solicitar permiso de MediaProjection si no está activo
        final granted = await NativeBridge.requestMediaProjection();
        if (!granted) {
          print('❌ Permiso de captura de pantalla denegado');
          return;
        }

        // Esperar un momento para que el servicio inicie
        await Future.delayed(const Duration(milliseconds: 500));
      }

      // Iniciar servicio foreground
      final started = await NativeBridge.startScreenCapture();
      if (!started) {
        print('❌ No se pudo iniciar el servicio de captura');
        return;
      }

      print('✅ Servicio de captura iniciado');

      // 1. Crear PeerConnection PRIMERO con TURN server propio
      if (_peerConnection == null) {
        await testTurnConnectivity(turnServerIP ?? '', turnServerPort ?? 0);
        _peerConnection = await createPeerConnection(
          {
            'iceServers': [
              if (turnServerIP != null && turnServerPort != null)
                {
                  'urls': 'turn:$turnServerIP:$turnServerPort',
                  if (turnServerUsername != null) 'username': turnServerUsername,
                  if (turnServerCredential != null) 'credential': turnServerCredential,
                },
              // TURNS (TLS) - opcional para certificados SSL
              // {
              //   'urls': 'turns:192.168.28.132:5349',
              //   'username': 'remotecontrol',
              //   'credential': 'remotecontrol123',
              // },
              // STUN servers públicos (gratuitos)
              {'urls': 'stun:stun.l.google.com:19302'},
              {'urls': 'stun:stun1.l.google.com:19302'},
            ],
            'iceTransportPolicy': 'all', // Permite STUN y TURN
            // 'iceTransportPolicy': 'relay', // Forzar uso de TURN para debugging
            'bundlePolicy': 'max-bundle',
            'rtcpMuxPolicy': 'require',
            'sdpSemantics': 'unified-plan',
          },
          {
            'mandatory': {},
            'optional': [
              {'DtlsSrtpKeyAgreement': true},
            ],
          },
        );

        // Configurar handlers de ICE candidates
        _peerConnection!.onIceCandidate = (candidate) {
          if (candidate.candidate == null || candidate.candidate!.isEmpty) {
            print('🧊 ICE: Candidato vacío (fin de gathering)');
            return;
          }

          // Marcar actividad cuando lleguen candidatos
          _markActivity();

          final candStr = candidate.candidate!;

          // 🔍 Detectar tipo de candidato
          String icon = '⚪';
          String type = 'UNKNOWN';

          if (candStr.contains('typ relay')) {
            icon = '🔵';
            type = 'TURN (relay)';
            // Extraer IP del relay
            final relayMatch = RegExp(r'raddr (\S+)').firstMatch(candStr);
            if (relayMatch != null) {
              // se puede usar relayMatch.group(1) para debug si se necesita
            }
          } else if (candStr.contains('typ srflx')) {
            icon = '🟡';
            type = 'STUN (srflx)';
          } else if (candStr.contains('typ host')) {
            icon = '🟢';
            type = 'HOST (local)';
          }

          // Log completo para debugging
          final display = candStr.length > 80 ? candStr.substring(0, 80) + '...' : candStr;

          print('$icon ICE [$type]: $display');

          _sendMessage({'type': 'ice-candidate', 'candidate': candidate.toMap()});
        };

        // Configurar handler de estado de conexión
        _peerConnection!.onConnectionState = (state) {
          print('🔗 Estado de conexión WebRTC: $state');
          if (state == RTCPeerConnectionState.RTCPeerConnectionStateFailed) {
            print('❌ Conexión WebRTC falló - intentando limpiar recursos');
            _handleConnectionFailure();
          } else if (state == RTCPeerConnectionState.RTCPeerConnectionStateConnected) {
            print('✅ Conexión WebRTC establecida exitosamente');
            _markActivity();
          }
        };

        // Handler de estado de ICE
        _peerConnection!.onIceConnectionState = (state) {
          print('🧊 Estado ICE: $state');
          if (state == RTCIceConnectionState.RTCIceConnectionStateFailed || state == RTCIceConnectionState.RTCIceConnectionStateDisconnected) {
            print('⚠️ ICE connection issue: $state');
          }
        };

        // Handler de recolección de ICE
        _peerConnection!.onIceGatheringState = (state) {
          print('🧊 Estado de recolección ICE: $state');
          _markActivity();
        };

        print('✅ PeerConnection creado con configuración mejorada');
      }

      // 2. Capturar pantalla para WebRTC
      _localStream = await navigator.mediaDevices.getDisplayMedia({
        'video': {'width': 1280, 'height': 720, 'frameRate': 30},
        'audio': false,
      });

      print('✅ Stream de pantalla capturado');

      // 3. Agregar stream local al PeerConnection
      _localStream!.getTracks().forEach((track) {
        print('➕ Agregando track: ${track.kind} - ${track.id}');
        _peerConnection!.addTrack(track, _localStream!);
      });

      print('✅ Tracks agregados al PeerConnection');

      // 4. Crear oferta DESPUÉS de agregar tracks
      RTCSessionDescription offer = await _peerConnection!.createOffer({'offerToReceiveAudio': false, 'offerToReceiveVideo': true});
      await _peerConnection!.setLocalDescription(offer);

      print('✅ Oferta WebRTC creada');

      // 5. Enviar oferta al servidor
      _sendMessage({'type': 'webrtc-offer', 'sdp': offer.toMap()});

      // Marcar actividad tras generar y enviar oferta
      _markActivity();

      print('✅ Oferta enviada al servidor');
      print('✅ Screen capture y WebRTC iniciados completamente');

      // 6. Timeout de conexión - si no se conecta en 60 segundos, limpiar
      Future.delayed(const Duration(seconds: 60), () {
        if (_peerConnection != null && _peerConnection!.connectionState != RTCPeerConnectionState.RTCPeerConnectionStateConnected) {
          print('⏱️ Timeout de conexión WebRTC - limpiando recursos');
          print(jsonEncode(_peerConnection!.connectionState));
          _handleConnectionFailure();
        }
      });
    } catch (e) {
      print('❌ Error al iniciar screen capture: $e');
      // Limpiar en caso de error
      await stopScreenCapture();
    }
  }

  // Manejar fallo de conexión WebRTC
  void _handleConnectionFailure() async {
    print('🔄 Manejando fallo de conexión WebRTC');
    try {
      await stopScreenCapture();
    } catch (e) {
      print('❌ Error al limpiar después de fallo: $e');
    }
  }

  // Manejar comandos de control
  Future<void> _handleCommand(Map<String, dynamic> command) async {
    final action = command['action'];
    print('Ejecutando comando: $action');

    // Marcar actividad al recibir un comando
    _markActivity();

    switch (action) {
      case 'startStream':
        await startScreenCapture();
        break;
      case 'stopStream':
        await stopScreenCapture();
        break;
      case 'touch':
        final x = (command['x'] as num).toDouble();
        final y = (command['y'] as num).toDouble();
        await NativeBridge.simulateTouch(x, y);
        break;
      case 'swipe':
        final x1 = (command['x1'] as num).toDouble();
        final y1 = (command['y1'] as num).toDouble();
        final x2 = (command['x2'] as num).toDouble();
        final y2 = (command['y2'] as num).toDouble();
        final duration = command['duration'] ?? 300;
        await NativeBridge.simulateSwipe(x1, y1, x2, y2, duration: duration);
        break;
      case 'pressBack':
        await NativeBridge.pressBack();
        break;
      case 'pressHome':
        await NativeBridge.pressHome();
        break;
      case 'pressRecents':
        await NativeBridge.pressRecents();
        break;
      case 'lockDevice':
        await NativeBridge.lockDevice();
        break;
      case 'changeSettings':
        await _changeSystemSettings(command);
        break;
      case 'inputText':
        final text = command['text'] as String?;
        if (text != null) {
          await NativeBridge.inputText(text);
        }
        break;
      case 'commandApp':
        final cmd = command['cmd'] as String?;
        if (cmd != null) {
          _sendCommandToApp(cmd, command['params']);
        }
        break;
    }
  }

  // Cambiar configuraciones del sistema (Device Owner)
  Future<void> _changeSystemSettings(Map<String, dynamic> settings) async {
    final key = settings['key'];
    final value = settings['value'];
    if (key != null && value != null) {
      await NativeBridge.changeSetting(key, value);
    }
  }

  // Enviar comando a la app principal de forma segura
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

  // Enviar mensaje por WebSocket
  void _sendMessage(Map<String, dynamic> message) {
    if (_isConnected && _channel != null) {
      _channel!.sink.add(jsonEncode(message));
    }
  }

  Future<void> stopScreenCapture() async {
    try {
      print('🛑 Iniciando detención de screen capture...');

      // 1. Detener tracks del stream PRIMERO
      if (_localStream != null) {
        print('🛑 Deteniendo ${_localStream!.getTracks().length} tracks...');
        final tracks = _localStream!.getTracks();
        for (var track in tracks) {
          try {
            print('🛑 Deteniendo track: ${track.kind} - ${track.id}');
            track.stop();
            print('✅ Track detenido: ${track.kind}');
          } catch (e) {
            print('⚠️ Error deteniendo track: $e');
          }
        }

        // Esperar que los tracks terminen de detenerse
        await Future.delayed(const Duration(milliseconds: 500));
      }

      // 2. Cerrar PeerConnection
      if (_peerConnection != null) {
        print('🛑 Cerrando PeerConnection (estado: ${_peerConnection!.connectionState})');
        try {
          await _peerConnection!.close();
          print('✅ PeerConnection cerrado');
        } catch (e) {
          print('⚠️ Error cerrando PeerConnection: $e');
        }
        _peerConnection = null;
      }

      // 3. Esperar para que WebRTC libere completamente
      await Future.delayed(const Duration(milliseconds: 800));

      // 4. Dispose del stream (esto debe liberar el Surface)
      if (_localStream != null) {
        try {
          print('🛑 Disposing stream...');
          _localStream!.dispose();
          print('✅ Stream disposed');
        } catch (e) {
          print('⚠️ Error en dispose: $e');
        }
        _localStream = null;
      }

      // 5. Esperar significativamente para asegurar que Flutter liberó el Surface
      print('⏳ Esperando liberación completa del Surface...');
      await Future.delayed(const Duration(milliseconds: 1000));

      // 6. Liberar MediaProjection nativo
      print('🛑 Liberando MediaProjection nativo...');
      await NativeBridge.releaseMediaProjection();
      print('✅ MediaProjection liberado');

      // 7. Esperar antes de detener servicio
      await Future.delayed(const Duration(milliseconds: 500));

      // 8. Finalmente detener servicio nativo
      print('🛑 Deteniendo servicio...');
      final stopped = await NativeBridge.stopScreenCapture();
      if (stopped) {
        print('✅ Servicio nativo detenido');
      }

      // Cancelar timer de inactividad al detener capture
      _cancelInactivityTimer();

      print('✅ Screen capture detenido completamente');
    } catch (e) {
      print('❌ Error al detener screen capture: $e');
      // Intentar limpiar de todos modos con delays largos
      _localStream = null;
      _peerConnection = null;
      try {
        await Future.delayed(const Duration(milliseconds: 1000));
        await NativeBridge.releaseMediaProjection();
        await Future.delayed(const Duration(milliseconds: 500));
        await NativeBridge.stopScreenCapture();
      } catch (e2) {
        print('❌ Error al detener servicio nativo: $e2');
      }
    }
  }

  // Dispose completo con lifecycle robusto
  Future<void> dispose() async {
    if (_isDisposed) {
      print('⚠️ Ya se llamó dispose anteriormente');
      return;
    }

    print('🗑️ Iniciando dispose de RemoteControl...');
    _isDisposed = true;

    // 1. Cerrar WebSocket
    try {
      _channel?.sink.close();
      _isConnected = false;
      print('✅ WebSocket cerrado');
    } catch (e) {
      print('⚠️ Error cerrando WebSocket: $e');
    }

    // 2. Cerrar StreamController de forma segura
    try {
      if (_commandController != null && !_commandController!.isClosed) {
        await _commandController!.close();
        print('✅ StreamController cerrado');
      }
    } catch (e) {
      print('⚠️ Error cerrando StreamController: $e');
    }

    // 3. Detener captura de pantalla
    try {
      await stopScreenCapture();
      print('✅ Screen capture detenido');
    } catch (e) {
      print('⚠️ Error deteniendo screen capture: $e');
    }

    // Cancelar timer de inactividad
    _cancelInactivityTimer();

    print('✅ Dispose completado');
  }

  // Reconectar: útil para reiniciar después de errores o dispose
  Future<void> reconnect() async {
    print('🔄 Reconectando...');

    // Si fue disposed, resetear el flag para permitir reconexión
    if (_isDisposed) {
      print('🔄 Reseteando estado disposed para reconexión');
      _isDisposed = false;
    }

    // Cerrar conexiones actuales
    try {
      _channel?.sink.close();
      _isConnected = false;
    } catch (e) {
      print('⚠️ Error cerrando conexión anterior: $e');
    }

    // Recrear el command controller
    _ensureCommandController();

    // Reconectar
    await connect();
  }

  Future<void> _handleWebRTCAnswer(Map<String, dynamic> sdp) async {
    // Manejar respuesta WebRTC del cliente web (el dispositivo envió la oferta)
    try {
      if (_peerConnection == null) {
        print('❌ PeerConnection no inicializado');
        return;
      }

      // Marcar actividad al recibir answer
      _markActivity();

      final description = RTCSessionDescription(sdp['sdp'], sdp['type']);
      await _peerConnection!.setRemoteDescription(description);
      print('✅ Respuesta WebRTC recibida y aplicada');
    } catch (e) {
      print('❌ Error al manejar respuesta WebRTC: $e');
    }
  }

  Future<void> _addIceCandidate(Map<String, dynamic> candidate) async {
    try {
      // Marcar actividad al agregar ICE
      _markActivity();
      await _peerConnection?.addCandidate(RTCIceCandidate(candidate['candidate'], candidate['sdpMid'], candidate['sdpMLineIndex']));
    } catch (e) {
      print('Error al agregar ICE candidate: $e');
    }
  }
}
