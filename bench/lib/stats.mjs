/**
 * Summary statistics for a handful of samples. Benchmark runs on simulators
 * are noisy, so the median is the headline number and the spread is kept
 * alongside it.
 */
export function summarize(samples) {
  const values = samples
    .filter((value) => typeof value === 'number' && Number.isFinite(value))
    .sort((a, b) => a - b)
  if (values.length === 0) {
    return null
  }

  const mean = values.reduce((sum, value) => sum + value, 0) / values.length
  const middle = Math.floor(values.length / 2)
  const median =
    values.length % 2 === 0
      ? (values[middle - 1] + values[middle]) / 2
      : values[middle]
  const variance =
    values.reduce((sum, value) => sum + (value - mean) ** 2, 0) / values.length

  return {
    n: values.length,
    median,
    mean,
    min: values[0],
    max: values[values.length - 1],
    stdev: Math.sqrt(variance),
  }
}
