#!/usr/bin/env node
/**
 * Runs the benchmark scenario against the benchmark builds in artifacts/ and
 * writes the raw numbers to results/<build>/<platform>-<framework>.json
 * (results/<build>-device/ with --physical).
 *
 *   node run.mjs --platform ios --framework native
 *   node run.mjs --platform android --framework all --iterations 10
 *   node run.mjs --platform ios --framework all --build debug
 *   node run.mjs --platform android --framework all --physical --serial <serial>
 *
 * Build the apps first with scripts/build.sh, and keep mock-server running.
 * The Expo debug build also needs Metro (`npx expo start` in expo/expo-app).
 */
import { mkdir, readdir, readFile, stat, writeFile } from 'node:fs/promises'
import path from 'node:path'
import { fileURLToPath } from 'node:url'
import { parseArgs } from 'node:util'

import { AgentDevice } from './lib/agent-device.mjs'
import { MOCK_SERVER_PORT, reversePort } from './lib/android.mjs'
import { iterationLabel, splitByIteration } from './lib/log-segments.mjs'
import { computeTimings, parseMarkers } from './lib/markers.mjs'
import { runScenario } from './lib/scenario.mjs'
import { summarize } from './lib/stats.mjs'
import {
  appId,
  artifactPath,
  BUILDS,
  FRAMEWORKS,
  PLATFORMS,
} from './lib/targets.mjs'

const { values: options } = parseArgs({
  options: {
    platform: { type: 'string' },
    framework: { type: 'string', default: 'all' },
    iterations: { type: 'string', default: '5' },
    warmup: { type: 'string', default: '1' },
    retries: { type: 'string', default: '2' },
    'settle-ms': { type: 'string', default: '2000' },
    device: { type: 'string' },
    // How the README names the device, e.g. "iPhone 17 シミュレータ（iOS 26.5）".
    'device-label': { type: 'string' },
    udid: { type: 'string' },
    serial: { type: 'string' },
    build: { type: 'string', default: 'release' },
    physical: { type: 'boolean', default: false },
    out: { type: 'string', default: 'results' },
    'skip-install': { type: 'boolean', default: false },
    verbose: { type: 'boolean', default: false },
  },
})

const platform = options.platform
if (!PLATFORMS.includes(platform)) {
  console.error(`--platform must be one of: ${PLATFORMS.join(', ')}`)
  process.exit(1)
}
const frameworks =
  options.framework === 'all' ? FRAMEWORKS : options.framework.split(',')
const iterations = Number(options.iterations)
const warmup = Number(options.warmup)
const retries = Number(options.retries)
const settleMs = Number(options['settle-ms'])
const build = options.build
if (!BUILDS.includes(build)) {
  console.error(`--build must be one of: ${BUILDS.join(', ')}`)
  process.exit(1)
}
/** Physical devices are measured on their own and reported separately. */
const physical = options.physical
const resultsName = physical ? `${build}-device` : build

/** Selects the device on the first command; the session remembers it. */
const target = [
  '--platform',
  platform,
  ...(options.device ? ['--device', options.device] : []),
  ...(options.udid ? ['--udid', options.udid] : []),
  ...(options.serial ? ['--serial', options.serial] : []),
]

const log = (line) => console.log(`[bench] ${line}`)

async function sizeOf(file) {
  const info = await stat(file)
  if (!info.isDirectory()) {
    return info.size
  }
  let total = 0
  for (const entry of await readdir(file)) {
    total += await sizeOf(path.join(file, entry))
  }
  return total
}

function summarizeRuns(runs, pick) {
  const keys = new Set(runs.flatMap((run) => Object.keys(pick(run) ?? {})))
  return Object.fromEntries(
    [...keys].map((key) => [
      key,
      summarize(runs.map((run) => pick(run)?.[key])),
    ]),
  )
}

async function measure(framework) {
  const id = appId(framework, platform)
  const artifact = artifactPath(framework, platform, build, physical)
  const device = new AgentDevice({
    session: `bench-${platform}${physical ? '-device' : ''}`,
    log: options.verbose ? log : () => {},
  })

  log(
    `${platform}/${framework}: installing ${path.relative(process.cwd(), artifact)}`,
  )
  if (!options['skip-install']) {
    // `install` rather than `reinstall`: reinstall fails when the app is not
    // there yet, and the apps keep no state that a fresh install would clear.
    await device.call(['install', id, artifact, ...target])
  }
  const opened = await device.call(['open', id, '--relaunch', ...target])

  // The session log is read after every run and then cleared. An iOS run logs
  // megabytes (the XCTest runner is chatty), and agent-device rotates app.log
  // past 5 MB keeping one generation, so reading once at the end loses the
  // first runs' markers.
  const readIfPresent = (file) => readFile(file, 'utf8').catch(() => '')
  const readSessionLog = async () => {
    const { path: logPath } = await device.call(['logs', 'path'])
    return `${await readIfPresent(`${logPath}.1`)}\n${await readIfPresent(logPath)}`
  }

  const total = warmup + iterations
  const runs = []
  try {
    for (let index = 0; index < total; index++) {
      for (let attempt = 0; ; attempt++) {
        await device.call(['logs', 'clear', '--restart'])
        await device.call(['logs', 'mark', iterationLabel(index)])
        try {
          const run = await runScenario(device, {
            appId: id,
            platform,
            settleMs,
            // On a physical iPhone the app log is the output of the process
            // agent-device launched, and `logs clear --restart` has just
            // relaunched the app to capture it. Relaunching again would start
            // a process whose markers never reach the log.
            relaunch: !(physical && platform === 'ios'),
          })
          // Let the log stream flush the run's last markers.
          await device.call(['wait', '1500'])
          const [segment] = splitByIteration(
            (await readSessionLog()).replaceAll(
              iterationLabel(index),
              iterationLabel(0),
            ),
            1,
          )
          runs.push({ ...run, markers: parseMarkers(segment) })
          break
        } catch (error) {
          if (attempt >= retries) {
            throw error
          }
          log(
            `${platform}/${framework}: run ${index} failed, retrying (${error.message})`,
          )
        }
      }
      log(
        `${platform}/${framework}: run ${index + 1}/${total}${index < warmup ? ' (warm-up)' : ''}`,
      )
    }
  } finally {
    await device.call(['logs', 'stop']).catch(() => {})
  }
  await device.call(['close']).catch(() => {})

  const all = runs.map(({ markers, ...run }, index) => ({
    index,
    warmup: index < warmup,
    ...run,
    timings: computeTimings(markers),
  }))
  const measured = all.filter((run) => !run.warmup)

  return {
    framework,
    platform,
    build,
    physical,
    appId: id,
    device: {
      name: opened.device,
      id: opened.id,
      ...(options['device-label'] ? { label: options['device-label'] } : {}),
    },
    measuredAt: new Date().toISOString(),
    agentDevice: await AgentDevice.version(),
    iterations,
    warmup,
    appSizeBytes: await sizeOf(artifact),
    summary: {
      timingsMs: summarizeRuns(measured, (run) => run.timings),
      memoryKb: summarizeRuns(measured, (run) => run.memoryKb),
      startupRoundtripMs: summarize(
        measured.map((run) => run.startupRoundtripMs),
      ),
    },
    runs: all,
  }
}

const outDir = path.resolve(
  path.dirname(fileURLToPath(import.meta.url)),
  options.out,
  resultsName,
)
await mkdir(outDir, { recursive: true })

/** React Native's debug build loads its JavaScript from Metro. */
const METRO_PORT = 8081
const needsMetro = build === 'debug' && frameworks.includes('expo')
if (needsMetro) {
  const status = await fetch(`http://127.0.0.1:${METRO_PORT}/status`)
    .then((response) => response.text())
    .catch(() => '')
  if (!status.includes('packager-status:running')) {
    console.error(
      'The Expo debug build loads its JavaScript from Metro. Start it first:\n' +
        '  cd ../expo/expo-app && npx expo start',
    )
    process.exit(1)
  }
}

if (platform === 'android') {
  await reversePort(MOCK_SERVER_PORT, { serial: options.serial })
  if (needsMetro) {
    await reversePort(METRO_PORT, { serial: options.serial })
  }
}

for (const framework of frameworks) {
  const result = await measure(framework)
  const file = path.join(outDir, `${platform}-${framework}.json`)
  await writeFile(file, `${JSON.stringify(result, null, 2)}\n`)

  const timings = Object.entries(result.summary.timingsMs)
    .map(([key, value]) => `${key}=${value?.median ?? '-'}`)
    .join(' ')
  log(`${platform}/${framework}: ${timings}`)
  log(`${platform}/${framework}: wrote ${path.relative(process.cwd(), file)}`)
}
