#!/usr/bin/env python3
"""Stage-2 pbxproj patch (idempotent). Applied AFTER patch_pbxproj.py.

Adds:
- Runner.Release.entitlements file reference (in Runner group).
- Swaps CODE_SIGN_ENTITLEMENTS on Runner Release + Profile configs to point
  at the production entitlements file, so App Store builds ship with
  aps-environment=production without manual Xcode edits.
- SystemCapabilities.com.apple.Push=1 on the Runner target attributes so
  Xcode shows Push Notifications capability as already enabled.
"""

from __future__ import annotations

import os
import secrets
import sys


ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
PBX = os.path.join(ROOT, "ios", "Runner.xcodeproj", "project.pbxproj")

RUNNER_GROUP = "97C146F01CF9000F007C117D"
RUNNER_TARGET = "97C146ED1CF9000F007C117D"
RUNNER_RELEASE_CFG = "97C147071CF9000F007C117D"
RUNNER_PROFILE_CFG = "249021D4217E4FDB00AE95B9"

MARKER = "Runner.Release.entitlements"


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
    if MARKER in txt and "com.apple.Push" in txt:
        print("stage-2 already applied — nothing to do")
        return 0

    if MARKER not in txt:
        release_ref = U()
        # PBXFileReference for the release entitlements file.
        file_ref = (
            f"\t\t{release_ref} /* Runner.Release.entitlements */ = "
            f"{{isa = PBXFileReference; lastKnownFileType = text.plist.entitlements; "
            f"path = Runner.Release.entitlements; sourceTree = \"<group>\"; }};\n"
        )
        end_marker = "/* End PBXFileReference section */"
        idx = txt.index(end_marker)
        txt = txt[:idx] + file_ref + txt[idx:]

        # Add to Runner group children.
        anchor = (
            f"{RUNNER_GROUP} /* Runner */ = {{\n\t\t\tisa = PBXGroup;\n"
            f"\t\t\tchildren = (\n"
        )
        idx = txt.index(anchor)
        idx_end = txt.index(");", idx)
        line = f"\t\t\t\t{release_ref} /* Runner.Release.entitlements */,\n"
        txt = txt[:idx_end] + line + txt[idx_end:]

        # Repoint CODE_SIGN_ENTITLEMENTS in Release + Profile Runner configs.
        for uid in (RUNNER_RELEASE_CFG, RUNNER_PROFILE_CFG):
            block_start = txt.index(uid)
            block_end = txt.index("};", block_start)
            head, block, tail = (
                txt[:block_start],
                txt[block_start:block_end],
                txt[block_end:],
            )
            new_block = block.replace(
                "CODE_SIGN_ENTITLEMENTS = Runner/Runner.entitlements;",
                "CODE_SIGN_ENTITLEMENTS = Runner/Runner.Release.entitlements;",
                1,
            )
            if new_block == block:
                raise SystemExit(
                    f"failed to swap entitlements for cfg {uid}"
                )
            txt = head + new_block + tail

    if "com.apple.Push" not in txt:
        # Add SystemCapabilities.com.apple.Push = enabled=1 to Runner attrs.
        anchor = (
            f"{RUNNER_TARGET} = {{\n"
            f"\t\t\t\t\t\tCreatedOnToolsVersion = 7.3.1;\n"
            f"\t\t\t\t\t\tLastSwiftMigration = 1100;\n"
            f"\t\t\t\t\t}};"
        )
        replacement = (
            f"{RUNNER_TARGET} = {{\n"
            f"\t\t\t\t\t\tCreatedOnToolsVersion = 7.3.1;\n"
            f"\t\t\t\t\t\tLastSwiftMigration = 1100;\n"
            f"\t\t\t\t\t\tSystemCapabilities = {{\n"
            f"\t\t\t\t\t\t\tcom.apple.Push = {{\n"
            f"\t\t\t\t\t\t\t\tenabled = 1;\n"
            f"\t\t\t\t\t\t\t}};\n"
            f"\t\t\t\t\t\t}};\n"
            f"\t\t\t\t\t}};"
        )
        if anchor not in txt:
            raise SystemExit("Runner TargetAttributes anchor not found")
        txt = txt.replace(anchor, replacement, 1)

    write(txt)

    v = read()
    # Verify: Debug still points at dev entitlements, Release/Profile at prod.
    def cfg_block(uid: str) -> str:
        start = v.find(uid)
        return v[start:start + 2000]

    assert (
        "CODE_SIGN_ENTITLEMENTS = Runner/Runner.entitlements;"
        in cfg_block("97C147061CF9000F007C117D")  # Runner Debug
    ), "Debug entitlements should stay on dev file"
    for uid in (RUNNER_RELEASE_CFG, RUNNER_PROFILE_CFG):
        assert (
            "CODE_SIGN_ENTITLEMENTS = Runner/Runner.Release.entitlements;"
            in cfg_block(uid)
        ), f"Release/Profile entitlements missing on {uid}"
    assert "com.apple.Push" in v
    assert (
        v.count("CODE_SIGN_ENTITLEMENTS = Runner/Runner.entitlements;")
        + v.count("CODE_SIGN_ENTITLEMENTS = Runner/Runner.Release.entitlements;")
        == 3
    )
    with open(PBX, "rb") as fh:
        raw = fh.read()
    assert raw[:3] != b"\xef\xbb\xbf"
    assert b"\r\n" not in raw
    print("stage-2 patched OK: dev+prod entitlements + Push capability enabled")
    return 0


if __name__ == "__main__":
    sys.exit(main())
