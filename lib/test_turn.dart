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
    print('❌ Error de socket: ${e.message}');
    print('   Código: ${e.osError?.errorCode}');
  } catch (e) {
    print('❌ Error inesperado: $e');
  }
}
