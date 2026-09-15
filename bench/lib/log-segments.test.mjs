import assert from 'node:assert/strict'
import { describe, it } from 'node:test'

import { iterationLabel, splitByIteration } from './log-segments.mjs'

describe('splitByIteration', () => {
  const log = [
    'noise before the first run',
    `[agent-device] mark ${iterationLabel(0)}`,
    'BENCH|processStart|1',
    `[agent-device] mark ${iterationLabel(1)}`,
    'BENCH|processStart|2',
    'BENCH|hostFirstFrame|3',
  ].join('\n')

  it('gives each run the lines after its mark', () => {
    assert.deepEqual(splitByIteration(log, 2), [
      'BENCH|processStart|1',
      'BENCH|processStart|2\nBENCH|hostFirstFrame|3',
    ])
  })

  it('starts a retried run at its last mark', () => {
    const retried = [
      `mark ${iterationLabel(0)}`,
      'BENCH|processStart|1',
      `mark ${iterationLabel(0)}`,
      'BENCH|processStart|2',
    ].join('\n')

    assert.deepEqual(splitByIteration(retried, 1), ['BENCH|processStart|2'])
  })

  it('does not confuse run 1 with run 10', () => {
    const many = [
      `mark ${iterationLabel(1)}`,
      'BENCH|a|1',
      `mark ${iterationLabel(10)}`,
      'BENCH|a|10',
    ].join('\n')

    assert.equal(
      splitByIteration(many, 2)[1],
      'BENCH|a|1\nmark bench-iteration-10\nBENCH|a|10',
    )
  })

  it('returns an empty chunk for a run that left no mark', () => {
    assert.deepEqual(splitByIteration('', 1), [''])
  })
})
