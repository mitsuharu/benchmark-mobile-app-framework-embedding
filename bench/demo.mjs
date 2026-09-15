#!/usr/bin/env node
/**
 * Records the demo GIFs in the root README: each benchmark build walking
 * through the screens at a pace a reader can follow.
 *
 *   node demo.mjs --platform ios --framework all
 *   node demo.mjs --platform android --framework kmp --serial emulator-5554
 *
 * Build the apps first with scripts/build.sh, and keep mock-server running.
 * The recordings are turned into GIFs by scripts/mp4-to-gif.swift (macOS).
 */
import { execFile } from 'node:child_process'
import { mkdir, mkdtemp } from 'node:fs/promises'
import { tmpdir } from 'node:os'
import path from 'node:path'
import { fileURLToPath } from 'node:url'
import { parseArgs, promisify } from 'node:util'

import { AgentDevice } from './lib/agent-device.mjs'
import { MOCK_SERVER_PORT, reversePort } from './lib/android.mjs'
import {
  COMMAND_APPLIED_TEXT,
  FIRST_RESULT_TEXT,
  SEARCH_BUTTON_TEXT,
  SELECTORS,
  tap,
  WAIT_MS,
} from './lib/scenario.mjs'
import { appId, artifactPath, FRAMEWORKS, PLATFORMS } from './lib/targets.mjs'

const { values: options } = parseArgs({
  options: {
    platform: { type: 'string' },
    framework: { type: 'string', default: 'all' },
    device: { type: 'string' },
    udid: { type: 'string' },
    serial: { type: 'string' },
    out: { type: 'string', default: '../docs/media' },
    width: { type: 'string', default: '270' },
    fps: { type: 'string', default: '8' },
  },
})

const platform = options.platform
if (!PLATFORMS.includes(platform)) {
  console.error(`--platform must be one of: ${PLATFORMS.join(', ')}`)
  process.exit(1)
}
const frameworks =
  options.framework === 'all' ? FRAMEWORKS : options.framework.split(',')

const target = [
  '--platform',
  platform,
  ...(options.device ? ['--device', options.device] : []),
  ...(options.udid ? ['--udid', options.udid] : []),
  ...(options.serial ? ['--serial', options.serial] : []),
]

const BENCH_ROOT = path.dirname(fileURLToPath(import.meta.url))
const outDir = path.resolve(BENCH_ROOT, options.out)
const workDir = await mkdtemp(path.join(tmpdir(), 'bench-demo-'))

/** How long each state stays on screen, so the GIF can be followed. */
const PAUSE_MS = '1200'

async function record(framework) {
  const selectors = SELECTORS[platform]
  const device = new AgentDevice({ session: `demo-${platform}` })
  const video = path.join(workDir, `${platform}-${framework}.mp4`)
  const pause = () => device.call(['wait', PAUSE_MS])

  await device.call([
    'install',
    appId(framework, platform),
    artifactPath(framework, platform),
    ...target,
  ])
  await device.call([
    'open',
    appId(framework, platform),
    '--relaunch',
    ...target,
  ])
  await device.call(['wait', selectors.openEmbedded, String(WAIT_MS)])

  await device.call(['record', 'start', video, '--quality', 'high'])
  try {
    await pause()
    await device.call(['press', selectors.openEmbedded])
    await device.call(['wait', 'text', SEARCH_BUTTON_TEXT, String(WAIT_MS)])
    await pause()
    await tap(device, selectors.search)
    await device.call(['wait', 'text', FIRST_RESULT_TEXT, String(WAIT_MS)])
    await pause()
    for (const selector of selectors.sendCommand) {
      await device.call(['press', selector])
    }
    await device.call(['wait', 'text', COMMAND_APPLIED_TEXT, String(WAIT_MS)])
    await pause()
    await tap(device, selectors.back)
    await device.call(['wait', selectors.openEmbedded, String(WAIT_MS)])
    await pause()
  } finally {
    await device.call(['record', 'stop'])
    await device.call(['close']).catch(() => {})
  }

  const gif = path.join(outDir, `${platform}-${framework}.gif`)
  const { stdout } = await promisify(execFile)('swift', [
    path.join(BENCH_ROOT, 'scripts', 'mp4-to-gif.swift'),
    video,
    gif,
    options.width,
    options.fps,
  ])
  console.log(`[demo] ${stdout.trim()}`)
}

await mkdir(outDir, { recursive: true })
if (platform === 'android') {
  await reversePort(MOCK_SERVER_PORT, { serial: options.serial })
}
for (const framework of frameworks) {
  await record(framework)
}
