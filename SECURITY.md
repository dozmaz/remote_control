# Security Policy

## 🔒 Supported Versions

| Version | Supported          |
| ------- | ------------------ |
| 1.0.0   | :white_check_mark: |

## 🚨 Reporting a Vulnerability

We take security seriously. If you discover a security vulnerability in this plugin, please follow responsible disclosure practices:

### How to Report

**DO NOT** create a public GitHub issue for security vulnerabilities.

Instead, please report security issues via:

1. **Email**: security@yourcompany.com (preferred)
2. **GitHub Security Advisory**: Use the "Security" tab to privately report vulnerabilities

### What to Include

Please provide as much information as possible:

- Description of the vulnerability
- Steps to reproduce the issue
- Potential impact and attack scenarios
- Any proof-of-concept code (if applicable)
- Suggested fixes (if you have ideas)

### Response Timeline

- **Initial Response**: Within 48 hours
- **Status Update**: Within 7 days
- **Fix Timeline**: Depends on severity (critical issues prioritized)

### Disclosure Policy

- We will acknowledge receipt of your report within 48 hours
- We will provide regular updates on our progress
- We will credit you in the security advisory (unless you prefer to remain anonymous)
- We request you wait for our fix before public disclosure (coordinated disclosure)

## 🛡️ Security Considerations

### Known Security Risks

This plugin enables remote control of Android devices, which inherently carries security risks:

#### HIGH RISK

1. **Accessibility Service Abuse**
   - Can read all screen content
   - Can perform any user action
   - **Mitigation**: Only enable for trusted remote users

2. **Device Admin Abuse**
   - Can lock device
   - Can wipe all data
   - **Mitigation**: Only use in enterprise/MDM scenarios with explicit consent

3. **Unauthorized Remote Access**
   - Weak token authentication
   - No encryption on commands
   - **Mitigation**: Use strong tokens, implement WSS, add server-side authorization

#### MEDIUM RISK

4. **Man-in-the-Middle Attacks**
   - WebSocket traffic interception
   - **Mitigation**: Always use WSS (wss://) with valid TLS certificates

5. **Token Exposure**
   - Hardcoded tokens in code
   - Tokens in logs or URLs
   - **Mitigation**: Use secure storage, never log tokens, use Authorization headers

6. **Command Injection**
   - Malicious commands from compromised server
   - **Mitigation**: Validate all commands client-side, implement rate limiting

### Security Best Practices

#### For Plugin Users

1. **Authentication**
   ```dart
   // ❌ BAD: Hardcoded token
   final remoteControl = RemoteControl(
     token: 'my_secret_token',  // ❌ Never do this
   );
   
   // ✅ GOOD: Secure storage
   import 'package:flutter_secure_storage/flutter_secure_storage.dart';
   
   final storage = FlutterSecureStorage();
   final token = await storage.read(key: 'remote_control_token');
   final remoteControl = RemoteControl(
     token: token!,
     serverUrl: 'wss://secure-server.com',  // Always use wss://
   );
   ```

2. **Command Validation**
   ```dart
   remoteControl.onCustomCommand.listen((command) {
     // Validate command structure
     if (!command.containsKey('action') || !command.containsKey('timestamp')) {
       print('⚠️ Rejected malformed command');
       return;
     }
     
     // Whitelist allowed commands
     const allowedCommands = ['vibrate', 'notification', 'getData'];
     if (!allowedCommands.contains(command['action'])) {
       print('⚠️ Rejected unauthorized command: ${command['action']}');
       return;
     }
     
     // Check timestamp to prevent replay attacks
     final timestamp = DateTime.parse(command['timestamp']);
     if (DateTime.now().difference(timestamp) > Duration(minutes: 5)) {
       print('⚠️ Rejected expired command');
       return;
     }
     
     // Execute validated command
     executeCommand(command);
   });
   ```

3. **Minimize Permissions**
   ```xml
   <!-- Only declare permissions you actually use -->
   <uses-permission android:name="android.permission.INTERNET" />
   <uses-permission android:name="android.permission.FOREGROUND_SERVICE" />
   <!-- Don't include BIND_DEVICE_ADMIN unless you really need it -->
   ```

4. **User Consent**
   ```dart
   // Always explain before requesting accessibility
   await showDialog(
     context: context,
     builder: (context) => AlertDialog(
       title: Text('Enable Remote Control?'),
       content: Text(
         'This will allow remote users to control your device. '
         'Only enable this if you trust the remote user.\n\n'
         'Remote users will be able to:\n'
         '• See your screen\n'
         '• Tap and swipe\n'
         '• Enter text\n'
         '• Use back/home buttons'
       ),
       // ... action buttons
     ),
   );
   ```

#### For Backend Developers

1. **Server-Side Token Validation**
   ```python
   # backend_server.py
   
   @app.websocket("/remote/{device_id}")
   async def websocket_endpoint(websocket: WebSocket, device_id: str, token: str):
       # ALWAYS validate token
       if not validate_token(token, device_id):
           await websocket.close(code=1008, reason="Invalid token")
           return
       
       # Additional checks
       if not is_device_authorized(device_id):
           await websocket.close(code=1008, reason="Unauthorized device")
           return
       
       # Check rate limiting
       if is_rate_limited(device_id):
           await websocket.close(code=1008, reason="Rate limit exceeded")
           return
       
       # Accept connection
       await manager.connect(websocket, device_id, 'device')
   ```

2. **CORS Configuration**
   ```python
   # Don't use allow_origins=["*"] in production!
   app.add_middleware(
       CORSMiddleware,
       allow_origins=["https://trusted-domain.com"],  # Specific domains only
       allow_credentials=True,
       allow_methods=["GET", "POST"],
       allow_headers=["Authorization", "Content-Type"],
   )
   ```

3. **Rate Limiting**
   ```python
   from collections import defaultdict
   from time import time
   
   connection_attempts = defaultdict(list)
   
   def is_rate_limited(device_id: str, max_attempts=5, window=60):
       now = time()
       attempts = connection_attempts[device_id]
       
       # Remove old attempts outside window
       attempts[:] = [t for t in attempts if now - t < window]
       
       if len(attempts) >= max_attempts:
           return True
       
       attempts.append(now)
       return False
   ```

4. **Input Validation**
   ```python
   def validate_command(command: dict) -> bool:
       # Whitelist allowed command types
       allowed_types = ['command', 'webrtc-answer', 'ice-candidate']
       if command.get('type') not in allowed_types:
           return False
       
       # Validate command structure
       if command.get('type') == 'command':
           if 'action' not in command:
               return False
           
           # Whitelist allowed actions
           allowed_actions = ['startStream', 'stopStream', 'vibrate']
           if command['action'] not in allowed_actions:
               return False
       
       return True
   ```

### Security Checklist

Before deploying to production:

- [ ] All WebSocket connections use WSS (not WS)
- [ ] HTTPS used for all HTTP endpoints
- [ ] Valid TLS certificates (not self-signed)
- [ ] Token authentication enabled on backend
- [ ] Tokens stored in secure storage (not hardcoded)
- [ ] CORS configured with specific allowed origins
- [ ] Rate limiting implemented on backend
- [ ] Command validation on both client and server
- [ ] Accessibility service usage explained to users
- [ ] Device admin only used if absolutely necessary
- [ ] Privacy policy includes all sensitive permissions
- [ ] Logging doesn't expose tokens or sensitive data
- [ ] Regular dependency updates for security patches

## 🔍 Security Auditing

### Self-Audit Questions

1. **Authentication**: Can an attacker connect without a valid token?
2. **Authorization**: Can an attacker control devices they shouldn't?
3. **Encryption**: Are all connections encrypted (WSS/HTTPS)?
4. **Input Validation**: Are commands validated before execution?
5. **Rate Limiting**: Can an attacker spam connections/commands?
6. **Permissions**: Are only necessary permissions declared?
7. **Token Storage**: Are tokens stored securely?
8. **Logging**: Are tokens/sensitive data logged?

### Automated Tools

Consider using these tools for security scanning:

- **Dart/Flutter**: `flutter analyze`, `dart analyze`
- **Android**: Android Studio's built-in security checks
- **Dependencies**: `flutter pub outdated`, vulnerability scanners
- **Backend**: `bandit` (Python), `safety` (dependencies)

### Regular Security Tasks

- [ ] Review dependencies quarterly for known vulnerabilities
- [ ] Test with OWASP Mobile Security Testing Guide
- [ ] Conduct penetration testing before major releases
- [ ] Review logs for suspicious activity
- [ ] Rotate tokens regularly
- [ ] Update TLS certificates before expiration

## 📚 Resources

- [OWASP Mobile Security](https://owasp.org/www-project-mobile-security/)
- [Android Security Best Practices](https://developer.android.com/topic/security/best-practices)
- [WebRTC Security](https://webrtc-security.github.io/)
- [Flutter Security](https://flutter.dev/docs/deployment/security)

## 📞 Contact

For security-related inquiries:

- **Email**: security@yourcompany.com
- **GitHub**: Use Security Advisory for private reports
- **PGP Key**: [Link to PGP public key if available]

## 🙏 Hall of Fame

We appreciate security researchers who help make this project safer:

<!-- Contributors who report vulnerabilities will be listed here -->
- [Your name here] - Report #1 - [Date]

---

**Last Updated**: 2026-02-09

