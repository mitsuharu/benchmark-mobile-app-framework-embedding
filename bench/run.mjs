#!/usr/bin/env node
/**
 * Runs the benchmark scenario against the benchmark builds in artifacts/ and
 * writes the raw numbers to results/<platform>-<framework>.json.
 *
 *   node run.mjs --platform ios --framework native
 *   node run.mjs --platform android --framework all --iterations 10
 *
 * Build the apps first with scripts/build.sh, and keep mock-server running.
 */
import { mkdir, readdir, readFile, stat, writeFile } from 'node:fs/promises'
import path from 'node:path'
import { fileURLToPath } from 'node:url'
import { parseArgs } from 'node:util'

import { AgentDevice } from './lib/agent-device.mjs'
import { iterationLabel, splitByIteration } from './lib/log-segments.mjs'
import { computeTimings, parseMarkers } from './lib/markers.mjs'
import { runScenario } from './lib/scenario.mjs'
import { summarize } from './lib/stats.mjs'
import { appId, artifactPath, FRAMEWORKS, PLATFORMS } from './lib/targets.mjs'

const { values: options } = parseArgs({
  options: {
    platform: { type: 'string' },
    framework: { type: 'string', default: 'all' },
    iterations: { type: 'string', default: '5' },
    warmup: { type: 'string', default: '1' },
    retries: { type: 'string', default: '2' },
    'settle-ms': { type: 'string', default: '2000' },
    device: { type: 'string' },
    udid: { type: 'string' },
    serial: { type: 'string' },
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
  const artifact = artifactPath(framework, platform)
  const device = new AgentDevice({
    session: `bench-${platform}`,
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
  await device.call(['logs', 'clear', '--restart'])

  const total = warmup + iterations
  const runs = []
  try {
    for (let index = 0; index < total; index++) {
      for (let attempt = 0; ; attempt++) {
        await device.call(['logs', 'mark', iterationLabel(index)])
        try {
          runs.push(
            await runScenario(device, { appId: id, platform, settleMs }),
          )
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
    // Let the log stream flush the last run's markers.
    await device.call(['wait', '1500'])
  } finally {
    await device.call(['logs', 'stop']).catch(() => {})
  }

  // agent-device rotates app.log to app.log.1 past 5 MB and keeps one
  // generation, so a long run's first iterations can sit in the older file.
  const { path: logPath } = await device.call(['logs', 'path'])
  const readIfPresent = (file) => readFile(file, 'utf8').catch(() => '')
  const log = `${await readIfPresent(`${logPath}.1`)}\n${await readFile(logPath, 'utf8')}`
  const segments = splitByIteration(log, total)
  await device.call(['close']).catch(() => {})

  const all = runs.map((run, index) => ({
    index,
    warmup: index < warmup,
    ...run,
    timings: computeTimings(parseMarkers(segments[index])),
  }))
  const measured = all.filter((run) => !run.warmup)

  return {
    framework,
    platform,
    appId: id,
    device: { name: opened.device, id: opened.id },
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
)
await mkdir(outDir, { recursive: true })

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
