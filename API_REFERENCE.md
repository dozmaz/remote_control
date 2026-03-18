# API Reference

Complete API documentation for the `remote_control` plugin.

## Table of Contents

- [RemoteControl Class](#remotecontrol-class)
- [NativeBridge Class](#nativebridge-class)
- [Enums and Types](#enums-and-types)
- [Backend API](#backend-api)

---

## RemoteControl Class

Main class for managing remote control connections.

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

#### Parameters

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `serverUrl` | `String` | Yes | WebSocket signaling server URL (use `wss://` for secure) |
| `deviceMac` | `String` | Yes | Unique device identifier |
| `token` | `String` | Yes | Authentication token |
| `turnServerIP` | `String?` | No | TURN server IP address for NAT traversal |
| `turnServerPort` | `int?` | No | TURN server port (typically 3478) |
| `turnServerUsername` | `String?` | No | TURN server username |
| `turnServerCredential` | `String?` | No | TURN server credential/password |
| `inactivityDuration` | `Duration` | No | Timeout duration for inactivity (default: 1 minute) |

#### Example

```dart
final remoteControl = RemoteControl(
  serverUrl: 'wss://signal.example.com',
  deviceMac: 'DEVICE_001',
  token: await secureStorage.read(key: 'auth_token'),
  turnServerIP: 'turn.example.com',
  turnServerPort: 3478,
  turnServerUsername: 'user',
  turnServerCredential: 'pass',
  inactivityDuration: Duration(minutes: 5),
);
```

### Properties

#### isConnected

```dart
bool get isConnected
```

Returns `true` if connected to the signaling server.

**Example:**
```dart
if (remoteControl.isConnected) {
  print('Connected to server');
}
```

#### onCustomCommand

```dart
Stream<Map<String, dynamic>> get onCustomCommand
```

Stream of custom commands received from the server.

**Example:**
```dart
remoteControl.onCustomCommand.listen((command) {
  print('Received command: ${command['action']}');
  switch (command['action']) {
    case 'vibrate':
      HapticFeedback.vibrate();
      break;
    case 'navigate':
      Navigator.pushNamed(context, command['route']);
      break;
  }
});
```

### Methods

#### connect()

```dart
Future<void> connect()
```

Connect to the WebSocket signaling server.

**Returns:** `Future<void>` that completes when connection is established.

**Throws:** Exception if connection fails.

**Example:**
```dart
try {
  await remoteControl.connect();
  print('✅ Connected');
} catch (e) {
  print('❌ Connection failed: $e');
}
```

#### reconnect()

```dart
Future<void> reconnect()
```

Reconnect to the server. Safe to call after `dispose()`.

**Returns:** `Future<void>` that completes when reconnection succeeds.

**Example:**
```dart
// Reconnect after network interruption
await remoteControl.reconnect();
```

#### startScreenCapture()

```dart
Future<void> startScreenCapture()
```

Start screen capture and WebRTC streaming. Requires MediaProjection permission.

**Returns:** `Future<void>` that completes when capture starts.

**Throws:** Exception if permission denied or capture fails.

**Example:**
```dart
try {
  await remoteControl.startScreenCapture();
  print('Screen capture started');
} catch (e) {
  print('Failed to start capture: $e');
}
```

#### stopScreenCapture()

```dart
Future<void> stopScreenCapture()
```

Stop screen capture and release MediaProjection resources.

**Returns:** `Future<void>` that completes when capture stops.

**Example:**
```dart
await remoteControl.stopScreenCapture();
```

#### dispose()

```dart
Future<void> dispose()
```

Release all resources (WebSocket, WebRTC, streams). Must be called when done.

**Returns:** `Future<void>` that completes when cleanup is done.

**Example:**
```dart
@override
void dispose() {
  remoteControl.dispose();
  super.dispose();
}
```

#### getPlatformVersion()

```dart
Future<String?> getPlatformVersion()
```

Get the platform version string (mainly for testing).

**Returns:** Platform version or `null`.

---

## NativeBridge Class

Static methods for Android native functionality.

### Methods

#### isAccessibilityEnabled()

```dart
static Future<bool> isAccessibilityEnabled()
```

Check if the accessibility service is enabled.

**Returns:** `true` if enabled.

**Example:**
```dart
bool enabled = await NativeBridge.isAccessibilityEnabled();
if (!enabled) {
  print('Please enable accessibility service');
}
```

#### openAccessibilitySettings()

```dart
static Future<void> openAccessibilitySettings()
```

Open Android accessibility settings screen.

**Example:**
```dart
await NativeBridge.openAccessibilitySettings();
```

#### requestMediaProjection()

```dart
static Future<bool> requestMediaProjection()
```

Request MediaProjection permission for screen capture.

**Returns:** `true` if granted, `false` if denied.

**Example:**
```dart
bool granted = await NativeBridge.requestMediaProjection();
if (granted) {
  await remoteControl.startScreenCapture();
}
```

#### startScreenCapture()

```dart
static Future<bool> startScreenCapture()
```

Start the foreground screen capture service.

**Returns:** `true` if service started successfully.

**Example:**
```dart
bool started = await NativeBridge.startScreenCapture();
```

#### stopScreenCapture()

```dart
static Future<void> stopScreenCapture()
```

Stop the screen capture service.

**Example:**
```dart
await NativeBridge.stopScreenCapture();
```

#### isScreenCaptureRunning()

```dart
static Future<bool> isScreenCaptureRunning()
```

Check if screen capture service is running.

**Returns:** `true` if running.

**Example:**
```dart
if (await NativeBridge.isScreenCaptureRunning()) {
  print('Capture is active');
}
```

#### simulateTouch()

```dart
static Future<bool> simulateTouch(double x, double y)
```

Simulate a touch at screen coordinates (requires accessibility service).

**Parameters:**
- `x`: Horizontal position (pixels)
- `y`: Vertical position (pixels)

**Returns:** `true` if successful.

**Example:**
```dart
// Tap at center of 1080p screen
await NativeBridge.simulateTouch(540, 960);
```

#### simulateSwipe()

```dart
static Future<bool> simulateSwipe(
  double x1, 
  double y1, 
  double x2, 
  double y2, 
  int durationMs
)
```

Simulate a swipe gesture.

**Parameters:**
- `x1`, `y1`: Start coordinates
- `x2`, `y2`: End coordinates
- `durationMs`: Swipe duration in milliseconds

**Returns:** `true` if successful.

**Example:**
```dart
// Swipe from bottom to top (scroll up)
await NativeBridge.simulateSwipe(540, 1500, 540, 500, 300);
```

#### pressBack()

```dart
static Future<bool> pressBack()
```

Press the back button.

**Returns:** `true` if successful.

**Example:**
```dart
await NativeBridge.pressBack();
```

#### pressHome()

```dart
static Future<bool> pressHome()
```

Press the home button.

**Returns:** `true` if successful.

**Example:**
```dart
await NativeBridge.pressHome();
```

#### pressRecents()

```dart
static Future<bool> pressRecents()
```

Press the recent apps button.

**Returns:** `true` if successful.

**Example:**
```dart
await NativeBridge.pressRecents();
```

#### inputText()

```dart
static Future<bool> inputText(String text)
```

Input text into the focused field.

**Parameters:**
- `text`: Text to input

**Returns:** `true` if successful.

**Example:**
```dart
await NativeBridge.inputText('Hello from remote!');
```

#### isDeviceOwner()

```dart
static Future<bool> isDeviceOwner()
```

Check if the app is registered as device owner.

**Returns:** `true` if device owner.

**Example:**
```dart
if (await NativeBridge.isDeviceOwner()) {
  print('Device admin features available');
}
```

#### lockDevice()

```dart
static Future<void> lockDevice()
```

Lock the device immediately (requires device admin).

**Example:**
```dart
await NativeBridge.lockDevice();
```

---

## Enums and Types

### Command Structure

Commands received via `onCustomCommand` follow this structure:

```dart
{
  'type': 'command',
  'action': String,        // Command action name
  'timestamp': String?,    // ISO 8601 timestamp (optional)
  // Additional parameters based on action
}
```

### Common Command Actions

| Action | Description | Parameters |
|--------|-------------|------------|
| `startStream` | Start screen streaming | None |
| `stopStream` | Stop screen streaming | None |
| `touch` | Simulate touch | `x`, `y` |
| `swipe` | Simulate swipe | `x1`, `y1`, `x2`, `y2`, `duration` |
| `input` | Input text | `text` |
| `back` | Press back button | None |
| `home` | Press home button | None |
| `recents` | Press recents button | None |
| `vibrate` | Trigger vibration | `duration` (optional) |
| `showMessage` | Display a UI message/snackbar | `message` |
| `openUrl` | Open a URL | `url` |
| `inactivityTimeout` | Inactivity timeout fired | `reason`, `durationMinutes` |

### Custom Commands

You can define custom commands in your backend:

```dart
remoteControl.onCustomCommand.listen((command) {
  if (command['action'] == 'customAction') {
    // Handle your custom logic
    final param = command['parameter'];
    doSomething(param);
  }
});
```

---

## Backend API

### WebSocket Endpoint

```
ws(s)://server/remote/{device_id}?token={token}&type={type}
```

**Parameters:**
- `device_id`: Unique device identifier
- `token`: Authentication token
- `type`: Either `"device"` or `"controller"`

### Message Types

#### From Device to Server

**WebRTC Offer:**
```json
{
  "type": "webrtc-offer",
  "sdp": "v=0\r\no=- ...",
  "from": "device_id"
}
```

**ICE Candidate:**
```json
{
  "type": "ice-candidate",
  "candidate": {
    "candidate": "...",
    "sdpMLineIndex": 0,
    "sdpMid": "0"
  },
  "from": "device_id"
}
```

#### From Controller to Device

**WebRTC Answer:**
```json
{
  "type": "webrtc-answer",
  "sdp": "v=0\r\no=- ...",
  "to": "device_id"
}
```

**Command:**
```json
{
  "type": "command",
  "action": "touch",
  "x": 540,
  "y": 960,
  "to": "device_id"
}
```

### HTTP Endpoints

#### GET /

Health check.

**Response:**
```json
{
  "status": "online",
  "devices": 5
}
```

#### GET /ping

Ping endpoint.

**Response:**
```json
{
  "status": "ok",
  "message": "pong"
}
```

#### GET /devices

List connected devices.

**Response:**
```json
{
  "devices": [
    {"id": "device_001", "type": "device"},
    {"id": "device_002", "type": "device"}
  ],
  "count": 2
}
```

#### GET /status/{device_id}

Get device connection status.

**Response:**
```json
{
  "device_id": "device_001",
  "connected": true,
  "last_seen": "2026-02-09T10:30:00Z",
  "seconds_since_last_seen": 5.2
}
```

#### POST /command/{device_id}

Send command via HTTP.

**Request Body:**
```json
{
  "action": "vibrate",
  "duration": 500
}
```

**Response:**
```json
{
  "status": "sent",
  "device": "device_001",
  "command": {"action": "vibrate", "duration": 500}
}
```

---

## Error Handling

### Common Exceptions

```dart
try {
  await remoteControl.connect();
} on SocketException {
  // Network error
  print('Check your internet connection');
} on TimeoutException {
  // Connection timeout
  print('Server is not responding');
} on WebSocketException {
  // WebSocket error
  print('WebSocket connection failed');
} catch (e) {
  // Other errors
  print('Unexpected error: $e');
}
```

### Error Codes

| Code | Meaning | Action |
|------|---------|--------|
| `1008` | Policy violation (invalid token) | Check authentication |
| `1009` | Message too large | Reduce payload size |
| `1011` | Server error | Check server logs |

---

## Best Practices

1. **Always dispose**: Call `dispose()` when done
2. **Error handling**: Wrap calls in try-catch
3. **Reconnection**: Implement retry logic for production
4. **Token security**: Never hardcode tokens
5. **Validate commands**: Check command structure before execution
6. **Logging**: Log important events for debugging

---

## Examples

See the [example/](../example/) directory for complete working examples.

---

**Last Updated**: 2026-02-09

