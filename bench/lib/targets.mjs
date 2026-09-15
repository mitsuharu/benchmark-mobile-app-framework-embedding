/**
 * What gets measured: every framework on every platform, and where the
 * benchmark build of each ends up (see scripts/build.sh).
 */
import path from 'node:path'
import { fileURLToPath } from 'node:url'

export const FRAMEWORKS = ['native', 'kmp', 'flutter', 'expo']
export const PLATFORMS = ['ios', 'android']

const BENCH_ROOT = fileURLToPath(new URL('..', import.meta.url))

/** Bundle id (iOS) / application id (Android) of each host app. */
const APP_IDS = {
  // `native` is a Java keyword, so it cannot be part of an Android package.
  native: {
    ios: 'com.example.benchmark.native.host',
    android: 'com.example.benchmark.nativeapp.host',
  },
  kmp: 'com.example.benchmark.kmp.host',
  flutter: 'com.example.benchmark.flutter.host',
  // Kept from sample-expo-brownfield.
  expo: 'com.example.sample.expo.brownfield.host',
}

export function appId(framework, platform) {
  const id = APP_IDS[framework]
  if (!id) {
    throw new Error(`Unknown framework "${framework}"`)
  }
  return typeof id === 'string' ? id : id[platform]
}

/** How the apps are built; see scripts/build.sh. */
export const BUILDS = ['release', 'debug']

/**
 * The installable build that scripts/build.sh produces. An iOS build for a
 * physical device is a separate, signed build for iphoneos; Android runs the
 * same APK on emulators and devices.
 */
export function artifactPath(
  framework,
  platform,
  build = 'release',
  physical = false,
) {
  const file = platform === 'ios' ? 'HostApp.app' : `app-${build}.apk`
  const dir = platform === 'ios' && physical ? 'ios-device' : platform
  return path.join(BENCH_ROOT, 'artifacts', build, framework, dir, file)
}
