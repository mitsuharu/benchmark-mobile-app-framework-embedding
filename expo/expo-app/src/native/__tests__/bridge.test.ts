import { sendMessage } from 'expo-brownfield'

import type { Repository } from '../../api/github'
import {
  DEFAULT_KEYWORD,
  markAfterFrame,
  markBench,
  notifySearchFailed,
  notifySearchSucceeded,
} from '../bridge'

jest.mock('expo-brownfield', () => ({
  sendMessage: jest.fn(),
  popToNative: jest.fn(),
}))

const sendMessageMock = sendMessage as jest.MockedFunction<typeof sendMessage>

const repository = (overrides: Partial<Repository> = {}): Repository => ({
  id: 65750241,
  fullName: 'expo/expo',
  description: 'An open-source framework',
  stars: 51842,
  language: 'TypeScript',
  htmlUrl: 'https://github.com/expo/expo',
  ...overrides,
})

describe('notifySearchSucceeded', () => {
  beforeEach(() => sendMessageMock.mockReset())

  it('sends the keyword along with the results', () => {
    notifySearchSucceeded('expo', [repository()])

    expect(sendMessageMock).toHaveBeenCalledTimes(1)
    const [message] = sendMessageMock.mock.calls[0]
    expect(message.type).toBe('searchSucceeded')
    expect(message.keyword).toBe('expo')
    expect(message.repositories).toHaveLength(1)
  })

  it('sends only the fields native consumes', () => {
    notifySearchSucceeded('expo', [repository()])

    const [message] = sendMessageMock.mock.calls[0]
    expect(Object.keys(message.repositories[0]).sort()).toEqual([
      'fullName',
      'id',
      'language',
      'stars',
    ])
  })

  it('never sends a nested null', () => {
    // Android cannot convert a nested null to a Kotlin type:
    // "Cannot convert '[object Object]' to a Kotlin type. Value is null".
    notifySearchSucceeded('expo', [
      repository({ language: null, description: null }),
    ])

    const [message] = sendMessageMock.mock.calls[0]
    expect(message.repositories[0].language).toBe('')
    expect(JSON.stringify(message)).not.toContain('null')
  })

  it('sends an empty list unchanged', () => {
    notifySearchSucceeded('expo', [])

    const [message] = sendMessageMock.mock.calls[0]
    expect(message.repositories).toEqual([])
  })
})

describe('notifySearchFailed', () => {
  beforeEach(() => sendMessageMock.mockReset())

  it('sends the keyword and the error message', () => {
    notifySearchFailed('expo', 'API rate limit exceeded')

    expect(sendMessageMock).toHaveBeenCalledWith({
      type: 'searchFailed',
      keyword: 'expo',
      message: 'API rate limit exceeded',
    })
  })
})

describe('DEFAULT_KEYWORD', () => {
  it('is used when the host app passes no initialProps', () => {
    expect(DEFAULT_KEYWORD).toBe('expo')
  })
})

describe('markBench', () => {
  beforeEach(() => sendMessageMock.mockReset())

  it('sends the marker with the time it was taken', () => {
    jest.spyOn(Date, 'now').mockReturnValue(1_789_434_143_650)

    markBench('searchTapped')

    expect(sendMessageMock).toHaveBeenCalledWith({
      type: 'benchMark',
      name: 'searchTapped',
      epochMs: 1_789_434_143_650,
    })
  })

  it('waits for two frames when asked to', () => {
    const frames: FrameRequestCallback[] = []
    jest
      .spyOn(globalThis, 'requestAnimationFrame')
      .mockImplementation((callback) => frames.push(callback))

    markAfterFrame('searchRendered')
    expect(sendMessageMock).not.toHaveBeenCalled()

    // The first frame draws the change; the second means it is on screen.
    frames[0](0)
    expect(sendMessageMock).not.toHaveBeenCalled()

    frames[1](0)
    expect(sendMessageMock).toHaveBeenCalledWith(
      expect.objectContaining({ type: 'benchMark', name: 'searchRendered' }),
    )
  })
})
