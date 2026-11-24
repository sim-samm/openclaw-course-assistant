#!/usr/bin/env python3
"""Google Generative AI URL-rewrite proxy.

Workaround for the OpenClaw 2026.5.19 baked-in alias map that forces
    google/gemini-3.1-flash-lite -> google/gemini-3.1-flash-lite-preview
The "-preview" model is retired by Google (404 NOT_FOUND), but OpenClaw
issues the request anyway because the rewrite happens at runtime inside
the gateway binary, ahead of provider config and ahead of
`agents.defaults.models[...].params.model`.

This proxy intercepts the outbound HTTP request, rewrites the retired
"-preview" segment back to the stable id in the URL path, and forwards
to the real Google API host. Other paths pass through unchanged.

Wire-up:
- OpenClaw config: models.providers.google.baseUrl = "http://google-genai-proxy:8788"
- Deploy: ./gcp/vm/setup-google-genai-proxy.sh (sidecar on openclaw_default)
- See docs/MODEL_RECOVERY_PLAN.md "OpenClaw 2026.5.19 normalization bug".

Stdlib only (no pip install) -- runs on python:3.11-slim out of the box.
"""

import http.server
import socketserver
import sys
import urllib.error
import urllib.request

UPSTREAM_SCHEME = "https"
UPSTREAM_HOST = "generativelanguage.googleapis.com"
LISTEN_PORT_DEFAULT = 8788

# Path-segment rewrites applied before forwarding.
REWRITES = [
    ("gemini-3.1-flash-lite-preview", "gemini-3.1-flash-lite"),
]

# RFC 7230 hop-by-hop headers + a few request/response framers we manage ourselves.
HOP_HEADERS = {
    "connection",
    "content-encoding",
    "content-length",
    "host",
    "keep-alive",
    "proxy-authenticate",
    "proxy-authorization",
    "te",
    "trailers",
    "transfer-encoding",
    "upgrade",
}


def rewrite_path(path):
    """Apply both fixes:

    1) Substitute the OpenClaw-emitted retired `-preview` segment with the
       stable Google model id (the user-visible bug).
    2) Prepend `/v1beta` when missing (the secondary OpenClaw bug: its
       google-generative-ai provider issues `streamGenerateContent` with a
       bare `/models/...` path; only the non-stream `:generateContent` path
       includes `/v1beta/`). Google rejects bare `/models/` with 404.
    """
    notes = []
    for old, new in REWRITES:
        if old in path:
            path = path.replace(old, new)
            notes.append("%s->%s" % (old, new))
    if path.startswith("/models/"):
        path = "/v1beta" + path
        notes.append("prefix-v1beta")
    return path, notes


class Handler(http.server.BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"
    server_version = "OpenClawGenaiProxy/1.0"

    def _proxy(self):
        try:
            length = int(self.headers.get("Content-Length", "0") or 0)
            body = self.rfile.read(length) if length > 0 else None
            new_path, notes = rewrite_path(self.path)
            if notes:
                self.log_message("rewrite %s notes=%s", new_path.split("?", 1)[0], ",".join(notes))

            target = "%s://%s%s" % (UPSTREAM_SCHEME, UPSTREAM_HOST, new_path)
            req = urllib.request.Request(target, data=body, method=self.command)
            for k, v in self.headers.items():
                if k.lower() in HOP_HEADERS:
                    continue
                req.add_header(k, v)
            req.add_header("Host", UPSTREAM_HOST)

            try:
                resp = urllib.request.urlopen(req, timeout=120)
                status = resp.status
                resp_headers = resp.headers
            except urllib.error.HTTPError as e:
                status = e.code
                resp = e
                resp_headers = e.headers

            self.send_response(status)
            for k, v in resp_headers.items():
                if k.lower() in HOP_HEADERS:
                    continue
                self.send_header(k, v)
            self.send_header("Transfer-Encoding", "chunked")
            self.end_headers()

            while True:
                chunk = resp.read(8192)
                if not chunk:
                    break
                self.wfile.write(b"%x\r\n" % len(chunk))
                self.wfile.write(chunk)
                self.wfile.write(b"\r\n")
                self.wfile.flush()
            self.wfile.write(b"0\r\n\r\n")
            self.wfile.flush()
        except Exception as e:
            try:
                self.send_error(502, "proxy error: %s" % e)
            except Exception:
                pass

    do_GET = _proxy
    do_POST = _proxy
    do_PUT = _proxy
    do_PATCH = _proxy
    do_DELETE = _proxy
    do_OPTIONS = _proxy

    def log_message(self, fmt, *args):
        sys.stderr.write("[proxy] " + (fmt % args) + "\n")
        sys.stderr.flush()


class ThreadedHTTPServer(socketserver.ThreadingMixIn, http.server.HTTPServer):
    daemon_threads = True
    allow_reuse_address = True


def main():
    port = int(sys.argv[1]) if len(sys.argv) > 1 else LISTEN_PORT_DEFAULT
    print("[proxy] listening 0.0.0.0:%d -> %s://%s" % (port, UPSTREAM_SCHEME, UPSTREAM_HOST), flush=True)
    for old, new in REWRITES:
        print("[proxy] rewrite: %s -> %s" % (old, new), flush=True)
    ThreadedHTTPServer(("0.0.0.0", port), Handler).serve_forever()


if __name__ == "__main__":
    main()
