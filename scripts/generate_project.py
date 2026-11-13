"""Generate native Xcode targets without third-party tools or package resolution."""
from pathlib import Path
import hashlib
root = Path(__file__).resolve().parent.parent
out = root / 'OpenPharmaMeeting.xcodeproj'; out.mkdir(exist_ok=True)
def uid(s): return hashlib.sha256(s.encode()).hexdigest()[:24].upper()
objects=[]
def obj(name, body): objects.append(f'{uid(name)} = {{ {body} }};'); return uid(name)
modules=['MeetingDataKit','MeetingCaptureKit','TranscriptionKit','PrivacyPolicyKit','EnterpriseConnectorKit','ReportKit']
allnames=modules+['OpenPharmaMeeting']
products={}; files=[]
assets_ref=obj('App/Assets.xcassets', 'isa = PBXFileReference; lastKnownFileType = folder.assetcatalog; path = "App/Assets.xcassets"; sourceTree = SOURCE_ROOT;')
files.append(assets_ref)
assets_build=obj('App/Assets.xcassets build', f'isa = PBXBuildFile; fileRef = {assets_ref};')
localized_builds=[]
for name in ['Localizable.strings','InfoPlist.strings']:
    localized_refs=[]
    for language in ['en','ru']:
        localized_refs.append(obj(f'App/{language}.lproj/{name}', f'isa = PBXFileReference; lastKnownFileType = text.plist.strings; path = "App/{language}.lproj/{name}"; sourceTree = SOURCE_ROOT;'))
    variant=obj('App/'+name, f'isa = PBXVariantGroup; children = ({",".join(localized_refs)},); name = {name}; sourceTree = "<group>";')
    files.append(variant)
    localized_builds.append(obj('App/'+name+' build', f'isa = PBXBuildFile; fileRef = {variant};'))
for name in allnames:
    app=name=='OpenPharmaMeeting'
    products[name]=obj(name+'product', f'isa = PBXFileReference; explicitFileType = {"wrapper.application" if app else "archive.ar"}; path = {name+".app" if app else "lib"+name+".a"}; sourceTree = BUILT_PRODUCTS_DIR;')
for name in allnames:
    app=name=='OpenPharmaMeeting'
    builds=[]
    for path in sorted((root/('App' if app else 'Sources/'+name)).glob('*.swift')):
        rel=str(path.relative_to(root))
        ref=obj(rel, f'isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = "{rel}"; sourceTree = SOURCE_ROOT;'); files.append(ref)
        builds.append(obj(rel+'build', f'isa = PBXBuildFile; fileRef = {ref};'))
    deps=modules if app else ([] if name=='MeetingDataKit' else ['MeetingDataKit'])
    dependencies=[]; links=[]
    for dep in deps:
        proxy=obj(name+dep+'proxy',f'isa = PBXContainerItemProxy; containerPortal = {uid("project")}; proxyType = 1; remoteGlobalIDString = {uid(dep+"target")}; remoteInfo = {dep};')
        dependencies.append(obj(name+dep+'dep',f'isa = PBXTargetDependency; target = {uid(dep+"target")}; targetProxy = {proxy};'))
        links.append(obj(name+dep+'link',f'isa = PBXBuildFile; fileRef = {products[dep]};'))
    sources=obj(name+'sources',f'isa = PBXSourcesBuildPhase; buildActionMask = 2147483647; files = ({",".join(builds)},); runOnlyForDeploymentPostprocessing = 0;')
    frameworks=obj(name+'frameworks',f'isa = PBXFrameworksBuildPhase; buildActionMask = 2147483647; files = ({(",".join(links)+",") if links else ""}); runOnlyForDeploymentPostprocessing = 0;')
    resources=obj(name+'resources',f'isa = PBXResourcesBuildPhase; buildActionMask = 2147483647; files = ({",".join([assets_build]+localized_builds)},); runOnlyForDeploymentPostprocessing = 0;') if app else None
    configs=[]
    for c in ['Debug','Release']:
        extra='GENERATE_INFOPLIST_FILE = NO; INFOPLIST_FILE = App/Info.plist; TARGETED_DEVICE_FAMILY = 2; ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;' if app else 'DEFINES_MODULE = YES; SKIP_INSTALL = YES;'
        configs.append(obj(name+c,f'''isa = XCBuildConfiguration; name = {c}; buildSettings = {{
        SDKROOT = iphoneos; IPHONEOS_DEPLOYMENT_TARGET = 16.0; SWIFT_VERSION = 5.0;
        PRODUCT_NAME = "$(TARGET_NAME)"; PRODUCT_BUNDLE_IDENTIFIER = org.openpharmameeting.{name};
        ALWAYS_SEARCH_USER_PATHS = NO; CODE_SIGN_STYLE = Automatic; CURRENT_PROJECT_VERSION = 4; MARKETING_VERSION = 0.1.2;
        SWIFT_OPTIMIZATION_LEVEL = "{'-Onone' if c=='Debug' else '-O'}"; {extra}
        SUPPORTS_MACCATALYST = NO; ENABLE_USER_SCRIPT_SANDBOXING = YES;
        }};'''))
    conf=obj(name+'configs',f'isa = XCConfigurationList; buildConfigurations = ({",".join(configs)},); defaultConfigurationIsVisible = 0; defaultConfigurationName = Release;')
    obj(name+'target',f'''isa = PBXNativeTarget; name = {name}; productName = {name}; productReference = {products[name]}; productType = "com.apple.product-type.{"application" if app else "library.static"}"; buildConfigurationList = {conf}; buildPhases = ({sources},{frameworks}{(','+resources) if resources else ''},); buildRules = (); dependencies = ({(",".join(dependencies)+",") if dependencies else ""});''')
productsGroup=obj('products',f'isa = PBXGroup; children = ({",".join(products.values())},); name = Products; sourceTree = "<group>";')
group=obj('group',f'isa = PBXGroup; children = ({",".join(files)},{productsGroup},); sourceTree = "<group>";')
pconfigs=[]
for c in ['Debug','Release']: pconfigs.append(obj('project'+c,f'isa = XCBuildConfiguration; name = {c}; buildSettings = {{}};'))
pconf=obj('projectconfigs',f'isa = XCConfigurationList; buildConfigurations = ({",".join(pconfigs)},); defaultConfigurationIsVisible = 0; defaultConfigurationName = Release;')
project=obj('project',f'''isa = PBXProject; attributes = {{ LastUpgradeCheck = 1600; }}; buildConfigurationList = {pconf}; compatibilityVersion = "Xcode 14.0"; developmentRegion = en; knownRegions = (en,ru,Base); mainGroup = {group}; productRefGroup = {productsGroup}; projectDirPath = ""; projectRoot = ""; targets = ({",".join(uid(n+"target") for n in allnames)},);''')
(out/'project.pbxproj').write_text('// !$*UTF8*$!\n{ archiveVersion = 1; classes = {}; objectVersion = 56; objects = {\n'+'\n'.join(objects)+f'\n}}; rootObject = {project}; }}\n')
scheme=out/'xcshareddata/xcschemes'; scheme.mkdir(parents=True,exist_ok=True)
ref=f'<BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{uid("OpenPharmaMeetingtarget")}" BuildableName="OpenPharmaMeeting.app" BlueprintName="OpenPharmaMeeting" ReferencedContainer="container:OpenPharmaMeeting.xcodeproj"/>'
(scheme/'OpenPharmaMeeting.xcscheme').write_text(f'''<?xml version="1.0" encoding="UTF-8"?>
<Scheme LastUpgradeVersion="1600" version="1.3"><BuildAction parallelizeBuildables="YES" buildImplicitDependencies="YES"><BuildActionEntries><BuildActionEntry buildForTesting="YES" buildForRunning="YES" buildForProfiling="YES" buildForArchiving="YES" buildForAnalyzing="YES">{ref}</BuildActionEntry></BuildActionEntries></BuildAction><LaunchAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.IDERunLauncher" launchStyle="0" useCustomWorkingDirectory="NO" ignoresPersistentStateOnLaunch="NO" debugDocumentVersioning="YES" debugServiceExtension="internal" allowLocationSimulation="YES"><BuildableProductRunnable runnableDebuggingMode="0">{ref}</BuildableProductRunnable></LaunchAction><AnalyzeAction buildConfiguration="Debug"/><ArchiveAction buildConfiguration="Release" revealArchiveInOrganizer="YES"/></Scheme>''')
