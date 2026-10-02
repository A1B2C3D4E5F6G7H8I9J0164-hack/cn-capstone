#!/usr/bin/env python3
"""
Backend Application Server Instance A
Team Member: Rachit Gupta (Mac 3)
Role: Backend Application Server A
Host IP: 10.7.22.10
Port: 3001
"""

import json
from http.server import HTTPServer, BaseHTTPRequestHandler

HOST = "0.0.0.0"
PORT = 3001
BACKEND_ID = "A"
ETAG_VALUE = '"A-v1"'

class BackendHandler(BaseHTTPRequestHandler):
    server_version = "BackendServer-A/1.0"

    def do_GET(self):
        # Support conditional caching requests (Task F)
        client_etag = self.headers.get("If-None-Match")
        if client_etag == ETAG_VALUE:
            self.send_response(304)
            self.send_header("ETag", ETAG_VALUE)
            self.send_header("Cache-Control", "max-age=60")
            self.send_header("X-Backend", BACKEND_ID)
            self.end_headers()
            return

        if self.path == "/" or self.path == "":
            response_data = {
                "backend": BACKEND_ID,
                "status": "ok",
                "service": "cn-project"
            }
        elif self.path == "/api/status":
            response_data = {
                "backend": BACKEND_ID,
                "status": "ok"
            }
        else:
            self.send_response(404)
            self.send_header("Content-Type", "application/json")
            self.end_headers()
            self.wfile.write(json.dumps({"error": "not found"}).encode("utf-8"))
            return

        body = json.dumps(response_data).encode("utf-8")
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Connection", "keep-alive")
        self.send_header("Cache-Control", "max-age=60")
        self.send_header("ETag", ETAG_VALUE)
        self.send_header("X-Backend", BACKEND_ID)
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, format, *args):
        print(f"[{BACKEND_ID}] {self.address_string()} - {format % args}")

def run():
    server = HTTPServer((HOST, PORT), BackendHandler)
    print(f"Backend A running on http://{HOST}:{PORT}")
    print(f"Machine: Mac 3 | Member: Rachit Gupta | Bound to: 0.0.0.0:{PORT}")
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\nStopping Backend A...")
        server.server_close()

if __name__ == "__main__":
    run()
