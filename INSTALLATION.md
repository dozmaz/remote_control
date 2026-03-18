# Installation Guide

Complete installation and setup instructions for the `remote_control` plugin.

## 📋 Prerequisites

- Flutter SDK >= 3.7.0
- Dart SDK >= 3.0.0
- Android Studio or VS Code
- Android device or emulator (Android 7.0+ / API 24+)

## 🚀 Installation Steps

### 1. Add Dependency

Add `remote_control` to your `pubspec.yaml`:

```yaml
dependencies:
  flutter:
    sdk: flutter
  remote_control_webrtc: ^1.0.0
```

Then run:

```bash
flutter pub get
```

### 2. Configure Android Manifest

Edit your `android/app/src/main/AndroidManifest.xml`:

#### Minimal Configuration (Screen Capture Only)

```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android"
    package="com.yourcompany.yourapp">

    <!-- Required permissions -->
    <uses-permission android:name="android.permission.INTERNET" />
    <uses-permission android:name="android.permission.FOREGROUND_SERVICE" />

    <application
        android:label="@string/app_name"
        android:icon="@mipmap/ic_launcher">
        
        <!-- Your main activity -->
        <activity
            android:name=".MainActivity"
            android:exported="true">
            <!-- ... intent filters ... -->
        </activity>
    </application>
</manifest>
```

#### Full Configuration (With Remote Control)

```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android"
    package="com.yourcompany.yourapp">

    <!-- Required permissions -->
    <uses-permission android:name="android.permission.INTERNET" />
    <uses-permission android:name="android.permission.FOREGROUND_SERVICE" />
    
    <!-- Optional: for audio/video -->
    <uses-permission android:name="android.permission.RECORD_AUDIO" />
    <uses-permission android:name="android.permission.CAMERA" />
    <uses-permission android:name="android.permission.MODIFY_AUDIO_SETTINGS" />

    <application
        android:label="@string/app_name"
        android:icon="@mipmap/ic_launcher">
        
        <activity
            android:name=".MainActivity"
            android:exported="true">
            <!-- ... -->
        </activity>

        <!-- Accessibility Service -->
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
    </application>
</manifest>
```

### 3. Add Accessibility Service Description String

Create or edit `android/app/src/main/res/values/strings.xml`:

```xml
<?xml version="1.0" encoding="utf-8"?>
<resources>
    <string name="app_name">Your App Name</string>
    <string name="remote_control_accessibility_description">
        Allows remote users to control this device by simulating touch, 
        swipe, and text input actions. Enable only if you trust the remote user.
    </string>
</resources>
```

### 4. Setup Backend Signaling Server

#### Option A: Use Provided Backend

Navigate to the backend directory and run:

```bash
cd backend

# Install dependencies
pip install fastapi uvicorn websockets

# Set environment variables (optional)
export RC_TOKEN="your_secure_token_here"
export RC_PORT=8080

# Run server
python backend_server.py
```

#### Option B: Docker Deployment

```bash
cd backend
docker-compose up -d
```

#### Option C: Deploy to Cloud

Deploy `backend_server.py` to your preferred cloud provider:
- Heroku
- AWS Lambda + API Gateway
- Google Cloud Run
- Azure App Service
- DigitalOcean App Platform

Make sure to:
- Set environment variables (`RC_TOKEN`, `RC_PORT`)
- Enable HTTPS/WSS with valid certificates
- Configure firewall rules

### 5. Configure TURN Server (Optional but Recommended)

For reliable connections behind NAT/firewalls, set up a TURN server:

#### Option A: coturn (Open Source)

```bash
# Install coturn
sudo apt-get install coturn

# Edit /etc/turnserver.conf
listening-port=3478
fingerprint
lt-cred-mech
realm=yourserver.com
user=username:password
```

#### Option B: Cloud TURN Services

Use a managed service:
- **Twilio TURN**: https://www.twilio.com/stun-turn
- **Xirsys**: https://xirsys.com/
- **Metered TURN**: https://www.metered.ca/turn-server

### 6. Basic Code Setup

In your Flutter app:

```dart
import 'package:flutter/material.dart';
import 'package:remote_control_webrtc/remote_control.dart';
import 'package:remote_control_webrtc/native_bridge.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late RemoteControl remoteControl;
  bool isConnected = false;

  @override
  void initState() {
    super.initState();
    _initializeRemoteControl();
  }

  void _initializeRemoteControl() {
    remoteControl = RemoteControl(
      serverUrl: 'wss://your-signaling-server.com',
      deviceMac: 'DEVICE_ID_123',  // Use unique device ID
      token: 'your_secure_token',
      turnServerIP: 'turn.yourserver.com',
      turnServerPort: 3478,
      turnServerUsername: 'username',
      turnServerCredential: 'password',
    );

    // Listen for commands
    remoteControl.onCustomCommand.listen((command) {
      print('Command received: ${command['action']}');
      _handleCommand(command);
    });
  }

  void _handleCommand(Map<String, dynamic> command) {
    switch (command['action']) {
      case 'vibrate':
        // Handle vibration
        break;
      case 'notification':
        // Show notification
        break;
    }
  }

  Future<void> _connect() async {
    try {
      await remoteControl.connect();
      setState(() => isConnected = true);
      print('Connected to server');
    } catch (e) {
      print('Connection failed: $e');
    }
  }

  Future<void> _startCapture() async {
    // Check accessibility service
    bool accessibilityEnabled = await NativeBridge.isAccessibilityEnabled();
    if (!accessibilityEnabled) {
      // Show dialog and open settings
      await NativeBridge.openAccessibilitySettings();
      return;
    }

    // Start screen capture
    await remoteControl.startScreenCapture();
  }

  @override
  void dispose() {
    remoteControl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: Text('Remote Control')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(isConnected ? 'Connected' : 'Disconnected'),
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: _connect,
                child: Text('Connect'),
              ),
              ElevatedButton(
                onPressed: _startCapture,
                child: Text('Start Screen Capture'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

## ✅ Verification Steps

### 1. Check Plugin Installation

```bash
flutter pub get
flutter pub deps | grep remote_control
```

### 2. Verify Manifest Configuration

```bash
# Check if permissions are declared
cat android/app/src/main/AndroidManifest.xml | grep "uses-permission"
```

### 3. Test Backend Connection

```bash
# Test WebSocket endpoint
wscat -c "ws://localhost:8080/remote/test-device?token=your_token&type=device"
```

### 4. Test Accessibility Service

1. Run the app: `flutter run`
2. Go to **Settings > Accessibility**
3. Find your app's service
4. Enable it
5. Try remote control features

### 5. Run Example App

```bash
cd example
flutter run
```

## 🔧 Troubleshooting Installation

### Problem: "Plugin not found"

```bash
# Solution: Clean and reinstall
flutter clean
flutter pub get
cd android && ./gradlew clean
cd .. && flutter run
```

### Problem: "AndroidManifest.xml merge failed"

Check for duplicate permission declarations between your app and the plugin.

```bash
# View merged manifest
cd android
./gradlew :app:processDebugManifest --console=plain
```

### Problem: "Accessibility service not showing in settings"

Ensure the service is declared correctly in manifest and the XML resource exists:

```bash
# Check if XML file exists
ls android/app/src/main/res/xml/remote_control_accessibility_service.xml
```

If missing, copy from plugin:
```bash
cp ../remote_control/android/src/main/res/xml/remote_control_accessibility_service.xml android/app/src/main/res/xml/
```

### Problem: "Backend won't start"

```bash
# Check Python version (3.8+)
python --version

# Install dependencies
pip install -r backend/requirements.txt

# Check port availability
lsof -i :8080  # On Linux/Mac
netstat -ano | findstr :8080  # On Windows
```

### Problem: "TURN server not working"

Test TURN connectivity:

```bash
# Use Trickle ICE test
# Visit: https://webrtc.github.io/samples/src/content/peerconnection/trickle-ice/

# Or use turnutils_uclient
turnutils_uclient -v -u username -w password turn.yourserver.com
```

## 📚 Next Steps

After successful installation:

1. Read [PERMISSIONS.md](./PERMISSIONS.md) for security setup
2. Check [USAGE_GUIDE.md](./USAGE_GUIDE.md) for examples
3. Review [SECURITY.md](./SECURITY.md) for best practices
4. Explore the [example/](./example/) app

## 💬 Getting Help

If you encounter issues:

1. Check this installation guide thoroughly
2. Review [Troubleshooting section in README](./README.md#troubleshooting)
3. Search [GitHub Issues](https://github.com/dozmaz/remote_control/issues)
4. Open a new issue with:
   - Flutter version (`flutter --version`)
   - Error logs
   - Steps to reproduce
   - Manifest configuration

## 📦 Optional Dependencies

For enhanced functionality, consider installing:

```yaml
dependencies:
  # Secure storage for tokens
  flutter_secure_storage: ^9.0.0
  
  # Permission handling
  permission_handler: ^12.0.1
  
  # HTTP requests
  http: ^1.6.0
  
  # Device information
  device_info_plus: ^12.3.0
```

---

**Installation complete!** 🎉 You're ready to start using the remote_control plugin.

