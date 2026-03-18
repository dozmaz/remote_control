# Backend (ejemplo) — remote_control

Este directorio contiene los componentes de ejemplo que actúan como backend/signaling para la aplicación `remote_control`.

Archivos principales
- `backend_server.py`: ejemplo de backend (servidor de signaling WebRTC y WebSocket) escrito con FastAPI.
- `docker-compose.yml`: archivo de ejemplo para levantar un servicio Coturn (TURN server) usado para NAT traversal en conexiones WebRTC.

Este README documenta qué hace cada archivo, cómo ejecutarlos localmente y notas de seguridad y solución de problemas.

---

## backend_server.py — resumen

`backend_server.py` es el backend de ejemplo incluido en este repositorio. Su propósito principal es proporcionar:

- Un servidor de signaling WebRTC basado en WebSocket para la comunicación entre el dispositivo Android (role `device`) y el controlador (role `controller`).
- Endpoints HTTP de respaldo para enviar comandos y consultar el estado de dispositivos.

Principales características observables en el código:
- Framework: FastAPI
- Soporte WebSocket en `/remote/{device_id}` con parámetro `token` y `type` (por defecto `device`).
- Endpoints HTTP:
  - `GET /` - estado general
  - `GET /ping` - salud
  - `GET /devices` - lista de dispositivos conectados
  - `GET /status/{device_id}` - estado (connected, last_seen)
  - `POST /command/{device_id}` - enviar comando HTTP al dispositivo
  - `POST /test/stream/{device_id}` - endpoint de prueba para iniciar/detener stream
- Administración de conexiones en memoria (clase `ConnectionManager`): mantiene websockets de devices y controllers, envía mensajes entre ellos y almacena `last_seen`.
- Variables de entorno soportadas:
  - `RC_TOKEN` — token de autenticación simple (por defecto `your_token_here` en el código)
  - `RC_PORT` — puerto donde escucha el servidor (por defecto `3003` en el código)

Ejecución (modo desarrollo)

Se puede ejecutar de dos formas principales:

- Ejecutando directamente el script (usa `uvicorn.run(...)` en el bloque `if __name__ == "__main__"`):

PowerShell:

```powershell
$env:RC_TOKEN = "mi_token_seguro"
$env:RC_PORT = "3003"
python backend_server.py
```

CMD (Windows):

```cmd
set RC_TOKEN=mi_token_seguro
set RC_PORT=3003
python backend_server.py
```

- Usando `uvicorn` directamente (útil para desarrollo o deploy):

PowerShell / CMD:

```powershell
$env:RC_TOKEN = "mi_token_seguro"
uvicorn backend_server:app --host 0.0.0.0 --port 3003 --log-level info
```

Notas:
- Asegúrate de instalar las dependencias (p. ej. `fastapi`, `uvicorn`). Ver sección Dependencias.
- El servidor realiza autenticación por token en el código comentado; por ahora la comprobación está desactivada (líneas comentadas). Si quieres activar la verificación, descomenta el bloque donde compara `token` con `TOKEN`.

Pruebas rápidas de endpoints

- Estado general:

```bash
curl http://localhost:3003/ping
# -> {"status":"ok","message":"pong"}
```

- Lista de dispositivos:

```bash
curl http://localhost:3003/devices
```

- Estado de un dispositivo:

```bash
curl http://localhost:3003/status/DEVICE_ID
```

Probar WebSocket

- Cliente `controller` se conecta a: `ws://<server>:<port>/remote/<device_id>?token=<token>&type=controller`
- `device` se conecta a: `ws://<server>:<port>/remote/<device_id>?token=<token>&type=device`

Puedes usar herramientas como `wscat` (npm) o `websocat` para pruebas manuales.

---

## docker-compose.yml — Coturn (TURN server)

El archivo `docker-compose.yml` en este directorio define un servicio `coturn` usando la imagen `coturn/coturn:latest`. Coturn se utiliza como servidor TURN para facilitar NAT traversal de WebRTC cuando no es posible establecer conexión P2P directa.

Contenido relevante (resumen):
- Imagen: `coturn/coturn:latest`
- Nombre del contenedor: `coturn-server`
- Puertos expuestos (host:container):
  - `3478:3478/udp`  (UDP TURN/STUN)
  - `3478:3478/tcp`  (TCP TURN)
  - `5349:5349/tcp`  (TLS TURN — requiere certificados en producción)
  - `5766:5766/tcp`  (opcional, usado por la imagen)
  - `49152-49200:49152-49200/udp` (rango de puertos para datos RTP/RTCP)
- Comandos pasados al contenedor (ejemplo del archivo):
  - `--lt-cred-mech` habilita long-term authentication
  - `--user=remotecontrol:r3m0t3-c0ntr0l+123` usuario/contraseña preconfigurados
  - `--realm=remotecontrol` dominio/realm del servidor
  - `--external-ip=192.168.100.212` dirección IP externa (debe ajustarse a su entorno)

Nota importante sobre credenciales y `external-ip`:
- El `docker-compose.yml` de ejemplo incluye una credencial preconfigurada (`remotecontrol` / `r3m0t3-c0ntr0l+123`). Esto es solo para ejemplo y pruebas locales; no lo uses en producción.
- `--external-ip` debe apuntar a la IP pública (o dejar vacío si el contenedor obtiene ip correctamente). En entornos con NAT/Cloud, debes reemplazar `192.168.100.212` por la IP pública o configurar correctamente la red.

Cómo levantar el servicio

Desde el directorio `backend` (donde está `docker-compose.yml`):

PowerShell / CMD:

```powershell
# Levantar en background
docker-compose up -d

# Ver logs
docker-compose logs -f coturn

# Parar y remover
docker-compose down
```

Si usas Docker Desktop en Windows asegúrate de que Docker esté corriendo y que los puertos no estén bloqueados por firewall.

Uso desde la aplicación (ejemplo)

En la configuración del cliente WebRTC (lado controlador o dispositivo) debes pasar las credenciales TURN cuando solicites iceServers. Por ejemplo (pseudo-dart):

```dart
final iceServers = [
  {
    'urls': ['turn:YOUR_TURN_HOST:3478'],
    'username': 'remotecontrol',
    'credential': 'r3m0t3-c0ntr0l+123',
  }
];
```

De nuevo: reemplaza `YOUR_TURN_HOST` por la IP pública o el hostname de tu servidor Coturn y cambia usuario/contraseña por credenciales seguras.

---

## Dependencias

Para ejecutar `backend_server.py` necesitas (mínimo):

- Python 3.8+ (probablemente 3.10+ recomendado)
- fastapi
- uvicorn
- starlette (ya viene con fastapi)

Instalación rápida (venv recomendado):

PowerShell:

```powershell
python -m venv .venv
.\.venv\Scripts\Activate.ps1
pip install --upgrade pip
pip install fastapi uvicorn
```

CMD:

```cmd
python -m venv .venv
.\.venv\Scripts\activate
pip install --upgrade pip
pip install fastapi uvicorn
```

Si prefieres un `requirements.txt`, crea uno con:

```
fastapi
uvicorn
```

---

## Notas de seguridad y producción

- No incluyas credenciales en el repositorio. Usa variables de entorno, Docker secrets o un gestor de secretos.
- Protege el endpoint WebSocket con TLS (https/wss) en producción y exige autenticación robusta.
- Coturn en producción debe configurarse con certificados (para TLS 5349) y con credenciales seguras.
- Limita el acceso por IP si es posible y monitoriza logs para intentos de acceso no autorizados.

---

## Solución de problemas rápida

- "No puedo conectar al servidor WebSocket": asegúrate de que `backend_server.py` está corriendo y que el puerto está abierto (firewall). Prueba `curl http://<host>:<port>/ping`.
- "TURN no funciona / no llega el tráfico de media": confirme `external-ip` en `docker-compose.yml`, que los puertos UDP 3478 y el rango 49152-49200 estén abiertos/forwardeados.
- "Credenciales inválidas": revisa el usuario/contraseña configurado en Coturn y la configuración de iceServers del cliente.
- Revisa logs del contenedor Coturn con `docker-compose logs -f coturn`.

---

## Verificación rápida

- Desde la raíz del repo, el `README.md` ya apunta a `./backend/README.md` por lo que, al crear este archivo, los enlaces deberían funcionar en la vista del repositorio.
- Puedes abrir `backend/README.md` en tu editor o en GitHub para verificar el renderizado Markdown.

---

Si quieres, puedo:
- Añadir ejemplos concretos de llamadas WebSocket usando `wscat`/`websocat`.
- Mover las credenciales actuales del `docker-compose.yml` a variables de entorno y mostrar cómo consumirlas.
- Añadir un `requirements.txt` o `pyproject.toml` de ejemplo para gestión de dependencias.

Dime qué prefieres y hago los cambios.
