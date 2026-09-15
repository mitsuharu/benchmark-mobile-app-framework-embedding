import { searchRepositories } from '../github'

describe('searchRepositories', () => {
  const fetchMock = jest.fn()

  beforeEach(() => {
    fetchMock.mockReset()
    globalThis.fetch = fetchMock as unknown as typeof fetch
  })

  const respondWith = (body: unknown, ok = true, status = 200) => {
    fetchMock.mockResolvedValue({ ok, status, json: async () => body })
  }

  it('sends the request to the configured base url', async () => {
    // The benchmark build points the client at bench/mock-server.
    respondWith({ total_count: 0, items: [] })

    await searchRepositories('expo', 20, 'http://127.0.0.1:8787/')

    const [url] = fetchMock.mock.calls[0]
    const parsed = new URL(url as string)
    expect(parsed.origin).toBe('http://127.0.0.1:8787')
    expect(parsed.pathname).toBe('/search/repositories')
  })

  it('uses the real API by default', async () => {
    respondWith({ total_count: 0, items: [] })

    await searchRepositories('expo')

    const [url] = fetchMock.mock.calls[0]
    expect(new URL(url as string).origin).toBe('https://api.github.com')
  })

  it('queries the keyword sorted by stars', async () => {
    respondWith({ total_count: 0, items: [] })

    await searchRepositories('expo')

    const [url, init] = fetchMock.mock.calls[0]
    const { searchParams } = new URL(url as string)
    expect(searchParams.get('q')).toBe('expo')
    expect(searchParams.get('sort')).toBe('stars')
    expect(searchParams.get('order')).toBe('desc')
    expect(searchParams.get('per_page')).toBe('20')
    expect((init as RequestInit).headers).toMatchObject({
      Accept: 'application/vnd.github+json',
    })
  })

  it('honours a custom page size', async () => {
    respondWith({ total_count: 0, items: [] })

    await searchRepositories('expo', 5)

    const [url] = fetchMock.mock.calls[0]
    expect(new URL(url as string).searchParams.get('per_page')).toBe('5')
  })

  it('maps the response onto the Repository shape', async () => {
    respondWith({
      total_count: 1,
      items: [
        {
          id: 65750241,
          full_name: 'expo/expo',
          description: 'An open-source framework',
          stargazers_count: 51842,
          language: 'TypeScript',
          html_url: 'https://github.com/expo/expo',
        },
      ],
    })

    await expect(searchRepositories('expo')).resolves.toEqual([
      {
        id: 65750241,
        fullName: 'expo/expo',
        description: 'An open-source framework',
        stars: 51842,
        language: 'TypeScript',
        htmlUrl: 'https://github.com/expo/expo',
      },
    ])
  })

  it('keeps null description and language as null', async () => {
    respondWith({
      total_count: 1,
      items: [
        {
          id: 1,
          full_name: 'a/b',
          description: null,
          stargazers_count: 0,
          language: null,
          html_url: 'https://github.com/a/b',
        },
      ],
    })

    const [repository] = await searchRepositories('expo')
    expect(repository.description).toBeNull()
    expect(repository.language).toBeNull()
  })

  it('surfaces the API message when the request is rejected', async () => {
    // Unauthenticated search is rate limited to 10 requests / minute.
    respondWith({ message: 'API rate limit exceeded' }, false, 403)

    await expect(searchRepositories('expo')).rejects.toThrow(
      'API rate limit exceeded',
    )
  })

  it('falls back to the status code when there is no message', async () => {
    respondWith({}, false, 500)

    await expect(searchRepositories('expo')).rejects.toThrow('500')
  })
})
