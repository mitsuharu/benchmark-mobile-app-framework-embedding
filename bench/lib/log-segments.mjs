/**
 * Splits the session app log into one chunk per scenario run.
 *
 * The runner writes `agent-device logs mark <label>` before each run, and the
 * app's markers for that run follow it in the log. A run that is retried is
 * marked again, so a run starts at the *last* mark with its label.
 */
export const iterationLabel = (index) => `bench-iteration-${index}`

const hasLabel = (line, index) =>
  new RegExp(`\\b${iterationLabel(index)}\\b`).test(line)

export function splitByIteration(log, count) {
  const lines = log.split('\n')
  const segments = []
  for (let index = 0; index < count; index++) {
    const start = lines.findLastIndex((line) => hasLabel(line, index))
    if (start === -1) {
      segments.push('')
      continue
    }
    const next = lines.findIndex(
      (line, at) => at > start && hasLabel(line, index + 1),
    )
    segments.push(
      lines.slice(start + 1, next === -1 ? undefined : next).join('\n'),
    )
  }
  return segments
}
