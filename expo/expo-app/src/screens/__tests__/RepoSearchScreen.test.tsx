import { act, fireEvent, render, waitFor } from '@testing-library/react-native'
import { popToNative } from 'expo-brownfield'

import { searchRepositories } from '../../api/github'
import {
  addKeywordListener,
  markAfterFrame,
  markBench,
  notifySearchFailed,
  notifySearchSucceeded,
} from '../../native/bridge'
import { RepoSearchScreen } from '../RepoSearchScreen'

jest.mock('expo-brownfield', () => ({
  popToNative: jest.fn(),
  sendMessage: jest.fn(),
}))
jest.mock('../../api/github', () => ({ searchRepositories: jest.fn() }))
jest.mock('../../native/bridge', () => ({
  notifySearchSucceeded: jest.fn(),
  notifySearchFailed: jest.fn(),
  addKeywordListener: jest.fn(() => () => {}),
  markBench: jest.fn(),
  markAfterFrame: jest.fn(),
}))

/** What the benchmark build hands over through `initialProps`. */
const API = 'http://127.0.0.1:8787'

const searchMock = searchRepositories as jest.MockedFunction<
  typeof searchRepositories
>

const results = [
  {
    id: 65750241,
    fullName: 'expo/expo',
    description: 'An open-source framework',
    stars: 51842,
    language: 'TypeScript',
    htmlUrl: 'https://github.com/expo/expo',
  },
  {
    id: 1,
    fullName: 'a/b',
    description: null,
    stars: 0,
    language: null,
    htmlUrl: 'https://github.com/a/b',
  },
]

describe('RepoSearchScreen', () => {
  beforeEach(() => jest.clearAllMocks())

  it('shows the keyword handed over by the host app', async () => {
    const { getByText } = await render(
      <RepoSearchScreen apiBaseUrl={API} initialKeyword="expo-brownfield" />,
    )

    expect(getByText('keyword: expo-brownfield')).toBeTruthy()
  })

  it('does not search until the button is pressed', async () => {
    const { getByText } = await render(
      <RepoSearchScreen apiBaseUrl={API} initialKeyword="expo" />,
    )

    expect(searchMock).not.toHaveBeenCalled()
    expect(getByText('ボタンを押すと検索結果が表示されます。')).toBeTruthy()
  })

  it('lists the repositories returned for the keyword', async () => {
    searchMock.mockResolvedValue(results)
    const { getByText } = await render(
      <RepoSearchScreen apiBaseUrl={API} initialKeyword="expo" />,
    )

    await fireEvent.press(getByText('リポジトリを検索'))

    await waitFor(() => expect(getByText('expo/expo')).toBeTruthy())
    expect(searchMock).toHaveBeenCalledWith('expo', 20, API)
    expect(getByText('★ 51,842 · TypeScript')).toBeTruthy()
    // A repository with no language shows the star count on its own.
    expect(getByText('★ 0')).toBeTruthy()
  })

  it('reports the results back to the host app', async () => {
    searchMock.mockResolvedValue(results)
    const { getByText } = await render(
      <RepoSearchScreen apiBaseUrl={API} initialKeyword="expo" />,
    )

    await fireEvent.press(getByText('リポジトリを検索'))

    await waitFor(() =>
      expect(notifySearchSucceeded).toHaveBeenCalledWith('expo', results),
    )
    expect(notifySearchFailed).not.toHaveBeenCalled()
  })

  it('shows the failure and reports it to the host app', async () => {
    searchMock.mockRejectedValue(new Error('API rate limit exceeded'))
    const { getByText } = await render(
      <RepoSearchScreen apiBaseUrl={API} initialKeyword="expo" />,
    )

    await fireEvent.press(getByText('リポジトリを検索'))

    await waitFor(() =>
      expect(getByText('API rate limit exceeded')).toBeTruthy(),
    )
    expect(notifySearchFailed).toHaveBeenCalledWith(
      'expo',
      'API rate limit exceeded',
    )
    expect(notifySearchSucceeded).not.toHaveBeenCalled()
  })

  it('asks the host app to close the screen', async () => {
    const { getByText } = await render(
      <RepoSearchScreen apiBaseUrl={API} initialKeyword="expo" />,
    )

    await fireEvent.press(getByText('ネイティブに戻る'))

    expect(popToNative).toHaveBeenCalledWith(true)
  })

  it('follows a keyword the host app sends while the screen is open', async () => {
    // initialProps cannot change once the screen exists, so the host app sends
    // the new keyword over the message channel instead.
    const listener = addKeywordListener as jest.MockedFunction<
      typeof addKeywordListener
    >
    searchMock.mockResolvedValue(results)
    const { getByText } = await render(
      <RepoSearchScreen apiBaseUrl={API} initialKeyword="expo" />,
    )

    const [onKeyword] = listener.mock.calls[0]
    await act(async () => onKeyword('swift'))

    expect(getByText('keyword: swift')).toBeTruthy()

    await fireEvent.press(getByText('リポジトリを検索'))
    await waitFor(() =>
      expect(searchMock).toHaveBeenCalledWith('swift', 20, API),
    )
  })

  it('clears the previous results when the keyword is replaced', async () => {
    const listener = addKeywordListener as jest.MockedFunction<
      typeof addKeywordListener
    >
    searchMock.mockResolvedValue(results)
    const { getByText, queryByText } = await render(
      <RepoSearchScreen apiBaseUrl={API} initialKeyword="expo" />,
    )
    await fireEvent.press(getByText('リポジトリを検索'))
    await waitFor(() => expect(getByText('expo/expo')).toBeTruthy())

    const [onKeyword] = listener.mock.calls[0]
    await act(async () => onKeyword('swift'))

    expect(queryByText('expo/expo')).toBeNull()
  })
})

describe('RepoSearchScreen benchmark markers', () => {
  beforeEach(() => jest.clearAllMocks())

  it('marks its first frame', async () => {
    await render(<RepoSearchScreen apiBaseUrl={API} initialKeyword="expo" />)

    expect(markAfterFrame).toHaveBeenCalledWith('embedFirstFrame')
  })

  it('marks the tap and the rendered results of a search', async () => {
    searchMock.mockResolvedValue(results)
    const { getByText } = await render(
      <RepoSearchScreen apiBaseUrl={API} initialKeyword="expo" />,
    )

    await fireEvent.press(getByText('リポジトリを検索'))

    expect(markBench).toHaveBeenCalledWith('searchTapped')
    await waitFor(() =>
      expect(markAfterFrame).toHaveBeenCalledWith('searchRendered'),
    )
  })

  it('marks a keyword the host replaced, but not the initial one', async () => {
    const listener = addKeywordListener as jest.MockedFunction<
      typeof addKeywordListener
    >
    await render(<RepoSearchScreen apiBaseUrl={API} initialKeyword="expo" />)
    expect(markAfterFrame).not.toHaveBeenCalledWith('keywordApplied')

    const [onKeyword] = listener.mock.calls[0]
    await act(async () => onKeyword('swift'))

    expect(markAfterFrame).toHaveBeenCalledWith('keywordApplied')
  })

  it('does not mark results when a search fails', async () => {
    searchMock.mockRejectedValue(new Error('API rate limit exceeded'))
    const { getByText } = await render(
      <RepoSearchScreen apiBaseUrl={API} initialKeyword="expo" />,
    )

    await fireEvent.press(getByText('リポジトリを検索'))
    await waitFor(() => expect(notifySearchFailed).toHaveBeenCalled())

    expect(markAfterFrame).not.toHaveBeenCalledWith('searchRendered')
  })
})
