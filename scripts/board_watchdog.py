#!/usr/bin/env python3
import json
import os
import time
import urllib.parse
import urllib.request
from datetime import datetime

API_BASE = os.getenv("MC_API_BASE", "http://127.0.0.1:8000/api/v1")
TOKEN = os.getenv("MC_TOKEN", "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef")
BOARD_ID = os.getenv("MC_BOARD_ID", "a9375778-e3d9-4f80-aa09-dbb73533bcfe")
GATEWAY_ID = os.getenv("MC_GATEWAY_ID", "07bc56e2-15b4-446e-9834-e771901cbcac")
INTERVAL = int(os.getenv("MC_WATCHDOG_INTERVAL", "60"))
SYNC_COOLDOWN = int(os.getenv("MC_SYNC_COOLDOWN", "180"))

HEADERS = {
    "Authorization": f"Bearer {TOKEN}",
    "Content-Type": "application/json",
}


def ts():
    return datetime.now().strftime("%Y-%m-%d %H:%M:%S")


def request_json(method: str, path: str, data: dict | None = None):
    url = f"{API_BASE}{path}"
    body = None if data is None else json.dumps(data).encode()
    req = urllib.request.Request(url, data=body, headers=HEADERS, method=method)
    with urllib.request.urlopen(req, timeout=20) as resp:
        raw = resp.read().decode() or "{}"
        return json.loads(raw)


def main():
    print(f"[{ts()}] watchdog start board={BOARD_ID}", flush=True)
    last_sync = 0.0
    while True:
        try:
            agents = request_json("GET", "/agents").get("items", [])
            board_agents = [a for a in agents if a.get("board_id") == BOARD_ID]
            unhealthy = [
                a for a in board_agents
                if a.get("status") in {"offline", "provisioning", "updating", "error"}
            ]

            if unhealthy:
                names = ", ".join(f"{a.get('name')}:{a.get('status')}" for a in unhealthy)
                print(f"[{ts()}] unhealthy -> {names}", flush=True)

                now = time.time()
                if now - last_sync >= SYNC_COOLDOWN:
                    q = urllib.parse.urlencode({
                        "include_main": "true",
                        "board_id": BOARD_ID,
                        "reset_sessions": "true",
                        "force_bootstrap": "true",
                        "rotate_tokens": "true",
                    })
                    sync_path = f"/gateways/{GATEWAY_ID}/templates/sync?{q}"
                    sync_resp = request_json("POST", sync_path)
                    print(f"[{ts()}] sync -> updated={sync_resp.get('agents_updated')} skipped={sync_resp.get('agents_skipped')} errors={len(sync_resp.get('errors', []))}", flush=True)
                    last_sync = now

                for a in unhealthy:
                    aid = a["id"]
                    hb = request_json("POST", f"/agents/{aid}/heartbeat", {"status": "healthy"})
                    print(f"[{ts()}] heartbeat {hb.get('name')} -> {hb.get('status')}", flush=True)
            else:
                print(f"[{ts()}] healthy: {len(board_agents)} board agents", flush=True)

        except Exception as e:
            print(f"[{ts()}] watchdog error: {e}", flush=True)

        time.sleep(INTERVAL)


if __name__ == "__main__":
    main()
