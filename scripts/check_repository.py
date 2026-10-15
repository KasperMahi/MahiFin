"""Structural sanity checks, not a substitute for Swift compilation or hardware tests."""
from pathlib import Path
import json
import plistlib
import re

root = Path(__file__).resolve().parents[1]
for platform in ("iOS", "tvOS"):
    plist = plistlib.loads((root / "Apps" / platform / "Info.plist").read_bytes())
    assert "NSAppTransportSecurity" not in plist, "No global ATS exceptions"
    assert (root / f"MahiFin.xcodeproj/xcshareddata/xcschemes/MahiFin-{platform}.xcscheme").exists()
project = (root / "MahiFin.xcodeproj/project.pbxproj").read_text()
assert 'IPHONEOS_DEPLOYMENT_TARGET = "18.0"' in project
assert 'TVOS_DEPLOYMENT_TARGET = "18.0"' in project
json.loads((root / "Packages/MahiFinCore/Tests/MahiFinCoreTests/Fixtures/items.json").read_text())
en = (root / "Resources/en.lproj/Localizable.strings").read_text(encoding="utf-8")
da = (root / "Resources/da.lproj/Localizable.strings").read_text(encoding="utf-8")
keys = lambda s: set(re.findall(r'^"([^"]+)"\s*=', s, re.M))
assert keys(en) == keys(da), "Localization keys must match"
assert (root / "THIRD_PARTY_NOTICES.md").exists()
print("Project structure, deployment targets, fixture JSON and localization parity passed")
