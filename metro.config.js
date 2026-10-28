// Expo's default Metro config, plus one rule for a linked SDK checkout (tools/sdk_link.sh).
// The checkout brings its own react, react-native and react-native-webview for its tests. Resolving those from inside it bundles a second React Native, which fails at startup with "TypeError: property is not writable".
// So those packages always resolve from this app, as if they were imported from the project root.
const path = require("path");
const { getDefaultConfig } = require("expo/metro-config");

const config = getDefaultConfig(__dirname);

const SINGLETONS = ["react", "react-native", "react-native-webview"];
const appOrigin = path.join(__dirname, "index.js");

config.resolver.resolveRequest = (context, moduleName, platform) => {
  const singleton = SINGLETONS.some((name) => moduleName === name || moduleName.startsWith(`${name}/`));
  return context.resolveRequest(singleton ? { ...context, originModulePath: appOrigin } : context, moduleName, platform);
};

module.exports = config;
