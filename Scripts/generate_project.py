from pathlib import Path
import hashlib
from xml.sax.saxutils import escape
root=Path(__file__).resolve().parent.parent
def uid(s): return hashlib.sha1(s.encode()).hexdigest()[:24].upper()
def q(s): return '"'+s.replace('\\','\\\\').replace('"','\\"')+'"'
objects=[]
def obj(name, body): objects.append(f'\t\t{uid(name)} = {{ {body} }};')
files=[]
for folder in ['App','Core']:
    for path in sorted((root/'Songcrumb'/folder).glob('*.swift')):
        name=folder+'/'+path.name
        obj('ref:'+name,f'isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = {q(path.name)}; sourceTree = "<group>";')
        obj('build:'+name,f'isa = PBXBuildFile; fileRef = {uid("ref:"+name)};')
        files.append(name)
for name,typ in [('Info.plist','text.plist.xml'),('Songcrumb.entitlements','text.plist.entitlements'),('AppIcon.icns','image.icns')]:
    obj('ref:'+name,f'isa = PBXFileReference; lastKnownFileType = {typ}; path = {q(name)}; sourceTree = "<group>";')
obj('build:icon',f'isa = PBXBuildFile; fileRef = {uid("ref:AppIcon.icns")};')
obj('product','isa = PBXFileReference; explicitFileType = wrapper.application; includeInIndex = 0; path = Songcrumb.app; sourceTree = BUILT_PRODUCTS_DIR;')
for folder in ['App','Core']:
    children=', '.join(uid('ref:'+f) for f in files if f.startswith(folder+'/'))
    obj('group:'+folder,f'isa = PBXGroup; children = ({children},); name = {folder}; path = Songcrumb/{folder}; sourceTree = "<group>";')
obj('group:resources',f'isa = PBXGroup; children = ({uid("ref:Info.plist")}, {uid("ref:Songcrumb.entitlements")}, {uid("ref:AppIcon.icns")},); name = Resources; path = Songcrumb; sourceTree = "<group>";')
obj('group:products',f'isa = PBXGroup; children = ({uid("product")},); name = Products; sourceTree = "<group>";')
obj('group:main',f'isa = PBXGroup; children = ({uid("group:App")}, {uid("group:Core")}, {uid("group:resources")}, {uid("group:products")},); sourceTree = "<group>";')
obj('phase:sources',f'isa = PBXSourcesBuildPhase; buildActionMask = 2147483647; files = ({", ".join(uid("build:"+f) for f in files)},); runOnlyForDeploymentPostprocessing = 0;')
obj('phase:frameworks','isa = PBXFrameworksBuildPhase; buildActionMask = 2147483647; files = (); runOnlyForDeploymentPostprocessing = 0;')
obj('phase:resources',f'isa = PBXResourcesBuildPhase; buildActionMask = 2147483647; files = ({uid("build:icon")},); runOnlyForDeploymentPostprocessing = 0;')
common={'ARCHS':'arm64','SDKROOT':'macosx','MACOSX_DEPLOYMENT_TARGET':'14.0','SWIFT_VERSION':'5.0','CLANG_ENABLE_MODULES':'YES','SWIFT_STRICT_CONCURRENCY':'targeted'}
app={'PRODUCT_NAME':'$(TARGET_NAME)','PRODUCT_BUNDLE_IDENTIFIER':'io.github.akshatdhabi.songcrumb','INFOPLIST_FILE':'Songcrumb/Info.plist','GENERATE_INFOPLIST_FILE':'NO','CODE_SIGN_ENTITLEMENTS':'Songcrumb/Songcrumb.entitlements','CODE_SIGN_STYLE':'Automatic','CODE_SIGN_IDENTITY':'-','ENABLE_HARDENED_RUNTIME':'YES','ENABLE_APP_SANDBOX':'NO','SUPPORTED_PLATFORMS':'macosx','MARKETING_VERSION':'1.0','CURRENT_PROJECT_VERSION':'1','LD_RUNPATH_SEARCH_PATHS':'$(inherited) @executable_path/../Frameworks'}
for owner in ['project','target']:
    for config in ['Debug','Release']:
        settings={**common, **(app if owner=='target' else {}),'SWIFT_OPTIMIZATION_LEVEL':'-Onone' if config=='Debug' else '-O','DEBUG_INFORMATION_FORMAT':'dwarf' if config=='Debug' else 'dwarf-with-dsym'}
        if config=='Debug': settings['SWIFT_ACTIVE_COMPILATION_CONDITIONS']='DEBUG'; settings['ENABLE_TESTABILITY']='YES'
        if config=='Release': settings['SWIFT_COMPILATION_MODE']='wholemodule'
        body=' '.join(k+' = '+q(v)+';' for k,v in settings.items())
        obj('config:'+owner+config,f'isa = XCBuildConfiguration; buildSettings = {{ {body} }}; name = {config};')
    obj('configs:'+owner,f'isa = XCConfigurationList; buildConfigurations = ({uid("config:"+owner+"Debug")}, {uid("config:"+owner+"Release")},); defaultConfigurationIsVisible = 0; defaultConfigurationName = Release;')
obj('target',f'isa = PBXNativeTarget; buildConfigurationList = {uid("configs:target")}; buildPhases = ({uid("phase:sources")}, {uid("phase:frameworks")}, {uid("phase:resources")},); buildRules = (); dependencies = (); name = Songcrumb; productName = Songcrumb; productReference = {uid("product")}; productType = "com.apple.product-type.application";')
obj('project',f'isa = PBXProject; attributes = {{ BuildIndependentTargetsInParallel = YES; LastUpgradeCheck = 1600; }}; buildConfigurationList = {uid("configs:project")}; compatibilityVersion = "Xcode 14.0"; developmentRegion = en; hasScannedForEncodings = 0; knownRegions = (en, Base,); mainGroup = {uid("group:main")}; productRefGroup = {uid("group:products")}; projectDirPath = ""; projectRoot = ""; targets = ({uid("target")},);')
(root/'Songcrumb.xcodeproj/project.pbxproj').write_text('// !$*UTF8*$!\n{\n\tarchiveVersion = 1;\n\tclasses = {};\n\tobjectVersion = 56;\n\tobjects = {\n'+'\n'.join(objects)+'\n\t};\n\trootObject = '+uid('project')+';\n}\n')
ref=f'<BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{uid("target")}" BuildableName="Songcrumb.app" BlueprintName="Songcrumb" ReferencedContainer="container:Songcrumb.xcodeproj"/>'
scheme=f'''<?xml version="1.0" encoding="UTF-8"?>
<Scheme LastUpgradeVersion="1600" version="1.3">
<BuildAction parallelizeBuildables="YES" buildImplicitDependencies="YES"><BuildActionEntries><BuildActionEntry buildForTesting="YES" buildForRunning="YES" buildForProfiling="YES" buildForArchiving="YES" buildForAnalyzing="YES">{ref}</BuildActionEntry></BuildActionEntries></BuildAction>
<TestAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" shouldUseLaunchSchemeArgsEnv="YES"><Testables/></TestAction>
<LaunchAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" launchStyle="0" useCustomWorkingDirectory="NO" ignoresPersistentStateOnLaunch="NO" debugDocumentVersioning="YES" debugServiceExtension="internal" allowLocationSimulation="YES"><BuildableProductRunnable runnableDebuggingMode="0">{ref}</BuildableProductRunnable></LaunchAction>
<ProfileAction buildConfiguration="Release" shouldUseLaunchSchemeArgsEnv="YES" savedToolIdentifier="" useCustomWorkingDirectory="NO" debugDocumentVersioning="YES"><BuildableProductRunnable runnableDebuggingMode="0">{ref}</BuildableProductRunnable></ProfileAction>
<AnalyzeAction buildConfiguration="Debug"/>
<ArchiveAction buildConfiguration="Release" revealArchiveInOrganizer="YES"/>
</Scheme>'''
(root/'Songcrumb.xcodeproj/xcshareddata/xcschemes/Songcrumb.xcscheme').write_text(scheme)
