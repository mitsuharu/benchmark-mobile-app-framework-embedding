/**
 * Minimal GitHub Search API client.
 * https://docs.github.com/en/rest/search/search#search-repositories
 */

export const DEFAULT_API_BASE_URL = 'https://api.github.com'

export type Repository = {
  id: number
  fullName: string
  description: string | null
  stars: number
  language: string | null
  htmlUrl: string
}

type SearchResponse = {
  total_count: number
  items: {
    id: number
    full_name: string
    description: string | null
    stargazers_count: number
    language: string | null
    html_url: string
  }[]
  message?: string
}

/**
 * @param baseUrl Where to send the request. The benchmark build points this
 *   at bench/mock-server through `initialProps`.
 */
export async function searchRepositories(
  keyword: string,
  perPage: number = 20,
  baseUrl: string = DEFAULT_API_BASE_URL,
): Promise<Repository[]> {
  const query = new URLSearchParams({
    q: keyword,
    sort: 'stars',
    order: 'desc',
    per_page: String(perPage),
  })

  const endpoint = `${baseUrl.replace(/\/+$/, '')}/search/repositories`
  const response = await fetch(`${endpoint}?${query.toString()}`, {
    headers: {
      Accept: 'application/vnd.github+json',
      'X-GitHub-Api-Version': '2022-11-28',
    },
  })

  const json = (await response.json()) as SearchResponse

  if (!response.ok) {
    // Unauthenticated search is rate limited to 10 requests / minute.
    throw new Error(
      json.message ?? `GitHub API responded with ${response.status}`,
    )
  }

  return json.items.map((item) => ({
    id: item.id,
    fullName: item.full_name,
    description: item.description,
    stars: item.stargazers_count,
    language: item.language,
    htmlUrl: item.html_url,
  }))
}
