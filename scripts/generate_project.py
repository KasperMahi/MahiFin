"""Deterministically generate a dependency-free, two-target Xcode project."""
from pathlib import Path
import hashlib
import plistlib

ROOT = Path(__file__).resolve().parents[1]
PROJECT = ROOT / "MahiFin.xcodeproj"
PROJECT.mkdir(exist_ok=True)
objects = {}

def uid(name):
    return hashlib.sha256(name.encode()).hexdigest()[:24].upper()

def quote(value):
    return '"' + str(value).replace('\\', '\\\\').replace('"', '\\"') + '"'

def obj(name, kind, fields):
    key = uid(name)
    objects[key] = "isa = " + kind + "; " + fields
    return key

def array(values):
    return "(" + ", ".join(values) + ")"

def settings(values):
    return "{" + " ".join(f"{k} = {quote(v)};" for k, v in values.items()) + "}"

products = []
targets = []
all_refs = []
package = obj("package", "XCLocalSwiftPackageReference", 'relativePath = Packages/MahiFinCore;')

# Shared localized resource variant. No private artwork or media is bundled.
languages = []
for lang in ("en", "da"):
    languages.append(obj("localization-" + lang, "PBXFileReference", f'lastKnownFileType = text.plist.strings; name = {lang}; path = Resources/{lang}.lproj/Localizable.strings; sourceTree = SOURCE_ROOT;'))
resource = obj("strings", "PBXVariantGroup", f'children = {array(languages)}; name = Localizable.strings; sourceTree = "<group>";')
all_refs.append(resource)

for platform, sdk, family, minimum in (("iOS", "iphoneos", "1,2", "IPHONEOS_DEPLOYMENT_TARGET"), ("tvOS", "appletvos", "3", "TVOS_DEPLOYMENT_TARGET")):
    name = "MahiFin-" + platform
    source_builds = []
    paths = sorted((ROOT / "Apps" / "Shared").glob("*.swift"))
    paths += sorted((ROOT / "Apps" / platform).glob("*.swift"))
    for path in paths:
        relative = path.relative_to(ROOT).as_posix()
        reference = obj("file-" + relative, "PBXFileReference", f'lastKnownFileType = sourcecode.swift; path = {quote(relative)}; sourceTree = SOURCE_ROOT;')
        all_refs.append(reference)
        source_builds.append(obj(name + relative, "PBXBuildFile", f'fileRef = {reference};'))
    sources = obj(name + "sources", "PBXSourcesBuildPhase", f'buildActionMask = 2147483647; files = {array(source_builds)}; runOnlyForDeploymentPostprocessing = 0;')
    product_dep = obj(name + "core", "XCSwiftPackageProductDependency", f'package = {package}; productName = MahiFinCore;')
    linked_core = obj(name + "link", "PBXBuildFile", f'productRef = {product_dep};')
    frameworks = obj(name + "frameworks", "PBXFrameworksBuildPhase", f'buildActionMask = 2147483647; files = ({linked_core}); runOnlyForDeploymentPostprocessing = 0;')
    strings_build = obj(name + "stringsbuild", "PBXBuildFile", f'fileRef = {resource};')
    resources = obj(name + "resources", "PBXResourcesBuildPhase", f'buildActionMask = 2147483647; files = ({strings_build}); runOnlyForDeploymentPostprocessing = 0;')
    product = obj(name + "product", "PBXFileReference", f'explicitFileType = wrapper.application; includeInIndex = 0; path = {name}.app; sourceTree = BUILT_PRODUCTS_DIR;')
    products.append(product)
    configs = []
    for config in ("Debug", "Release"):
        values = {
            "PRODUCT_NAME": name, "PRODUCT_BUNDLE_IDENTIFIER": "dk.mahifin." + platform.lower(),
            "SDKROOT": sdk, "SUPPORTED_PLATFORMS": "iphoneos iphonesimulator" if platform == "iOS" else "appletvos appletvsimulator",
            "TARGETED_DEVICE_FAMILY": family, minimum: "18.0", "SWIFT_VERSION": "5.0",
            "INFOPLIST_FILE": "Apps/" + platform + "/Info.plist", "CODE_SIGN_STYLE": "Automatic",
            "GENERATE_INFOPLIST_FILE": "NO", "SWIFT_OPTIMIZATION_LEVEL": "-Onone" if config == "Debug" else "-O",
            "SWIFT_ACTIVE_COMPILATION_CONDITIONS": "DEBUG" if config == "Debug" else "",
            "ENABLE_USER_SCRIPT_SANDBOXING": "YES", "MARKETING_VERSION": "0.1.0", "CURRENT_PROJECT_VERSION": "1",
        }
        configs.append(obj(name + config, "XCBuildConfiguration", f'buildSettings = {settings(values)}; name = {config};'))
    configs_ref = obj(name + "configs", "XCConfigurationList", f'buildConfigurations = {array(configs)}; defaultConfigurationIsVisible = 0; defaultConfigurationName = Release;')
    target = obj(name + "target", "PBXNativeTarget", f'buildConfigurationList = {configs_ref}; buildPhases = ({sources}, {frameworks}, {resources}); buildRules = (); dependencies = (); name = {quote(name)}; packageProductDependencies = ({product_dep}); productName = {quote(name)}; productReference = {product}; productType = "com.apple.product-type.application";')
    targets.append(target)
    test_name = name + "-UITests"
    test_file = obj("uitest-file", "PBXFileReference", 'lastKnownFileType = sourcecode.swift; path = Tests/UITests/OnboardingTests.swift; sourceTree = SOURCE_ROOT;')
    all_refs.append(test_file)
    test_build = obj(test_name + "source", "PBXBuildFile", f'fileRef = {test_file};')
    test_sources = obj(test_name + "sources", "PBXSourcesBuildPhase", f'buildActionMask = 2147483647; files = ({test_build}); runOnlyForDeploymentPostprocessing = 0;')
    test_frameworks = obj(test_name + "frameworks", "PBXFrameworksBuildPhase", 'buildActionMask = 2147483647; files = (); runOnlyForDeploymentPostprocessing = 0;')
    test_resources = obj(test_name + "resources", "PBXResourcesBuildPhase", 'buildActionMask = 2147483647; files = (); runOnlyForDeploymentPostprocessing = 0;')
    test_product = obj(test_name + "product", "PBXFileReference", f'explicitFileType = wrapper.cfbundle; includeInIndex = 0; path = {test_name}.xctest; sourceTree = BUILT_PRODUCTS_DIR;')
    products.append(test_product)
    test_configs = []
    for config in ("Debug", "Release"):
        test_values = {"PRODUCT_NAME": test_name, "PRODUCT_BUNDLE_IDENTIFIER": "dk.mahifin." + platform.lower() + ".uitests", "SDKROOT": sdk, "TARGETED_DEVICE_FAMILY": family, minimum: "18.0", "SWIFT_VERSION": "5.0", "GENERATE_INFOPLIST_FILE": "YES", "TEST_TARGET_NAME": name, "CODE_SIGN_STYLE": "Automatic"}
        test_configs.append(obj(test_name + config, "XCBuildConfiguration", f'buildSettings = {settings(test_values)}; name = {config};'))
    test_config_list = obj(test_name + "configs", "XCConfigurationList", f'buildConfigurations = {array(test_configs)}; defaultConfigurationIsVisible = 0; defaultConfigurationName = Release;')
    proxy = obj(test_name + "proxy", "PBXContainerItemProxy", f'containerPortal = {uid("project")}; proxyType = 1; remoteGlobalIDString = {target}; remoteInfo = {quote(name)};')
    dependency = obj(test_name + "dependency", "PBXTargetDependency", f'target = {target}; targetProxy = {proxy};')
    test_target = obj(test_name + "target", "PBXNativeTarget", f'buildConfigurationList = {test_config_list}; buildPhases = ({test_sources}, {test_frameworks}, {test_resources}); buildRules = (); dependencies = ({dependency}); name = {quote(test_name)}; productName = {quote(test_name)}; productReference = {test_product}; productType = "com.apple.product-type.bundle.ui-testing";')
    targets.append(test_target)
    scheme_dir = PROJECT / "xcshareddata" / "xcschemes"
    scheme_dir.mkdir(parents=True, exist_ok=True)
    reference_xml = f'<BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{target}" BuildableName="{name}.app" BlueprintName="{name}" ReferencedContainer="container:MahiFin.xcodeproj"/>'
    scheme = f'''<?xml version="1.0" encoding="UTF-8"?>
<Scheme LastUpgradeVersion="1640" version="1.7">
 <BuildAction parallelizeBuildables="YES" buildImplicitDependencies="YES"><BuildActionEntries><BuildActionEntry buildForTesting="YES" buildForRunning="YES" buildForProfiling="YES" buildForArchiving="YES" buildForAnalyzing="YES">{reference_xml}</BuildActionEntry></BuildActionEntries></BuildAction>
 <TestAction buildConfiguration="Debug" shouldUseLaunchSchemeArgsEnv="YES"><Testables><TestableReference skipped="NO"><BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{test_target}" BuildableName="{test_name}.xctest" BlueprintName="{test_name}" ReferencedContainer="container:MahiFin.xcodeproj"/></TestableReference></Testables></TestAction>
 <LaunchAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" launchStyle="0" useCustomWorkingDirectory="NO" ignoresPersistentStateOnLaunch="NO" debugDocumentVersioning="YES" allowLocationSimulation="YES"><BuildableProductRunnable runnableDebuggingMode="0">{reference_xml}</BuildableProductRunnable></LaunchAction>
 <ProfileAction buildConfiguration="Release" shouldUseLaunchSchemeArgsEnv="YES" savedToolIdentifier="" useCustomWorkingDirectory="NO" debugDocumentVersioning="YES"><BuildableProductRunnable runnableDebuggingMode="0">{reference_xml}</BuildableProductRunnable></ProfileAction>
 <AnalyzeAction buildConfiguration="Debug"/><ArchiveAction buildConfiguration="Release" revealArchiveInOrganizer="YES"/>
</Scheme>
'''
    (scheme_dir / (name + ".xcscheme")).write_text(scheme, encoding="utf-8")
    plist = {"CFBundleDevelopmentRegion": "en", "CFBundleExecutable": "$(EXECUTABLE_NAME)", "CFBundleIdentifier": "$(PRODUCT_BUNDLE_IDENTIFIER)", "CFBundleInfoDictionaryVersion": "6.0", "CFBundleName": "MahiFin", "CFBundlePackageType": "APPL", "CFBundleShortVersionString": "$(MARKETING_VERSION)", "CFBundleVersion": "$(CURRENT_PROJECT_VERSION)"}
    if platform == "iOS":
        plist.update({"UILaunchScreen": {}, "UIBackgroundModes": ["audio"], "UISupportedInterfaceOrientations": ["UIInterfaceOrientationPortrait", "UIInterfaceOrientationLandscapeLeft", "UIInterfaceOrientationLandscapeRight"]})
    (ROOT / "Apps" / platform).mkdir(exist_ok=True)
    (ROOT / "Apps" / platform / "Info.plist").write_bytes(plistlib.dumps(plist, sort_keys=True))

product_group = obj("products", "PBXGroup", f'children = {array(products)}; name = Products; sourceTree = "<group>";')
main_group = obj("group", "PBXGroup", f'children = {array(sorted(set(all_refs)) + [product_group])}; sourceTree = "<group>";')
configs = []
for config in ("Debug", "Release"):
    configs.append(obj("project-" + config, "XCBuildConfiguration", 'buildSettings = {CLANG_ENABLE_MODULES = YES;}; name = ' + config + ';'))
config_list = obj("project-configs", "XCConfigurationList", f'buildConfigurations = {array(configs)}; defaultConfigurationIsVisible = 0; defaultConfigurationName = Release;')
project = obj("project", "PBXProject", f'attributes = {{LastUpgradeCheck = 1640;}}; buildConfigurationList = {config_list}; compatibilityVersion = "Xcode 14.0"; developmentRegion = en; hasScannedForEncodings = 0; knownRegions = (en, da, Base); mainGroup = {main_group}; packageReferences = ({package}); productRefGroup = {product_group}; projectDirPath = ""; projectRoot = ""; targets = {array(targets)};')
text = "// !$*UTF8*$!\n{ archiveVersion = 1; classes = {}; objectVersion = 56; objects = {\n"
text += "\n".join(f"{key} = {{ {objects[key]} }};" for key in sorted(objects))
text += f"\n}}; rootObject = {project}; }}\n"
(PROJECT / "project.pbxproj").write_text(text, encoding="utf-8")
print("Generated iOS/tvOS 18 targets and shared schemes")
