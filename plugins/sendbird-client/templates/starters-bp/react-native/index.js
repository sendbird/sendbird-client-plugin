import { AppRegistry } from 'react-native';
import App from './App';
import appConfig from './app.json';

// app.json `name` is the name both native projects start: getMainComponentName in
// android/.../MainActivity.kt and withModuleName in ios/StarterReactNative/SceneDelegate.swift.
AppRegistry.registerComponent(appConfig.name, () => App);
