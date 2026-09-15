import assert from 'node:assert/strict'
import { describe, it } from 'node:test'

import { summarize } from './stats.mjs'

describe('summarize', () => {
  it('takes the middle value of an odd number of samples', () => {
    const summary = summarize([30, 10, 20])

    assert.equal(summary.median, 20)
    assert.equal(summary.min, 10)
    assert.equal(summary.max, 30)
    assert.equal(summary.mean, 20)
    assert.equal(summary.n, 3)
  })

  it('averages the two middle values of an even number of samples', () => {
    assert.equal(summarize([40, 10, 20, 30]).median, 25)
  })

  it('skips runs where the step was not measured', () => {
    assert.equal(summarize([10, null, 30]).n, 2)
  })

  it('returns null when nothing was measured', () => {
    assert.equal(summarize([null, undefined]), null)
    assert.equal(summarize([]), null)
  })

  it('reports the spread', () => {
    assert.equal(summarize([2, 4, 4, 4, 5, 5, 7, 9]).stdev, 2)
  })
})
