import assert from 'node:assert/strict'
import { describe, it } from 'node:test'

import { computeTimings, parseMarkers } from './markers.mjs'

describe('parseMarkers', () => {
  it('reads markers out of unified logging and logcat lines', () => {
    const log = [
      '2026-09-15 10:00:00.000 HostApp[123:456] [bench:marker] BENCH|processStart|1000',
      '09-15 10:00:00.100  1234  1234 I Bench   : BENCH|hostFirstFrame|1350',
      'unrelated line',
    ].join('\n')

    assert.deepEqual(parseMarkers(log), [
      { name: 'processStart', epochMs: 1000 },
      { name: 'hostFirstFrame', epochMs: 1350 },
    ])
  })

  it('ignores redacted values', () => {
    // What a Logger interpolation without `privacy: .public` looks like.
    assert.deepEqual(parseMarkers('BENCH|<private>|<private>'), [])
  })
})

describe('computeTimings', () => {
  const run = [
    ['processStart', 1000],
    ['hostFirstFrame', 1400],
    ['embedOpenTapped', 5000],
    ['embedFirstFrame', 5300],
    ['searchTapped', 8000],
    ['resultsReceived', 8120],
    ['searchRendered', 8100],
    ['commandSent', 9000],
    ['keywordApplied', 9030],
    ['embedOpenTapped', 12000],
    ['embedFirstFrame', 12100],
  ].map(([name, epochMs]) => ({ name, epochMs }))

  it('measures each step of the scenario', () => {
    assert.deepEqual(computeTimings(run), {
      coldStartMs: 400,
      embedOpenColdMs: 300,
      embedOpenWarmMs: 100,
      searchRenderMs: 100,
      searchToHostMs: 120,
      commandMs: 30,
    })
  })

  it('pairs markers by time, not by arrival order', () => {
    // The embedded side's markers can reach the log after the host's.
    const shuffled = [...run].reverse()

    assert.equal(computeTimings(shuffled).embedOpenWarmMs, 100)
  })

  it('reports a step that never finished as null', () => {
    const timings = computeTimings(
      run.filter((marker) => marker.name !== 'keywordApplied'),
    )

    assert.equal(timings.commandMs, null)
    assert.equal(timings.coldStartMs, 400)
  })

  it('reports a step that never started as null', () => {
    assert.equal(computeTimings([]).coldStartMs, null)
  })
})
