from fastapi import FastAPI, WebSocket, WebSocketDisconnect, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from typing import Dict, List, Optional
import json
import asyncio
import uvicorn
import os
from datetime import datetime, timezone
from starlette.websockets import WebSocketState

# Config
TOKEN = os.environ.get("RC_TOKEN", "your_token_here")
PORT = int(os.environ.get("RC_PORT", "3003"))

app = FastAPI(title="Remote Control Backend (WebRTC signaling)")
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Connection manager
class ConnectionManager:
    def __init__(self):
        # device_id -> websocket (Android device)
        self.devices: Dict[str, WebSocket] = {}
        # device_id -> list of controller websockets
        self.controllers: Dict[str, List[WebSocket]] = {}
        # device_id -> last activity datetime (UTC)
        self.last_seen: Dict[str, datetime] = {}
        # lock
        self.lock = asyncio.Lock()

    async def connect(self, websocket: WebSocket, device_id: str, role: str):
        await websocket.accept()
        now = datetime.now(timezone.utc)
        async with self.lock:
            if role == 'device':
                self.devices[device_id] = websocket
                self.last_seen[device_id] = now
                print(f"✅ Device connected: {device_id}")
            else:
                lst = self.controllers.setdefault(device_id, [])
                lst.append(websocket)
                print(f"✅ Controller connected for {device_id} (controllers: {len(lst)})")

    async def disconnect(self, websocket: WebSocket, device_id: str, role: str):
        async with self.lock:
            if role == 'device':
                if device_id in self.devices and self.devices[device_id] is websocket:
                    del self.devices[device_id]
                    self.last_seen.pop(device_id, None)
                    print(f"❌ Device disconnected: {device_id}")
            else:
                lst = self.controllers.get(device_id)
                if lst and websocket in lst:
                    lst.remove(websocket)
                    print(f"❌ Controller disconnected for {device_id} (remaining: {len(lst)})")
                    if len(lst) == 0:
                        del self.controllers[device_id]

    async def update_last_seen(self, device_id: str):
        now = datetime.now(timezone.utc)
        async with self.lock:
            if device_id in self.devices:
                self.last_seen[device_id] = now

    async def send_to_device(self, device_id: str, message: dict) -> bool:
        async with self.lock:
            ws = self.devices.get(device_id)
            if not ws:
                print(f"⚠️ Device {device_id} not connected")
                return False
            try:
                await ws.send_text(json.dumps(message, ensure_ascii=False))
                # update last seen on successful send
                self.last_seen[device_id] = datetime.now(timezone.utc)
                print(f"📤 Sent to device {device_id}: {message}")
                return True
            except Exception as e:
                print(f"❌ Error sending to device {device_id}: {e}")
                return False

    async def send_to_controllers(self, device_id: str, message: dict):
        async with self.lock:
            lst = list(self.controllers.get(device_id, []))
        for ws in lst:
            try:
                await ws.send_text(json.dumps(message, ensure_ascii=False))
            except Exception as e:
                print(f"❌ Error sending to controller for {device_id}: {e}")

    async def broadcast(self, message: dict):
        # send to all devices and controllers
        async with self.lock:
            devices = list(self.devices.values())
            controllers = [ws for lst in self.controllers.values() for ws in lst]
        for ws in devices + controllers:
            try:
                await ws.send_text(json.dumps(message, ensure_ascii=False))
            except Exception:
                pass

    def list_devices(self):
        return [{'id': did, 'type': 'device'} for did in self.devices.keys()]

    async def is_connected(self, device_id: str) -> bool:
        async with self.lock:
            ws = self.devices.get(device_id)
            if not ws:
                return False
            try:
                return ws.client_state == WebSocketState.CONNECTED
            except Exception:
                # Fallback to presence check
                return device_id in self.devices

    async def get_last_seen(self, device_id: str) -> Optional[datetime]:
        async with self.lock:
            return self.last_seen.get(device_id)

manager = ConnectionManager()

@app.get("/")
async def root():
    return {"status": "online", "devices": len(manager.devices)}

@app.get("/ping")
async def ping():
    return {"status": "ok", "message": "pong"}

@app.get("/devices")
async def devices():
    return {"devices": manager.list_devices(), "count": len(manager.devices)}

@app.get("/status/{device_id}")
async def device_status(device_id: str):
    connected = await manager.is_connected(device_id)
    last_seen_dt = await manager.get_last_seen(device_id)
    last_seen = last_seen_dt.isoformat() if last_seen_dt else None
    seconds_since = None
    if last_seen_dt:
        seconds_since = (datetime.now(timezone.utc) - last_seen_dt).total_seconds()
    return {"device_id": device_id, "connected": connected, "last_seen": last_seen, "seconds_since_last_seen": seconds_since}

@app.websocket("/remote/{device_id}")
async def websocket_endpoint(websocket: WebSocket, device_id: str, token: str, type: str = "device"):
    # simple token auth
#     if token != TOKEN:
#         print(f"❌ Rejecting connection for {device_id}: invalid token")
#         await websocket.close(code=1008, reason="Invalid token")
#         return

    role = type  # 'device' or 'controller'
    await manager.connect(websocket, device_id, role)

    try:
        while True:
            data = await websocket.receive_text()
            # update last seen for device role
            if role == 'device':
                await manager.update_last_seen(device_id)
            try:
                message = json.loads(data)
            except Exception:
                print(f"⚠️ Received non-json message from {device_id}: {data}")
                continue

            msg_type = message.get('type', 'unknown')
            print(f"📨 Message from {device_id} ({role}): {msg_type}")

            if role == 'device':
                # From Android -> forward offers/ice to controllers
                if msg_type in ['webrtc-offer', 'ice-candidate']:
                    await manager.send_to_controllers(device_id, message)
                else:
                    # other device-origin messages broadcast to controllers
                    await manager.send_to_controllers(device_id, message)
            else:
                # From controller web -> handle signaling and commands
                if msg_type in ['webrtc-answer', 'ice-candidate']:
                    await manager.send_to_device(device_id, message)
                elif msg_type == 'command' or message.get('action'):
                    # send command to device and ack back to controller
                    sent = await manager.send_to_device(device_id, message)
                    ack = {'type': 'command_status', 'to': device_id, 'status': 'sent' if sent else 'failed'}
                    try:
                        await websocket.send_text(json.dumps(ack, ensure_ascii=False))
                    except Exception:
                        pass
                else:
                    # Unknown controller message -> forward to device
                    await manager.send_to_device(device_id, message)

    except WebSocketDisconnect:
        print(f"⚠️ WebSocketDisconnect: {device_id} ({role})")
        await manager.disconnect(websocket, device_id, role)
    except Exception as e:
        print(f"❌ WebSocket error for {device_id} ({role}): {e}")
        await manager.disconnect(websocket, device_id, role)

@app.post("/command/{device_id}")
async def http_send_command(device_id: str, command: dict):
    message = {'type': 'command', **command}
    sent = await manager.send_to_device(device_id, message)
    if not sent:
        raise HTTPException(status_code=404, detail="Device not connected")
    return {"status": "sent", "device": device_id, "command": command}

@app.post("/test/stream/{device_id}")
async def test_stream(device_id: str, start: bool = True):
    action = 'startStream' if start else 'stopStream'
    message = {'type': 'command', 'action': action}
    sent = await manager.send_to_device(device_id, message)
    return {"status": "sent" if sent else "failed", "device": device_id}

if __name__ == "__main__":
    import socket
    hostname = socket.gethostname()
    local_ip = socket.gethostbyname(hostname)
    print("="*60)
    print("Remote Control Backend starting")
    print(f"Listening on 0.0.0.0:{PORT}, token={TOKEN}")
    print(f"Local IP detected: {local_ip}")
    print("="*60)
    uvicorn.run("backend_server:app", host="0.0.0.0", port=PORT, log_level="info")
