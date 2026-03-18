import 'dart:async';
import 'package:flutter/material.dart';
import 'package:remote_control_webrtc/remote_control.dart';

/// Ejemplo de uso del plugin RemoteControl con reconexión robusta
void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Remote Control Example',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const RemoteControlPage(),
    );
  }
}

class RemoteControlPage extends StatefulWidget {
  const RemoteControlPage({super.key});

  @override
  State<RemoteControlPage> createState() => _RemoteControlPageState();
}

class _RemoteControlPageState extends State<RemoteControlPage> {
  RemoteControl? _remoteControl;
  StreamSubscription? _commandSubscription;
  bool _isConnected = false;
  bool _isConnecting = false;
  final List<String> _commandLog = [];
  Timer? _autoReconnectTimer;

  @override
  void initState() {
    super.initState();
    _initializeRemoteControl();
  }

  Future<void> _initializeRemoteControl() async {
    // Configurar con tus valores reales
    _remoteControl = RemoteControl(
      serverUrl: 'http://192.168.1.100:8000',
      deviceMac: 'XX:XX:XX:XX:XX:XX',
      token: 'demo_token_123',
      turnServerIP: '192.168.1.100',
      turnServerPort: 3478,
      turnServerUsername: 'user',
      turnServerCredential: 'pass',
    );

    // Escuchar comandos personalizados
    _commandSubscription = _remoteControl!.onCustomCommand.listen(
      _handleCommand,
      onError: (error) {
        _addLog('❌ Error en stream: $error');
      },
    );

    // Intentar conectar
    await _connect();

    // Iniciar reconexión automática
    _startAutoReconnect();
  }

  Future<void> _connect() async {
    if (_isConnecting) return;

    setState(() {
      _isConnecting = true;
    });

    try {
      await _remoteControl!.connect();
      setState(() {
        _isConnected = true;
        _isConnecting = false;
      });
      _addLog('✅ Conectado exitosamente');
    } catch (e) {
      setState(() {
        _isConnected = false;
        _isConnecting = false;
      });
      _addLog('❌ Error al conectar: $e');
    }
  }

  Future<void> _reconnect() async {
    if (_isConnecting) return;

    setState(() {
      _isConnecting = true;
    });

    _addLog('🔄 Intentando reconectar...');

    try {
      await _remoteControl!.reconnect();
      setState(() {
        _isConnected = true;
        _isConnecting = false;
      });
      _addLog('✅ Reconectado exitosamente');
    } catch (e) {
      setState(() {
        _isConnected = false;
        _isConnecting = false;
      });
      _addLog('❌ Error al reconectar: $e');
    }
  }

  Future<void> _disconnect() async {
    _addLog('🛑 Desconectando...');

    await _remoteControl?.dispose();

    setState(() {
      _isConnected = false;
    });

    _addLog('✅ Desconectado');
  }

  void _startAutoReconnect() {
    _autoReconnectTimer = Timer.periodic(
      const Duration(seconds: 30),
      (timer) async {
        if (_remoteControl != null && !_remoteControl!.isConnected && !_isConnecting) {
          _addLog('⏰ Reconexión automática...');
          await _reconnect();
        }
      },
    );
  }

  void _handleCommand(Map<String, dynamic> command) {
    final cmd = command['cmd'] as String;
    final params = command['params'];

    _addLog('📨 Comando: $cmd');
    if (params != null) {
      _addLog('   Parámetros: $params');
    }

    // Manejar comandos específicos
    switch (cmd) {
      case 'showMessage':
        _showMessage(params['message'] ?? 'Sin mensaje');
        break;
      case 'vibrate':
        _addLog('📳 Vibrando...');
        break;
      case 'openUrl':
        _addLog('🌐 Abriendo URL: ${params['url']}');
        break;
      default:
        _addLog('⚠️ Comando no implementado: $cmd');
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _addLog(String message) {
    setState(() {
      _commandLog.insert(0, '${DateTime.now().toString().substring(11, 19)} - $message');
      if (_commandLog.length > 50) {
        _commandLog.removeLast();
      }
    });
  }

  void _clearLog() {
    setState(() {
      _commandLog.clear();
    });
  }

  @override
  void dispose() {
    _autoReconnectTimer?.cancel();
    _commandSubscription?.cancel();
    _remoteControl?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Remote Control Example'),
        actions: [
          Icon(
            _isConnected ? Icons.cloud_done : Icons.cloud_off,
            color: _isConnected ? Colors.green : Colors.red,
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: Column(
        children: [
          // Panel de estado
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: _isConnected ? Colors.green.shade50 : Colors.red.shade50,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isConnected ? '✅ Conectado' : '❌ Desconectado',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: _isConnected ? Colors.green : Colors.red,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Estado: ${_isConnecting ? "Conectando..." : (_isConnected ? "En línea" : "Fuera de línea")}',
                  style: const TextStyle(fontSize: 14),
                ),
              ],
            ),
          ),

          // Botones de control
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton.icon(
                  onPressed: _isConnecting ? null : _reconnect,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Reconectar'),
                ),
                ElevatedButton.icon(
                  onPressed: _isConnected ? _disconnect : null,
                  icon: const Icon(Icons.stop),
                  label: const Text('Desconectar'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ),

          const Divider(),

          // Log de comandos
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Log de Eventos',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                TextButton.icon(
                  onPressed: _clearLog,
                  icon: const Icon(Icons.clear_all),
                  label: const Text('Limpiar'),
                ),
              ],
            ),
          ),

          Expanded(
            child: _commandLog.isEmpty
                ? const Center(
                    child: Text(
                      'No hay eventos registrados',
                      style: TextStyle(color: Colors.grey),
                    ),
                  )
                : ListView.builder(
                    itemCount: _commandLog.length,
                    itemBuilder: (context, index) {
                      return ListTile(
                        dense: true,
                        leading: _getIconForLog(_commandLog[index]),
                        title: Text(
                          _commandLog[index],
                          style: const TextStyle(
                            fontSize: 12,
                            fontFamily: 'monospace',
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Icon _getIconForLog(String log) {
    if (log.contains('✅')) return const Icon(Icons.check_circle, color: Colors.green, size: 16);
    if (log.contains('❌')) return const Icon(Icons.error, color: Colors.red, size: 16);
    if (log.contains('🔄') || log.contains('⏰')) return const Icon(Icons.refresh, color: Colors.orange, size: 16);
    if (log.contains('📨')) return const Icon(Icons.mail, color: Colors.blue, size: 16);
    if (log.contains('🛑')) return const Icon(Icons.stop, color: Colors.grey, size: 16);
    return const Icon(Icons.info, color: Colors.grey, size: 16);
  }
}
