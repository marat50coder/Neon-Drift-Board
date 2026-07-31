#!/usr/bin/env bash
# Re-enables Push Notifications + Notification Service Extension for
# Neon Drift Board once the bundle identifier `com.neondrift.boardgame`
# can be registered on the Apple Developer team (63V23FXWWW), OR you have
# swapped in a different (available) bundle id + a matching Firebase plist.
#
# Usage:
#   bash tool/reenable_push.sh
#
# What it does (safe / idempotent):
#   1) Uncomments the NeonMediaNotification pod target in ios/Podfile.
#   2) Resets ios/Runner.xcodeproj/project.pbxproj to git HEAD.
#   3) Applies:
#        tool/patch_pbxproj.py         (NSE target + entitlements + plist)
#        tool/patch_pbxproj_stage2.py  (dev/prod entitlements + Push cap)
#      instead of patch_pbxproj_no_push.py.
#   4) Runs `pod install`.
#   5) Runs a signing dry-run to verify Push provisioning resolves.

set -euo pipefail

cd "$(dirname "$0")/.."

echo "==> Uncommenting NeonMediaNotification pod target"
python3 - <<'PY'
from pathlib import Path
podfile = Path("ios/Podfile")
text = podfile.read_text()
patched = (
    text
    .replace("# target 'NeonMediaNotification' do\n", "target 'NeonMediaNotification' do\n")
    .replace("#   use_frameworks!\n", "  use_frameworks!\n")
    .replace("#   platform :ios, '15.0'\n", "  platform :ios, '15.0'\n")
    .replace("#   pod 'Firebase/Messaging', '12.15.0'\n", "  pod 'Firebase/Messaging', '12.15.0'\n")
    .replace("# end\n\npost_install do |installer|", "end\n\npost_install do |installer|")
)
if patched == text:
    print("Podfile already has NSE target enabled — skipping")
else:
    podfile.write_text(patched)
    print("Podfile: NSE target enabled")
PY

echo "==> Resetting pbxproj + applying push patches"
git checkout ios/Runner.xcodeproj/project.pbxproj
python3 tool/patch_pbxproj.py
python3 tool/patch_pbxproj_stage2.py

echo "==> pod install"
( cd ios && pod install )

echo "==> Verifying provisioning resolves (Debug)"
xcodebuild \
  -workspace ios/Runner.xcworkspace \
  -scheme Runner \
  -sdk iphoneos \
  -configuration Debug \
  -allowProvisioningUpdates \
  -destination 'generic/platform=iOS' \
  build 2>&1 | tail -5

echo "==> Done. Push + NSE re-enabled."
