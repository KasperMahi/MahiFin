"""Run genuine XCUITest on available iOS/tvOS simulators; fail explicitly if missing."""
import json
from pathlib import Path
import subprocess

devices = json.loads(subprocess.check_output(["xcrun", "simctl", "list", "devices", "available", "--json"]))["devices"]
for platform, prefix in (("iOS", "iPhone"), ("tvOS", "Apple TV")):
    candidates = [(runtime, device) for runtime, values in devices.items() for device in values if platform in runtime and device["name"].startswith(prefix) and device.get("isAvailable")]
    if not candidates:
        raise SystemExit(f"No {platform} simulator runtime available; unsigned generic build is separate from UI smoke")
    runtime, device = sorted(candidates, key=lambda pair: pair[0], reverse=True)[0]
    print(f"UI smoke: {platform} {runtime} {device['name']}", flush=True)
    Path("TestResults").mkdir(exist_ok=True)
    subprocess.run(["xcodebuild", "-project", "MahiFin.xcodeproj", "-scheme", f"MahiFin-{platform}", "-destination", f"platform={'iOS' if platform == 'iOS' else 'tvOS'} Simulator,id={device['udid']}", "-derivedDataPath", f"DerivedData/{platform}", "-resultBundlePath", f"TestResults/{platform}.xcresult", "CODE_SIGNING_ALLOWED=NO", "test"], check=True)
