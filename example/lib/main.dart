import 'package:flutter/material.dart';
import 'dart:async';

import 'package:flutter/services.dart';
import 'package:remote_control/remote_control.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  String _platformVersion = 'Unknown';
  final _logController = ScrollController();

  // Configurables por el usuario
  final _serverController = TextEditingController(text: 'https://example.com');
  final _macController = TextEditingController(text: '00:11:22:33:44:55');
  final _tokenController = TextEditingController(text: 'YOUR_TOKEN');

  RemoteControl? _remoteControl;
  StreamSubscription<Map<String, dynamic>>? _cmdSub;

  void _appendLog(String s) {
    final now = DateTime.now().toIso8601String();
    setState(() {
      _platformVersion = '$now - $s\n' + _platformVersion;
    });
    // Scroll to top after short delay
    Future.delayed(const Duration(milliseconds: 50), () {
      if (_logController.hasClients) {
        _logController.jumpTo(_logController.position.minScrollExtent);
      }
    });
  }

  RemoteControl _createRemoteControl() {
    return RemoteControl(
      serverUrl: _serverController.text.trim(),
      deviceMac: _macController.text.trim(),
      token: _tokenController.text.trim(),
    );
  }

  @override
  void initState() {
    super.initState();
    initPlatformState();
  }

  // Platform messages are asynchronous, so we initialize in an async method.
  Future<void> initPlatformState() async {
    String platformVersion;
    // Platform messages may fail, so we use a try/catch PlatformException.
    // We also handle the message potentially returning null.
    try {
      _remoteControl ??= _createRemoteControl();
      platformVersion = await _remoteControl!.getPlatformVersion() ?? 'Unknown platform version';
    } on PlatformException {
      platformVersion = 'Failed to get platform version.';
    }

    // If the widget was removed from the tree while the asynchronous platform
    // message was in flight, we want to discard the reply rather than calling
    // setState to update our non-existent appearance.
    if (!mounted) return;

    setState(() {
      _platformVersion = platformVersion;
    });
  }

  @override
  void dispose() {
    _cmdSub?.cancel();
    _remoteControl?.dispose();
    _serverController.dispose();
    _macController.dispose();
    _tokenController.dispose();
    _logController.dispose();
    super.dispose();
  }

  Future<void> _getPlatformVersion() async {
    try {
      // Crear instancia temporal si no existe
      _remoteControl ??= _createRemoteControl();
      final v = await _remoteControl!.getPlatformVersion();
      _appendLog('PlatformVersion: ${v ?? 'null'}');
    } catch (e) {
      _appendLog('Error getPlatformVersion: $e');
    }
  }

  Future<void> _connect() async {
    try {
      _remoteControl ??= _createRemoteControl();

      // Suscribir comandos personalizados
      _ensureCmdSub();

      await _remoteControl!.connect();
      _appendLog('Connected to server');
    } catch (e) {
      _appendLog('Connect error: $e');
    }
  }

  void _ensureCmdSub() {
    if (_cmdSub == null && _remoteControl != null) {
      _cmdSub = _remoteControl!.onCustomCommand.listen((cmd) {
        _appendLog('Received custom cmd: $cmd');
      }, onError: (e) {
        _appendLog('Command stream error: $e');
      });
    }
  }

  Future<void> _startStream() async {
    if (_remoteControl == null) {
      _appendLog('Create and connect first');
      return;
    }
    try {
      await _remoteControl!.startScreenCapture();
      _appendLog('startScreenCapture called');
    } catch (e) {
      _appendLog('startStream error: $e');
    }
  }

  Future<void> _stopStream() async {
    if (_remoteControl == null) return _appendLog('No instance');
    try {
      await _remoteControl!.stopScreenCapture();
      _appendLog('stopScreenCapture called');
    } catch (e) {
      _appendLog('stopStream error: $e');
    }
  }

  Future<void> _reconnect() async {
    if (_remoteControl == null) {
      _appendLog('No instance - creating one');
      _remoteControl = _createRemoteControl();
    }
    try {
      await _remoteControl!.reconnect();
      _appendLog('reconnected');
      _ensureCmdSub();
    } catch (e) {
      _appendLog('reconnect error: $e');
    }
  }

  Future<void> _disposeRemote() async {
    if (_remoteControl == null) return _appendLog('Nothing to dispose');
    try {
      await _remoteControl!.dispose();
      _appendLog('disposed');
      _remoteControl = null;
      await _cmdSub?.cancel();
      _cmdSub = null;
    } catch (e) {
      _appendLog('dispose error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Plugin example app'),
        ),
        body: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            children: [
              TextField(
                controller: _serverController,
                decoration: const InputDecoration(labelText: 'serverUrl'),
              ),
              TextField(
                controller: _macController,
                decoration: const InputDecoration(labelText: 'deviceMac'),
              ),
              TextField(
                controller: _tokenController,
                decoration: const InputDecoration(labelText: 'token'),
              ),
              const SizedBox(height: 8),
              Wrap(spacing: 8, runSpacing: 8, children: [
                ElevatedButton(onPressed: _getPlatformVersion, child: const Text('PlatformVersion')),
                ElevatedButton(onPressed: _connect, child: const Text('Connect')),
                ElevatedButton(onPressed: _startStream, child: const Text('Start Stream')),
                ElevatedButton(onPressed: _stopStream, child: const Text('Stop Stream')),
                ElevatedButton(onPressed: _reconnect, child: const Text('Reconnect')),
                ElevatedButton(onPressed: _disposeRemote, child: const Text('Dispose')),
              ]),
              const SizedBox(height: 12),
              const Divider(),
              Expanded(
                child: SingleChildScrollView(
                  controller: _logController,
                  reverse: true,
                  child: Text(_platformVersion),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
