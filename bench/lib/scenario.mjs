/**
 * One run of the benchmark scenario, driven through agent-device.
 *
 * The durations come from the markers the apps log (see markers.mjs), not
 * from how long these commands take, so agent-device's own overhead does not
 * leak into the numbers. What this measures directly is memory, sampled once
 * the UI has settled at each stage.
 */

/**
 * How each platform exposes the controls. The labels are shared by every
 * implementation (AGENTS.md); only the way agent-device reaches them differs.
 */
export const SELECTORS = {
  ios: {
    openEmbedded: 'id="openEmbedded"',
    search: 'label="リポジトリを検索"',
    back: 'label="ネイティブに戻る"',
    // The keyword menu in the navigation bar. Its items appear twice in the
    // accessibility tree (the row and the button inside it), so pick the button.
    sendCommand: ['label="キーワード"', 'role="button" label="swift"'],
  },
  android: {
    openEmbedded: 'id="openEmbedded"',
    // The buttons look different on each framework: React Native exposes a
    // Pressable and the Text inside it as two actionable nodes with the same
    // text, while a Compose button is an unlabelled group around its Text.
    // Finding by text and taking the first match hits the button in both.
    search: { find: 'リポジトリを検索' },
    back: { find: 'ネイティブに戻る' },
    sendCommand: ['text="swift"'],
  },
}

/** Text that proves each stage has been reached. */
export const SEARCH_BUTTON_TEXT = 'リポジトリを検索'
export const FIRST_RESULT_TEXT = 'expo/expo'
export const COMMAND_APPLIED_TEXT = 'keyword: swift'

export const WAIT_MS = 30_000

/** Taps a control given as a selector or as `{ find: text }` (see SELECTORS). */
export function tap(device, target) {
  return device.call(
    typeof target === 'string'
      ? ['press', target]
      : ['find', target.find, 'click', '--first'],
  )
}

/** The process memory reported by `perf memory sample`, in kB. */
export function memoryKb(data, platform) {
  const memory = data?.metrics?.memory
  if (!memory?.available) {
    return null
  }
  // iOS simulators only expose the resident size (from `ps`). On Android, PSS
  // is the figure the system itself uses to account an app's memory.
  return (
    (platform === 'ios' ? memory.residentMemoryKb : memory.totalPssKb) ?? null
  )
}

/**
 * Relaunches the app and walks through the scenario once:
 * launch → open the embedded screen → search → send a keyword →
 * back to the host → open the embedded screen again → back.
 *
 * With `relaunch: false` the app is expected to have just been launched
 * already (see run.mjs), and is only brought to the front.
 */
export async function runScenario(
  device,
  { appId, platform, settleMs, relaunch = true },
) {
  const selectors = SELECTORS[platform]
  const memory = {}

  const settleAndSample = async (stage) => {
    await device.call(['wait', String(settleMs)])
    memory[stage] = memoryKb(
      await device.call(['perf', 'memory', 'sample']),
      platform,
    )
  }
  const openEmbedded = async () => {
    await device.call(['press', selectors.openEmbedded])
    await device.call(['wait', 'text', SEARCH_BUTTON_TEXT, String(WAIT_MS)])
  }
  const backToHost = async () => {
    await tap(device, selectors.back)
    await device.call(['wait', selectors.openEmbedded, String(WAIT_MS)])
  }

  const opened = await device.call(
    relaunch ? ['open', appId, '--relaunch'] : ['open', appId],
  )
  await device.call(['wait', selectors.openEmbedded, String(WAIT_MS)])
  await settleAndSample('hostIdle')

  await openEmbedded()
  await settleAndSample('embedOpened')

  await tap(device, selectors.search)
  await device.call(['wait', 'text', FIRST_RESULT_TEXT, String(WAIT_MS)])
  await settleAndSample('afterSearch')

  for (const selector of selectors.sendCommand) {
    await device.call(['press', selector])
  }
  await device.call(['wait', 'text', COMMAND_APPLIED_TEXT, String(WAIT_MS)])

  await backToHost()
  await settleAndSample('backToHost')

  // The second visit shows what reusing the embedded runtime costs.
  await openEmbedded()
  await backToHost()

  return {
    startupRoundtripMs: opened?.startup?.durationMs ?? null,
    memoryKb: memory,
  }
}
