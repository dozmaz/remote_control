# remote_control_example

This directory contains two interactive examples demonstrating the features of the `remote_control` plugin.

## Example Apps

### 1. Basic Plugin Test (`lib/main.dart`)
A straightforward example exposing basic functions like starting screen capture, connecting, and manually dispatching functions.

To run:
```bash
flutter run
```

### 2. Robust Example (`lib/reconnect_example.dart`)
An advanced implementation showing how to properly handle connectivity state, auto-reconnection loops, custom server command handling, and event logging.

To run:
```bash
flutter run -t lib/reconnect_example.dart
```
