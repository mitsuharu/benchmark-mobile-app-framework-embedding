import assert from 'node:assert/strict'
import { describe, it } from 'node:test'

import { memoryKb } from './scenario.mjs'

// Trimmed from real `agent-device perf memory sample --json` output.
const ios = {
  metrics: {
    memory: {
      available: true,
      residentMemoryKb: 253136,
      method: 'ps-process-snapshot',
    },
  },
}
const android = {
  metrics: {
    memory: {
      available: true,
      totalPssKb: 55152,
      totalRssKb: 185924,
      method: 'adb-shell-dumpsys-meminfo',
    },
  },
}

describe('memoryKb', () => {
  it('reads the resident size on iOS', () => {
    assert.equal(memoryKb(ios, 'ios'), 253136)
  })

  it('reads PSS on Android', () => {
    assert.equal(memoryKb(android, 'android'), 55152)
  })

  it('reports an unavailable sample as null', () => {
    assert.equal(
      memoryKb({ metrics: { memory: { available: false } } }, 'ios'),
      null,
    )
    assert.equal(memoryKb(undefined, 'android'), null)
  })
})
