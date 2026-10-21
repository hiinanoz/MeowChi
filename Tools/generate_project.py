#!/usr/bin/env python3
"""Generates Meowchi.xcodeproj from the folder layout (no XcodeGen needed).

Run after adding, moving or deleting files:  python3 Tools/generate_project.py
Every .swift file under Meowchi/ and MeowchiTests/ is compiled; asset catalogs,
string catalogs, audio and fonts are bundled as resources.
"""
import hashlib, pathlib, re

ROOT = pathlib.Path(__file__).resolve().parent.parent
APP, TESTS = "Meowchi", "MeowchiTests"
BUNDLE_ID = "com.meowchi.game"
DEPLOYMENT_TARGET = "17.0"
DEVICE_FAMILY = "1"  # 1 = iPhone. Use "1,2" when iPad support lands.
MARKETING_VERSION, BUILD = "0.1.0", "1"
REGIONS = ["en", "Base", "tr", "es", "de", "ja", "ko", "fr"]

TYPES = {".swift": "sourcecode.swift", ".xcassets": "folder.assetcatalog", ".xcstrings": "text.json.xcstrings",
         ".json": "text.json", ".caf": "file", ".wav": "audio.wav", ".mp3": "audio.mp3", ".m4a": "file",
         ".ttf": "file", ".otf": "file", ".md": "net.daringfireball.markdown"}
RESOURCE_EXT = {".xcassets", ".xcstrings", ".json", ".caf", ".wav", ".mp3", ".m4a", ".ttf", ".otf"}
LEAF_DIRS = {".xcassets"}

objects = {}


def uid(*parts):
    return hashlib.md5("/".join(parts).encode()).hexdigest()[:24].upper()


def add(oid, obj):
    objects[oid] = obj
    return oid


def scan(folder, target):
    """Returns (group id, sources, resources) for a folder tree."""
    sources, resources, children = [], [], []
    for item in sorted(folder.iterdir(), key=lambda p: p.name.lower()):
        if item.name.startswith("."):
            continue
        rel = str(item.relative_to(ROOT))
        if item.is_dir() and item.suffix not in LEAF_DIRS:
            gid, s, r = scan(item, target)
            children.append(gid); sources += s; resources += r
            continue
        ftype = TYPES.get(item.suffix)
        if not ftype:
            continue
        fid = add(uid("file", rel), {"isa": "PBXFileReference", "lastKnownFileType": ftype,
                                     "path": item.name, "sourceTree": "<group>"})
        children.append(fid)
        if item.suffix == ".swift":
            sources.append(add(uid("build", target, rel), {"isa": "PBXBuildFile", "fileRef": fid}))
        elif item.suffix in RESOURCE_EXT:
            resources.append(add(uid("build", target, rel), {"isa": "PBXBuildFile", "fileRef": fid}))
    gid = add(uid("group", str(folder.relative_to(ROOT))),
              {"isa": "PBXGroup", "children": children, "path": folder.name, "sourceTree": "<group>"})
    return gid, sources, resources


def config_list(name, debug, release):
    d = add(uid("cfg", name, "Debug"), {"isa": "XCBuildConfiguration", "buildSettings": debug, "name": "Debug"})
    r = add(uid("cfg", name, "Release"), {"isa": "XCBuildConfiguration", "buildSettings": release, "name": "Release"})
    return add(uid("cfglist", name), {"isa": "XCConfigurationList", "buildConfigurations": [d, r],
                                      "defaultConfigurationIsVisible": "0", "defaultConfigurationName": "Release"})


def phase(isa, name, files):
    return add(uid("phase", name), {"isa": isa, "buildActionMask": "2147483647", "files": files,
                                    "runOnlyForDeploymentPostprocessing": "0"})


PROJECT_BASE = {
    "ALWAYS_SEARCH_USER_PATHS": "NO", "CLANG_ENABLE_MODULES": "YES", "CLANG_ENABLE_OBJC_ARC": "YES",
    "COPY_PHASE_STRIP": "NO", "ENABLE_STRICT_OBJC_MSGSEND": "YES", "ENABLE_USER_SCRIPT_SANDBOXING": "YES",
    "GCC_C_LANGUAGE_STANDARD": "gnu17", "IPHONEOS_DEPLOYMENT_TARGET": DEPLOYMENT_TARGET,
    "LOCALIZATION_PREFERS_STRING_CATALOGS": "YES", "MTL_FAST_MATH": "YES", "SDKROOT": "iphoneos",
    "SWIFT_VERSION": "5.0", "TARGETED_DEVICE_FAMILY": DEVICE_FAMILY,
}
PROJECT_DEBUG = {**PROJECT_BASE, "DEBUG_INFORMATION_FORMAT": "dwarf", "ENABLE_TESTABILITY": "YES",
                 "GCC_OPTIMIZATION_LEVEL": "0", "GCC_PREPROCESSOR_DEFINITIONS": ["DEBUG=1", "$(inherited)"],
                 "ONLY_ACTIVE_ARCH": "YES", "SWIFT_ACTIVE_COMPILATION_CONDITIONS": "DEBUG $(inherited)",
                 "SWIFT_OPTIMIZATION_LEVEL": "-Onone"}
PROJECT_RELEASE = {**PROJECT_BASE, "DEBUG_INFORMATION_FORMAT": "dwarf-with-dsym", "ENABLE_NS_ASSERTIONS": "NO",
                   "SWIFT_COMPILATION_MODE": "wholemodule", "VALIDATE_PRODUCT": "YES"}
APP_SETTINGS = {
    "ASSETCATALOG_COMPILER_APPICON_NAME": "AppIcon", "ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME": "AccentColor",
    "CODE_SIGN_STYLE": "Automatic", "CURRENT_PROJECT_VERSION": BUILD, "MARKETING_VERSION": MARKETING_VERSION,
    "ENABLE_PREVIEWS": "YES", "GENERATE_INFOPLIST_FILE": "YES",
    "INFOPLIST_KEY_CFBundleDisplayName": "Meowchi", "INFOPLIST_KEY_LSApplicationCategoryType": "public.app-category.simulation-games",
    "INFOPLIST_KEY_UIApplicationSceneManifest_Generation": "YES", "INFOPLIST_KEY_UILaunchScreen_Generation": "YES",
    "INFOPLIST_KEY_UIStatusBarStyle": "UIStatusBarStyleLightContent",
    "INFOPLIST_KEY_UISupportedInterfaceOrientations_iPhone": "UIInterfaceOrientationPortrait",
    "INFOPLIST_KEY_UISupportedInterfaceOrientations_iPad": "UIInterfaceOrientationPortrait UIInterfaceOrientationPortraitUpsideDown UIInterfaceOrientationLandscapeLeft UIInterfaceOrientationLandscapeRight",
    "LD_RUNPATH_SEARCH_PATHS": ["$(inherited)", "@executable_path/Frameworks"],
    "PRODUCT_BUNDLE_IDENTIFIER": BUNDLE_ID, "PRODUCT_NAME": "$(TARGET_NAME)", "SWIFT_EMIT_LOC_STRINGS": "YES",
}
TEST_SETTINGS = {
    "BUNDLE_LOADER": "$(TEST_HOST)", "CODE_SIGN_STYLE": "Automatic", "CURRENT_PROJECT_VERSION": BUILD,
    "GENERATE_INFOPLIST_FILE": "YES", "MARKETING_VERSION": MARKETING_VERSION,
    "PRODUCT_BUNDLE_IDENTIFIER": BUNDLE_ID + ".tests", "PRODUCT_NAME": "$(TARGET_NAME)", "SWIFT_EMIT_LOC_STRINGS": "NO",
    "TEST_HOST": f"$(BUILT_PRODUCTS_DIR)/{APP}.app/$(BUNDLE_EXECUTABLE_FOLDER_PATH)/{APP}",
}


def main():
    app_group, app_src, app_res = scan(ROOT / APP, APP)
    test_group, test_src, test_res = scan(ROOT / TESTS, TESTS)
    app_product = add(uid("product", APP), {"isa": "PBXFileReference", "explicitFileType": "wrapper.application",
                                            "includeInIndex": "0", "path": f"{APP}.app", "sourceTree": "BUILT_PRODUCTS_DIR"})
    test_product = add(uid("product", TESTS), {"isa": "PBXFileReference", "explicitFileType": "wrapper.cfbundle",
                                               "includeInIndex": "0", "path": f"{TESTS}.xctest", "sourceTree": "BUILT_PRODUCTS_DIR"})
    products = add(uid("group", "Products"), {"isa": "PBXGroup", "children": [app_product, test_product],
                                               "name": "Products", "sourceTree": "<group>"})
    main_group = add(uid("group", "<main>"), {"isa": "PBXGroup", "children": [app_group, test_group, products],
                                               "sourceTree": "<group>"})
    project_id, app_id, test_id = uid("project"), uid("target", APP), uid("target", TESTS)
    add(app_id, {"isa": "PBXNativeTarget", "buildConfigurationList": config_list(APP, APP_SETTINGS, APP_SETTINGS),
                 "buildPhases": [phase("PBXSourcesBuildPhase", APP + "src", app_src),
                                 phase("PBXFrameworksBuildPhase", APP + "fw", []),
                                 phase("PBXResourcesBuildPhase", APP + "res", app_res)],
                 "buildRules": [], "dependencies": [], "name": APP, "productName": APP,
                 "productReference": app_product, "productType": "com.apple.product-type.application"})
    proxy = add(uid("proxy"), {"isa": "PBXContainerItemProxy", "containerPortal": project_id, "proxyType": "1",
                               "remoteGlobalIDString": app_id, "remoteInfo": APP})
    dep = add(uid("dep"), {"isa": "PBXTargetDependency", "target": app_id, "targetProxy": proxy})
    add(test_id, {"isa": "PBXNativeTarget", "buildConfigurationList": config_list(TESTS, TEST_SETTINGS, TEST_SETTINGS),
                  "buildPhases": [phase("PBXSourcesBuildPhase", TESTS + "src", test_src),
                                  phase("PBXFrameworksBuildPhase", TESTS + "fw", []),
                                  phase("PBXResourcesBuildPhase", TESTS + "res", test_res)],
                  "buildRules": [], "dependencies": [dep], "name": TESTS, "productName": TESTS,
                  "productReference": test_product, "productType": "com.apple.product-type.bundle.unit-test"})
    add(project_id, {"isa": "PBXProject",
                     "attributes": {"BuildIndependentTargetsInParallel": "1", "LastSwiftUpdateCheck": "1520",
                                    "LastUpgradeCheck": "1520",
                                    "TargetAttributes": {app_id: {"CreatedOnToolsVersion": "15.2"},
                                                         test_id: {"CreatedOnToolsVersion": "15.2", "TestTargetID": app_id}}},
                     "buildConfigurationList": config_list("project", PROJECT_DEBUG, PROJECT_RELEASE),
                     "compatibilityVersion": "Xcode 14.0", "developmentRegion": "en", "hasScannedForEncodings": "0",
                     "knownRegions": REGIONS, "mainGroup": main_group, "productRefGroup": products,
                     "projectDirPath": "", "projectRoot": "", "targets": [app_id, test_id]})

    root = {"archiveVersion": "1", "classes": {}, "objectVersion": "56",
            "objects": dict(sorted(objects.items())), "rootObject": project_id}
    proj = ROOT / f"{APP}.xcodeproj"
    (proj / "project.xcworkspace").mkdir(parents=True, exist_ok=True)
    (proj / "project.pbxproj").write_text("// !$*UTF8*$!\n" + fmt(root, "") + "\n")
    (proj / "project.xcworkspace/contents.xcworkspacedata").write_text(
        '<?xml version="1.0" encoding="UTF-8"?>\n<Workspace version = "1.0">\n'
        '   <FileRef location = "self:">\n   </FileRef>\n</Workspace>\n')
    schemes = proj / "xcshareddata/xcschemes"; schemes.mkdir(parents=True, exist_ok=True)
    (schemes / f"{APP}.xcscheme").write_text(scheme(app_id, test_id))


def q(s):
    return s if re.fullmatch(r"[A-Za-z0-9_./]+", s) else '"' + s.replace("\\", "\\\\").replace('"', '\\"') + '"'


def fmt(v, ind):
    if isinstance(v, dict):
        return "{\n" + "".join(f"{ind}\t{q(k)} = {fmt(x, ind + chr(9))};\n" for k, x in v.items()) + ind + "}"
    if isinstance(v, list):
        return "(\n" + "".join(f"{ind}\t{fmt(x, ind + chr(9))},\n" for x in v) + ind + ")"
    return q(str(v))


def ref(bid, name):
    return (f'<BuildableReference BuildableIdentifier = "primary" BlueprintIdentifier = "{bid}" '
            f'BuildableName = "{name}" BlueprintName = "{name.split(".")[0]}" ReferencedContainer = "container:{APP}.xcodeproj"></BuildableReference>')


def scheme(app_id, test_id):
    app = ref(app_id, f"{APP}.app")
    dbg = 'selectedDebuggerIdentifier = "Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier = "Xcode.DebuggerFoundation.Launcher.LLDB"'
    return f'''<?xml version="1.0" encoding="UTF-8"?>
<Scheme LastUpgradeVersion = "1520" version = "1.7">
   <BuildAction parallelizeBuildables = "YES" buildImplicitDependencies = "YES">
      <BuildActionEntries>
         <BuildActionEntry buildForTesting = "YES" buildForRunning = "YES" buildForProfiling = "YES" buildForArchiving = "YES" buildForAnalyzing = "YES">
            {app}
         </BuildActionEntry>
      </BuildActionEntries>
   </BuildAction>
   <TestAction buildConfiguration = "Debug" {dbg} shouldUseLaunchSchemeArgsEnv = "YES">
      <Testables>
         <TestableReference skipped = "NO">
            {ref(test_id, f"{TESTS}.xctest")}
         </TestableReference>
      </Testables>
   </TestAction>
   <LaunchAction buildConfiguration = "Debug" {dbg} launchStyle = "0" useCustomWorkingDirectory = "NO" ignoresPersistentStateOnLaunch = "NO" debugDocumentVersioning = "YES" debugServiceExtension = "internal" allowLocationSimulation = "YES">
      <BuildableProductRunnable runnableDebuggingMode = "0">
         {app}
      </BuildableProductRunnable>
   </LaunchAction>
   <ProfileAction buildConfiguration = "Release" shouldUseLaunchSchemeArgsEnv = "YES" savedToolIdentifier = "" useCustomWorkingDirectory = "NO" debugDocumentVersioning = "YES">
      <BuildableProductRunnable runnableDebuggingMode = "0">
         {app}
      </BuildableProductRunnable>
   </ProfileAction>
   <AnalyzeAction buildConfiguration = "Debug"></AnalyzeAction>
   <ArchiveAction buildConfiguration = "Release" revealArchiveInOrganizer = "YES"></ArchiveAction>
</Scheme>
'''


if __name__ == "__main__":
    main()
