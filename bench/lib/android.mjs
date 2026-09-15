/**
 * Android device setup that agent-device has no command for.
 */
import { execFile } from 'node:child_process'
import path from 'node:path'
import { promisify } from 'node:util'

export const MOCK_SERVER_PORT = 8787

/**
 * Makes the mock server answer on the emulator's own 127.0.0.1.
 *
 * The emulator can reach the host's loopback through 10.0.2.2, but every
 * request through that NAT took 0.6-1 s on the machine this was built on,
 * which drowned out the differences being measured. `adb reverse` forwards
 * the port instead (a few ms). This is device setup rather than UI
 * automation, so adb is called directly.
 */
export async function reversePort(port, { serial } = {}) {
  const sdk = process.env.ANDROID_HOME ?? process.env.ANDROID_SDK_ROOT
  const adb = sdk ? path.join(sdk, 'platform-tools', 'adb') : 'adb'
  await promisify(execFile)(adb, [
    ...(serial ? ['-s', serial] : []),
    'reverse',
    `tcp:${port}`,
    `tcp:${port}`,
  ])
}
