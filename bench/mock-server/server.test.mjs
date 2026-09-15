import assert from 'node:assert/strict'
import { after, before, describe, it } from 'node:test'

import { createMockServer, HOST } from './server.mjs'

describe('mock server', () => {
  let server
  let origin

  before(async () => {
    server = createMockServer()
    await new Promise((resolve) => server.listen(0, HOST, resolve))
    origin = `http://${HOST}:${server.address().port}`
  })

  after(() => new Promise((resolve) => server.close(resolve)))

  it('answers a search with the recorded 20-item page', async () => {
    const response = await fetch(
      `${origin}/search/repositories?q=expo&sort=stars&order=desc&per_page=20`,
    )

    assert.equal(response.status, 200)
    const body = await response.json()
    assert.equal(body.items.length, 20)
    assert.equal(body.items[0].full_name, 'expo/expo')
  })

  it('carries every field the apps decode', async () => {
    const response = await fetch(`${origin}/search/repositories?q=swift`)
    const [item] = (await response.json()).items

    assert.deepEqual(Object.keys(item).sort(), [
      'description',
      'full_name',
      'html_url',
      'id',
      'language',
      'stargazers_count',
    ])
  })

  it('rejects a search without a query like the real API', async () => {
    const response = await fetch(`${origin}/search/repositories`)

    assert.equal(response.status, 422)
    assert.equal((await response.json()).message, 'Validation Failed')
  })

  it('answers anything else with 404', async () => {
    const response = await fetch(`${origin}/users/octocat`)

    assert.equal(response.status, 404)
  })

  it('waits for the configured delay', async () => {
    const slow = createMockServer({ delayMs: 50 })
    await new Promise((resolve) => slow.listen(0, HOST, resolve))
    try {
      const startedAt = performance.now()
      await fetch(
        `http://${HOST}:${slow.address().port}/search/repositories?q=a`,
      )
      assert.ok(performance.now() - startedAt >= 45)
    } finally {
      await new Promise((resolve) => slow.close(resolve))
    }
  })
})
