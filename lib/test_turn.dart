import 'dart:developer';
import 'dart:io';

Future<void> testTurnConnectivity(String hostIp, int port) async {
  try {
    final socket = await Socket.connect(
      hostIp,
      port,
      timeout: Duration(seconds: 5),
    );
    await socket.close();
} on SocketException catch (e) {
    log('❌ Error de socket: ${e.message}');
    log('   Código: ${e.osError?.errorCode}');
  } catch (e) {
    log('❌ Error inesperado: $e');
  }
}
