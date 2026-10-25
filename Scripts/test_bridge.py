#!/usr/bin/env python3
"""Integration test of the real Swift listener. No music apps or external network needed."""
import http.client
import json
from pathlib import Path
import socket
import subprocess
import time

ROOT = Path(__file__).resolve().parent.parent
BUILD = ROOT / "build" / "bridge-tests"
BUILD.mkdir(parents=True, exist_ok=True)
TOKEN = "a" * 64
harness = BUILD / "Harness.swift"
harness.write_text(r'''import Foundation
import Network
@main struct Harness {
    static func main() {
        let bridge = BrowserBridge(port: 48538)
        bridge.onStatus = { status in fputs("\(status)\n", stderr) }
        bridge.onPlayback = { track in
            print(track?.title ?? "EMPTY"); fflush(stdout)
        }
        bridge.start(token: String(repeating: "a", count: 64))
        withExtendedLifetime(bridge) { dispatchMain() }
    }
}
''')
subprocess.run(["xcrun", "swiftc", "-swift-version", "5", "-parse-as-library",
                "-module-cache-path", str(ROOT / "build/module-cache"),
                *[str(p) for p in sorted((ROOT / "Songcrumb/Core").glob("*.swift"))], str(ROOT / "Songcrumb/App/BrowserBridge.swift"),
                str(harness), "-o", str(BUILD / "Harness")], check=True)
process = subprocess.Popen([str(BUILD / "Harness")], stdout=subprocess.PIPE, text=True)
try:
    for _ in range(80):
        try:
            with socket.create_connection(("127.0.0.1", 48538), timeout=.1): break
        except OSError: time.sleep(.05)
    else: raise AssertionError("Listener did not start")
    packet = dict(trackID="fixture", title="Fixture song", artist="Songcrumb", album="Test", duration=100,
                  position=20, playing=True, rate=1, valid=True)
    def post(payload, token=TOKEN, origin=None, path="/v1/playback"):
        headers = {"Content-Type": "application/json", "Authorization": "Bearer " + token}
        if origin: headers["Origin"] = origin
        connection = http.client.HTTPConnection("127.0.0.1", 48538, timeout=3)
        connection.request("POST", path, json.dumps(payload), headers)
        response = connection.getresponse(); status = response.status
        response.read(); connection.close()
        return status
    assert post(packet) == 200
    assert process.stdout.readline().strip() == "Fixture song"
    assert post(packet, token="wrong") == 403
    assert post(packet, origin="https://malicious.example") == 403
    assert post(packet, origin="chrome-extension://abcdefghijklmnopabcdefghijklmnop") == 200
    assert process.stdout.readline().strip() == "Fixture song"
    assert post(packet, path="/other") == 400
    assert post({**packet, "position": -1}) == 422
    assert post({**packet, "rate": 99}) == 422
    assert post({**packet, "valid": False}) == 200
    assert process.stdout.readline().strip() == "EMPTY"
    assert post({**packet, "title": "x" * 20_000}) in (400, 413)
    print("Bridge integration: 9 checks passed (pairing, origin, validation, routing, size limit).")
finally:
    process.terminate(); process.wait(timeout=3)
