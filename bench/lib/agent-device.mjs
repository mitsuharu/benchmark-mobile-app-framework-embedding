/**
 * A thin wrapper around the agent-device CLI.
 *
 * The runner shells out to the CLI rather than using the Node API so that
 * every step it takes can be replayed by hand from a terminal, flag for flag.
 */
import { execFile } from 'node:child_process'
import { fileURLToPath } from 'node:url'
import { promisify } from 'node:util'

const execFileAsync = promisify(execFile)

const BIN = fileURLToPath(
  new URL('../node_modules/.bin/agent-device', import.meta.url),
)

export class AgentDeviceError extends Error {
  constructor(args, detail) {
    super(`agent-device ${args.join(' ')}: ${detail?.message ?? 'failed'}`)
    this.code = detail?.code
    this.detail = detail
  }
}

const parse = (stdout) => {
  try {
    return JSON.parse(stdout)
  } catch {
    return null
  }
}

export class AgentDevice {
  /**
   * @param {object} options
   * @param {string} options.session Name of the agent-device session. One per
   *   platform, so iOS and Android runs never pick up each other's device.
   * @param {(line: string) => void} [options.log]
   */
  constructor({ session, log = () => {} }) {
    this.session = session
    this.log = log
  }

  /** Runs one command and returns its `data` payload. */
  async call(args, { timeoutMs = 180_000 } = {}) {
    this.log(`agent-device ${args.join(' ')}`)
    try {
      const { stdout } = await execFileAsync(
        BIN,
        [...args, '--session', this.session, '--json'],
        { timeout: timeoutMs, maxBuffer: 32 * 1024 * 1024 },
      )
      const result = parse(stdout)
      if (!result?.success) {
        throw new AgentDeviceError(args, result?.error)
      }
      return result.data
    } catch (error) {
      if (error instanceof AgentDeviceError) {
        throw error
      }
      // A non-zero exit still prints the JSON error on stdout.
      const result = parse(error.stdout ?? '')
      throw new AgentDeviceError(
        args,
        result?.error ?? { message: error.message },
      )
    }
  }

  static async version() {
    const { stdout } = await execFileAsync(BIN, ['--version'])
    return stdout.trim()
  }
}
