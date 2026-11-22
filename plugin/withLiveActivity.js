const fs = require('fs');
const path = require('path');
const { withInfoPlist, withEntitlementsPlist, withXcodeProject, withDangerousMod } = require('@expo/config-plugins');

const EXT = 'LACWidget';
const TEMPLATES = path.join(__dirname, 'templates');
const SHARED = path.join(__dirname, '..', 'ios', 'Shared', 'LACAttributes.swift');

/** options: { viewFile?: string } path (relative to project root) of a custom SwiftUI file replacing the default view */
module.exports = function withLiveActivity(config, options = {}) {
  config = withInfoPlist(config, (c) => {
    c.modResults.NSSupportsLiveActivities = true;
    c.modResults.NSSupportsLiveActivitiesFrequentUpdates = true;
    return c;
  });

  config = withEntitlementsPlist(config, (c) => {
    c.modResults['aps-environment'] ??= 'development'; // Xcode swaps to production when archiving
    return c;
  });

  config = withDangerousMod(config, ['ios', (c) => {
    const dir = path.join(c.modRequest.platformProjectRoot, EXT);
    fs.mkdirSync(dir, { recursive: true });
    fs.copyFileSync(SHARED, path.join(dir, 'LACAttributes.swift')); // always refreshed
    fs.copyFileSync(path.join(TEMPLATES, 'LACWidgetBundle.swift'), path.join(dir, 'LACWidgetBundle.swift'));
    fs.copyFileSync(path.join(TEMPLATES, 'Info.plist'), path.join(dir, 'Info.plist'));
    const view = path.join(dir, 'LACLiveActivityView.swift');
    if (options.viewFile) fs.copyFileSync(path.resolve(c.modRequest.projectRoot, options.viewFile), view);
    else if (!fs.existsSync(view)) fs.copyFileSync(path.join(TEMPLATES, 'LACLiveActivityView.swift'), view);
    return c;
  }]);

  config = withXcodeProject(config, (c) => {
    const proj = c.modResults;
    if (proj.pbxTargetByName(EXT)) return c; // already added (prebuild without --clean)

    const bundleId = `${c.ios.bundleIdentifier}.${EXT}`;
    const files = ['LACAttributes.swift', 'LACWidgetBundle.swift', 'LACLiveActivityView.swift'];
    const group = proj.addPbxGroup([...files, 'Info.plist'], EXT, EXT);
    proj.addToPbxGroup(group.uuid, proj.getFirstProject().firstProject.mainGroup);

    const target = proj.addTarget(EXT, 'app_extension', EXT, bundleId);
    proj.addBuildPhase(files, 'PBXSourcesBuildPhase', 'Sources', target.uuid);
    proj.addBuildPhase([], 'PBXResourcesBuildPhase', 'Resources', target.uuid);
    proj.addBuildPhase([], 'PBXFrameworksBuildPhase', 'Frameworks', target.uuid);

    const main = proj.getFirstTarget().uuid;
    proj.addBuildPhase([`${EXT}.appex`], 'PBXCopyFilesBuildPhase', 'Embed Foundation Extensions', main, 'app_extension');
    proj.addTargetDependency(main, [target.uuid]);

    const team = c.ios.appleTeamId;
    const configs = proj.pbxXCBuildConfigurationSection();
    for (const key of Object.keys(configs)) {
      const s = configs[key].buildSettings;
      if (!s || s.PRODUCT_NAME !== `"${EXT}"`) continue;
      Object.assign(s, {
        INFOPLIST_FILE: `${EXT}/Info.plist`,
        PRODUCT_BUNDLE_IDENTIFIER: bundleId,
        SWIFT_VERSION: '5.0',
        IPHONEOS_DEPLOYMENT_TARGET: '16.2',
        TARGETED_DEVICE_FAMILY: '"1,2"',
        MARKETING_VERSION: c.version ?? '1.0.0',
        CURRENT_PROJECT_VERSION: c.ios.buildNumber ?? '1',
        SKIP_INSTALL: 'YES',
        CODE_SIGN_STYLE: 'Automatic',
        LD_RUNPATH_SEARCH_PATHS: '"$(inherited) @executable_path/Frameworks @executable_path/../../Frameworks"',
        ...(team ? { DEVELOPMENT_TEAM: team } : {}),
      });
    }
    return c;
  });

  return config;
};
