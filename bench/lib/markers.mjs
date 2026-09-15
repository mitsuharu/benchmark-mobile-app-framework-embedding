/**
 * Reads the `BENCH|<name>|<epochMs>` markers every implementation writes to
 * the app log (see AGENTS.md) and turns one run's markers into durations.
 */

const MARKER = /BENCH\|([A-Za-z]+)\|(\d+)/

/**
 * Every marker found in a log, in the order it was written. iOS apps write
 * each marker both to unified logging and to stderr (a physical iPhone's log
 * only has the latter), so a log can hold the same marker twice; repeats of
 * the same name and time are kept once.
 */
export function parseMarkers(log) {
  const markers = []
  const seen = new Set()
  for (const line of log.split('\n')) {
    const match = MARKER.exec(line)
    if (!match) {
      continue
    }
    const key = `${match[1]}|${match[2]}`
    if (seen.has(key)) {
      continue
    }
    seen.add(key)
    markers.push({ name: match[1], epochMs: Number(match[2]) })
  }
  return markers
}

/**
 * The first `end` marker written at or after `start`, paired with it.
 * Returns the duration in milliseconds, or null when either is missing.
 */
function between(markers, startName, endName, occurrence = 0) {
  const starts = markers.filter((marker) => marker.name === startName)
  const start = starts[occurrence]
  if (!start) {
    return null
  }
  const end = markers.find(
    (marker) => marker.name === endName && marker.epochMs >= start.epochMs,
  )
  return end ? end.epochMs - start.epochMs : null
}

/**
 * Durations for one run of the scenario in bench/README.md: a cold launch,
 * the embedded screen opened twice, one search and one keyword command.
 */
export function computeTimings(markers) {
  // Markers can arrive out of order when the embedded side hands its
  // timestamps to the host over a channel, so pair them by time.
  const sorted = [...markers].sort((a, b) => a.epochMs - b.epochMs)
  return {
    coldStartMs: between(sorted, 'processStart', 'hostFirstFrame'),
    embedOpenColdMs: between(sorted, 'embedOpenTapped', 'embedFirstFrame', 0),
    embedOpenWarmMs: between(sorted, 'embedOpenTapped', 'embedFirstFrame', 1),
    searchRenderMs: between(sorted, 'searchTapped', 'searchRendered'),
    searchToHostMs: between(sorted, 'searchTapped', 'resultsReceived'),
    commandMs: between(sorted, 'commandSent', 'keywordApplied'),
  }
}
