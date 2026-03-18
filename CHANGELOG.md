# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.0.1] - 2026-03-18

### 🎉 Initial Release

#### Added
- WebSocket connection for real-time bidirectional communication
- WebRTC screen capture with MediaProjection API
- Accessibility Service for remote control (touch, swipe, text input)
- Device Admin support for lock/wipe features (optional)
- Token-based authentication
- TURN server support for NAT traversal
- Auto-reconnection with robust lifecycle management
- Inactivity timeout handling
- Custom command system
- Native bridge for Android platform features
- Foreground service for screen capture
- Stream-based command notification system

#### Features
- `RemoteControl` class with connect/reconnect/dispose lifecycle
- `NativeBridge` for native Android functionality:
  - Screen capture control
  - Accessibility service management
  - Device admin operations
  - Touch/swipe/text input simulation
  - System button actions (back, home, recents)
- Signaling server backend (Python/FastAPI)
- Docker support for backend deployment
- Comprehensive error handling and logging

#### Documentation
- README.md with quick start and examples
- PERMISSIONS.md with security guidance
- USAGE_GUIDE.md with detailed use cases
- LIFECYCLE_PATTERN.md explaining state management
- XML resource templates for accessibility and device admin

#### Platform Support
- Android (minSdk 24 / Android 7.0+)
- iOS: Not supported (planned for future release)

#### Dependencies
- flutter_webrtc: ^1.3.0
- web_socket_channel: ^3.0.3
- permission_handler: ^12.0.1
- http: ^1.6.0
- device_info_plus: ^12.3.0
- android_intent_plus: ^6.0.0

### 🔒 Security
- Minimal plugin manifest (only INTERNET permission)
- Sensitive permissions moved to host app
- Token authentication support
- WSS (secure WebSocket) recommended
- Comprehensive security documentation

### Known Limitations
- Android only (iOS not yet implemented)
- Accessibility service requires manual user enablement
- Device admin features require user activation
- TURN server must be configured separately

## [Unreleased]

### Planned Features
- iOS support
- End-to-end encryption for commands
- Multi-device connection management
- Screen recording to file
- Gesture recording and replay
- Biometric authentication integration
- OAuth2 support for backend

---

## Version History

- **0.0.1** (2026-02-09): Initial release

