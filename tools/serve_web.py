#!/usr/bin/env python3
"""Serve the Galactic Fishing Co. web export over Tailscale.

Usage: python3 tools/serve_web.py [port] [build_dir]
Serves with the COOP/COEP headers Godot web exports may need, plus
correct MIME types for .wasm/.pck. Binds to the Tailscale interface so
Alan's devices on the tailnet can reach it.

Run in background: nohup python3 tools/serve_web.py 8903 > /tmp/gfc-web.log 2>&1 &
"""
import functools
import http.server
import sys

PORT = int(sys.argv[1]) if len(sys.argv) > 1 else 8903
BUILD_DIR = sys.argv[2] if len(sys.argv) > 2 else "build/web"
HOST = "100.70.89.32"  # pc-wsl Tailscale IP


class Handler(http.server.SimpleHTTPRequestHandler):
    def end_headers(self):
        # Required for Godot web exports that use SharedArrayBuffer (threaded builds).
        # Harmless for single-threaded builds.
        self.send_header("Cross-Origin-Opener-Policy", "same-origin")
        self.send_header("Cross-Origin-Embedder-Policy", "require-corp")
        super().end_headers()

    def log_message(self, *args):
        pass  # quiet


Handler.extensions_map.update({
    ".wasm": "application/wasm",
    ".pck": "application/octet-stream",
    ".js": "application/javascript",
})


if __name__ == "__main__":
    handler = functools.partial(Handler, directory=BUILD_DIR)
    with http.server.ThreadingHTTPServer((HOST, PORT), handler) as srv:
        print("Serving %s at http://%s:%d/" % (BUILD_DIR, HOST, PORT), flush=True)
        srv.serve_forever()
