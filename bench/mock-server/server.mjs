#!/usr/bin/env node
/**
 * A stand-in for the GitHub Search API.
 *
 * Every implementation searches through this server during a benchmark run, so
 * the numbers depend neither on the network nor on GitHub's limit of 10
 * unauthenticated searches per minute. It answers `GET /search/repositories`
 * with a fixed 20-item page recorded from the real API, whatever the query.
 *
 *   node mock-server/server.mjs [--port 8787] [--host 127.0.0.1] [--delay-ms 0] [--quiet]
 */
import { readFileSync } from 'node:fs'
import { createServer } from 'node:http'
import { fileURLToPath } from 'node:url'
import { parseArgs } from 'node:util'

export const DEFAULT_PORT = 8787

/**
 * Loopback by default. The iOS simulator shares the host's network, and
 * Android devices and emulators reach it through `adb reverse`, so nothing
 * else on the LAN needs to see this server. A physical iPhone cannot reach
 * the Mac's loopback: run a second instance with `--host <the Mac's LAN
 * address>` for it.
 */
export const HOST = '127.0.0.1'

const FIXTURE_PATH = new URL(
  './fixtures/search-repositories.json',
  import.meta.url,
)

const json = (response, status, body) => {
  response.writeHead(status, {
    'content-type': 'application/json; charset=utf-8',
  })
  response.end(typeof body === 'string' ? body : JSON.stringify(body))
}

export function createMockServer({
  delayMs = 0,
  fixture = readFileSync(FIXTURE_PATH, 'utf8'),
  log = () => {},
} = {}) {
  return createServer((request, response) => {
    const url = new URL(request.url ?? '/', `http://${HOST}`)
    log(`${request.method} ${url.pathname}${url.search}`)

    if (request.method !== 'GET' || url.pathname !== '/search/repositories') {
      json(response, 404, { message: 'Not Found' })
      return
    }
    // Mirrors the real API, which rejects a search without a query.
    if (!url.searchParams.get('q')) {
      json(response, 422, { message: 'Validation Failed' })
      return
    }

    setTimeout(() => json(response, 200, fixture), delayMs)
  })
}

if (process.argv[1] === fileURLToPath(import.meta.url)) {
  const { values } = parseArgs({
    options: {
      port: { type: 'string', default: String(DEFAULT_PORT) },
      host: { type: 'string', default: HOST },
      'delay-ms': { type: 'string', default: '0' },
      quiet: { type: 'boolean', default: false },
    },
  })

  const server = createMockServer({
    delayMs: Number(values['delay-ms']),
    log: values.quiet
      ? () => {}
      : (line) => console.log(`[mock-server] ${line}`),
  })
  server.listen(Number(values.port), values.host, () => {
    console.log(
      `[mock-server] listening on http://${values.host}:${values.port}`,
    )
  })
}
