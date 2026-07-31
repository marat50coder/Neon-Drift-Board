#!/usr/bin/env python3
"""Minimal pbxproj patch for Neon Drift Board — WITHOUT Push.

Adds GoogleService-Info.plist as a Runner resource (needed for Firebase.initializeApp).
Does NOT wire Push capability, entitlements or the Notification Service Extension.

Idempotent: exits early if already applied.

Companion of tool/patch_pbxproj.py + tool/patch_pbxproj_stage2.py, which
DO wire Push. Use those once the bundle identifier can be registered on the
Apple Developer team (see docs/PUSH_REENABLE.md).
"""

from __future__ import annotations

import os
import secrets
import sys


ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
PBX = os.path.join(ROOT, "ios", "Runner.xcodeproj", "project.pbxproj")

RUNNER_GROUP = "97C146F01CF9000F007C117D"
RUNNER_RESOURCES_PHASE = "97C146EC1CF9000F007C117D"

MARKER = "GoogleService-Info.plist"


def U() -> str:
    return secrets.token_hex(12).upper()


def read() -> str:
    with open(PBX, "rb") as fh:
        raw = fh.read()
    if raw.startswith(b"\xef\xbb\xbf"):
        raise SystemExit("pbxproj has a UTF-8 BOM; refuse")
    return raw.decode("utf-8")


def write(text: str) -> None:
    if "\r\n" in text:
        raise SystemExit("pbxproj should not contain CRLF")
    with open(PBX, "wb") as fh:
        fh.write(text.encode("utf-8"))


def main() -> int:
    txt = read()
    if MARKER in txt:
        print("pbxproj already knows about GoogleService-Info.plist — nothing to do")
        return 0

    gsi_ref = U()
    gsi_buildfile = U()

    # PBXBuildFile
    txt = txt.replace(
        "/* End PBXBuildFile section */",
        (
            f"\t\t{gsi_buildfile} /* GoogleService-Info.plist in Resources */ = "
            f"{{isa = PBXBuildFile; fileRef = {gsi_ref} /* GoogleService-Info.plist */; }};\n"
            "/* End PBXBuildFile section */"
        ),
        1,
    )

    # PBXFileReference
    txt = txt.replace(
        "/* End PBXFileReference section */",
        (
            f"\t\t{gsi_ref} /* GoogleService-Info.plist */ = "
            f"{{isa = PBXFileReference; lastKnownFileType = text.plist.xml; "
            f"path = \"GoogleService-Info.plist\"; sourceTree = \"<group>\"; }};\n"
            "/* End PBXFileReference section */"
        ),
        1,
    )

    # Runner group children — add plist.
    anchor = (
        f"{RUNNER_GROUP} /* Runner */ = {{\n\t\t\tisa = PBXGroup;\n\t\t\tchildren = (\n"
    )
    idx = txt.index(anchor)
    idx_end = txt.index(");", idx)
    txt = (
        txt[:idx_end]
        + f"\t\t\t\t{gsi_ref} /* GoogleService-Info.plist */,\n"
        + txt[idx_end:]
    )

    # Runner Resources build phase — add plist.
    phase_open = f"{RUNNER_RESOURCES_PHASE} /* Resources */ = {{"
    p_idx = txt.index(phase_open)
    p_close = txt.index("};", p_idx)
    block = txt[p_idx:p_close]
    block2 = block.replace(
        "files = (\n",
        f"files = (\n\t\t\t\t{gsi_buildfile} /* GoogleService-Info.plist in Resources */,\n",
        1,
    )
    txt = txt[:p_idx] + block2 + txt[p_close:]

    write(txt)

    # Verify.
    v = read()
    assert MARKER in v
    with open(PBX, "rb") as fh:
        raw = fh.read()
    assert raw[:3] != b"\xef\xbb\xbf"
    assert b"\r\n" not in raw
    # Sanity: no push-related residue leaked from earlier patches.
    assert "CODE_SIGN_ENTITLEMENTS" not in v, "entitlements should not be wired"
    assert "com.apple.Push" not in v, "Push capability should not be wired"
    assert "NeonMediaNotification" not in v, "NSE target should not be wired"
    print("pbxproj patched (no-push): GoogleService-Info.plist wired as Runner resource")
    return 0


if __name__ == "__main__":
    sys.exit(main())
