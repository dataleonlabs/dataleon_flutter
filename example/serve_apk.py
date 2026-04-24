#!/usr/bin/env python3
"""Simple HTTP server that serves the APK with correct MIME type."""
import http.server
import os

PORT = 9090
APK_PATH = "/data/dataleon_flutter/example/build/app/outputs/flutter-apk/app-debug.apk"

class APKHandler(http.server.BaseHTTPRequestHandler):
    def do_GET(self, *args, **kwargs):
        if self.path == "/" or self.path == "/download":
            self.send_response(200)
            self.send_header("Content-Type", "application/vnd.android.package-archive")
            self.send_header("Content-Disposition", 'attachment; filename="dataleon-example.apk"')
            file_size = os.path.getsize(APK_PATH)
            self.send_header("Content-Length", str(file_size))
            self.end_headers()
            with open(APK_PATH, "rb") as f:
                self.wfile.write(f.read())
        else:
            self.send_response(404)
            self.end_headers()

if __name__ == "__main__":
    server = http.server.HTTPServer(("0.0.0.0", PORT), APKHandler)
    print(f"APK download ready at http://0.0.0.0:{PORT}/download")
    server.serve_forever()
