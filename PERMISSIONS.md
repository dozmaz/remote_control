# Permissions Guide

This document explains all permissions required by the `remote_control` plugin and their security implications.

## 📋 Permission Overview

### Required Permissions

These permissions are essential for core functionality:

#### 1. `android.permission.INTERNET`
- **Purpose**: WebSocket and WebRTC communication
- **Risk Level**: Low
- **Required**: Yes
- **User Prompt**: No (granted automatically)
- **Where to declare**: Host app manifest

#### 2. `android.permission.FOREGROUND_SERVICE`
- **Purpose**: Screen capture service runs in foreground
- **Risk Level**: Low
- **Required**: Yes (Android 9+)
- **User Prompt**: No (granted automatically)
- **Where to declare**: Host app manifest

#### 3. `android.permission.BIND_ACCESSIBILITY_SERVICE`
- **Purpose**: Enable remote touch, swipe, and input control
- **Risk Level**: **HIGH**
- **Required**: Yes (for remote control features)
- **User Prompt**: Yes (manual enable in Settings)
- **Where to declare**: Host app manifest (on `<service>` tag)

**Security Warning**: Accessibility services can read screen content and perform actions. Only enable if your app legitimately needs remote control.

### Optional Permissions

These permissions enable additional features:

#### 4. `android.permission.RECORD_AUDIO`
- **Purpose**: WebRTC audio streaming
- **Risk Level**: Medium
- **Required**: No (only if audio is needed)
- **User Prompt**: Yes (runtime permission)
- **Where to declare**: Host app manifest

#### 5. `android.permission.CAMERA`
- **Purpose**: WebRTC camera streaming
- **Risk Level**: Medium
- **Required**: No (only if camera is needed)
- **User Prompt**: Yes (runtime permission)
- **Where to declare**: Host app manifest

#### 6. `android.permission.WRITE_SETTINGS`
- **Purpose**: Modify system settings (brightness, volume, etc.)
- **Risk Level**: Medium
- **Required**: No
- **User Prompt**: Yes (via `ACTION_MANAGE_WRITE_SETTINGS`)
- **Where to declare**: Host app manifest

**Note**: This permission only works for certain settings. System settings (`WRITE_SECURE_SETTINGS`) require system/privileged apps.

#### 7. `android.permission.SYSTEM_ALERT_WINDOW`
- **Purpose**: Display overlay windows
- **Risk Level**: Medium
- **Required**: No
- **User Prompt**: Yes (via `ACTION_MANAGE_OVERLAY_PERMISSION`)
- **Where to declare**: Host app manifest

#### 8. `android.permission.BIND_DEVICE_ADMIN`
- **Purpose**: Lock device, wipe data, manage security policies
- **Risk Level**: **CRITICAL**
- **Required**: No (only for device management features)
- **User Prompt**: Yes (user must activate device admin)
- **Where to declare**: Host app manifest (on `<receiver>` tag)

**Security Warning**: Device admin can wipe all data. Only use if absolutely necessary (e.g., enterprise MDM apps).

## 🔒 Security Best Practices

### 1. Principle of Least Privilege
Only declare permissions your app actually uses:

```xml
<!-- ❌ BAD: Declaring all permissions "just in case" -->
<uses-permission android:name="android.permission.CAMERA" />
<uses-permission android:name="android.permission.RECORD_AUDIO" />
<uses-permission android:name="android.permission.WRITE_SETTINGS" />

<!-- ✅ GOOD: Only declare what you use -->
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.FOREGROUND_SERVICE" />
```

### 2. Runtime Permission Requests
For dangerous permissions, request at runtime with clear explanation:

```dart
import 'package:permission_handler/permission_handler.dart';

Future<void> requestPermissions() async {
  // Explain why before requesting
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('Microphone Access'),
      content: Text('This app needs microphone access to enable audio during remote sessions.'),
      actions: [
        TextButton(
          onPressed: () async {
            Navigator.pop(context);
            await Permission.microphone.request();
          },
          child: Text('Allow'),
        ),
      ],
    ),
  );
}
```

### 3. Accessibility Service Transparency
Be transparent about accessibility service usage:

```dart
Future<void> promptAccessibilityService() async {
  bool enabled = await NativeBridge.isAccessibilityEnabled();
  
  if (!enabled) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Enable Remote Control'),
        content: Text(
          'To allow remote control, please enable the accessibility service.\n\n'
          'This allows remote users to:\n'
          '• Tap and swipe on your screen\n'
          '• Enter text\n'
          '• Navigate using back/home buttons\n\n'
          'Only enable this if you trust the remote user.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              NativeBridge.openAccessibilitySettings();
            },
            child: Text('Open Settings'),
          ),
        ],
      ),
    );
  }
}
```

### 4. Device Admin Usage
Device admin should only be used in enterprise/MDM scenarios:

```dart
// ❌ BAD: Requesting device admin for consumer apps
await requestDeviceAdmin();

// ✅ GOOD: Only in enterprise apps with user consent
if (isEnterpriseMode && userConsentedToMDM) {
  await requestDeviceAdmin();
}
```

### 5. Secure Communication
Always use encrypted connections:

```dart
// ❌ BAD: Unencrypted WebSocket
final remoteControl = RemoteControl(
  serverUrl: 'ws://insecure-server.com',  // ❌
  // ...
);

// ✅ GOOD: Secure WebSocket with TLS
final remoteControl = RemoteControl(
  serverUrl: 'wss://secure-server.com',  // ✅
  // ...
);
```

## 📱 Host App Manifest Template

### Minimal Configuration (Screen Capture Only)

```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android"
    package="com.yourcompany.yourapp">

    <!-- Minimal permissions -->
    <uses-permission android:name="android.permission.INTERNET" />
    <uses-permission android:name="android.permission.FOREGROUND_SERVICE" />

    <application>
        <!-- No additional services needed -->
    </application>
</manifest>
```

### Full Configuration (All Features)

```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android"
    package="com.yourcompany.yourapp">

    <!-- Required permissions -->
    <uses-permission android:name="android.permission.INTERNET" />
    <uses-permission android:name="android.permission.FOREGROUND_SERVICE" />
    
    <!-- Optional: Audio/Video streaming -->
    <uses-permission android:name="android.permission.RECORD_AUDIO" />
    <uses-permission android:name="android.permission.CAMERA" />
    <uses-permission android:name="android.permission.MODIFY_AUDIO_SETTINGS" />
    
    <!-- Optional: Advanced features -->
    <uses-permission android:name="android.permission.WRITE_SETTINGS" />
    <uses-permission android:name="android.permission.SYSTEM_ALERT_WINDOW" />

    <application
        android:label="@string/app_name"
        android:icon="@mipmap/ic_launcher">
        
        <!-- Your main activity -->
        <activity android:name=".MainActivity">
            <!-- ... -->
        </activity>

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

        <!-- Device Admin Receiver (optional: only for device lock/wipe) -->
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

## 🔍 Permission Auditing

### Google Play Store Review

Google Play has strict policies on sensitive permissions:

1. **Accessibility Services**: Must provide a clear explanation in your app listing
2. **Device Admin**: Requires prominent disclosure and legitimate use case
3. **Overlays**: Must explain why overlays are necessary

### Pre-submission Checklist

- [ ] Only declared permissions actually used in the app
- [ ] Privacy policy mentions all sensitive permissions
- [ ] In-app explanations before requesting permissions
- [ ] Accessibility service description is clear and accurate
- [ ] Device admin (if used) is for legitimate enterprise/MDM use
- [ ] All WebSocket connections use WSS (not WS)
- [ ] Tokens are stored securely (not hardcoded)

## 🛡️ Threat Model

### Attack Vectors

1. **Malicious remote controller**: An attacker gains access to your signaling server
   - **Mitigation**: Token authentication, server-side authorization, rate limiting

2. **Man-in-the-middle**: Attacker intercepts WebSocket traffic
   - **Mitigation**: Use WSS (WebSocket Secure) with valid TLS certificates

3. **Accessibility service abuse**: Malicious app uses accessibility to steal data
   - **Mitigation**: Clear user consent, audit accessibility usage, limit scope

4. **Device admin abuse**: App wipes device maliciously
   - **Mitigation**: Only enable in trusted enterprise scenarios, clear warnings

### Defense in Depth

```dart
// Layer 1: Network Security
final remoteControl = RemoteControl(
  serverUrl: 'wss://secure-server.com',  // TLS encryption
  token: await secureStorage.read(key: 'auth_token'),  // Secure token storage
);

// Layer 2: Server-side validation
// Your backend should verify:
// - Token is valid and not expired
// - Device ID matches the token
// - User has permission to control this device
// - Rate limiting to prevent abuse

// Layer 3: Client-side validation
remoteControl.onCustomCommand.listen((command) {
  // Validate command before execution
  if (!isValidCommand(command)) {
    print('⚠️ Rejected invalid command: $command');
    return;
  }
  
  // Log all commands for audit trail
  auditLog.record(command);
  
  // Execute command
  executeCommand(command);
});
```

## 📞 Support

If you have security concerns or questions about permissions:

1. Review this document thoroughly
2. Check [SECURITY.md](./SECURITY.md) for vulnerability reporting
3. Open a GitHub issue with the `security` label
4. For private security issues, contact the maintainers directly

## 📚 References

- [Android Permissions Overview](https://developer.android.com/guide/topics/permissions/overview)
- [Accessibility Service Security](https://developer.android.com/guide/topics/ui/accessibility/service)
- [Device Administration](https://developer.android.com/guide/topics/admin/device-admin)
- [Google Play Policy on Sensitive Permissions](https://support.google.com/googleplay/android-developer/answer/9888170)

