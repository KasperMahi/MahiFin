"""Run genuine XCUITest on available iOS/tvOS simulators; fail explicitly if missing."""
import json
from pathlib import Path
import subprocess
import platform as host_platform

devices = json.loads(subprocess.check_output(["xcrun", "simctl", "list", "devices", "available", "--json"]))["devices"]
failures = []
for platform, prefix in (("iOS", "iPhone"), ("tvOS", "Apple TV")):
    # Xcode 16.4's SDKs target OS 18. Newer runtimes installed alongside Xcode 26 are not compatible test destinations.
    candidates = [(runtime, device) for runtime, values in devices.items() for device in values if f".{platform}-18-" in runtime and device["name"].startswith(prefix) and device.get("isAvailable")]
    if not candidates:
        print(f"No {platform} 18 simulator runtime available for Xcode 16.4; unsigned generic build is separate from UI smoke", flush=True)
        failures.append(platform)
        continue
    runtime, device = sorted(candidates, key=lambda pair: (pair[0].endswith("-18-5"), pair[0]), reverse=True)[0]
    print(f"UI smoke: {platform} {runtime} {device['name']}", flush=True)
    Path("TestResults").mkdir(exist_ok=True)
    architecture = "arm64" if host_platform.machine() == "arm64" else "x86_64"
    package_sources = str(Path("DerivedData/SourcePackages").resolve())
    # Wait for SpringBoard/FrontBoard before XCTest installs its runner. Serialize destinations
    # rather than letting Xcode create unbooted test clones alongside the other platform.
    try:
        if device["state"] != "Booted":
            subprocess.run(["xcrun", "simctl", "boot", device["udid"]], check=True, timeout=60)
        subprocess.run(["xcrun", "simctl", "bootstatus", device["udid"], "-b"], check=True, timeout=300)
        subprocess.run(["xcodebuild", "-project", "MahiFin.xcodeproj", "-scheme", f"MahiFin-{platform}", "-destination", f"platform={platform} Simulator,id={device['udid']}", "-parallel-testing-enabled", "NO", "-clonedSourcePackagesDirPath", package_sources, "-derivedDataPath", f"DerivedData/Smoke/{platform}", "-resultBundlePath", f"TestResults/{platform}.xcresult", "CODE_SIGNING_ALLOWED=NO", f"ARCHS={architecture}", "test"], check=True, timeout=900)
    except (subprocess.CalledProcessError, subprocess.TimeoutExpired) as error:
        print(f"{platform} UI tests FAILED: {type(error).__name__}; retaining result bundle and testing the other platform", flush=True)
        failures.append(platform)
    finally:
        subprocess.run(["xcrun", "simctl", "shutdown", device["udid"]], check=False, timeout=60)
if failures:
    raise SystemExit("UI smoke failed: " + ", ".join(failures))
