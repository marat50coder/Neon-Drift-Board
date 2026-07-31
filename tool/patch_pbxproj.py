#!/usr/bin/env python3
"""One-shot patcher: wire NSE target + entitlements + GoogleService-Info.plist
into ios/Runner.xcodeproj/project.pbxproj.

Idempotent: if the NSE product bundle id is already present, exits with
"pbxproj already patched" and does nothing.
"""

from __future__ import annotations

import os
import re
import secrets
import sys


ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
PBX = os.path.join(ROOT, "ios", "Runner.xcodeproj", "project.pbxproj")

# Known-existing pbxproj UUIDs (do NOT regenerate; anchor everything to them).
MAIN_GROUP = "97C146E51CF9000F007C117D"
RUNNER_GROUP = "97C146F01CF9000F007C117D"
RUNNER_TARGET = "97C146ED1CF9000F007C117D"
RUNNER_RESOURCES_PHASE = "97C146EC1CF9000F007C117D"
PROJECT_OBJECT = "97C146E61CF9000F007C117D"
RUNNER_DEBUG_CFG = "97C147061CF9000F007C117D"
RUNNER_RELEASE_CFG = "97C147071CF9000F007C117D"
RUNNER_PROFILE_CFG = "249021D4217E4FDB00AE95B9"
RUNNER_EMBED_FRAMEWORKS_PHASE = "9705A1C41CF9048500538489"

NSE_NAME = "NeonMediaNotification"
NSE_BUNDLE_ID = "com.neondrift.boardgame.NeonMediaNotification"
DEV_TEAM = "63V23FXWWW"


def U() -> str:
    return secrets.token_hex(12).upper()


def read() -> str:
    with open(PBX, "rb") as fh:
        raw = fh.read()
    if raw.startswith(b"\xef\xbb\xbf"):
        raise SystemExit("pbxproj has a UTF-8 BOM; refuse to touch it")
    return raw.decode("utf-8")


def write(text: str) -> None:
    if "\r\n" in text:
        raise SystemExit("pbxproj should not contain CRLF here")
    with open(PBX, "wb") as fh:
        fh.write(text.encode("utf-8"))


def insert_before(text: str, marker: str, block: str) -> str:
    idx = text.index(marker)
    return text[:idx] + block + text[idx:]


def main() -> int:
    txt = read()
    if NSE_BUNDLE_ID in txt:
        print("pbxproj already patched — nothing to do")
        return 0

    # ── UUIDs ──────────────────────────────────────────────────────────
    NS_SWIFT_REF = U()
    NS_SWIFT_BUILDFILE = U()
    NSE_INFOPLIST_REF = U()
    NSE_APPEX_REF = U()
    NSE_GROUP = U()
    NSE_TARGET = U()
    NSE_SOURCES_PHASE = U()
    NSE_CONTAINER_PROXY = U()
    NSE_TARGET_DEP = U()
    NSE_CFG_LIST = U()
    NSE_DEBUG_CFG = U()
    NSE_RELEASE_CFG = U()
    NSE_PROFILE_CFG = U()
    NSE_APPEX_EMBED_BUILDFILE = U()
    RUNNER_EMBED_APPEX_PHASE = U()
    ENTITLEMENTS_REF = U()
    GSI_REF = U()
    GSI_BUILDFILE = U()

    # ── PBXBuildFile section ───────────────────────────────────────────
    build_files = (
        f"\t\t{NS_SWIFT_BUILDFILE} /* NotificationService.swift in Sources */ = "
        f"{{isa = PBXBuildFile; fileRef = {NS_SWIFT_REF} /* NotificationService.swift */; }};\n"
        f"\t\t{NSE_APPEX_EMBED_BUILDFILE} /* {NSE_NAME}.appex in Embed App Extensions */ = "
        f"{{isa = PBXBuildFile; fileRef = {NSE_APPEX_REF} /* {NSE_NAME}.appex */; "
        f"settings = {{ATTRIBUTES = (RemoveHeadersOnCopy, ); }}; }};\n"
        f"\t\t{GSI_BUILDFILE} /* GoogleService-Info.plist in Resources */ = "
        f"{{isa = PBXBuildFile; fileRef = {GSI_REF} /* GoogleService-Info.plist */; }};\n"
    )
    txt = insert_before(txt, "/* End PBXBuildFile section */", build_files)

    # ── PBXFileReference section ───────────────────────────────────────
    refs = (
        f"\t\t{NS_SWIFT_REF} /* NotificationService.swift */ = "
        f"{{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; "
        f"path = NotificationService.swift; sourceTree = \"<group>\"; }};\n"
        f"\t\t{NSE_INFOPLIST_REF} /* Info.plist */ = "
        f"{{isa = PBXFileReference; lastKnownFileType = text.plist.xml; "
        f"path = Info.plist; sourceTree = \"<group>\"; }};\n"
        f"\t\t{NSE_APPEX_REF} /* {NSE_NAME}.appex */ = "
        f"{{isa = PBXFileReference; explicitFileType = \"wrapper.app-extension\"; "
        f"includeInIndex = 0; path = \"{NSE_NAME}.appex\"; sourceTree = BUILT_PRODUCTS_DIR; }};\n"
        f"\t\t{GSI_REF} /* GoogleService-Info.plist */ = "
        f"{{isa = PBXFileReference; lastKnownFileType = text.plist.xml; "
        f"path = \"GoogleService-Info.plist\"; sourceTree = \"<group>\"; }};\n"
        f"\t\t{ENTITLEMENTS_REF} /* Runner.entitlements */ = "
        f"{{isa = PBXFileReference; lastKnownFileType = text.plist.entitlements; "
        f"path = Runner.entitlements; sourceTree = \"<group>\"; }};\n"
    )
    txt = insert_before(txt, "/* End PBXFileReference section */", refs)

    # ── PBXGroup section: add NSE group INSIDE the PBXGroup section ────
    nse_group = (
        f"\t\t{NSE_GROUP} /* {NSE_NAME} */ = {{\n"
        f"\t\t\tisa = PBXGroup;\n"
        f"\t\t\tchildren = (\n"
        f"\t\t\t\t{NS_SWIFT_REF} /* NotificationService.swift */,\n"
        f"\t\t\t\t{NSE_INFOPLIST_REF} /* Info.plist */,\n"
        f"\t\t\t);\n"
        f"\t\t\tpath = {NSE_NAME};\n"
        f"\t\t\tsourceTree = \"<group>\";\n"
        f"\t\t}};\n"
    )
    txt = insert_before(txt, "/* End PBXGroup section */", nse_group)

    # Attach NSE group to the main project group children (before Products).
    main_children_anchor = (
        f"{MAIN_GROUP} = {{\n\t\t\tisa = PBXGroup;\n\t\t\tchildren = (\n"
    )
    idx = txt.index(main_children_anchor)
    idx_end = txt.index(");", idx)
    injected_line = f"\t\t\t\t{NSE_GROUP} /* {NSE_NAME} */,\n"
    txt = txt[:idx_end] + injected_line + txt[idx_end:]

    # Add GoogleService-Info.plist + Runner.entitlements to Runner group.
    runner_group_anchor = (
        f"{RUNNER_GROUP} /* Runner */ = {{\n\t\t\tisa = PBXGroup;\n\t\t\tchildren = (\n"
    )
    idx = txt.index(runner_group_anchor)
    idx_end = txt.index(");", idx)
    runner_children_extra = (
        f"\t\t\t\t{GSI_REF} /* GoogleService-Info.plist */,\n"
        f"\t\t\t\t{ENTITLEMENTS_REF} /* Runner.entitlements */,\n"
    )
    txt = txt[:idx_end] + runner_children_extra + txt[idx_end:]

    # ── PBXSourcesBuildPhase for NSE ───────────────────────────────────
    nse_sources = (
        f"\t\t{NSE_SOURCES_PHASE} /* Sources */ = {{\n"
        f"\t\t\tisa = PBXSourcesBuildPhase;\n"
        f"\t\t\tbuildActionMask = 2147483647;\n"
        f"\t\t\tfiles = (\n"
        f"\t\t\t\t{NS_SWIFT_BUILDFILE} /* NotificationService.swift in Sources */,\n"
        f"\t\t\t);\n"
        f"\t\t\trunOnlyForDeploymentPostprocessing = 0;\n"
        f"\t\t}};\n"
    )
    txt = insert_before(txt, "/* End PBXSourcesBuildPhase section */", nse_sources)

    # ── PBXCopyFilesBuildPhase: embed appex into Runner (dstSubfolderSpec=13) ─
    embed_phase = (
        f"\t\t{RUNNER_EMBED_APPEX_PHASE} /* Embed App Extensions */ = {{\n"
        f"\t\t\tisa = PBXCopyFilesBuildPhase;\n"
        f"\t\t\tbuildActionMask = 2147483647;\n"
        f"\t\t\tdstPath = \"\";\n"
        f"\t\t\tdstSubfolderSpec = 13;\n"
        f"\t\t\tfiles = (\n"
        f"\t\t\t\t{NSE_APPEX_EMBED_BUILDFILE} /* {NSE_NAME}.appex in Embed App Extensions */,\n"
        f"\t\t\t);\n"
        f"\t\t\tname = \"Embed App Extensions\";\n"
        f"\t\t\trunOnlyForDeploymentPostprocessing = 0;\n"
        f"\t\t}};\n"
    )
    txt = insert_before(txt, "/* End PBXCopyFilesBuildPhase section */", embed_phase)

    # ── PBXContainerItemProxy for NSE target dependency ────────────────
    proxy_block = (
        f"\t\t{NSE_CONTAINER_PROXY} /* PBXContainerItemProxy */ = {{\n"
        f"\t\t\tisa = PBXContainerItemProxy;\n"
        f"\t\t\tcontainerPortal = {PROJECT_OBJECT} /* Project object */;\n"
        f"\t\t\tproxyType = 1;\n"
        f"\t\t\tremoteGlobalIDString = {NSE_TARGET};\n"
        f"\t\t\tremoteInfo = {NSE_NAME};\n"
        f"\t\t}};\n"
    )
    txt = insert_before(txt, "/* End PBXContainerItemProxy section */", proxy_block)

    # ── PBXTargetDependency ────────────────────────────────────────────
    dep_block = (
        f"\t\t{NSE_TARGET_DEP} /* PBXTargetDependency */ = {{\n"
        f"\t\t\tisa = PBXTargetDependency;\n"
        f"\t\t\ttarget = {NSE_TARGET} /* {NSE_NAME} */;\n"
        f"\t\t\ttargetProxy = {NSE_CONTAINER_PROXY} /* PBXContainerItemProxy */;\n"
        f"\t\t}};\n"
    )
    txt = insert_before(txt, "/* End PBXTargetDependency section */", dep_block)

    # ── PBXNativeTarget for NSE ────────────────────────────────────────
    nse_target = (
        f"\t\t{NSE_TARGET} /* {NSE_NAME} */ = {{\n"
        f"\t\t\tisa = PBXNativeTarget;\n"
        f"\t\t\tbuildConfigurationList = {NSE_CFG_LIST} /* Build configuration list for PBXNativeTarget \"{NSE_NAME}\" */;\n"
        f"\t\t\tbuildPhases = (\n"
        f"\t\t\t\t{NSE_SOURCES_PHASE} /* Sources */,\n"
        f"\t\t\t);\n"
        f"\t\t\tbuildRules = (\n"
        f"\t\t\t);\n"
        f"\t\t\tdependencies = (\n"
        f"\t\t\t);\n"
        f"\t\t\tname = {NSE_NAME};\n"
        f"\t\t\tproductName = {NSE_NAME};\n"
        f"\t\t\tproductReference = {NSE_APPEX_REF} /* {NSE_NAME}.appex */;\n"
        f"\t\t\tproductType = \"com.apple.product-type.app-extension\";\n"
        f"\t\t}};\n"
    )
    txt = insert_before(txt, "/* End PBXNativeTarget section */", nse_target)

    # ── XCBuildConfiguration entries for NSE (Debug/Release/Profile) ───
    def cfg(uid: str, name: str) -> str:
        return (
            f"\t\t{uid} /* {name} */ = {{\n"
            f"\t\t\tisa = XCBuildConfiguration;\n"
            f"\t\t\tbuildSettings = {{\n"
            f"\t\t\t\tCODE_SIGN_STYLE = Automatic;\n"
            f"\t\t\t\tCURRENT_PROJECT_VERSION = \"$(FLUTTER_BUILD_NUMBER)\";\n"
            f"\t\t\t\tDEVELOPMENT_TEAM = {DEV_TEAM};\n"
            f"\t\t\t\tGENERATE_INFOPLIST_FILE = NO;\n"
            f"\t\t\t\tINFOPLIST_FILE = {NSE_NAME}/Info.plist;\n"
            f"\t\t\t\tIPHONEOS_DEPLOYMENT_TARGET = 15.0;\n"
            f"\t\t\t\tLD_RUNPATH_SEARCH_PATHS = (\n"
            f"\t\t\t\t\t\"$(inherited)\",\n"
            f"\t\t\t\t\t\"@executable_path/Frameworks\",\n"
            f"\t\t\t\t\t\"@executable_path/../../Frameworks\",\n"
            f"\t\t\t\t);\n"
            f"\t\t\t\tMARKETING_VERSION = \"$(FLUTTER_BUILD_NAME)\";\n"
            f"\t\t\t\tPRODUCT_BUNDLE_IDENTIFIER = {NSE_BUNDLE_ID};\n"
            f"\t\t\t\tPRODUCT_NAME = \"$(TARGET_NAME)\";\n"
            f"\t\t\t\tSKIP_INSTALL = YES;\n"
            f"\t\t\t\tSWIFT_VERSION = 5.0;\n"
            f"\t\t\t\tTARGETED_DEVICE_FAMILY = \"1,2\";\n"
            f"\t\t\t}};\n"
            f"\t\t\tname = {name};\n"
            f"\t\t}};\n"
        )

    nse_cfgs = cfg(NSE_DEBUG_CFG, "Debug") + cfg(NSE_RELEASE_CFG, "Release") + cfg(NSE_PROFILE_CFG, "Profile")
    txt = insert_before(txt, "/* End XCBuildConfiguration section */", nse_cfgs)

    # ── XCConfigurationList for NSE ────────────────────────────────────
    nse_cfg_list = (
        f"\t\t{NSE_CFG_LIST} /* Build configuration list for PBXNativeTarget \"{NSE_NAME}\" */ = {{\n"
        f"\t\t\tisa = XCConfigurationList;\n"
        f"\t\t\tbuildConfigurations = (\n"
        f"\t\t\t\t{NSE_DEBUG_CFG} /* Debug */,\n"
        f"\t\t\t\t{NSE_RELEASE_CFG} /* Release */,\n"
        f"\t\t\t\t{NSE_PROFILE_CFG} /* Profile */,\n"
        f"\t\t\t);\n"
        f"\t\t\tdefaultConfigurationIsVisible = 0;\n"
        f"\t\t\tdefaultConfigurationName = Release;\n"
        f"\t\t}};\n"
    )
    txt = insert_before(txt, "/* End XCConfigurationList section */", nse_cfg_list)

    # ── Add NSE target to root project.targets ─────────────────────────
    project_targets_anchor = f"targets = (\n\t\t\t\t{RUNNER_TARGET} /* Runner */,\n"
    txt = txt.replace(
        project_targets_anchor,
        project_targets_anchor + f"\t\t\t\t{NSE_TARGET} /* {NSE_NAME} */,\n",
        1,
    )

    # ── Add TargetDependency + embed phase to Runner target ────────────
    runner_target_open = f"{RUNNER_TARGET} /* Runner */ = {{"
    r_idx = txt.index(runner_target_open)
    r_close = txt.index("};", r_idx)
    runner_block = txt[r_idx:r_close]

    # Add embed phase into buildPhases list, right after the existing
    # Embed Frameworks phase (keeps a stable order).
    ef_anchor = f"{RUNNER_EMBED_FRAMEWORKS_PHASE} /* Embed Frameworks */,\n"
    runner_block2 = runner_block.replace(
        ef_anchor,
        ef_anchor + f"\t\t\t\t{RUNNER_EMBED_APPEX_PHASE} /* Embed App Extensions */,\n",
        1,
    )
    # Add dep
    runner_block2 = runner_block2.replace(
        "dependencies = (\n",
        f"dependencies = (\n\t\t\t\t{NSE_TARGET_DEP} /* PBXTargetDependency */,\n",
        1,
    )
    txt = txt[:r_idx] + runner_block2 + txt[r_close:]

    # ── Add GoogleService-Info.plist to Runner Resources phase ─────────
    res_open = f"{RUNNER_RESOURCES_PHASE} /* Resources */ = {{"
    res_idx = txt.index(res_open)
    res_close = txt.index("};", res_idx)
    res_block = txt[res_idx:res_close]
    res_block2 = res_block.replace(
        "files = (\n",
        f"files = (\n\t\t\t\t{GSI_BUILDFILE} /* GoogleService-Info.plist in Resources */,\n",
        1,
    )
    txt = txt[:res_idx] + res_block2 + txt[res_close:]

    # ── Add CODE_SIGN_ENTITLEMENTS to Runner build configs ─────────────
    for uid in (RUNNER_DEBUG_CFG, RUNNER_RELEASE_CFG, RUNNER_PROFILE_CFG):
        cfg_open = f"{uid} /*"
        c_idx = txt.index(cfg_open)
        # Insert inside buildSettings dict (after the opening `{`).
        bs_marker = "buildSettings = {\n"
        bs_pos = txt.index(bs_marker, c_idx) + len(bs_marker)
        line = "\t\t\t\tCODE_SIGN_ENTITLEMENTS = Runner/Runner.entitlements;\n"
        txt = txt[:bs_pos] + line + txt[bs_pos:]

    # ── TargetAttributes: mark NSE ProvisioningStyle ───────────────────
    ta_anchor = "TargetAttributes = {"
    ta_idx = txt.index(ta_anchor)
    ta_end = txt.index("};", ta_idx)
    ta_extra = (
        f"\n\t\t\t\t\t{NSE_TARGET} = {{\n"
        f"\t\t\t\t\t\tCreatedOnToolsVersion = 15.0;\n"
        f"\t\t\t\t\t\tProvisioningStyle = Automatic;\n"
        f"\t\t\t\t\t}};"
    )
    # Insert right before the closing };
    txt = txt[:ta_end] + ta_extra + "\n\t\t\t\t" + txt[ta_end:]

    write(txt)

    # ── Verification ───────────────────────────────────────────────────
    v = read()
    assert NSE_BUNDLE_ID in v, "NSE bundle id missing"
    g0 = v.find("/* Begin PBXGroup section */")
    g1 = v.find("/* End PBXGroup section */")
    assert g0 < v.find(NSE_GROUP) < g1, "NSE group not inside PBXGroup section"

    # Entitlements exactly on Runner configs, never on NSE configs.
    for uid in (RUNNER_DEBUG_CFG, RUNNER_RELEASE_CFG, RUNNER_PROFILE_CFG):
        block = v[v.find(uid): v.find(uid) + 2000]
        assert "CODE_SIGN_ENTITLEMENTS = Runner/Runner.entitlements" in block, uid
    for uid in (NSE_DEBUG_CFG, NSE_RELEASE_CFG, NSE_PROFILE_CFG):
        block = v[v.find(uid): v.find(uid) + 2000]
        assert "CODE_SIGN_ENTITLEMENTS" not in block, f"entitlements on NSE {uid}"

    # No baseConfigurationReference on NSE configs.
    for uid in (NSE_DEBUG_CFG, NSE_RELEASE_CFG, NSE_PROFILE_CFG):
        block = v[v.find(uid): v.find(uid) + 2000]
        assert "baseConfigurationReference" not in block

    assert v.count("CODE_SIGN_ENTITLEMENTS = Runner/Runner.entitlements") == 3

    with open(PBX, "rb") as fh:
        raw = fh.read()
    assert raw[:3] != b"\xef\xbb\xbf", "BOM sneaked back in"
    assert b"\r\n" not in raw, "CRLF sneaked in"

    print(
        "pbxproj patched OK: nse_target={} appex_ref={} group={}".format(
            NSE_TARGET, NSE_APPEX_REF, NSE_GROUP,
        )
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
