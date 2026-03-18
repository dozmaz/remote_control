import 'dart:async';
import 'dart:convert';
import 'dart:developer';

import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:remote_control_webrtc/native_bridge.dart';
import 'package:remote_control_webrtc/test_turn.dart';
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
      log('🔄 StreamController recreado');
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
    log('🎯 RemoteControl inicializado (inactivityDuration=${inactivityDuration.inMinutes}m)');
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
    //log('⏱️ Inactivity timer started (${inactivityDuration.inSeconds}s)');
  }

  void _cancelInactivityTimer() {
    _inactivityTimer?.cancel();
    _inactivityTimer = null;
  }

  Future<void> _handleInactivityTimeout() async {
    log('⏳ Inactividad detectada (${inactivityDuration.inMinutes}m). Cerrando conexión...');

    // Notificar a la app principal
    try {
      _sendCommandToApp('inactivityTimeout', {
        'reason': 'no_interaction',
        'durationMinutes': inactivityDuration.inMinutes,
        'lastActivity': _lastActivity?.toIso8601String(),
      });
    } catch (e) {
      log('⚠️ Error notificando inactivity a app: $e');
    }

    // Intentar limpiar recursos WebRTC
    try {
      await stopScreenCapture();
    } catch (e) {
      log('⚠️ Error al detener screen capture en inactivity: $e');
    }

    // Cerrar WebSocket
    try {
      _channel?.sink.close();
      _isConnected = false;
      log('✅ WebSocket cerrado por inactividad');
    } catch (e) {
      log('⚠️ Error cerrando websocket por inactividad: $e');
    }

    // Cancelar timer (por si acaso)
    _cancelInactivityTimer();
  }

  // Conectar WebSocket
  Future<void> connect() async {
    // Si fue disposed, resetear automáticamente para permitir primera conexión
    if (_isDisposed) {
      log('🔄 Reseteando estado disposed para conexión');
      _isDisposed = false;
    }

    try {
      // Asegurar que el command controller esté disponible
      _ensureCommandController();

      final wsUrl = serverUrl.replaceFirst('http', 'ws');
      final uri = Uri.parse('$wsUrl/remote/$deviceMac?token=$token&type=device');

      log('🔌 Intentando conectar a: $uri');
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
          log('❌ WebSocket desconectado');
        },
        onError: (error) {
          _isConnected = false;
          log('❌ Error WebSocket: $error');
        },
      );

      // Esperar un momento para verificar la conexión
      await Future.delayed(const Duration(milliseconds: 500));
      _isConnected = true;
      log('✅ WebSocket conectado exitosamente');

      // Iniciar timer de inactividad al conectar
      _markActivity();
    } catch (e) {
      log('❌ Error al conectar WebSocket: $e');
      _isConnected = false;
      rethrow;
    }
  }

  // Manejar mensajes del servidor
  void _handleMessage(Map<String, dynamic> message) async {
    log('📨 Mensaje recibido: ${message['type']}');

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
        log('⚠️  Tipo de mensaje no manejado: ${message['type']}');
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
          log('❌ Permiso de captura de pantalla denegado');
          return;
        }

        // Esperar un momento para que el servicio inicie
        await Future.delayed(const Duration(milliseconds: 500));
      }

      // Iniciar servicio foreground
      final started = await NativeBridge.startScreenCapture();
      if (!started) {
        log('❌ No se pudo iniciar el servicio de captura');
        return;
      }

      log('✅ Servicio de captura iniciado');

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
            log('🧊 ICE: Candidato vacío (fin de gathering)');
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
          final display = candStr.length > 80 ? '${candStr.substring(0, 80)}...' : candStr;

          log('$icon ICE [$type]: $display');

          _sendMessage({'type': 'ice-candidate', 'candidate': candidate.toMap()});
        };

        // Configurar handler de estado de conexión
        _peerConnection!.onConnectionState = (state) {
          log('🔗 Estado de conexión WebRTC: $state');
          if (state == RTCPeerConnectionState.RTCPeerConnectionStateFailed) {
            log('❌ Conexión WebRTC falló - intentando limpiar recursos');
            _handleConnectionFailure();
          } else if (state == RTCPeerConnectionState.RTCPeerConnectionStateConnected) {
            log('✅ Conexión WebRTC establecida exitosamente');
            _markActivity();
          }
        };

        // Handler de estado de ICE
        _peerConnection!.onIceConnectionState = (state) {
          log('🧊 Estado ICE: $state');
          if (state == RTCIceConnectionState.RTCIceConnectionStateFailed || state == RTCIceConnectionState.RTCIceConnectionStateDisconnected) {
            log('⚠️ ICE connection issue: $state');
          }
        };

        // Handler de recolección de ICE
        _peerConnection!.onIceGatheringState = (state) {
          log('🧊 Estado de recolección ICE: $state');
          _markActivity();
        };

        log('✅ PeerConnection creado con configuración mejorada');
      }

      // 2. Capturar pantalla para WebRTC
      _localStream = await navigator.mediaDevices.getDisplayMedia({
        'video': {'width': 1280, 'height': 720, 'frameRate': 30},
        'audio': false,
      });

      log('✅ Stream de pantalla capturado');

      // 3. Agregar stream local al PeerConnection
      _localStream!.getTracks().forEach((track) {
        log('➕ Agregando track: ${track.kind} - ${track.id}');
        _peerConnection!.addTrack(track, _localStream!);
      });

      log('✅ Tracks agregados al PeerConnection');

      // 4. Crear oferta DESPUÉS de agregar tracks
      RTCSessionDescription offer = await _peerConnection!.createOffer({'offerToReceiveAudio': false, 'offerToReceiveVideo': true});
      await _peerConnection!.setLocalDescription(offer);

      log('✅ Oferta WebRTC creada');

      // 5. Enviar oferta al servidor
      _sendMessage({'type': 'webrtc-offer', 'sdp': offer.toMap()});

      // Marcar actividad tras generar y enviar oferta
      _markActivity();

      log('✅ Oferta enviada al servidor');
      log('✅ Screen capture y WebRTC iniciados completamente');

      // 6. Timeout de conexión - si no se conecta en 60 segundos, limpiar
      Future.delayed(const Duration(seconds: 60), () {
        if (_peerConnection != null && _peerConnection!.connectionState != RTCPeerConnectionState.RTCPeerConnectionStateConnected) {
          log('⏱️ Timeout de conexión WebRTC - limpiando recursos');
          log(jsonEncode(_peerConnection!.connectionState));
          _handleConnectionFailure();
        }
      });
    } catch (e) {
      log('❌ Error al iniciar screen capture: $e');
      // Limpiar en caso de error
      await stopScreenCapture();
    }
  }

  // Manejar fallo de conexión WebRTC
  void _handleConnectionFailure() async {
    log('🔄 Manejando fallo de conexión WebRTC');
    try {
      await stopScreenCapture();
    } catch (e) {
      log('❌ Error al limpiar después de fallo: $e');
    }
  }

  // Manejar comandos de control
  Future<void> _handleCommand(Map<String, dynamic> command) async {
    final action = command['action'];
    log('Ejecutando comando: $action');

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
      log('⚠️ No se puede enviar comando: instancia disposed');
      return;
    }

    _ensureCommandController();

    if (_commandController != null && !_commandController!.isClosed) {
      _commandController!.add({
        'cmd': cmd,
        'params': params,
      });
      log('✅ Comando enviado a la app: $cmd');
    } else {
      log('❌ No se pudo enviar comando, controller no disponible');
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
      log('🛑 Iniciando detención de screen capture...');

      // 1. Detener tracks del stream PRIMERO
      if (_localStream != null) {
        log('🛑 Deteniendo ${_localStream!.getTracks().length} tracks...');
        final tracks = _localStream!.getTracks();
        for (var track in tracks) {
          try {
            log('🛑 Deteniendo track: ${track.kind} - ${track.id}');
            track.stop();
            log('✅ Track detenido: ${track.kind}');
          } catch (e) {
            log('⚠️ Error deteniendo track: $e');
          }
        }

        // Esperar que los tracks terminen de detenerse
        await Future.delayed(const Duration(milliseconds: 500));
      }

      // 2. Cerrar PeerConnection
      if (_peerConnection != null) {
        log('🛑 Cerrando PeerConnection (estado: ${_peerConnection!.connectionState})');
        try {
          await _peerConnection!.close();
          log('✅ PeerConnection cerrado');
        } catch (e) {
          log('⚠️ Error cerrando PeerConnection: $e');
        }
        _peerConnection = null;
      }

      // 3. Esperar para que WebRTC libere completamente
      await Future.delayed(const Duration(milliseconds: 800));

      // 4. Dispose del stream (esto debe liberar el Surface)
      if (_localStream != null) {
        try {
          log('🛑 Disposing stream...');
          _localStream!.dispose();
          log('✅ Stream disposed');
        } catch (e) {
          log('⚠️ Error en dispose: $e');
        }
        _localStream = null;
      }

      // 5. Esperar significativamente para asegurar que Flutter liberó el Surface
      log('⏳ Esperando liberación completa del Surface...');
      await Future.delayed(const Duration(milliseconds: 1000));

      // 6. Liberar MediaProjection nativo
      log('🛑 Liberando MediaProjection nativo...');
      await NativeBridge.releaseMediaProjection();
      log('✅ MediaProjection liberado');

      // 7. Esperar antes de detener servicio
      await Future.delayed(const Duration(milliseconds: 500));

      // 8. Finalmente detener servicio nativo
      log('🛑 Deteniendo servicio...');
      final stopped = await NativeBridge.stopScreenCapture();
      if (stopped) {
        log('✅ Servicio nativo detenido');
      }

      // Cancelar timer de inactividad al detener capture
      _cancelInactivityTimer();

      log('✅ Screen capture detenido completamente');
    } catch (e) {
      log('❌ Error al detener screen capture: $e');
      // Intentar limpiar de todos modos con delays largos
      _localStream = null;
      _peerConnection = null;
      try {
        await Future.delayed(const Duration(milliseconds: 1000));
        await NativeBridge.releaseMediaProjection();
        await Future.delayed(const Duration(milliseconds: 500));
        await NativeBridge.stopScreenCapture();
      } catch (e2) {
        log('❌ Error al detener servicio nativo: $e2');
      }
    }
  }

  // Dispose completo con lifecycle robusto
  Future<void> dispose() async {
    if (_isDisposed) {
      log('⚠️ Ya se llamó dispose anteriormente');
      return;
    }

    log('🗑️ Iniciando dispose de RemoteControl...');
    _isDisposed = true;

    // 1. Cerrar WebSocket
    try {
      _channel?.sink.close();
      _isConnected = false;
      log('✅ WebSocket cerrado');
    } catch (e) {
      log('⚠️ Error cerrando WebSocket: $e');
    }

    // 2. Cerrar StreamController de forma segura
    try {
      if (_commandController != null && !_commandController!.isClosed) {
        await _commandController!.close();
        log('✅ StreamController cerrado');
      }
    } catch (e) {
      log('⚠️ Error cerrando StreamController: $e');
    }

    // 3. Detener captura de pantalla
    try {
      await stopScreenCapture();
      log('✅ Screen capture detenido');
    } catch (e) {
      log('⚠️ Error deteniendo screen capture: $e');
    }

    // Cancelar timer de inactividad
    _cancelInactivityTimer();

    log('✅ Dispose completado');
  }

  // Reconectar: útil para reiniciar después de errores o dispose
  Future<void> reconnect() async {
    log('🔄 Reconectando...');

    // Si fue disposed, resetear el flag para permitir reconexión
    if (_isDisposed) {
      log('🔄 Reseteando estado disposed para reconexión');
      _isDisposed = false;
    }

    // Cerrar conexiones actuales
    try {
      _channel?.sink.close();
      _isConnected = false;
    } catch (e) {
      log('⚠️ Error cerrando conexión anterior: $e');
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
        log('❌ PeerConnection no inicializado');
        return;
      }

      // Marcar actividad al recibir answer
      _markActivity();

      final description = RTCSessionDescription(sdp['sdp'], sdp['type']);
      await _peerConnection!.setRemoteDescription(description);
      log('✅ Respuesta WebRTC recibida y aplicada');
    } catch (e) {
      log('❌ Error al manejar respuesta WebRTC: $e');
    }
  }

  Future<void> _addIceCandidate(Map<String, dynamic> candidate) async {
    try {
      // Marcar actividad al agregar ICE
      _markActivity();
      await _peerConnection?.addCandidate(RTCIceCandidate(candidate['candidate'], candidate['sdpMid'], candidate['sdpMLineIndex']));
    } catch (e) {
      log('Error al agregar ICE candidate: $e');
    }
  }
}
