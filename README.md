# remote_control

A Flutter plugin for Android remote control with screen capture, accessibility services, and bidirectional communication via WebRTC and WebSocket.

[![pub package](https://img.shields.io/pub/v/remote_control.svg)](https://pub.dev/packages/remote_control)
[![Platform](https://img.shields.io/badge/platform-android-blue.svg)](https://pub.dev/packages/remote_control)

## ✨ Features

- 📡 **WebSocket Connection** - Real-time bidirectional communication
- 🎥 **Screen Capture** - WebRTC streaming with MediaProjection API
- 🎮 **Remote Control** - Touch, swipe, text input via Accessibility Services
- 🔐 **Device Admin** - Lock device, manage settings (optional)
- 🔄 **Auto-reconnection** - Robust lifecycle with inactivity timeout
- 📨 **Custom Commands** - Extensible command system from server to app
- 🔒 **Token Authentication** - Secure connection with backend
- 🌐 **TURN Server Support** - NAT traversal for P2P connections

## 🚀 Quick Start

### Installation

Add to your `pubspec.yaml`:

```yaml
dependencies:
  remote_control: ^0.0.1
```

### Basic Usage

```dart
import 'package:remote_control/remote_control.dart';

// 1. Create instance
final remoteControl = RemoteControl(
  serverUrl: 'https://your-signaling-server.com',
  deviceMac: 'DEVICE_ID_OR_MAC',
  token: 'your_secure_token',
  turnServerIP: '192.168.1.100',  // Optional TURN server
  turnServerPort: 3478,
  turnServerUsername: 'user',
  turnServerCredential: 'pass',
  inactivityDuration: Duration(minutes: 5),
);

// 2. Connect to signaling server
await remoteControl.connect();

// 3. Listen for custom commands
remoteControl.onCustomCommand.listen((command) {
  print('Received: ${command['action']}');
  if (command['action'] == 'customAction') {
    // Handle your custom logic
  }
});

// 4. Start screen capture (requires MediaProjection permission)
await remoteControl.startScreenCapture();

// 5. Cleanup when done
await remoteControl.dispose();
```

## 📋 Android Setup

### 1. Host App Manifest Configuration

Add the following to your **app's** `android/app/src/main/AndroidManifest.xml`:

```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android"
    package="com.yourcompany.yourapp">

    <!-- Required permissions -->
    <uses-permission android:name="android.permission.INTERNET" />
    <uses-permission android:name="android.permission.FOREGROUND_SERVICE" />
    <uses-permission android:name="android.permission.RECORD_AUDIO" />
    <uses-permission android:name="android.permission.CAMERA" />
    <uses-permission android:name="android.permission.MODIFY_AUDIO_SETTINGS" />
    
    <!-- Optional: for advanced features -->
    <uses-permission android:name="android.permission.WRITE_SETTINGS" />
    <uses-permission android:name="android.permission.SYSTEM_ALERT_WINDOW" />

    <application>
        <!-- Accessibility Service (for remote control) -->
        <service
            android:name="bo.webrtc.remote_control.RemoteControlAccessibilityService"
            android:permission="android.permission.BIND_ACCESSIBILITY_SERVICE"
            android:exported="false">
            <intent-filter>
                <action android:name="android.accessibilityservice.AccessibilityService" />
            </intent-filter>
            <meta-data
                android:name="android.accessibilityservice"
                android:resource="@xml/remote_control_accessibility_service" />
        </service>

        <!-- Device Admin Receiver (optional: for lock/wipe features) -->
        <receiver
            android:name="bo.webrtc.remote_control.MyDeviceAdminReceiver"
            android:permission="android.permission.BIND_DEVICE_ADMIN"
            android:exported="false">
            <meta-data
                android:name="android.app.device_admin"
                android:resource="@xml/device_admin_receiver" />
            <intent-filter>
                <action android:name="android.app.action.DEVICE_ADMIN_ENABLED" />
            </intent-filter>
        </receiver>
    </application>
</manifest>
```

### 2. Permission Explanations

| Permission | Required? | Purpose |
|------------|-----------|---------|
| `INTERNET` | **Yes** | WebSocket and WebRTC communication |
| `FOREGROUND_SERVICE` | **Yes** | Screen capture service |
| `RECORD_AUDIO` | **Yes** | WebRTC audio (if needed) |
| `CAMERA` | No | WebRTC camera (if needed) |
| `BIND_ACCESSIBILITY_SERVICE` | **Yes** | Remote touch/swipe/input |
| `WRITE_SETTINGS` | No | Change system settings (optional) |
| `SYSTEM_ALERT_WINDOW` | No | Overlay windows (optional) |
| `BIND_DEVICE_ADMIN` | No | Lock device, wipe data (optional) |

⚠️ **Security Notice**: 
- Only declare permissions your app actually uses
- `BIND_ACCESSIBILITY_SERVICE` and `BIND_DEVICE_ADMIN` are sensitive and require user consent
- See [PERMISSIONS.md](./PERMISSIONS.md) for detailed security guidance

### 3. Enable Accessibility Service

Users must manually enable the accessibility service:

1. Go to **Settings > Accessibility**
2. Find your app's accessibility service
3. Enable it

You can request this programmatically:

```dart
import 'package:remote_control/native_bridge.dart';

// Check if enabled
bool enabled = await NativeBridge.isAccessibilityEnabled();

// Open settings if not enabled
if (!enabled) {
  await NativeBridge.openAccessibilitySettings();
}
```

## 📚 Documentation

- **[Permissions Guide](./PERMISSIONS.md)** - Security and permission details
- **[Usage Guide](./USAGE_GUIDE.md)** - Detailed examples and use cases
- **[Lifecycle Pattern](./LIFECYCLE_PATTERN.md)** - State management documentation
- **[Backend Setup](./backend/README.md)** - Signaling server setup
- **[Changelog](./CHANGELOG.md)** - Version history

## 🎯 Advanced Features

### Custom Commands

```dart
remoteControl.onCustomCommand.listen((command) {
  switch (command['action']) {
    case 'vibrate':
      HapticFeedback.vibrate();
      break;
    case 'notification':
      showNotification(command['message']);
      break;
    case 'getData':
      sendDataToServer(command['dataType']);
      break;
  }
});
```

### Inactivity Timeout

```dart
final remoteControl = RemoteControl(
  // ... other params
  inactivityDuration: Duration(minutes: 10),
);

remoteControl.onCustomCommand.listen((command) {
  if (command['action'] == 'inactivityTimeout') {
    print('Connection closed due to inactivity');
    // Navigate to idle screen, etc.
  }
});
```

### TURN Server Configuration

```dart
final remoteControl = RemoteControl(
  serverUrl: 'wss://your-server.com',
  deviceMac: 'device-123',
  token: 'token',
  // Configure your TURN server for NAT traversal
  turnServerIP: 'turn.yourserver.com',
  turnServerPort: 3478,
  turnServerUsername: 'username',
  turnServerCredential: 'credential',
);
```

## 🔄 Lifecycle Management

The plugin implements robust lifecycle handling:

```dart
// Safe to call connect() multiple times
await remoteControl.connect();

// Reconnect after dispose
await remoteControl.dispose();
await Future.delayed(Duration(seconds: 5));
await remoteControl.reconnect();  // ✅ Works

// Stream controller auto-recreates
remoteControl.onCustomCommand.listen(...);  // ✅ Always works
```

## 🐛 Troubleshooting

### Screen capture not working
- Ensure MediaProjection permission is granted
- Check that foreground service notification is showing
- Verify Android version >= 5.0 (API 21)

### Accessibility service not responding
- Verify service is enabled in Settings > Accessibility
- Restart the app after enabling the service
- Check logcat for accessibility-related errors

### WebRTC connection fails
- Verify TURN server credentials are correct
- Test TURN server connectivity separately
- Check firewall rules allow UDP/TCP on TURN ports
- Ensure signaling server is accessible

### WebSocket disconnects frequently
- Check network stability
- Verify token authentication is correct
- Review inactivity timeout settings
- Check server logs for connection errors

### "Cannot add new events after calling close"
This error is resolved in the current version. The `StreamController` auto-recreates when needed.

## 💡 Best Practices

1. Always call `dispose()` when finished
2. Use `reconnect()` to reconnect after errors
3. Implement auto-reconnection for long-running apps
4. Monitor `isConnected` to verify state
5. Handle errors with try-catch blocks
6. Use secure WebSocket (wss://) in production
7. Never hardcode tokens - use secure storage

## 📝 API Reference

### Constructor
```dart
RemoteControl({
  required String serverUrl,
  required String deviceMac,
  required String token,
  String? turnServerIP,
  int? turnServerPort,
  String? turnServerUsername,
  String? turnServerCredential,
  Duration inactivityDuration = const Duration(minutes: 1),
})
```

### Methods
- `Future<void> connect()` - Connect to signaling server
- `Future<void> reconnect()` - Reconnect (even after dispose)
- `Future<void> startScreenCapture()` - Start screen streaming
- `Future<void> stopScreenCapture()` - Stop screen streaming
- `Future<void> dispose()` - Release resources
- `bool get isConnected` - Connection state
- `Stream<Map<String, dynamic>> get onCustomCommand` - Command stream

## 📱 Example

The [example](./example/) directory contains two sample applications demonstrating different implementation approaches:

1. **Basic App** (`lib/main.dart`): A simple, interactive example for testing plugin features (commands, screen capture, etc.) manually.
   ```bash
   cd example
   flutter run
   ```

2. **Robust App** (`lib/reconnect_example.dart`): An advanced implementation showing robust auto-reconnection, detailed event logging, and UI state management.
   ```bash
   cd example
   flutter run -t lib/reconnect_example.dart
   ```

## 🤝 Contributing

Contributions are welcome! Please:
1. Fork the repository
2. Create a feature branch
3. Commit your changes
4. Push to the branch
5. Create a Pull Request

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🔒 Security

⚠️ **Important Security Considerations**:

1. **Never hardcode tokens** - Use secure storage (e.g., flutter_secure_storage)
2. **Use WSS/HTTPS** - Always use secure WebSocket (wss://) and HTTPS in production
3. **Implement server-side authentication** - Validate tokens on your backend
4. **Restrict accessibility service scope** - Only grant minimum required permissions
5. **Audit device admin usage** - Device admin policies can wipe data, use with caution
6. **Rate limiting** - Implement rate limiting on your signaling server
7. **Input validation** - Validate all commands from server before execution

See [PERMISSIONS.md](./PERMISSIONS.md) for detailed security guidance.

## 📞 Support

- 📧 Issues: [GitHub Issues](https://github.com/yourusername/remote_control/issues)
- 📖 Documentation: See the docs folder
- 💬 Discussions: [GitHub Discussions](https://github.com/yourusername/remote_control/discussions)

## 🙏 Credits

Built with:
- [flutter_webrtc](https://pub.dev/packages/flutter_webrtc) - WebRTC implementation
- [web_socket_channel](https://pub.dev/packages/web_socket_channel) - WebSocket client
- [permission_handler](https://pub.dev/packages/permission_handler) - Permission management

